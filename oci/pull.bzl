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
    "ghcr.io": {
        "realm": "ghcr.io/token",
        "scope": "repository:{repository}:pull",
        "service": "ghcr.io/token",
    },
}

def _get_auth(rctx, state, registry):
    # if we have a cached auth for this registry then just return it.
    # this will prevent repetitive calls to external cred helper binaries.
    if registry in state["auth"]:
        return state["auth"][registry]

    pattern = {}
    config = state["config"]

    if "auths" in config:
        for host_raw in config["auths"]:
            host = _strip_host(host_raw)
            if host == registry:
                auth_val = config["auths"][host_raw]

                if len(auth_val.keys()) == 0:
                    # zero keys indicates that credentials are stored in credsStore helper.
                    pattern = _fetch_auth_via_creds_helper(rctx, host_raw, config["credsStore"])

                elif "auth" in auth_val:
                    # base64 encoded plaintext username and password
                    raw_auth = auth_val["auth"]
                    (login, password) = base64.decode(raw_auth).split(":")
                    pattern = {
                        "type": "basic",
                        "login": login,
                        "password": password,
                    }

                elif "username" in auth_val and "password" in auth_val:
                    # plain text username and password
                    pattern = {
                        "type": "basic",
                        "login": auth_val["username"],
                        "password": auth_val["password"],
                    }

                # cache the result so that we don't do this again unnecessarily.
                state["auth"][registry] = pattern

    return pattern

def _get_token(rctx, state, registry, repository, identifier):
    pattern = _get_auth(rctx, state, registry)

    if registry in _www_authenticate:
        www_authenticate = _www_authenticate[registry]
        url = "https://{realm}?scope={scope}&service={service}".format(
            realm = www_authenticate["realm"],
            service = www_authenticate["service"],
            scope = www_authenticate["scope"].format(repository = repository),
        )

        # if a token for this repository and registry is acquired, use that instead.
        if url in state["token"]:
            return state["token"][url]

        rctx.download(
            url = [url],
            output = "www-authenticate.json",
            # optionally, sending the credentials to authenticate using the credentials.
            # this is for fetching from private repositories that require WWW-Authenticate
            auth = {url: pattern},
        )
        auth_raw = rctx.read("www-authenticate.json")
        auth = json.decode(auth_raw)
        pattern = {
            "type": "pattern",
            "pattern": "Bearer <password>",
            "password": auth["token"],
        }

        # put the token into cache so that we don't do the token exchange again.
        state["token"][url] = pattern

    return pattern

def _fetch_auth_via_creds_helper(rctx, raw_host, helper_name):
    executable = "{}.sh".format(helper_name)
    rctx.file(
        executable,
        content = """\
#!/usr/bin/env bash
exec "docker-credential-{}" get <<< "$1"
        """.format(helper_name),
    )
    result = rctx.execute([rctx.path(executable), raw_host])
    if result.return_code:
        fail("credential helper failed: \nSTDOUT:\n{}\nSTDERR:\n{}".format(result.stdout, result.stderr))

    response = json.decode(result.stdout)

    if response["Username"] == "<token>":
        fail("Identity tokens are not supported at the moment. See: https://github.com/bazel-contrib/rules_oci/issues/129")

    return {
        "type": "basic",
        "login": response["Username"],
        "password": response["Secret"],
    }

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

def _download(rctx, state, identifier, output, resource, download_fn = download.bazel, headers = {}):
    "Use the Bazel Downloader to fetch from the remote registry"

    if resource != "blobs" and resource != "manifests":
        fail("resource must be blobs or manifests")

    registry, repository, protocol = _parse_reference(rctx.attr.image)

    auth = _get_token(rctx, state, registry, repository, identifier)

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

def _download_manifest(rctx, state, identifier, output):
    _download(rctx, state, identifier, output, "manifests")
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
            state,
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

def _create_downloader(rctx):
    state = {
        "config": json.decode(rctx.read(rctx.attr.config)),
        "auth": {},
        "token": {},
    }
    return struct(
        download_blob = lambda identifier, output: _download(rctx, state, identifier, output, "blobs"),
        download_manifest = lambda identifier, output: _download_manifest(rctx, state, identifier, output),
    )

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
    downloader = _create_downloader(rctx)

    mf_file = _trim_hash_algorithm(rctx.attr.identifier)
    mf, mf_len = downloader.download_manifest(rctx.attr.identifier, mf_file)

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
        image_mf, image_mf_len = downloader.download_manifest(image_digest, image_mf_file)
    else:
        fail("Unrecognized mediaType {} in manifest file".format(mf["mediaType"]))

    image_config_file = _trim_hash_algorithm(image_mf["config"]["digest"])
    downloader.download_blob(image_mf["config"]["digest"], image_config_file)

    tars = []
    for layer in image_mf["layers"]:
        hash = _trim_hash_algorithm(layer["digest"])

        # TODO: we should avoid eager-download of the layers ("shallow pull")
        downloader.download_blob(layer["digest"], hash)
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
        "config": attr.label(doc = "Label to a .docker/config.json file. by default this is generated by oci_auth_config in oci_register_toolchains macro.", default = "@oci_auth_config//:config.json"),
    },
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
    downloader = _create_downloader(rctx)
    downloader.download_manifest(rctx.attr.tag, "manifest_list.json")
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
        "config": attr.label(doc = "Label to a .docker/config.json file. by default this is generated by oci_auth_config in oci_register_toolchains macro.", default = "@oci_auth_config//:config.json"),
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
