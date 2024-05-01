"Implementation details for image rule"

load("//oci/private:util.bzl", "util")

_ACCEPTED_TAR_EXTENSIONS = [
    ".tar",
    ".tgz",
    ".tar.gz",
    ".tzst",
    ".tar.zst",
]

_DOC = """Build an OCI compatible container image.

Note, most users should use the wrapper macro instead of this rule directly.
See [oci_image](#oci_image).

It takes number of tar files as layers to create image filesystem.
For incrementality, use more fine-grained tar files to build up the filesystem,
and choose an order so that less-frequently changed files appear earlier in the list.

```starlark
oci_image(
    # do not sort
    tars = [
        "rootfs.tar",
        "appfs.tar",
        "libc6.tar",
        "passwd.tar",
    ]
)
```

To base an oci_image on another oci_image, the `base` attribute can be used.

```starlark
oci_image(
    base = "//sys:base",
    tars = [
        "appfs.tar"
    ]
)
```

To combine `env` with environment variables from the `base`, bash style variable syntax can be used.

```starlark
oci_image(
    name = "base",
    env = {"PATH": "/usr/bin"}
)

oci_image(
    name = "app",
    base = ":base",
    env = {"PATH": "/usr/local/bin:$PATH"}
)
```
"""
_attrs = {
    "base": attr.label(allow_single_file = True, doc = "Label to an oci_image target to use as the base."),
    "tars": attr.label_list(allow_files = _ACCEPTED_TAR_EXTENSIONS, doc = """\
        List of tar files to add to the image as layers.
        Do not sort this list; the order is preserved in the resulting image.
        Less-frequently changed files belong in lower layers to reduce the network bandwidth required to pull and push.

        The authors recommend [dive](https://github.com/wagoodman/dive) to explore the layering of the resulting image.
    """),
    # See: https://github.com/opencontainers/image-spec/blob/main/config.md#properties
    "entrypoint": attr.label(doc = "A file containing a comma separated list to be used as the `entrypoint` to execute when the container starts. These values act as defaults and may be replaced by an entrypoint specified when creating a container.", allow_single_file = True),
    "cmd": attr.label(doc = "A file containing a comma separated list to be used as the `command & args` of the container. These values act as defaults and may be replaced by any specified when creating a container.", allow_single_file = True),
    "env": attr.label(doc = """\
A file containing the default values for the environment variables of the container. These values act as defaults and are merged with any specified when creating a container. Entries replace the base environment variables if any of the entries has conflicting keys.
To merge entries with keys specified in the base, `${KEY}` or `$KEY` syntax may be used.
    """, allow_single_file = True),
    "user": attr.string(doc = """
The `username` or `UID` which is a platform-specific structure that allows specific control over which user the process run as.
This acts as a default value to use when the value is not specified when creating a container.
For Linux based systems, all of the following are valid: `user`, `uid`, `user:group`, `uid:gid`, `uid:group`, `user:gid`.
If `group/gid` is not specified, the default group and supplementary groups of the given `user/uid` in `/etc/passwd` from the container are applied.
"""),
    "workdir": attr.string(doc = "Sets the current working directory of the `entrypoint` process in the container. This value acts as a default and may be replaced by a working directory specified when creating a container."),
    "exposed_ports": attr.label(doc = "A file containing a comma separated list of exposed ports. (e.g. 2000/tcp, 3000/udp or 4000. No protocol defaults to tcp).", allow_single_file = True),
    "os": attr.string(doc = "The name of the operating system which the image is built to run on. eg: `linux`, `windows`. See $GOOS documentation for possible values: https://go.dev/doc/install/source#environment"),
    "architecture": attr.string(doc = "The CPU architecture which the binaries in this image are built to run on. eg: `arm64`, `arm`, `amd64`, `s390x`. See $GOARCH documentation for possible values: https://go.dev/doc/install/source#environment"),
    "variant": attr.string(doc = "The variant of the specified CPU architecture. eg: `v6`, `v7`, `v8`. See: https://github.com/opencontainers/image-spec/blob/main/image-index.md#platform-variants for more."),
    "labels": attr.label(doc = "A file containing a dictionary of labels. Each line should be in the form `name=value`.", allow_single_file = True),
    "annotations": attr.label(doc = "A file containing a dictionary of annotations. Each line should be in the form `name=value`.", allow_single_file = True),
    "_image_sh": attr.label(default = "image.sh", allow_single_file = True),
    "_windows_constraint": attr.label(default = "@platforms//os:windows"),
}

def _platform_str(os, arch, variant = None):
    parts = dict(os = os, architecture = arch)
    if variant:
        parts["variant"] = variant
    return json.encode(parts)

def _oci_image_impl(ctx):
    if not ctx.attr.base and (not ctx.attr.os or not ctx.attr.architecture):
        fail("'os' and 'architecture' are mandatory when 'base' is unspecified.")
    if ctx.attr.base and (ctx.attr.os or ctx.attr.architecture or ctx.attr.variant):
        fail("'os', 'architecture' and 'variant' come from the image provided by 'base' and cannot be overridden.")

    regctl = ctx.toolchains["@rules_oci//oci:regctl_toolchain_type"]
    jq = ctx.toolchains["@aspect_bazel_lib//lib:jq_toolchain_type"]
    coreutils = ctx.toolchains["@aspect_bazel_lib//lib:coreutils_toolchain_type"]
    zstd = ctx.toolchains["@aspect_bazel_lib//lib:zstd_toolchain_type"]

    output = ctx.actions.declare_directory(ctx.label.name)

    # create the image builder
    builder = ctx.actions.declare_file("image_%s.sh" % ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._image_sh,
        output = builder,
        is_executable = True,
        substitutions = {
            "{{regctl_path}}": regctl.regctl_info.binary.dirname,
            "{{jq_path}}": jq.jqinfo.bin.dirname,
            "{{coreutils_path}}": coreutils.coreutils_info.bin.dirname,
            "{{zstd_path}}": zstd.zstdinfo.binary.dirname,
            "{{output}}": output.path,
        },
    )

    inputs = [builder] + ctx.files.tars
    args = ctx.actions.args()

    if ctx.attr.base:
        # reuse given base image
        args.add(ctx.file.base.path, format = "--from=%s")
        inputs.append(ctx.file.base)
    else:
        # create a scratch base image with given os/arch[/variant]
        args.add(_platform_str(ctx.attr.os, ctx.attr.architecture, ctx.attr.variant), format = "--scratch=%s")

    # add layers
    for layer in ctx.attr.tars:
        # tars are already added as input above.
        args.add_all(layer[DefaultInfo].files, format_each = "--layer=%s")

    if ctx.attr.entrypoint:
        args.add(ctx.file.entrypoint.path, format = "--entrypoint=%s")
        inputs.append(ctx.file.entrypoint)

    if ctx.attr.exposed_ports:
        args.add(ctx.file.exposed_ports.path, format = "--exposed-ports=%s")
        inputs.append(ctx.file.exposed_ports)

    if ctx.attr.cmd:
        args.add(ctx.file.cmd.path, format = "--cmd=%s")
        inputs.append(ctx.file.cmd)

    if ctx.attr.env:
        args.add(ctx.file.env.path, format = "--env=%s")
        inputs.append(ctx.file.env)

    if ctx.attr.labels:
        args.add(ctx.file.labels.path, format = "--labels=%s")
        inputs.append(ctx.file.labels)

    if ctx.attr.annotations:
        args.add(ctx.file.annotations.path, format = "--annotations=%s")
        inputs.append(ctx.file.annotations)

    if ctx.attr.user:
        args.add(ctx.attr.user, format = "--user=%s")

    if ctx.attr.workdir:
        args.add(ctx.attr.workdir, format = "--workdir=%s")

    action_env = {}

    # Windows: Don't convert arguments like --entrypoint=/some/bin to --entrypoint=C:/msys64/some/bin
    if ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        # See https://www.msys2.org/wiki/Porting/:
        # > Setting MSYS2_ARG_CONV_EXCL=* prevents any path transformation.
        action_env["MSYS2_ARG_CONV_EXCL"] = "*"

        # This one is for Windows Git MSys
        action_env["MSYS_NO_PATHCONV"] = "1"

    ctx.actions.run(
        inputs = inputs,
        arguments = [args],
        outputs = [output],
        env = action_env,
        executable = util.maybe_wrap_launcher_for_windows(ctx, builder),
        tools = [
            regctl.regctl_info.binary,
            jq.jqinfo.bin,
            coreutils.coreutils_info.bin,
            zstd.zstdinfo.binary,
        ],
        mnemonic = "OCIImage",
        progress_message = "OCI Image %{label}",
        toolchain = None,
    )

    return [
        DefaultInfo(
            files = depset([output]),
        ),
    ]

oci_image = rule(
    implementation = _oci_image_impl,
    attrs = _attrs,
    doc = _DOC,
    toolchains = [
        "@aspect_bazel_lib//lib:jq_toolchain_type",
        "@aspect_bazel_lib//lib:coreutils_toolchain_type",
        "@aspect_bazel_lib//lib:zstd_toolchain_type",
        "@rules_oci//oci:regctl_toolchain_type",
        "@bazel_tools//tools/sh:toolchain_type",
    ],
)
