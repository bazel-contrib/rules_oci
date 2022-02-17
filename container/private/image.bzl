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

    inputs = [ctx.attr.base[DefaultInfo].files]

    layers = ctx.actions.args()

    for layer in ctx.attr.layers:
        inputs.append(layer[DefaultInfo].files)
        layers.add_all(layer[DefaultInfo].files)

    reference = ctx.attr.base.label.name

    cmd = """
cp -a {base}/. {bundle}
for layer in "$@"
do
    echo $layer
    {umoci} raw add-layer --image {bundle}:{reference} "$layer"
done
{umoci} gc --layout {bundle}
""".format(
        base = ctx.attr.base[DefaultInfo].files.to_list()[0].path,
        bundle = bundle.path,
        umoci = toolchain.containerinfo.umoci_path,
        reference = reference
    )

    ctx.actions.run_shell(
        inputs = depset(transitive = inputs),
        command = cmd,
        arguments = [layers],
        tools = toolchain.containerinfo.umoci_files,
        outputs = [bundle],
        progress_message = "Amending layers %{label}"
    )

    bundle_app = ctx.actions.declare_directory("bundle_app")

    cmd = """
cp -a {bundle}/. {bundle_app}
{umoci} config $@
""".format(
        bundle = bundle.path,
        bundle_app = bundle_app.path,
        umoci = toolchain.containerinfo.umoci_path
    )

    config = ctx.actions.args()

    config.add("--image=%s:%s" % (bundle_app.path, reference))

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
        outputs = [bundle_app],
        progress_message = "Applying config %{label}"
    )

    return [
        DefaultInfo(
            files = depset([bundle_app]),
        ),
    ]

image = struct(
    implementation = _impl,
    attrs = _ATTRS,
    toolchains = ["@aspect_rules_container//container:toolchain_type"],
)
