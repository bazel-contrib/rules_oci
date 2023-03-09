"Implementation details for the push rule"

_DOC = """Push an oci_image or oci_image_index to a remote registry.

Pushing and tagging are performed sequentially which MAY lead to non-atomic pushes if one the following events occur;

- Remote registry rejects a tag due to various reasons. eg: forbidden characters, existing tags 
- Remote registry closes the connection during the tagging
- Local network outages

In order to avoid incomplete pushes oci_push will push the image by its digest and then apply the `default_tags` sequentially at
the remote registry. 

Any failure during pushing or tagging will be reported with non-zero exit code cause remaining steps to be skipped.


Push an oci_image to docker registry with latest tag

```starlark
oci_image(name = "image")

oci_push(
    image = ":image",
    repository = "index.docker.io/<ORG>/image",
    # FIXME default_tags = ["latest"]
)
```

Push an oci_image_index to github container registry with a semver tag

```starlark
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

FIXME

oci_push(
    image = ":app_image",
    repository = "ghcr.io/<OWNER>/image",
    metadata = ":FIXME",
)
```

You can pass flags to `crane` to override some attributes when you run the target:
- `tags`: `-t|--tag` flag, e.g. `bazel run //myimage:push -- --tag latest`
- `repository`: `-r|--repository` flag. e.g. `bazel run //myimage:push -- --repository index.docker.io/<ORG>/image`
"""
_attrs = {
    "image": attr.label(allow_single_file = True, doc = "Label to an oci_image or oci_image_index", mandatory = True),
    "repository": attr.string(mandatory = True, doc = """\
        Repository URL where the image will be signed at, e.g.: `index.docker.io/<user>/image`.
        Digests and tags are not allowed.
    """),
    "image_tags": attr.label(doc = "txt file containing tags, one per line", allow_single_file = [".txt"]),
    "_push_sh_tpl": attr.label(default = "push.sh.tpl", allow_single_file = True),
}

def _quote_args(args):
    return ["\"{}\"".format(arg) for arg in args]

def _impl(ctx):
    crane = ctx.toolchains["@rules_oci//oci:crane_toolchain_type"]
    yq = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"]

    if not ctx.file.image.is_directory:
        fail("image attribute must be a oci_image or oci_image_index")

    if ctx.attr.repository.find(":") != -1 or ctx.attr.repository.find("@") != -1:
        fail("repository attribute should not contain digest or tag.")

    fixed_args = []

    # fixed_args.extend(["--tag={}".format(tag) for tag in ctx.attr.default_tags])
    fixed_args.extend(["--repository", ctx.attr.repository])

    executable = ctx.actions.declare_file("push_%s.sh" % ctx.label.name)
    files = [ctx.file.image]
    substitutions = {
        "{{crane_path}}": crane.crane_info.binary.short_path,
        "{{yq_path}}": yq.yqinfo.bin.short_path,
        "{{image_dir}}": ctx.file.image.short_path,
        "{{fixed_args}}": " ".join(_quote_args(fixed_args)),
    }
    if ctx.attr.image_tags:
        files.append(ctx.file.image_tags)
        substitutions["{{tags}}"] = ctx.file.image_tags.short_path

    ctx.actions.expand_template(
        template = ctx.file._push_sh_tpl,
        output = executable,
        is_executable = True,
        substitutions = substitutions,
    )
    runfiles = ctx.runfiles(files = files)
    runfiles = runfiles.merge(yq.default.default_runfiles)
    runfiles = runfiles.merge(crane.default.default_runfiles)

    return DefaultInfo(executable = executable, runfiles = runfiles)

oci_push = rule(
    implementation = _impl,
    attrs = _attrs,
    doc = _DOC,
    executable = True,
    toolchains = [
        "@rules_oci//oci:crane_toolchain_type",
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
)
