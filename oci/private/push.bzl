"Implementation details for the push rule"

_DOC = """Push an oci_image or oci_image_index to a remote registry.

Internal rule used by the [oci_push macro](/docs/push.md#oci_push).

Pushing and tagging are performed sequentially which MAY lead to non-atomic pushes if one the following events occur;

- Remote registry rejects a tag due to various reasons. eg: forbidden characters, existing tags 
- Remote registry closes the connection during the tagging
- Local network outages

In order to avoid incomplete pushes oci_push will push the image by its digest and then apply the `image_tags` sequentially at
the remote registry. 

Any failure during pushing or tagging will be reported with non-zero exit code cause remaining steps to be skipped.


Push an oci_image to docker registry with latest tag

```starlark
oci_image(name = "image")

oci_push(
    image = ":image",
    repository = "index.docker.io/<ORG>/image",
    image_tags = ["latest"]
)
```

Push a multi-architecture image to github container registry with a semver tag

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

stamped_tags(
    name = "stamped",
    image_tags = [\"\"\"($stamp.BUILD_EMBED_LABEL // "0.0.0")\"\"\"],
)

oci_push(
    image = ":app_image",
    repository = "ghcr.io/<OWNER>/image",
    tags = ":stamped",
)
```

When running the pusher, you can pass flags:
- Override `repository`: `-r|--repository` flag. e.g. `bazel run //myimage:push -- --repository index.docker.io/<ORG>/image`
- Additional `image_tags`: `-t|--tag` flag, e.g. `bazel run //myimage:push -- --tag latest`
"""

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
        mandatory = True,
    ),
    "image_tags": attr.label(
        doc = """\
        a .txt file containing tags, one per line.
        These are passed to [`crane tag`](
        https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_tag.md)
        """,
        allow_single_file = [".txt"],
    ),
    "_push_sh_tpl": attr.label(
        default = "push.sh.tpl",
        allow_single_file = True,
    ),
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

    executable = ctx.actions.declare_file("push_%s.sh" % ctx.label.name)
    files = [ctx.file.image]
    substitutions = {
        "{{crane_path}}": crane.crane_info.binary.short_path,
        "{{yq_path}}": yq.yqinfo.bin.short_path,
        "{{image_dir}}": ctx.file.image.short_path,
        "{{fixed_args}}": " ".join(_quote_args(["--repository", ctx.attr.repository])),
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

oci_push_lib = struct(
    implementation = _impl,
    attrs = _attrs,
    toolchains = [
        "@rules_oci//oci:crane_toolchain_type",
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
)

oci_push = rule(
    doc = _DOC,
    implementation = oci_push_lib.implementation,
    attrs = oci_push_lib.attrs,
    toolchains = oci_push_lib.toolchains,
    executable = True,
)
