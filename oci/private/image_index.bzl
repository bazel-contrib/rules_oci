"Implementation details for oci_image_index rule"

load("@bazel_features//:features.bzl", "bazel_features")

_DOC = """Build a multi-architecture OCI compatible container image.

It takes number of `oci_image` targets to create a fat multi-architecture image conforming to [OCI Image Index Specification](https://github.com/opencontainers/image-spec/blob/main/image-index.md).

Image indexes can be created in two ways:

## Using Bazel platforms

While this feature is still experimental, it is the recommended way to create image indexes.

```starlark
go_binary(
    name = "app_can_cross_compile"
)

tar(
    name = "app_layer",
    srcs = [
        ":app_can_cross_compile",
    ],
)

oci_image(
    name = "image",
    tars = [":app_layer"],
)

oci_image_index(
    name = "image_multiarch",
    images = [":image"],
    platforms = [
        "@rules_go//go/toolchain:linux_amd64",
        "@rules_go//go/toolchain:linux_arm64",
    ],
)
```

An index given exactly one platform is itself built in that platform's configuration rather than the
caller's, so that it can point at the image's blobs with relative symlinks (see below). Its output
therefore lives in that configuration's `bazel-out` directory, and its own configurable attributes are
evaluated for that platform.

## Without using Bazel platforms

```starlark
oci_image(
    name = "app_linux_amd64"
)

oci_image(
    name = "app_linux_arm64"
)

oci_image_index(
    name = "app",
    images = [
        ":app_linux_amd64",
        ":app_linux_arm64"
    ]
)
```
"""

def _image_index_transition_impl(_, attr):
    return [
        {"//command_line_option:platforms": str(platform)}
        for platform in attr.platforms
    ]

_image_index_transition = transition(
    implementation = _image_index_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _image_index_self_transition_impl(settings, attr):
    # An index for a single platform is built in that platform's configuration, so it shares an
    # output directory with its image and can point at the image's blobs with relative symlinks
    # that stay valid in runfiles trees (see _can_link_blobs). A multi-platform index spans
    # configurations and stays in the caller's.
    if len(attr.platforms) == 1:
        return {"//command_line_option:platforms": str(attr.platforms[0])}
    return {"//command_line_option:platforms": settings["//command_line_option:platforms"]}

_image_index_self_transition = transition(
    implementation = _image_index_self_transition_impl,
    inputs = ["//command_line_option:platforms"],
    outputs = ["//command_line_option:platforms"],
)

_attrs = {
    "images": attr.label_list(
        mandatory = True,
        doc = "List of labels to oci_image targets.",
        cfg = _image_index_transition,
    ),
    "platforms": attr.label_list(
        doc = """This feature is highly EXPERIMENTAL and not subject to our usual SemVer guarantees.
A list of platform targets to build the image for. If specified, only one image can be specified in the images attribute.
""",
        providers = [platform_common.PlatformInfo],
    ),
    "annotations": attr.label(
        doc = "A file containing a dictionary of annotations to apply to the index manifest. Each line should be in the form `name=value`.",
        allow_single_file = True,
    ),
    "_image_index_sh_tpl": attr.label(default = "image_index.sh.tpl", allow_single_file = True),
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
}

def _expand_blobs_to_args(image, expander):
    return [
        "--blob={}".format(file.tree_relative_path)
        for file in expander.expand(image)
        if file.path.find("blobs") != -1
    ]

def _can_link_blobs(image, output, label):
    """Whether the index may point at the image's blobs with relative symlinks rather than copies.

    A symlink has to resolve both in the execution root, where a file lives at
    `bazel-out/<configuration>/bin/[external/<repo>/]<package>/<name>`, and in a runfiles tree,
    where it lives at `<repo>/<package>/<name>`. The relative path between two files is the same
    in both layouts only when they share a configuration and a repository.
    """
    return all([
        file.root.path == output.root.path and file.owner.repo_name == label.repo_name
        for file in image[DefaultInfo].files.to_list()
    ])

def _oci_image_index_impl(ctx):
    if len(ctx.attr.platforms) > 0 and len(ctx.attr.images) != len(ctx.attr.platforms):
        fail("platforms can only be specified when there is exactly one image in the images attribute.")

    jq = ctx.toolchains["@aspect_bazel_lib//lib:jq_toolchain_type"]
    coreutils = ctx.toolchains["@aspect_bazel_lib//lib:coreutils_toolchain_type"]

    launcher = ctx.actions.declare_file("image_index_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._image_index_sh_tpl,
        output = launcher,
        is_executable = True,
        substitutions = {
            "{{jq_path}}": jq.jqinfo.bin.path,
            "{{coreutils_path}}": coreutils.coreutils_info.bin.path,
        },
    )

    output = ctx.actions.declare_directory(ctx.label.name)

    # Like oci_image, point at blobs with relative symlinks instead of copying them where possible,
    # so the action neither copies nor re-uploads every layer of every image. A linked image's blobs
    # are themselves symlinks to its layers, so its files and runfiles are carried in the index's
    # runfiles for consumers that run from a runfiles tree. A copied image is self-contained.
    use_symlinks = bazel_features.rules.permits_treeartifact_uplevel_symlinks

    args = ctx.actions.args()
    args.add(output.path, format = "--output=%s")
    transitive_runfiles = []
    for images in ctx.split_attr.images.values():
        for image in images:
            link = use_symlinks and _can_link_blobs(image, output, ctx.label)
            for layout in image[DefaultInfo].files.to_list():
                args.add(layout.path, format = "--linked-image=%s" if link else "--image=%s")
                args.add_all([layout], map_each = _expand_blobs_to_args, expand_directories = False)
            if link:
                transitive_runfiles.append(image[DefaultInfo].files)
                transitive_runfiles.append(image[DefaultInfo].default_runfiles.files)

    inputs = list(ctx.files.images)
    if ctx.attr.annotations:
        args.add(ctx.file.annotations.path, format = "--annotations=%s")
        inputs.append(ctx.file.annotations)

    ctx.actions.run(
        inputs = inputs,
        arguments = [args],
        outputs = [output],
        executable = launcher,
        tools = [jq.jqinfo.bin, coreutils.coreutils_info.bin],
        mnemonic = "OCIIndex",
        progress_message = "OCI Index %{label}",
        toolchain = None,
    )

    return DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles(transitive_files = depset(transitive = transitive_runfiles)),
    )

oci_image_index = rule(
    implementation = _oci_image_index_impl,
    attrs = _attrs,
    cfg = _image_index_self_transition,
    doc = _DOC,
    toolchains = [
        "@aspect_bazel_lib//lib:jq_toolchain_type",
        "@aspect_bazel_lib//lib:coreutils_toolchain_type",
    ],
)
