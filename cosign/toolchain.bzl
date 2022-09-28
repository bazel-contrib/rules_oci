"""This module implements the cosign-specific toolchain rule."""

def _to_manifest_path(ctx, file):
    if file.short_path.startswith("../"):
        return "external/" + file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

CosignInfo = provider(
    doc = "Information about how to invoke the cosign executable.",
    fields = {
        "cosign_path": "Path to the cosign executable for the target platform.",
        "cosign_files": """Files required in runfiles to make the cosign executable available.

May be empty if the cosign_path points to a locally installed tool binary.""",
    },
)

def _cosign_toolchain_impl(ctx):
    if ctx.attr.cosign and ctx.attr.cosign_path:
        fail("Can only set one of cosign or cosign_path but both were set.")
    if not ctx.attr.cosign and not ctx.attr.cosign_path:
        fail("Must set one of cosign or cosign_path.")

    cosign_files = []
    cosign_path = ctx.attr.cosign_path

    if ctx.attr.cosign:
        cosign_files = ctx.attr.cosign.files.to_list()
        cosign_path = _to_manifest_path(ctx, cosign_files[0])

    # Make the $(COSIGN_BIN) variable available in places like genrules.
    # See https://docs.bazel.build/versions/main/be/make-variables.html#custom_variables
    template_variables = platform_common.TemplateVariableInfo({
        "COSIGN_BIN": cosign_path,
    })
    default = DefaultInfo(
        files = depset(cosign_files),
        runfiles = ctx.runfiles(files = cosign_files),
    )
    cosign_info = CosignInfo(
        cosign_path = cosign_path,
        cosign_files = cosign_files,
    )

    # Export all the providers inside our ToolchainInfo
    # so the resolved_toolchain rule can grab and re-export them.
    toolchain_info = platform_common.ToolchainInfo(
        cosign_info = cosign_info,
        template_variables = template_variables,
        default = default,
    )
    return [
        default,
        toolchain_info,
        template_variables,
    ]

cosign_toolchain = rule(
    implementation = _cosign_toolchain_impl,
    attrs = {
        "cosign": attr.label(
            doc = "A hermetically downloaded executable target for the target platform.",
            mandatory = False,
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
        "cosign_path": attr.string(
            doc = "Path to an existing executable for the target platform.",
            mandatory = False,
        ),
    },
    doc = """Defines a container compiler/runtime toolchain.

For usage see https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.
""",
)
