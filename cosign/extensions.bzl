"extensions for bzlmod"

load("//cosign/private:versions.bzl", "COSIGN_VERSIONS")
load(":repositories.bzl", "cosign_register_toolchains")

toolchains = tag_class(attrs = {
    "name": attr.string(
        doc = """\
Base name for generated repositories, allowing more than one set of toolchains to be registered.
Overriding the default is only permitted in the root module.
""",
        default = "oci_cosign",
    ),
    "version": attr.string(
        doc = "Explicit version of cosign to use. Defaults to the latest mirrored version.",
        default = COSIGN_VERSIONS.keys()[0],
        values = COSIGN_VERSIONS.keys(),
    ),
})

def _cosign_extension(module_ctx):
    root_direct_deps = []
    root_direct_dev_deps = []
    for mod in module_ctx.modules:
        for toolchains in mod.tags.toolchains:
            if toolchains.name != "oci_cosign" and not mod.is_root:
                fail("""\
                Only the root module may override the default name for the cosign toolchains.
                This prevents conflicting registrations in the global namespace of external repos.
                """)
            if mod.is_root:
                deps = root_direct_dev_deps if module_ctx.is_dev_dependency(toolchains) else root_direct_deps
                deps.append("%s_toolchains" % toolchains.name)

            cosign_register_toolchains(toolchains.name, version = toolchains.version, register = False)

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_direct_deps,
        root_module_direct_dev_deps = root_direct_dev_deps,
    )

cosign = module_extension(
    implementation = _cosign_extension,
    tag_classes = {
        "toolchains": toolchains,
    },
)
