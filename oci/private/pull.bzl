"Implementation details for oci_pull repository rules"

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//oci/private:authn.bzl", "authn")
load("//oci/private:download.bzl", "download")
load("//oci/private:util.bzl", "util")

# attributes that are specific to image reference url. shared between multiple targets
_IMAGE_REFERENCE_ATTRS = {
    "scheme": attr.string(
        doc = "scheme portion of the URL for fetching from the registry",
        values = ["http", "https"],
        default = "https",
    ),
    "registry": attr.string(
        doc = "Remote registry host to pull from, e.g. `gcr.io` or `index.docker.io`",
        mandatory = True,
    ),
    "repository": attr.string(
        doc = "Image path beneath the registry, e.g. `distroless/static`",
        mandatory = True,
    ),
    "identifier": attr.string(
        doc = "The digest or tag of the manifest file",
        mandatory = True,
    ),
    "config": attr.label(
        doc = "Label to a .docker/config.json file",
        allow_single_file = True,
    ),
    "config_path": attr.label(
        # TODO(2.0): remove
        doc = "Deprecated. Use DOCKER_CONFIG environment variable or config attribute instead. TODO(2.0): remove",
        allow_single_file = True,
    ),
}

SCHEMA1_ERROR="""\
Registry responded with a manifest that has `schemaVersion=1`
Usually happens when fetching from a registry that requires `Docker-Distribution-API-Version` header to be set
"""

OCI_MEDIA_TYPE_OR_AUTHN_ERROR="""\
Could not fetch the manifest. Either there was an authentication issue or trying to pull an image with OCI image media types.
"""


# Supported media types
# * OCI spec: https://github.com/opencontainers/image-spec/blob/main/media-types.md
# * Docker spec: https://github.com/distribution/distribution/blob/main/docs/spec/manifest-v2-2.md#media-types
_SUPPORTED_MEDIA_TYPES = {
    "index": [
        "application/vnd.docker.distribution.manifest.list.v2+json",
        "application/vnd.oci.image.index.v1+json",
    ],
    "manifest": [
        "application/vnd.docker.distribution.manifest.v2+json",
        "application/vnd.oci.image.manifest.v1+json",
    ],
}

def _config_path(rctx):
    if rctx.attr.config:
        return rctx.path(rctx.attr.config)
    elif rctx.attr.config_path:
        util.warning(rctx, "attribute config_path is deprecated and will be removed in 2.0. use DOCKER_CONFIG environment variable or config attribute instead.")
        return rctx.path(rctx.attr.config_path)
    else:
        return None

def _is_tag(str):
    return str.find(":") == -1

def _digest_into_blob_path(digest):
    "convert sha256:deadbeef into sha256/deadbeef"
    digest_path = digest.replace(":", "/", 1)
    return "blobs/{}".format(digest_path)

def _download(rctx, authn, identifier, output, resource, download_fn = download.bazel, headers = {}, allow_fail = False):
    "Use the Bazel Downloader to fetch from the remote registry"

    if resource != "blobs" and resource != "manifests":
        fail("resource must be blobs or manifests")

    auth = authn.get_token(rctx.attr.registry, rctx.attr.repository)

    # Construct the URL to fetch from remote, see
    # https://github.com/google/go-containerregistry/blob/62f183e54939eabb8e80ad3dbc787d7e68e68a43/pkg/v1/remote/descriptor.go#L234
    registry_url = "{scheme}://{registry}/v2/{repository}/{resource}/{identifier}".format(
        scheme = rctx.attr.scheme,
        registry = rctx.attr.registry,
        repository = rctx.attr.repository,
        resource = resource,
        identifier = identifier,
    )

    sha256 = ""

    if identifier.startswith("sha256:"):
        sha256 = identifier[len("sha256:"):]
    else:
        util.warning(rctx, "Fetching from {} without an integrity hash. The result will not be cached.".format(registry_url))

    return download_fn(
        rctx,
        output = output,
        sha256 = sha256,
        url = registry_url,
        auth = {registry_url: auth},
        headers = headers,
        allow_fail = allow_fail,
    )

def _download_manifest(rctx, authn, identifier, output):
    bytes = None
    manifest = None
    digest = None

    result = _download(rctx, authn, identifier, output, "manifests", allow_fail = True)

    fallback_to_curl = False
    if result.success:
        bytes = rctx.read(output)
        manifest = json.decode(bytes)
        digest = "sha256:{}".format(result.sha256)
        if manifest["schemaVersion"] == 1:
            fallback_to_curl = True
            util.warning(rctx, SCHEMA1_ERROR)
    else:
        fallback_to_curl = True
        util.warning(rctx, OCI_MEDIA_TYPE_OR_AUTHN_ERROR)
        explanation = authn.explain()
        if explanation:
            util.warning(rctx, explanation)

    if fallback_to_curl:    
        util.warning(rctx, "Falling back to using `curl`. See https://github.com/bazelbuild/bazel/issues/17829 for the context.")
        _download(
            rctx,
            authn,
            identifier,
            output,
            "manifests",
            download.curl,
            headers = {
                "Accept": ",".join(_SUPPORTED_MEDIA_TYPES["index"] + _SUPPORTED_MEDIA_TYPES["manifest"]),
                "Docker-Distribution-API-Version": "registry/2.0",
            }
        )
        bytes = rctx.read(output)
        manifest = json.decode(bytes)
        digest = "sha256:{}".format(util.sha256(rctx, output))

    return manifest, len(bytes), digest

def _create_downloader(rctx, authn):
    return struct(
        download_blob = lambda identifier, output: _download(rctx, authn, identifier, output, "blobs"),
        download_manifest = lambda identifier, output: _download_manifest(rctx, authn, identifier, output),
    )

_BUILD_FILE_TMPL = """\
"Generated by oci_pull. DO NOT EDIT!"

load("@aspect_bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")

copy_to_directory(
    name = "{target_name}",
    out = "layout",
    # Always use hardlink to avoid having copies of the blobs from external repository in the output-tree.
    hardlink = "on",
    include_external_repositories = ["*"],
    srcs = glob(["blobs/**"]) + [
        "oci-layout",
        "index.json",
    ],
    visibility = ["//visibility:public"]
)
"""

def _find_platform_manifest(image_mf, platform_wanted):
    for mf in image_mf["manifests"]:
        parts = [
            mf["platform"]["os"],
            mf["platform"]["architecture"],
        ]
        if "variant" in mf["platform"]:
            parts.append(mf["platform"]["variant"])

        platform = "/".join(parts)
        if platform_wanted == platform:
            return mf
    return None

def _oci_pull_impl(rctx):
    au = authn.new(rctx, _config_path(rctx))
    downloader = _create_downloader(rctx, au)

    manifest, size, digest = downloader.download_manifest(rctx.attr.identifier, "manifest.json")

    if manifest["mediaType"] in _SUPPORTED_MEDIA_TYPES["manifest"]:
        if rctx.attr.platform:
            fail("{}/{} is a single-architecture image, so attribute 'platforms' should not be set.".format(rctx.attr.registry, rctx.attr.repository))

    elif manifest["mediaType"] in _SUPPORTED_MEDIA_TYPES["index"]:
        if not rctx.attr.platform:
            fail("{}/{} is a multi-architecture image, so attribute 'platforms' is required.".format(rctx.attr.registry, rctx.attr.repository))

        matching_manifest = _find_platform_manifest(manifest, rctx.attr.platform)
        if not matching_manifest:
            fail("No matching manifest found in image {}/{} for platform {}".format(rctx.attr.registry, rctx.attr.repository, rctx.attr.platform))

        # extra download to get the manifest for the target platform
        manifest, size, digest = downloader.download_manifest(matching_manifest["digest"], "manifest.json")
    else:
        fail("Unrecognized mediaType {} in manifest file".format(manifest["mediaType"]))
    
    # symlink manifest.json to blobs with it's digest. 
    # it is okay to use symlink here as copy_to_directory will dereference it when creating the TreeArtifact.
    rctx.symlink("manifest.json", _digest_into_blob_path(digest))

    # download the image config
    downloader.download_blob(manifest["config"]["digest"], _digest_into_blob_path(manifest["config"]["digest"]))

    # download all layers
    # TODO: we should avoid eager-download of the layers ("shallow pull")
    for layer in manifest["layers"]:
        downloader.download_blob(layer["digest"], _digest_into_blob_path(layer["digest"]))

    rctx.file("index.json", util.build_manifest_json(
        media_type = manifest["mediaType"],
        size = size,
        digest = digest,
        platform = rctx.attr.platform,
    ))
    rctx.file("oci-layout", json.encode_indent({"imageLayoutVersion": "1.0.0"}, indent = "    "))

    rctx.file("BUILD.bazel", content = _BUILD_FILE_TMPL.format(
        target_name = rctx.attr.target_name
    ))

oci_pull = repository_rule(
    implementation = _oci_pull_impl,
    attrs = dicts.add(
        _IMAGE_REFERENCE_ATTRS,
        {
            "platform": attr.string(
                doc = "A single platform in `os/arch` format, for multi-arch images",
            ),
            "target_name": attr.string(
                doc = "Name given for the image target, e.g. 'image'",
                mandatory = True,
            ),
        },
    ),
    environ = authn.ENVIRON
)

_MULTI_PLATFORM_IMAGE_ALIAS_TMPL = """\
alias(
    name = "{target_name}",
    actual = select(
        {platform_map},
        no_match_error = \"\"\"could not find an image matching the target platform. \\navailable platforms are {available_platforms} \"\"\",
    ),
    visibility = ["//visibility:public"],
)
"""

_SINGLE_PLATFORM_IMAGE_ALIAS_TMPL = """\
alias(
    name = "{target_name}",
    actual = "@{original}//:{original}",
    visibility = ["//visibility:public"],
)
"""

def _oci_alias_impl(rctx):
    if rctx.attr.platforms and rctx.attr.platform:
        fail("Only one of 'platforms' or 'platform' may be set")
    if not rctx.attr.platforms and not rctx.attr.platform:
        fail("One of 'platforms' or 'platform' must be set")

    au = authn.new(rctx, _config_path(rctx))
    downloader = _create_downloader(rctx, au)

    available_platforms = []

    manifest, _, digest = downloader.download_manifest(rctx.attr.identifier, "mf.json")

    if manifest["mediaType"] in _SUPPORTED_MEDIA_TYPES["index"]:
        for submanifest in manifest["manifests"]:
            parts = [submanifest["platform"]["os"], submanifest["platform"]["architecture"]]
            if "variant" in submanifest["platform"]:
                parts.append(submanifest["platform"]["variant"])
            available_platforms.append('"{}"'.format("/".join(parts)))

    if _is_tag(rctx.attr.identifier) and rctx.attr.reproducible:
        is_bzlmod = hasattr(rctx.attr, "bzlmod_repository") and rctx.attr.bzlmod_repository

        optional_platforms = ""

        if len(available_platforms):
            optional_platforms = "'add platforms {}'".format(" ".join(available_platforms))

        util.warning(rctx, """\
For reproducible builds, a digest is recommended.
Either set 'reproducible = False' to silence this warning, or run the following command to change {rule} to use a digest:
{warning}

buildozer 'set digest "{digest}"' 'remove tag' 'remove platforms' {optional_platforms} {location}
    """.format(
            location = "MODULE.bazel:" + rctx.attr.bzlmod_repository if is_bzlmod else "WORKSPACE:" + rctx.attr.name,
            digest = digest,
            optional_platforms = optional_platforms,
            warning = "(make sure you use a recent buildozer release with MODULE.bazel support)" if is_bzlmod else "",
            rule = "oci.pull" if is_bzlmod else "oci_pull",
        ))

    build = ""
    if rctx.attr.platforms:
        build = _MULTI_PLATFORM_IMAGE_ALIAS_TMPL.format(
            name = rctx.attr.name,
            target_name = rctx.attr.target_name,
            available_platforms = ", ".join(available_platforms),
            platform_map = {
                str(k): v
                for k, v in rctx.attr.platforms.items()
            },
        )
    else:
        build = _SINGLE_PLATFORM_IMAGE_ALIAS_TMPL.format(
            name = rctx.attr.name,
            target_name = rctx.attr.target_name,
            original = rctx.attr.platform.name,
        )

    rctx.file("BUILD.bazel", content = build)

oci_alias = repository_rule(
    implementation = _oci_alias_impl,
    attrs = dicts.add(
        _IMAGE_REFERENCE_ATTRS,
        {
            "platforms": attr.label_keyed_string_dict(),
            "platform": attr.label(),
            "target_name": attr.string(),
            "reproducible": attr.bool(default = True, doc = "Set to False to silence the warning about reproducibility when using `tag`"),
            "bzlmod_repository": attr.string(
                doc = "For error reporting. When called from a module extension, provides the original name of the repository prior to mapping",
            ),
        },
    ),
    environ = authn.ENVIRON
)
