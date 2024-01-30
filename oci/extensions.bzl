"extensions for bzlmod"

load(":pull.bzl", "oci_pull")
load(":repositories.bzl", "oci_register_toolchains")

# TODO: it sucks that the API of the oci_pull macro has to be repeated here.
pull = tag_class(attrs = {
    "name": attr.string(doc = "Name of the generated repository"),
    "image": attr.string(doc = """the remote image without a tag, such as gcr.io/bazel-public/bazel"""),
    "platforms": attr.string_list(doc = """for multi-architecture images, a dictionary of the platforms it supports
            This creates a separate external repository for each platform, avoiding fetching layers."""),
    "digest": attr.string(doc = """the digest string, starting with "sha256:", "sha512:", etc.
            If omitted, instructions for pinning are provided."""),
    "tag": attr.string(doc = """a tag to choose an image from the registry.
            Exactly one of `tag` and `digest` must be set.
            Since tags are mutable, this is not reproducible, so a warning is printed."""),
    "reproducible": attr.bool(doc = """Set to False to silence the warning about reproducibility when using `tag`.""", default = True),
})

toolchains = tag_class(attrs = {
    "name": attr.string(doc = """\
Base name for generated repositories, allowing more than one set of toolchains to be registered.
Overriding the default is only permitted in the root module.
""", default = "oci"),
    "crane_version": attr.string(doc = "Explicit version of crane.", mandatory = True),
})

def _oci_extension(module_ctx):
    registrations = {}
    for mod in module_ctx.modules:
        for pull in mod.tags.pull:
            oci_pull(
                name = pull.name,
                image = pull.image,
                platforms = pull.platforms,
                digest = pull.digest,
                tag = pull.tag,
                reproducible = pull.reproducible,
                is_bzlmod = True,
            )
        for toolchains in mod.tags.toolchains:
            if toolchains.name != "oci" and not mod.is_root:
                fail("""\
                Only the root module may override the default name for the oci toolchains.
                This prevents conflicting registrations in the global namespace of external repos.
                """)
            if toolchains.name not in registrations.keys():
                registrations[toolchains.name] = []
            registrations[toolchains.name].append(toolchains.crane_version)
    for name, versions in registrations.items():
        if len(versions) > 1:
            # TODO: should be semver-aware, using MVS
            selected = sorted(versions, reverse = True)[0]

            # buildifier: disable=print
            print("NOTE: oci toolchains {} has multiple versions {}, selected {}".format(name, versions, selected))
        else:
            selected = versions[0]
        oci_register_toolchains(name, crane_version = selected, register = False)

oci = module_extension(
    implementation = _oci_extension,
    tag_classes = {
        "pull": pull,
        "toolchains": toolchains,
    },
)
