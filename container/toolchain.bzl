"""This module implements the language-specific toolchain rule.
"""

ContainerInfo = provider(
    doc = "Information about how to invoke the tool executable.",
    fields = {
        # Umoci
        "umoci_path": "Path to the umoci executable for the target platform.",
        "umoci_files": """Files required in runfiles to make the umoci executable available.

May be empty if the umoci_path points to a locally installed umoci binary.""",
        # Crane
        "crane_path": "Path to the tool executable for the target platform.",
        "crane_files": """Files required in runfiles to make the tool executable available.
May be empty if the crane_path points to a locally installed tool binary.""",
    },
)

# Avoid using non-normalized paths (workspace/../other_workspace/path)
def _to_manifest_path(ctx, file):
    if file.short_path.startswith("../"):
        return "external/" + file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

def _container_toolchain_impl(ctx):
    if ctx.attr.umoci and ctx.attr.umoci_path:
        fail("Can only set one of umoci or umoci_path but both were set.")
    if not ctx.attr.umoci and not ctx.attr.umoci_path:
        fail("Must set one of umoci or umoci_path.")

    umoci_files = []
    umoci_path = ctx.attr.umoci_path

    if ctx.attr.umoci:
        umoci_files = ctx.attr.umoci.files.to_list()
        umoci_path = _to_manifest_path(ctx, umoci_files[0])

    crane_files = []
    crane_path = ctx.attr.crane_path

    if ctx.attr.crane:
        crane_files = ctx.attr.crane.files.to_list()
        crane_path = _to_manifest_path(ctx, crane_files[0])

    # Make the $(UMOCI_BIN) and $(CRANE_BIN) variable available in places like genrules.
    # See https://docs.bazel.build/versions/main/be/make-variables.html#custom_variables
    template_variables = platform_common.TemplateVariableInfo({
        "UMOCI_BIN": umoci_path,
        "CRANE_BIN": crane_path,
    })
    default = DefaultInfo(
        files = depset(umoci_files),
        runfiles = ctx.runfiles(files = umoci_files),
    )
    containerinfo = ContainerInfo(
        umoci_path = umoci_path,
        umoci_files = umoci_files,
        crane_files = crane_files,
        crane_path = crane_path
    )

    # Export all the providers inside our ToolchainInfo
    # so the resolved_toolchain rule can grab and re-export them.
    toolchain_info = platform_common.ToolchainInfo(
        containerinfo = containerinfo,
        template_variables = template_variables,
        default = default,
    )
    return [
        default,
        toolchain_info,
        template_variables,
    ]

container_toolchain = rule(
    implementation = _container_toolchain_impl,
    attrs = {
        "umoci": attr.label(
            doc = "A hermetically downloaded executable target for the target platform.",
            mandatory = False,
            allow_single_file = True,
        ),
        "umoci_path": attr.string(
            doc = "Path to an existing executable for the target platform.",
            mandatory = False,
        ),
        "crane": attr.label(
            doc = "A hermetically downloaded executable target for the target platform.",
            mandatory = False,
            allow_single_file = True,
        ),
        "crane_path": attr.string(
            doc = "Path to an existing executable for the target platform.",
            mandatory = False,
        ),
    },
    doc = """Defines a crane/umoci toolchain.

For usage see https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.
""",
)
