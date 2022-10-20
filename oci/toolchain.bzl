"""This module implements the language-specific toolchain rule."""

def _to_manifest_path(ctx, file):
    if file.short_path.startswith("../"):
        return "external/" + file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

CraneInfo = provider(
    doc = "Information about how to invoke the crane executable.",
    fields = {
        "crane_path": "Path to the crane executable for the target platform.",
        "crane_files": """Files required in runfiles to make the crane executable available.

May be empty if the crane_path points to a locally installed tool binary.""",
    },
)


def _crane_toolchain_impl(ctx):
    if ctx.attr.crane and ctx.attr.crane_path:
        fail("Can only set one of crane or crane_path but both were set.")
    if not ctx.attr.crane and not ctx.attr.crane_path:
        fail("Must set one of crane or crane_path.")

    crane_files = []
    crane_path = ctx.attr.crane_path

    if ctx.attr.crane:
        crane_files = ctx.attr.crane.files.to_list()
        crane_path = _to_manifest_path(ctx, crane_files[0])

    # Make the $(CRANE_BIN) variable available in places like genrules.
    # See https://docs.bazel.build/versions/main/be/make-variables.html#custom_variables
    template_variables = platform_common.TemplateVariableInfo({
        "CRANE_BIN": crane_path,
    })
    default = DefaultInfo(
        files = depset(crane_files),
        runfiles = ctx.runfiles(files = crane_files),
    )
    crane_info = CraneInfo(
        crane_path = crane_path,
        crane_files = crane_files,
    )

    # Export all the providers inside our ToolchainInfo
    # so the resolved_toolchain rule can grab and re-export them.
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
            mandatory = False,
            allow_single_file = True,
            executable = True,
            cfg = "exec"
        ),
        "crane_path": attr.string(
            doc = "Path to an existing executable for the target platform.",
            mandatory = False,
        ),
    },
    doc = """Defines a container compiler/runtime toolchain.

For usage see https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.
""",
)


RegistryInfo = provider(
    doc = "Information about how to invoke the registry executable.",
    fields = {
        "launcher_path": "Path to the launcher script exporting a bash function named start_registry taking storage dir as the only argument.",
        "registry_path": "Path to the registry executable for the target platform.",
        "registry_files": """Files required in runfiles to make the registry executable available.

May be empty if the registry_path points to a locally installed tool binary.""",
    },
)

def _registry_toolchain_impl(ctx):
    if ctx.attr.registry and ctx.attr.registry_path:
        fail("Only one of 'registry' or 'registry_path' attributes can be set.")
    if not ctx.attr.registry and not ctx.attr.registry_path:
        fail("One of 'registry' or 'registry_path' attributes must be set.")

    registry_files = [ctx.file.launcher]
    registry_path = ctx.attr.registry_path
    launcher_path = _to_manifest_path(ctx, ctx.file.launcher)

    if ctx.attr.registry:
        registry_files.append(ctx.file.registry)
        registry_path = _to_manifest_path(ctx, ctx.file.registry)

    # Make the $(REGISTRY_BIN) variable available in places like genrules.
    # See https://docs.bazel.build/versions/main/be/make-variables.html#custom_variables
    template_variables = platform_common.TemplateVariableInfo({
        "REGISTRY_BIN": registry_path,
        "LAUNCHER": launcher_path
    })
    default = DefaultInfo(
        files = depset(registry_files),
        runfiles = ctx.runfiles(files = registry_files)
    )
    registry_info = RegistryInfo(
        registry_path = registry_path,
        registry_files = registry_files,
        launcher_path = launcher_path
    )

    # Export all the providers inside our ToolchainInfo
    # so the resolved_toolchain rule can grab and re-export them.
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
            doc = "Launcher script exporting a bash function named start_registry taking storage dir as the only argument.",
            allow_single_file = True,
            mandatory = True,
        ),
        "registry": attr.label(
            doc = "A hermetically downloaded registry executable for the target platform.",
            mandatory = False,
            allow_single_file = True
        ),
        "registry_path": attr.string(
            doc = "Path to an existing registry executable for the target platform.",
            mandatory = False,
        )
    },
    doc = """Defines a registry toolchain.

For usage see https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.
""",
)