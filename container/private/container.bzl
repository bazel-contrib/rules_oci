_attrs = {
    "base": attr.string(
        mandatory = True
    ),

    # See: https://github.com/opencontainers/image-spec/blob/main/config.md#properties
    "entrypoint": attr.string_list(),
    "cmd": attr.string_list(),
    "labels": attr.string_list(),
    "tag": attr.string_list(),
    "layers": attr.label_list(),
}


def _strip_external(path):
    return path[len("external/"):] if path.startswith("external/") else path


def _impl(ctx):
    toolchain = ctx.toolchains["@rules_container//container:toolchain_type"]

    launcher = ctx.actions.declare_file("crane.sh")

    ctx.actions.write(
        launcher,
        """#/usr/bin/env bash
set -o pipefail -o errexit -o nounset
{crane} --platform=linux/arm64 $@""".format(
            crane = toolchain.containerinfo.crane_path,
        ),
        is_executable = True,
    )

    # Pull the image
    pull = ctx.actions.args()

    tar = ctx.actions.declare_file("base_%s.tar" % ctx.label.name)

    pull.add_all([
        "append",
        "--base",
        ctx.attr.base,
        "--output",
        tar,
        "--new_tag",
        ctx.label.name,
    ])

    inputs = list()

    inputs.extend(toolchain.containerinfo.crane_files)

    if ctx.attr.layers:
        pull.add("--new_layer")
        for layer in ctx.attr.layers:
            inputs.extend(layer[DefaultInfo].files.to_list())
            pull.add_all(layer[DefaultInfo].files)

    ctx.actions.run(
        inputs = inputs,
        arguments = [pull],
        outputs = [tar],
        executable = launcher,
        progress_message = "Pulling base image (%s)" % ctx.attr.base
    )

    # Mutate it
    mutate = ctx.actions.args()
    resultTar = ctx.actions.declare_file("%s.tar" % ctx.label.name)

    mutate.add_all([
        "mutate",
        "--tag",
        ctx.label.name,
        tar,
        resultTar
    ])

    if ctx.attr.entrypoint:
        mutate.add("--entrypoint")
        mutate.add_all(ctx.attr.entrypoint)

    if ctx.attr.cmd:
        mutate.add("--cmd")
        mutate.add_all(ctx.attr.cmd)



    ctx.actions.run(
        inputs = [tar] + toolchain.containerinfo.crane_files,
        arguments = [mutate],
        outputs = [resultTar],
        executable = launcher,
        progress_message = "Mutating base image (%s)" % ctx.attr.base
    )

    return [
        DefaultInfo(
            files = depset([tar, resultTar]),
        ),
    ]



container = struct(
    implementation = _impl,
    attrs = _attrs,
    toolchains = ["@rules_container//container:toolchain_type"],
)