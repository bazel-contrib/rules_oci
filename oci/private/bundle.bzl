"Implementation details for oci rule"

_DOC = """Build a OCI compatible container image bundle.

It takes number of `oci_image/oci_image_index/oci_bundle`s to create a image bundle.

```starlark
oci_image(
    name = "app1_linux_amd64"
)

oci_image(
    name = "app1_linux_arm64"
)

oci_bundle(
    name = "app1",
    images = [
        ":app1_linux_amd64",
        ":app1_linux_arm64"
    ]
)

oci_image(
    name = "app2",
)

oci_bundle(
    name = "bundle",
    images = {
        "ghcr.io/<OWNER>/image1:tag": ":app1",
        "ghcr.io/<OWNER>/image2:tag": ":app2",
    },
)
```
"""

_attrs = {
    "image_refs": attr.string_list(mandatory = True, doc = "List of references."),
    "image_targets": attr.label_list(mandatory = True, doc = "List of labels to oci_image/oci_image_index/oci_bundle targets."),
    "_bundle_sh_tpl": attr.label(default = "bundle.sh.tpl", allow_single_file = True),
}

def _expand_image_to_args(image, expander):
    args = [
        "--image={}".format(image.path),
    ]
    for file in expander.expand(image):
        if file.path.find("blobs") != -1:
            args.append("--blob={}".format(file.tree_relative_path))
    return args

def _oci_bundle_impl(ctx):
    yq = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"]
    coreutils = ctx.toolchains["@aspect_bazel_lib//lib:coreutils_toolchain_type"]

    launcher = ctx.actions.declare_file("bundle_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._bundle_sh_tpl,
        output = launcher,
        is_executable = True,
        substitutions = {
            "{{yq_path}}": yq.yqinfo.bin.path,
            "{{coreutils_path}}": coreutils.coreutils_info.bin.path,
        },
    )

    output = ctx.actions.declare_directory(ctx.label.name)

    args = ctx.actions.args()
    args.add(output.path, format = "--output=%s")
    for i in range(len(ctx.files.image_targets)):
        ref = ctx.attr.image_refs[i]
        args.add_all([ctx.files.image_targets[i]], map_each = _expand_image_to_args, expand_directories = False)
        args.add(ref, format = "--ref=%s")

    ctx.actions.run(
        inputs = ctx.files.image_targets,
        arguments = [args],
        outputs = [output],
        executable = launcher,
        tools = [yq.yqinfo.bin, coreutils.coreutils_info.bin],
        mnemonic = "OCIBundle",
        progress_message = "OCI Bundle %{label}",
    )

    return DefaultInfo(files = depset([output]))

oci_bundle = rule(
    implementation = _oci_bundle_impl,
    attrs = _attrs,
    doc = _DOC,
    toolchains = [
        "@aspect_bazel_lib//lib:yq_toolchain_type",
        "@aspect_bazel_lib//lib:coreutils_toolchain_type",
    ],
)
