"Implementation details for oci_image_index rule"

_DOC = """Build a multi-architecture OCI compatible container image.

It takes number of `oci_image`s  to create a fat multi-architecture image.

Requires `wc` and either `sha256sum` or `shasum` to be installed on the execution machine.

```starlark
oci_image(
    name = "app_linux"
)

oci_image_index(
    name = "app",
    image = ":app_linux",
    platforms = [
        "@io_bazel_rules_go//go/toolchain:linux_amd64",
        "@io_bazel_rules_go//go/toolchain:linux_arm64",
    ]
)
```

Deprecated use without platform transition:

```starlark
oci_image(
    name = "app_linux_amd64",
)

oci_image(
    name = "app_linux_arm64",
)

oci_image_index(
    name = "app",
    image = [
        ":app_linux_amd64",
        ":app_linux_arm64"
    ],
)
```

Another variant for transitioning away from the deprecated use:

```starlark
oci_image(
    name = "app_linux_amd64",
)

oci_image(
    name = "app_linux_arm64",
)

alias(
    name = "app_linux",
    actual = select({
        "@platforms//cpu:x86_64": ":app_linux_amd64",
        "@platforms//cpu:aarch64": ":app_linux_arm64",
    }),
)

oci_image_index(
    name = "app",
    image = ":app_linux",
    platforms = [
        "@io_bazel_rules_go//go/toolchain:linux_amd64",
        "@io_bazel_rules_go//go/toolchain:linux_arm64",
    ],
)
```
"""

def _oci_platform_transition_impl(settings, attr):
    if attr.platforms == []:
        # No platform specified, use the current target platform only.
        ret = [settings]
    else:
        ret = [
            {
                "//command_line_option:platforms": [platform],
            }
            for platform in attr.platforms
        ]
    return ret

_oci_platform_transition = transition(
    implementation = _oci_platform_transition_impl,
    inputs = ["//command_line_option:platforms"],
    outputs = ["//command_line_option:platforms"],
)

_attrs = {
    "images": attr.label_list(mandatory = False, doc = "List of labels to oci_image targets."),
    "image": attr.label(mandatory = False, doc = "An oci_image target.", cfg = _oci_platform_transition),
    "platforms": attr.label_list(mandatory = False, default = [], doc = """
        The platforms to build the index for. Defaults to `[]` which means that only the current target platform is used.
    """),
    "_image_index_sh_tpl": attr.label(default = "image_index.sh.tpl", allow_single_file = True),
}

def _expand_image_to_args(image, expander):
    args = [
        "--image={}".format(image.path),
    ]
    for file in expander.expand(image):
        if file.path.find("blobs") != -1:
            args.append("--blob={}".format(file.tree_relative_path))
    return args

def _oci_image_index_impl(ctx):
    yq = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"]
    coreutils = ctx.toolchains["@aspect_bazel_lib//lib:coreutils_toolchain_type"]

    launcher = ctx.actions.declare_file("image_index_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._image_index_sh_tpl,
        output = launcher,
        is_executable = True,
        substitutions = {
            "{{yq_path}}": yq.yqinfo.bin.path,
            "{{coreutils_path}}": coreutils.coreutils_info.bin.path,
        },
    )

    output = ctx.actions.declare_directory(ctx.label.name)

    if ctx.attr.images:
        if ctx.attr.image or ctx.attr.platforms:
            fail("Specify either 'images' OR 'image' and 'platforms'.")
        print("Deprecated use of 'images' in %s. Please change to 'image' and 'platforms'." % ctx.label)
        image_files = ctx.files.images
    else:
        image_files = depset(transitive = [
            image[DefaultInfo].files
            for image in ctx.attr.image
        ])

    args = ctx.actions.args()
    args.add(output.path, format = "--output=%s")
    args.add_all(image_files, map_each = _expand_image_to_args, expand_directories = False)

    ctx.actions.run(
        inputs = image_files,
        arguments = [args],
        outputs = [output],
        executable = launcher,
        tools = [yq.yqinfo.bin, coreutils.coreutils_info.bin],
        mnemonic = "OCIIndex",
        progress_message = "OCI Index %{label}",
    )

    return DefaultInfo(files = depset([output]))

oci_image_index = rule(
    implementation = _oci_image_index_impl,
    attrs = _attrs,
    doc = _DOC,
    toolchains = [
        "@aspect_bazel_lib//lib:yq_toolchain_type",
        "@aspect_bazel_lib//lib:coreutils_toolchain_type",
    ],
)
