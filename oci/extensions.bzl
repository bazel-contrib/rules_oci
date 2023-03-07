"extensions for bzlmod"

load(":repositories.bzl", "oci_register_toolchains")

toolchains = tag_class(attrs = {
    "name": attr.string(doc = """\
Base name for generated repositories, allowing more than one set of toolchains to be registered.
Overriding the default is only permitted in the root module.
""", default = "oci"),
    "crane_version": attr.string(doc = "Explicit version of crane.", mandatory = True),
    "zot_version": attr.string(doc = "Explicit version of zot.", mandatory = True),
})

def _oci_extension(module_ctx):
    registrations = {}
    for mod in module_ctx.modules:
        for toolchains in mod.tags.toolchains:
            if toolchains.name != "oci" and not mod.is_root:
                fail("""\
                Only the root module may override the default name for the oci toolchains.
                This prevents conflicting registrations in the global namespace of external repos.
                """)
            if toolchains.name not in registrations.keys():
                registrations[toolchains.name] = []
            registrations[toolchains.name].append((toolchains.crane_version, toolchains.zot_version))
    for name, versions in registrations.items():
        if len(versions) > 1:
            # TODO: should be semver-aware, using MVS
            selected = sorted(versions, reverse = True)[0]

            # buildifier: disable=print
            print("NOTE: oci toolchains {} has multiple versions {}, selected {}".format(name, versions, selected))
        else:
            selected = versions[0]
        oci_register_toolchains(name, crane_version = selected[0], zot_version = selected[1], register = False)

oci = module_extension(
    implementation = _oci_extension,
    tag_classes = {
        "toolchains": toolchains,
    },
)
