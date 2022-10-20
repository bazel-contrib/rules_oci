"Implementation details for container rule"
_attrs = {
    "base": attr.string(
        mandatory = True,
    ),
    # See: https://github.com/opencontainers/image-spec/blob/main/config.md#properties
    "entrypoint": attr.string_list(),
    "cmd": attr.string_list(),
    "labels": attr.string_list(),
    "tag": attr.string_list(),
    "layers": attr.label_list(),
    "_container_sh_tpl": attr.label(default = "container.sh.tpl", allow_single_file = True),
}

def _impl(ctx):
    crane = ctx.toolchains["@contrib_rules_oci//oci:crane_toolchain_type"]
    registry = ctx.toolchains["@contrib_rules_oci//oci:registry_toolchain_type"]

    launcher = ctx.actions.declare_file("container_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._container_sh_tpl,
        output = launcher,
        is_executable = True,
        substitutions = {
            "%registry_launcher_path%": registry.registry_info.launcher_path,
            "%crane_path%": crane.crane_info.crane_path,
            "%storage_dir%": "/".join([ctx.bin_dir.path, ctx.label.package, "storage_%s" % ctx.label.name])
        }
    )

    inputs_depsets = []

    args = ctx.actions.args()
    args.add_all([
        "mutate",
        ctx.attr.base,
        "--tag",
        "oci:registry/{}".format(ctx.label.name)
    ])

    if ctx.attr.layers:
        args.add("--append")
        for layer in ctx.attr.layers:
            # TODO(thesayyn): allow only .tar files
            inputs_depsets.append(layer[DefaultInfo].files)
            args.add_all(layer[DefaultInfo].files)


    if ctx.attr.entrypoint:
        args.add_joined("--entrypoint", ctx.attr.entrypoint, join_with = ",")

    if ctx.attr.cmd:
        args.add_joined("--cmd", ctx.attr.cmd, join_with = ",")


    output = ctx.actions.declare_directory("image")
    args.add(output.path, format = "--output=%s")

    ctx.actions.run(
        inputs = depset(transitive = inputs_depsets),
        arguments = [args],
        outputs = [output],
        executable = launcher,
        tools = crane.crane_info.crane_files + registry.registry_info.registry_files,
        progress_message = "Building OCI Image",
    )

    return [
        DefaultInfo(
            files = depset([output]),
        ),
    ]

container = struct(
    implementation = _impl,
    attrs = _attrs,
    toolchains = [
        "@contrib_rules_oci//oci:crane_toolchain_type",
        "@contrib_rules_oci//oci:registry_toolchain_type"
    ],
)
