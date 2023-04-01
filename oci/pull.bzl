"""A repository rule to pull image layers using Bazel's downloader.

Typical usage in `WORKSPACE.bazel`:

```starlark
load("@rules_oci//oci:pull.bzl", "oci_pull")

# A single-arch base image
oci_pull(
    name = "distroless_java",
    digest = "sha256:161a1d97d592b3f1919801578c3a47c8e932071168a96267698f4b669c24c76d",
    image = "gcr.io/distroless/java17",
)

# A multi-arch base image
oci_pull(
    name = "distroless_static",
    digest = "sha256:c3c3d0230d487c0ad3a0d87ad03ee02ea2ff0b3dcce91ca06a1019e07de05f12",
    image = "gcr.io/distroless/static",
    platforms = [
        "linux/amd64",
        "linux/arm64",
    ],
)
```

Now you can refer to these as a base layer in `BUILD.bazel`.
The target is named the same as the external repo, so you can use a short label syntax:

```
oci_image(
    name = "app",
    base = "@distroless_static",
    ...
)
```
"""

load("@aspect_bazel_lib//lib:paths.bzl", "BASH_RLOCATION_FUNCTION")
load("@aspect_bazel_lib//lib:base64.bzl", "base64")
load("//oci/private:download.bzl", "download")

def _strip_host(url):
    # TODO: a principled way of doing this
    return url.replace("http://", "").replace("https://", "").replace("/v1/", "")

def _file_exists(rctx, path):
    result = rctx.execute(["stat", path])
    return result.return_code == 0

# Path of the auth file is determined by the order described here;
# https://github.com/google/go-containerregistry/tree/main/pkg/authn#tldr-for-consumers-of-this-package
def _get_auth_file_path(rctx):
    # this is the standard path where registry credentials are stored
    config_path = "{}/.docker/config.json".format(rctx.os.environ["HOME"])

    # set config path to DOCKER_CONFIG env if present
    if "DOCKER_CONFIG" in rctx.os.environ:
        config_path = rctx.os.environ["DOCKER_CONFIG"]

    if _file_exists(rctx, config_path):
        return config_path

    # https://docs.podman.io/en/latest/markdown/podman-login.1.html#authfile-path
    XDG_RUNTIME_DIR = "{}/.config".format(rctx.os.environ["HOME"])
    if "XDG_RUNTIME_DIR" in rctx.os.environ:
        XDG_RUNTIME_DIR = rctx.os.environ["XDG_RUNTIME_DIR"]

    config_path = "{}/containers/auth.json".format(XDG_RUNTIME_DIR)

    # podman support overriding the standard path for the auth file via this special environment variable.
    # https://docs.podman.io/en/latest/markdown/podman-login.1.html#authfile-path
    if "REGISTRY_AUTH_FILE" in rctx.os.environ:
        config_path = rctx.os.environ["REGISTRY_AUTH_FILE"]

    if _file_exists(rctx, config_path):
        return config_path

    return None

# Unfortunately bazel downloader doesn't let us sniff the WWW-Authenticate header, therefore we need to
# keep a map of known registries that require us to acquire a temporary token for authentication.
_www_authenticate = {
    "index.docker.io": {
        "realm": "auth.docker.io/token",
        "scope": "repository:{repository}:pull",
        "service": "registry.docker.io",
    },
    "public.ecr.aws": {
        "realm": "public.ecr.aws/token",
        "scope": "repository:{repository}:pull",
        "service": "public.ecr.aws",
    },
}

def _auth_basic(rctx, registry, repository, identifier):
    """A function that performs basic auth using docker/config.json

    Args:
        rctx: repository context
        registry: registry url
        repository: image repository
        identifier: tag or digest

    Returns:
        A dict for rctx.download#auth
    """
    pattern = {}

    config_path = _get_auth_file_path(rctx)

    if config_path:
        config_raw = rctx.read(config_path)
        config = json.decode(config_raw)

        for host_raw in config["auths"]:
            host = _strip_host(host_raw)
            if host == registry:
                raw_auth = config["auths"][host_raw]["auth"]
                (login, password) = base64.decode(raw_auth).split(":")
                pattern = {
                    "type": "basic",
                    "login": login,
                    "password": password,
                }
    else:
        # buildifier: disable=print
        print("""
WARNING: Could not find the `$HOME/.docker/config.json` and `$XDG_RUNTIME_DIR/containers/auth.json` file.

Running one of `podman login`, `docker login`, `crane login` may help.
        """)
        pattern = {}

    if registry in _www_authenticate:
        www_authenticate = _www_authenticate[registry]
        url = "https://{realm}?scope={scope}&service={service}".format(
            realm = www_authenticate["realm"],
            service = www_authenticate["service"],
            scope = www_authenticate["scope"].format(repository = repository),
        )
        rctx.download(
            url = [url],
            output = "www-authenticate.json",
        )
        auth_raw = rctx.read("www-authenticate.json")
        auth = json.decode(auth_raw)
        pattern = {
            "type": "pattern",
            "pattern": "Bearer <password>",
            "password": auth["token"],
        }

    return pattern

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

def _parse_reference(reference):
    protocol = "https"
    protocol_idx = reference.find("://")
    if protocol_idx != -1:
        protocol = reference[:protocol_idx]
        reference = reference[protocol_idx + 3:]
        if protocol != "http" and protocol != "https":
            fail("`{}` is not an allowed protocol. protocol can be either `http` or `https`".format(protocol))
    firstslash = reference.find("/")
    registry = reference[:firstslash]
    repository = reference[firstslash + 1:]

    return registry, repository, protocol

def _is_tag(str):
    return str.find(":") == -1

def _trim_hash_algorithm(identifier):
    "Optionally remove the sha256: prefix from identifier, if present"
    parts = identifier.split(":", 1)
    if len(parts) != 2:
        return identifier
    return parts[1]

def _download(rctx, identifier, output, resource = "blobs", download_fn = download.bazel, headers = {}):
    "Use the Bazel Downloader to fetch from the remote registry"

    if resource != "blobs" and resource != "manifests":
        fail("resource must be blobs or manifests")

    registry, repository, protocol = _parse_reference(rctx.attr.image)

    auth = _auth_basic(rctx, registry, repository, identifier)

    # Construct the URL to fetch from remote, see
    # https://github.com/google/go-containerregistry/blob/62f183e54939eabb8e80ad3dbc787d7e68e68a43/pkg/v1/remote/descriptor.go#L234
    registry_url = "{protocol}://{registry}/v2/{repository}/{resource}/{identifier}".format(
        protocol = protocol,
        registry = registry,
        repository = repository,
        resource = resource,
        identifier = identifier,
    )

    # TODO(https://github.com/bazel-contrib/rules_oci/issues/73): other hash algorithms
    if identifier.startswith("sha256:"):
        download_fn(
            rctx,
            output = output,
            sha256 = identifier[len("sha256:"):],
            url = registry_url,
            auth = {
                registry_url: auth,
            },
            headers = headers,
        )
    else:
        # buildifier: disable=print
        print("""
WARNING: fetching from %s without an integrity hash. The result will not be cached.""" % registry_url)
        download_fn(
            rctx,
            output = output,
            url = registry_url,
            auth = {
                registry_url: auth,
            },
            headers = headers,
        )

def _download_manifest(rctx, identifier, output):
    _download(rctx, identifier, output, "manifests")
    bytes = rctx.read(output)
    manifest = json.decode(bytes)
    if manifest["schemaVersion"] == 1:
        # buildifier: disable=print
        print("""
WARNING: registry responded with a manifest that has schemaVersion=1. Usually happens when fetching from a registry that requires `Docker-Distribution-API-Version` header to be set.
Falling back to using `curl`. See https://github.com/bazelbuild/bazel/issues/17829 for the context.
""")
        _download(
            rctx,
            identifier,
            output,
            "manifests",
            download.curl,
            headers = {
                "Accept": ",".join(_SUPPORTED_MEDIA_TYPES["index"] + _SUPPORTED_MEDIA_TYPES["manifest"]),
                "Docker-Distribution-API-Version": "registry/2.0",
            },
        )
        bytes = rctx.read(output)
        manifest = json.decode(bytes)

    return manifest, len(bytes)

_build_file = """\
"Generated by oci_pull"

load("@aspect_bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load("@aspect_bazel_lib//lib:jq.bzl", "jq")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

package(default_visibility = ["//visibility:public"])

# Mimic the output of crane pull [image] layout --format=oci
write_file(
    name = "write_layout",
    out = "oci-layout",
    content = [
        "{{",
        "    \\"imageLayoutVersion\\": \\"1.0.0\\"",
        "}}",
    ],
)

write_file(
    name = "write_index",
    out = "index.json",
    content = [\"\"\"{index_content}\"\"\"],
)

copy_to_directory(
    name = "blobs",
    # TODO(https://github.com/bazel-contrib/rules_oci/issues/73): other hash algorithms
    out = "blobs/sha256",
    include_external_repositories = ["*"],
    srcs = {tars} + [
        ":{manifest_file}",
        ":{config_file}",
    ],
)

copy_to_directory(
    name = "{target_name}",
    out = "layout",
    include_external_repositories = ["*"],
    srcs = [
        "blobs",
        "oci-layout",
        "index.json",
    ],
)
"""

def _find_platform_manifest(rctx, image_mf):
    for mf in image_mf["manifests"]:
        plat = "{}/{}".format(mf["platform"]["os"], mf["platform"]["architecture"])
        if plat == rctx.attr.platform:
            return mf
    fail("No matching manifest found in image {} for platform {}".format(rctx.attr.image, rctx.attr.platform))

def _oci_pull_impl(rctx):
    mf_file = _trim_hash_algorithm(rctx.attr.identifier)
    mf, mf_len = _download_manifest(rctx, rctx.attr.identifier, mf_file)

    if mf["mediaType"] in _SUPPORTED_MEDIA_TYPES["manifest"]:
        if rctx.attr.platform:
            fail("{} is a single-architecture image, so attribute 'platform' should not be set.".format(rctx.attr.image))
        image_mf_file = mf_file
        image_mf = mf
        image_mf_len = mf_len
        image_digest = rctx.attr.identifier
    elif mf["mediaType"] in _SUPPORTED_MEDIA_TYPES["index"]:
        # extra download to get the manifest for the selected arch
        if not rctx.attr.platform:
            fail("{} is a multi-architecture image, so attribute 'platform' is required.".format(rctx.attr.image))
        matching_mf = _find_platform_manifest(rctx, mf)
        image_digest = matching_mf["digest"]
        image_mf_file = _trim_hash_algorithm(image_digest)
        image_mf, image_mf_len = _download_manifest(rctx, image_digest, image_mf_file)
    else:
        fail("Unrecognized mediaType {} in manifest file".format(mf["mediaType"]))

    image_config_file = _trim_hash_algorithm(image_mf["config"]["digest"])
    _download(rctx, image_mf["config"]["digest"], image_config_file)

    tars = []
    for layer in image_mf["layers"]:
        hash = _trim_hash_algorithm(layer["digest"])

        # TODO: we should avoid eager-download of the layers ("shallow pull")
        _download(rctx, layer["digest"], hash)
        tars.append(hash)

    # To make testing against `crane pull` simple, we take care to produce a byte-for-byte-identical
    # index.json file, which means we can't use jq (it produces a trailing newline) or starlark
    # json.encode_indent (it re-orders keys in the dictionary).
    if rctx.attr.platform:
        os, arch = rctx.attr.platform.split("/", 1)
        index_mf = """\
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.oci.image.index.v1+json",
   "manifests": [
      {
         "mediaType": "%s",
         "size": %s,
         "digest": "%s",
         "platform": {
            "architecture": "%s",
            "os": "%s"
         }
      }
   ]
}""" % (image_mf["mediaType"], image_mf_len, image_digest, arch, os)
    else:
        index_mf = """\
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.oci.image.index.v1+json",
   "manifests": [
      {
         "mediaType": "%s",
         "size": %s,
         "digest": "%s"
      }
   ]
}""" % (image_mf["mediaType"], image_mf_len, image_digest)

    rctx.file("BUILD.bazel", content = _build_file.format(
        target_name = rctx.attr.target_name,
        tars = tars,
        index_content = index_mf,
        manifest_file = image_mf_file,
        config_file = image_config_file,
    ))

oci_pull_rule = repository_rule(
    implementation = _oci_pull_impl,
    attrs = {
        "image": attr.string(doc = "The name of the image we are fetching, e.g. gcr.io/distroless/static", mandatory = True),
        "identifier": attr.string(doc = "The digest or tag of the manifest file", mandatory = True),
        "platform": attr.string(doc = "platform in `os/arch` format, for multi-arch images"),
        "target_name": attr.string(doc = "Name given for the image target, e.g. 'image'", mandatory = True),
        "toolchain_name": attr.string(default = "oci", doc = "Value of name attribute to the oci_register_toolchains call in the workspace."),
    },
    environ = [
        # These environment variables allow standard authorization file path to overridden with something else therefore
        # needs to be tracked as part of the repository cache key so that bazel refetches these when any of the variables change.
        # while docker uses DOCKER_CONFIG for the override, podman uses REGISTRY_AUTH_FILE environment variable, and
        # since rules_oci has no preference over the runtime, it has to support both.
        # See: https://github.com/google/go-containerregistry/tree/main/pkg/authn#tldr-for-consumers-of-this-package for go implementation.
        "DOCKER_CONFIG",
        "REGISTRY_AUTH_FILE",
    ],
)

_alias_target = """\
alias(
    name = "{target_name}",
    actual = select(
        {platform_map}
    ),
    visibility = ["//visibility:public"],
)
"""

def _oci_alias_impl(rctx):
    rctx.file("BUILD.bazel", content = _alias_target.format(
        target_name = rctx.attr.target_name,
        platform_map = {str(k): v for k, v in rctx.attr.platforms.items()},
    ))

oci_alias = repository_rule(
    implementation = _oci_alias_impl,
    attrs = {
        "platforms": attr.label_keyed_string_dict(),
        "target_name": attr.string(),
    },
)

_latest_build = """\
load("@aspect_bazel_lib//lib:jq.bzl", "jq")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

jq(
    name = "platforms",
    srcs = ["manifest_list.json"],
    filter = "[(.manifests // [])[] | .platform | .os + \\"/\\" + .architecture]",
    # Print without newlines because it's too hard to indent that to fit under the generated
    # starlark code below.
    args = ["--compact-output"],
)

jq(
    name = "mediaType",
    srcs = ["manifest_list.json"],
    filter = ".mediaType",
    args = ["--raw-output"],
)

sh_binary(
    name = "pin",
    srcs = ["pin.sh"],
    data = [
        ":mediaType",
        ":platforms",
        "@bazel_tools//tools/bash/runfiles",
    ],
)
"""

_pin_sh = """\
#!/usr/bin/env bash
{rlocation}

mediaType="$(cat $(rlocation {name}/mediaType.json))"
echo -e "Replace your '{reponame}' declaration with the following:\n"

cat <<EOF
oci_pull(
    name = "{reponame}",
    digest = "sha256:{digest}",
    image = "{image}",
EOF

[[ $mediaType == "{manifestListType}" ]] && cat <<EOF
    # Listing of all platforms that were found in the image manifest.
    # You may remove any that you don't use.
    platforms = $(cat $(rlocation {name}/platforms.json)),
EOF

echo ")"
"""

def _pin_tag_impl(rctx):
    """Download the tag and create a repository that can produce pinning instructions"""
    _download_manifest(rctx, rctx.attr.tag, "manifest_list.json")
    result = rctx.execute(["shasum", "-a", "256", "manifest_list.json"])
    if result.return_code:
        msg = "shasum failed: \nSTDOUT:\n%s\nSTDERR:\n%s" % (result.stdout, result.stderr)
        fail(msg)
    rctx.file("pin.sh", _pin_sh.format(
        name = rctx.attr.name,
        reponame = rctx.attr.name.replace("_unpinned", ""),
        digest = result.stdout.split(" ", 1)[0],
        image = rctx.attr.image,
        rlocation = BASH_RLOCATION_FUNCTION,
        manifestListType = "application/vnd.oci.image.index.v1+json",
    ), executable = True)
    rctx.file("BUILD.bazel", _latest_build)

pin_tag = repository_rule(
    _pin_tag_impl,
    attrs = {
        "image": attr.string(doc = "The name of the image we are fetching, e.g. `gcr.io/distroless/static`", mandatory = True),
        "tag": attr.string(doc = "The tag being used, e.g. `latest`", mandatory = True),
        "toolchain_name": attr.string(default = "oci", doc = "Value of name attribute to the oci_register_toolchains call in the workspace."),
    },
)

# Note: there is no exhaustive list, image authors can use whatever name they like.
# This is only used for the oci_alias rule that makes a select() - if a mapping is missing,
# users can just write their own select() for it.
_DOCKER_ARCH_TO_BAZEL_CPU = {
    "amd64": "@platforms//cpu:x86_64",
    "arm": "@platforms//cpu:arm",
    "arm64": "@platforms//cpu:arm64",
    "ppc64le": "@platforms//cpu:ppc",
    "s390x": "@platforms//cpu:s390x",
}

def oci_pull(name, image, platforms = None, digest = None, tag = None, reproducible = True, toolchain_name = "oci"):
    """Repository macro to fetch image manifest data from a remote docker registry.

    To use the resulting image, you can use the `@wkspc` shorthand label, for example
    if `name = "distroless_base"`, then you can just use `base = "@distroless_base"`
    in rules like `oci_image`.

    > This shorthand syntax is broken on the command-line prior to Bazel 6.2.
    > See https://github.com/bazelbuild/bazel/issues/4385

    Args:
        name: repository with this name is created
        image: the remote image without a tag, such as gcr.io/bazel-public/bazel
        platforms: for multi-architecture images, a dictionary of the platforms it supports
            This creates a separate external repository for each platform, avoiding fetching layers.
        digest: the digest string, starting with "sha256:", "sha512:", etc.
            If omitted, instructions for pinning are provided.
        tag: a tag to choose an image from the registry.
            Exactly one of `tag` and `digest` must be set.
            Since tags are mutable, this is not reproducible, so a warning is printed.
        reproducible: Set to False to silence the warning about reproducibility when using `tag`.
        toolchain_name: Value of name attribute to the oci_register_toolchains call in the workspace.
    """

    if digest and tag:
        # Users might wish to leave tag=latest as "documentation" however if we just ignore tag
        # then it's never checked which means the documentation can be wrong.
        # For now just forbit having both, it's a non-breaking change to allow it later.
        fail("Only one of 'digest' or 'tag' may be set")

    if not digest and not tag:
        fail("One of 'digest' or 'tag' must be set")

    if tag and reproducible:
        pin_tag(name = name + "_unpinned", image = image, tag = tag, toolchain_name = toolchain_name)

        # Print a command - in the future we should print a buildozer command or
        # buildifier: disable=print
        print("""
WARNING: for reproducible builds, a digest is recommended.
Either set 'reproducible = False' to silence this warning,
or run the following command to change oci_pull to use a digest:

bazel run @{}_unpinned//:pin
""".format(name))
        return

    if platforms:
        select_map = {}
        for plat in platforms:
            plat_name = "_".join([name] + plat.split("/"))
            os, arch = plat.split("/", 1)
            oci_pull_rule(
                name = plat_name,
                image = image,
                identifier = digest or tag,
                platform = plat,
                target_name = plat_name,
                toolchain_name = toolchain_name,
            )
            select_map[_DOCKER_ARCH_TO_BAZEL_CPU[arch]] = "@" + plat_name
        oci_alias(
            name = name,
            platforms = select_map,
            target_name = name,
        )
    else:
        oci_pull_rule(
            name = name,
            image = image,
            identifier = digest or tag,
            target_name = name,
            toolchain_name = toolchain_name,
        )
