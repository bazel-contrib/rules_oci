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
    default_tags = ["latest"]
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

oci_push(
    image = ":app_image",
    repository = "ghcr.io/<OWNER>/image",
    default_tags = ["0.0.0"]
)
```

Ideally the semver information is gathered from a vcs, like git, instead of being hardcoded to the BUILD files.
However, due to nature of BUILD files being static, one has to use `-t|--tag` flag to pass the tag at runtime instead of using `default_tags`. eg. `bazel run //target:push -- --tag $(git tag)`

Similary, the `repository` attribute can be overridden at runtime with the `-r|--repository` flag. eg. `bazel run //target:push -- --repository index.docker.io/<ORG>/image`
"""
_attrs = {
    "image": attr.label(allow_single_file = True, doc = "Label to an oci_image or oci_image_index"),
    "repository": attr.string(mandatory = True, doc = "Repository URL where the image will be signed at. eg: index.docker.io/<user>/image. digests and tags are disallowed."),
    "default_tags": attr.string_list(doc = "List of tags to apply to the image at remote registry."),
    "_push_sh_tpl": attr.label(default = "push.sh.tpl", allow_single_file = True),
}

def _quote_args(args):
    return ["\"{}\"".format(arg) for arg in args]

def _impl(ctx):
    crane = ctx.toolchains["@contrib_rules_oci//oci:crane_toolchain_type"]
    jq = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"]

    if not ctx.file.image.is_directory:
        fail("image attribute must be a oci_image or oci_image_index")

    if ctx.attr.repository.find(":") != -1 or ctx.attr.repository.find("@") != -1:
        fail("repository attribute should not contain digest or tag.")

    fixed_args = ["--tag={}".format(tag) for tag in ctx.attr.default_tags]
    fixed_args.extend(["--repository", ctx.attr.repository])

    executable = ctx.actions.declare_file("push_%s.sh" % ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._push_sh_tpl,
        output = executable,
        is_executable = True,
        substitutions = {
            "{{crane_path}}": crane.crane_info.crane_path,
            "{{yq_path}}": jq.yqinfo.bin.short_path,
            "{{image_dir}}": ctx.file.image.short_path,
            "{{fixed_args}}": " ".join(_quote_args(fixed_args)),
        },
    )

    runfiles = ctx.runfiles(files = [ctx.file.image])
    runfiles = runfiles.merge(jq.default.default_runfiles)
    runfiles = runfiles.merge(crane.default.default_runfiles)

    return DefaultInfo(executable = executable, runfiles = runfiles)

oci_push = rule(
    implementation = _impl,
    attrs = _attrs,
    doc = _DOC,
    executable = True,
    toolchains = [
        "@contrib_rules_oci//oci:crane_toolchain_type",
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
)
