"""This module implements the language-specific toolchain rule.
"""

OciInfo = provider(
    doc = "Information about how to invoke the tool executable.",
    fields = {
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

def _oci_toolchain_impl(ctx):
    if ctx.attr.crane and ctx.attr.crane_path:
        fail("Can only set one of crane or crane_path but both were set.")
    if not ctx.attr.crane and not ctx.attr.crane_path:
        fail("Must set one of crane or crane_path.")

    crane_files = []
    crane_path = ctx.attr.crane_path

    if ctx.attr.crane:
        crane_files = ctx.attr.crane.files.to_list()
        crane_path = _to_manifest_path(ctx, crane_files[0])

    # Make the $(tool_BIN) variable available in places like genrules.
    # See https://docs.bazel.build/versions/main/be/make-variables.html#custom_variables
    template_variables = platform_common.TemplateVariableInfo({
        "crane_bin": crane_path,
    })
    default = DefaultInfo(
        files = depset(crane_files),
        runfiles = ctx.runfiles(files = crane_files),
    )
    oci_info = OciInfo(
        crane_path = crane_path,
        crane_files = crane_files,
    )

    # Export all the providers inside our ToolchainInfo
    # so the resolved_toolchain rule can grab and re-export them.
    toolchain_info = platform_common.ToolchainInfo(
        oci_info = oci_info,
        template_variables = template_variables,
        default = default,
    )
    return [
        default,
        toolchain_info,
        template_variables,
    ]

oci_toolchain = rule(
    implementation = _oci_toolchain_impl,
    attrs = {
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
    doc = """Defines a container compiler/runtime toolchain.

For usage see https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.
""",
)
