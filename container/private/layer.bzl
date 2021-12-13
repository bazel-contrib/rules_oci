_attrs = {
    "base": attr.string(
        mandatory = True
    )
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
echo "here"
{crane} $@""".format(
            crane = toolchain.containerinfo.crane_path,
        ),
        is_executable = True,
    )

    pull = ctx.actions.args()

    tar = ctx.actions.declare_file("_%s.tar" % ctx.label.name)

    pull.add_all([
        "pull",
        ctx.attr.base,
        tar
    ])
    
    print(pull)

    ctx.actions.run(
        inputs = [] + toolchain.containerinfo.crane_files,
        arguments = [pull],
        outputs = [tar],
        executable = launcher,
        progress_message = "Pulling base image (%s)" % ctx.attr.base
    )

    return [
        DefaultInfo(
            files = depset([tar]),
        ),
    ]



container = struct(
    implementation = _impl,
    attrs = _attrs,
    toolchains = ["@rules_container//container:toolchain_type"],
)