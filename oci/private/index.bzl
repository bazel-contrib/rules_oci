"Implementation details for oci_index rule"

_DOC = """Build a multi-architecture OCI compatible container image.

It takes number of `oci_image`s  to create a fat multi-architecture image.

```starlark
oci_image(
    name = "app_linux_amd64"
)

oci_image(
    name = "app_linux_arm64"
)

oci_index(
    name = "app",
    images = [
        ":app_linux_amd64",
        ":app_linux_arm64"
    ]
)
```
"""

_attrs = {
    "images": attr.label_list(mandatory = True, doc = "List of labels to oci_image targets."),
    "_index_sh_tpl": attr.label(default = "index.sh.tpl", allow_single_file = True),
}

def _expand_image_to_args(image, expander):
    args = [
        "--image={}".format(image.path),
    ]
    for file in expander.expand(image):
        if file.path.find("blobs") != -1:
            args.append("--blob={}".format(file.tree_relative_path))
    return args

def _oci_index_impl(ctx):
    yq = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"]

    launcher = ctx.actions.declare_file("index_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._index_sh_tpl,
        output = launcher,
        is_executable = True,
        substitutions = {
            "{{yq_path}}": yq.yqinfo.bin.path,
        },
    )

    output = ctx.actions.declare_directory(ctx.label.name)

    args = ctx.actions.args()
    args.add(output.path, format = "--output=%s")
    args.add_all(ctx.files.images, map_each = _expand_image_to_args, expand_directories = False)

    ctx.actions.run(
        inputs = ctx.files.images,
        arguments = [args],
        outputs = [output],
        executable = launcher,
        tools = [yq.yqinfo.bin],
        progress_message = "OCI Index %{label}",
    )

    return DefaultInfo(files = depset([output]))

oci_index = rule(
    implementation = _oci_index_impl,
    attrs = _attrs,
    doc = _DOC,
    toolchains = [
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
)
