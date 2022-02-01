_ATTRS = {
    "base": attr.label(),
    # See: https://github.com/opencontainers/image-spec/blob/main/config.md#properties
    "entrypoint": attr.string_list(),
    "working_dir": attr.string(),
    "cmd": attr.string_list(),
    "labels": attr.string_list(),
    "tag": attr.string_list(),
    "layers": attr.label_list(),
}

def _impl(ctx):
    toolchain = ctx.toolchains["@aspect_rules_container//container:toolchain_type"]

    # Copy the base and add layers
    bundle = ctx.actions.declare_directory("bundle")

    inputs = depset(transitive = [ctx.attr.base[DefaultInfo].files])

    layers = ctx.actions.args()

    for layer in ctx.attr.layers:
        inputs = depset(transitive = [layer[DefaultInfo].files, inputs])
        layers.add_all(layer[DefaultInfo].files)


    cmd = """
cp -r {base}/ {bundle}
for layer in "$@"
do
    echo $layer
    {umoci} raw add-layer --image {bundle} "$layer"
done
""".format(
        base = ctx.attr.base[DefaultInfo].files.to_list()[0].path,
        bundle = bundle.path,
        umoci = toolchain.containerinfo.umoci_path
    )

    ctx.actions.run_shell(
        inputs = inputs,
        command = cmd,
        arguments = [layers],
        tools = toolchain.containerinfo.umoci_files,
        outputs = [bundle]
    )

    

    # Config
    # TODO: os, arch
    bundle_app = ctx.actions.declare_directory("bundle_app")

    cmd = """
cp -r {bundle}/ {bundle_app}
{umoci} config $@
""".format(
        bundle = bundle.path,
        bundle_app = bundle_app.path,
        umoci = toolchain.containerinfo.umoci_path
    )

    config = ctx.actions.args()

    config.add_all(["--image", bundle_app.path])

    if ctx.attr.entrypoint:
        config.add_joined("--config.entrypoint", ctx.attr.entrypoint, join_with=",")

    if ctx.attr.cmd:
        config.add_joined("--config.cmd", ctx.attr.cmd, join_with=",")

    if ctx.attr.working_dir:
        config.add("--config.workingdir", ctx.attr.working_dir)

    ctx.actions.run_shell(
        inputs = [bundle],
        command = cmd,
        arguments = [config],
        tools = toolchain.containerinfo.umoci_files,
        outputs = [bundle_app]
    )

    return [
        DefaultInfo(
            files = depset([bundle_app]),
        ),
    ]

container = struct(
    implementation = _impl,
    attrs = _ATTRS,
    toolchains = ["@rules_container//container:toolchain_type"],
)
