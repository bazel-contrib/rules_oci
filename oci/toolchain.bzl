"""This module implements the language-specific toolchain rule."""

CraneInfo = provider(
    doc = "Information about how to invoke the crane executable.",
    fields = {
        "binary": "Executable crane binary",
    },
)

def _crane_toolchain_impl(ctx):
    binary = ctx.executable.crane
    template_variables = platform_common.TemplateVariableInfo({
        "CRANE_BIN": binary.path,
    })
    default = DefaultInfo(
        files = depset([binary]),
        runfiles = ctx.runfiles(files = [binary]),
    )
    crane_info = CraneInfo(binary = binary)
    toolchain_info = platform_common.ToolchainInfo(
        crane_info = crane_info,
        template_variables = template_variables,
        default = default,
    )
    return [
        default,
        toolchain_info,
        template_variables,
    ]

crane_toolchain = rule(
    implementation = _crane_toolchain_impl,
    attrs = {
        "crane": attr.label(
            doc = "A hermetically downloaded executable target for the target platform.",
            mandatory = True,
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Defines a crane toolchain. See: https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.",
)

RegistryInfo = provider(
    doc = "Information about how to invoke the registry executable.",
    fields = {
        "launcher": "Executable launcher wrapper",
        "registry": "Executable registry binary",
    },
)

def _registry_toolchain_impl(ctx):
    registry = ctx.executable.registry
    launcher = ctx.executable.launcher

    template_variables = platform_common.TemplateVariableInfo({
        "REGISTRY_BIN": registry.path,
        "LAUNCHER_WRAPPER": launcher.path,
    })
    default = DefaultInfo(
        files = depset([registry, launcher]),
        runfiles = ctx.runfiles(files = [registry, launcher]),
    )
    registry_info = RegistryInfo(
        registry = registry,
        launcher = launcher,
    )

    toolchain_info = platform_common.ToolchainInfo(
        registry_info = registry_info,
        template_variables = template_variables,
        default = default,
    )
    return [
        default,
        toolchain_info,
        template_variables,
    ]

registry_toolchain = rule(
    implementation = _registry_toolchain_impl,
    attrs = {
        "launcher": attr.label(
            doc = "A bash launcher script defining a bash function named `start_registry` that takes the following arguments `storage_dir, output, deadline`",
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_single_file = True,
        ),
        "registry": attr.label(
            doc = "A hermetically downloaded registry executable for the target platform.",
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_single_file = True,
        ),
    },
    doc = "Defines a registry toolchain. See: https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.",
)
