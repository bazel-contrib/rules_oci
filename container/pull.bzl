"Pulls an image from a registry"

_ATTRS = {
    "reference": attr.string(
        mandatory = True,
        doc = """
A reference to the image that resides in the remote registry. 
To ensure hermeticity avoid using tags. Instead provide a fully qualified reference such as `library/debian@sha256:fb45fd4e25abe55a656ca69`
Although using references such as library/debian@latest is okay for development purposes, should not not be submitted.
At best using tags will make your build non-hermetic.
"""
    ),
    "registry": attr.string(
        default = "index.docker.io",
    ),
    "toolchain": attr.string(
        default = "container",
    ),
}

OCI_IMAGE_INDEX = "application/vnd.oci.image.index.v1+json"
DOCKER_MANIFEST_LIST = "application/vnd.docker.distribution.manifest.list.v2+json"

def _is_image_index(descriptor):
    media_type = descriptor["mediaType"]
    return media_type == OCI_IMAGE_INDEX or media_type == DOCKER_MANIFEST_LIST

OCI_MANIFEST_SCHEMA1 = "application/vnd.oci.image.manifest.v1+json"
DOCKER_MANIFEST_SCHEMA2 = "application/vnd.docker.distribution.manifest.v2+json"

def _is_image(descriptor):
    media_type = descriptor["mediaType"]
    return media_type == OCI_MANIFEST_SCHEMA1 or media_type == DOCKER_MANIFEST_SCHEMA2

def _print_image(platform, digest, reference, registry):
    os = platform["os"]
    arch = platform["architecture"]
    if "variant" in platform and arch != "arm64":
        arch += platform["variant"]
    parts = [os, arch]
    if "os.version" in platform:
        parts.append(platform["os.version"].replace(".", "_"))

    return """
image_pull(
    name = "{name}",
    reference = "{reference}",
    digest = "{digest}",
    registry = "{registry}",
    visibility = ["//visibility:public"],
)
""".format(
        name = "_".join(parts),
        reference = reference,
        digest = digest,
        registry = registry,
    )

def _strip_tag_and_digest(ref):
    tag_index = ref.find(":")
    if tag_index != -1:
        ref = ref[:tag_index]
    digest_index = ref.find("@")
    if digest_index != -1:
        ref = ref[:digest_index]
    return ref

def _crane_label(rctx):
    os = rctx.os.name.lower()
    if os == "mac os x":
        os = "darwin"
    arch = rctx.execute(["uname", "-m"]).stdout.strip()
    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"
    return Label("@%s_%s_%s//:crane" % (rctx.attr.toolchain, os, arch))

def _config_to_platform(config):
    platform = dict(
        os = config["os"],
        architecture = config["architecture"],
    )
    if "variant" in config:
        platform["variant"] = config["variant"]
    return platform

def _impl(rctx):
    crane = rctx.path(_crane_label(rctx))

    rctx.report_progress("Fetching %s" % (rctx.attr.reference))

    reference = "/".join([rctx.attr.registry, rctx.attr.reference])
    stripped_reference = _strip_tag_and_digest(rctx.attr.reference)

    r = rctx.execute([crane, "manifest", reference])
    descriptor = json.decode(r.stdout)

    content = ["""load("@aspect_rules_container//container/private:pull.bzl", "image_pull")\n"""]

    if _is_image_index(descriptor):
        for descriptor in descriptor["manifests"]:
            content.append(
                _print_image(
                    descriptor["platform"],
                    descriptor["digest"],
                    stripped_reference,
                    rctx.attr.registry,
                ),
            )
    elif _is_image(descriptor):
        # this is a single image so find out what platform it has
        r = rctx.execute([crane, "config", reference])
        config = json.decode(r.stdout)
        digest = rctx.execute([crane, "digest", reference]).stdout.strip()
        content.append(
            _print_image(
                _config_to_platform(config),
                digest,
                stripped_reference,
                rctx.attr.registry,
            ),
        )

    rctx.file("BUILD.bazel", "".join(content))

container_pull = repository_rule(
    implementation = _impl,
    attrs = _ATTRS,
)
