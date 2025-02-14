"Implementation details for the push rule"

load("//oci/private:util.bzl", "util")

_DOC = """Push an oci_image or oci_image_index to a remote registry.

Internal rule used by the [oci_push macro](/docs/push.md#oci_push).
Most users should use the macro.

Authorization
=============

By default, oci_push uses the standard authorization config file located on the host where `oci_push` is running.
Therefore the following documentation may be consulted:

- https://docs.docker.com/engine/reference/commandline/login/
- https://docs.podman.io/en/latest/markdown/podman-login.1.html
- https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_auth_login.md

Behavior
========

Pushing and tagging are performed sequentially which MAY lead to non-atomic pushes if one the following events occur;

- Remote registry rejects a tag due to various reasons. eg: forbidden characters, existing tags
- Remote registry closes the connection during the tagging
- Local network outages

In order to avoid incomplete pushes oci_push will push the image by its digest and then apply the `remote_tags` sequentially at
the remote registry.

Any failure during pushing or tagging will be reported with non-zero exit code and cause remaining steps to be skipped.

Usage
=====

When running the pusher, you can pass flags to `bazel run`.

1. Override `repository` by passing the `-r|--repository` flag.

e.g. `bazel run //myimage:push -- --repository index.docker.io/<ORG>/image`

2. Supply tags in addition to `remote_tags` by passing the `-t|--tag` flag.

e.g. `bazel run //myimage:push -- --tag latest`

Examples
========

Push an oci_image to docker registry with 'latest' tag

```starlark
oci_image(name = "image")

oci_push(
    name = "push",
    image = ":image",
    repository = "index.docker.io/<ORG>/image",
    remote_tags = ["latest"]
)
```

Push a multi-architecture image to github container registry with a semver tag

```starlark
load("@aspect_bazel_lib//lib:expand_template.bzl", "expand_template_rule")

oci_image(name = "app_linux_arm64")

oci_image(name = "app_linux_amd64")

oci_image(name = "app_windows_amd64")

oci_image_index(
    name = "app_image",
    images = [
        ":app_linux_arm64",
        ":app_linux_amd64",
        ":app_windows_amd64",
    ]
)

# Use the value of --embed_label under --stamp, otherwise use a deterministic constant
# value to ensure cache hits for actions that depend on this.
expand_template(
    name = "stamped",
    out = "_stamped.tags.txt",
    template = ["0.0.0"],
    stamp_substitutions = {"0.0.0": "{{BUILD_EMBED_LABEL}}"},
)

oci_push(
    name = "push",
    image = ":app_image",
    repository = "ghcr.io/<OWNER>/image",
    remote_tags = ":stamped",
)
```

To push to more than one registry, or using multiple remote tags,
use [rules_multirun] to group multiple oci_push targets into one executable target.

For example:

```starlark
load("@rules_multirun//:defs.bzl", "command", "multirun")

REPOS = {
    "index": "index.docker.io/<ORG>/image",
    "ECR": "aws_account_id.dkr.ecr.us-west-2.amazonaws.com",
}

[
    oci_push(
        name = "push_image_" + k,
        image = ":image_index",
        remote_tags = ":stamped",
        repository = v,
    )
    for (k, v) in REPOS.items()
]

[
    command(
        name = k,
        command = "push_image_" + k,
    )
    for k in REPOS.keys()
]

multirun(
    name = "push_all",
    commands = REPOS.keys(),
)
```

[rules_multirun]: https://github.com/keith/rules_multirun
"""

# Helper rule for ensuring that the crane and yq toolchains are actually
# resolved for the architecture we are targeting.
def _transition_to_target_impl(settings, _attr):
    return {
        # String conversion is needed to prevent a crash with Bazel 6.x.
        "//command_line_option:extra_execution_platforms": [
            str(platform)
            for platform in settings["//command_line_option:platforms"]
        ],
    }

_transition_to_target = transition(
    implementation = _transition_to_target_impl,
    inputs = ["//command_line_option:platforms"],
    outputs = ["//command_line_option:extra_execution_platforms"],
)

_attrs = {
    "image": attr.label(
        allow_single_file = True,
        doc = "Label to an oci_image or oci_image_index",
        mandatory = True,
    ),
    "repository": attr.string(
        doc = """\
        Repository URL where the image will be signed at, e.g.: `index.docker.io/<user>/image`.
        Digests and tags are not allowed.
        """,
    ),
    "repository_file": attr.label(
        doc = """\
        The same as 'repository' but in a file. This allows pushing to different repositories based on stamping.
        """,
        allow_single_file = True,
    ),
    "remote_tags": attr.label(
        doc = """\
        a text file containing tags, one per line.
        These are passed to [`crane tag`](
        https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_tag.md)
        """,
        allow_single_file = True,
    ),
    "retry_count": attr.int(
        doc = "A number of retry(s) for push and tag",
        default = 0,
    ),
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
    "_crane": attr.label(
        cfg = _transition_to_target,
        default = "@oci_crane_toolchains//:current_toolchain",
    ),
    "_push_sh_tpl": attr.label(
        default = "push.sh.tpl",
        allow_single_file = True,
    ),
    "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    "_jq": attr.label(
        cfg = _transition_to_target,
        default = "@jq_toolchains//:resolved_toolchain",
    ),
}

def _quote_args(args):
    return ["\"{}\"".format(arg) for arg in args]

def _impl(ctx):
    crane = ctx.attr._crane[0][platform_common.ToolchainInfo]
    jq = ctx.attr._jq[0][platform_common.ToolchainInfo]

    if ctx.attr.repository and ctx.attr.repository_file:
        fail("must specify exactly one of 'repository_file' or 'repository'")

    if not ctx.file.image.is_directory:
        fail("image attribute must be a oci_image or oci_image_index")

    _, _, _, maybe_digest, maybe_tag = util.parse_image(ctx.attr.repository)
    if maybe_digest or maybe_tag:
        fail("`repository` attribute should not contain digest or tag. got: {}".format(ctx.attr.repository))

    if ctx.attr.retry_count < 0 or ctx.attr.retry_count % 1 != 0:
        fail("`retry_count` attribute should be natural number and non-negative")

    executable = ctx.actions.declare_file("push_%s.sh" % ctx.label.name)
    files = [ctx.file.image]
    substitutions = {
        "{{crane_path}}": crane.crane_info.binary.short_path,
        "{{jq_path}}": jq.jqinfo.bin.short_path,
        "{{image_dir}}": ctx.file.image.short_path,
        "{{fixed_args}}": "",
    }

    if ctx.attr.repository:
        substitutions["{{fixed_args}}"] += " ".join(_quote_args(["--repository", ctx.attr.repository]))
    elif ctx.attr.repository_file:
        files.append(ctx.file.repository_file)
        substitutions["{{repository_file}}"] = ctx.file.repository_file.short_path
    else:
        fail("must specify exactly one of 'repository_file' or 'repository'")

    if ctx.attr.remote_tags:
        files.append(ctx.file.remote_tags)
        substitutions["{{tags}}"] = ctx.file.remote_tags.short_path

    ctx.actions.expand_template(
        template = ctx.file._push_sh_tpl,
        output = executable,
        is_executable = True,
        substitutions = substitutions,
    )
    runfiles = ctx.runfiles(files = files)
    runfiles = runfiles.merge(jq.default.default_runfiles)
    runfiles = runfiles.merge(ctx.attr.image[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(crane.default.default_runfiles)

    return DefaultInfo(executable = util.maybe_wrap_launcher_for_windows(ctx, executable), runfiles = runfiles)

oci_push_lib = struct(
    implementation = _impl,
    attrs = _attrs,
    toolchains = ["@bazel_tools//tools/sh:toolchain_type"],
)

oci_push = rule(
    doc = _DOC,
    implementation = oci_push_lib.implementation,
    attrs = oci_push_lib.attrs,
    toolchains = oci_push_lib.toolchains,
    executable = True,
)
