"Downloader functions "

load("@aspect_bazel_lib//lib:base64.bzl", "base64")
load("@bazel_skylib//lib:versions.bzl", "versions")

def _auth_to_header(url, auth):
    for auth_url in auth:
        if auth_url == url:
            auth_val = auth[auth_url]

            if "type" not in auth_val:
                continue

            if auth_val["type"] == "basic":
                credentials = base64.encode("{}:{}".format(auth_val["login"], auth_val["password"]))
                return [
                    "--header",
                    "Authorization: Basic {}".format(credentials),
                ]
            elif auth_val["type"] == "pattern":
                token = auth_val["pattern"].replace("<password>", auth_val["password"])
                return [
                    "--header",
                    "Authorization: {}".format(token),
                ]
    return []

def _debug(message):
    # Change to true when debugging
    if False:
        # buildifier: disable=print
        print(message)

# Bazel-like downloader using curl
#  A workaround for https://github.com/bazelbuild/bazel/issues/17829
#  Features
#   - Can set custom headers
#   - Support for http2/3 out-of-the-box
#  Supports
#   - bazel repository cache. doesn't do re-fetches if repository rule gets invalidated
#   - authorization
#  Caveats
#   - Doesn't support --experimental_downloader_config. (can not read the flag therefore can't support it out of the box. though can be supported by introducing an attribute.)
#   - Doesn't support other http related bazel flags.
#   - Support for netrc. TODO: https://curl.se/docs/manpage.html#--netrc-file
#   - curl is not fetched hermetically. Though this can be done easily.
def _download(
        rctx,
        url,
        output,
        sha256 = "",
        executable = False,
        allow_fail = False,
        canonical_id = "",
        auth = {},
        integrity = "",
        # custom features
        method = "GET",
        headers = {}):
    if sha256 or integrity:
        cache_result = rctx.download(
            url = [],
            output = output,
            executable = executable,
            allow_fail = True,
            canonical_id = canonical_id,
            integrity = integrity,
            sha256 = sha256,
        )
        if cache_result.success:
            _debug("{} is in cache".format(url))
            return cache_result

    version_result = rctx.execute(["curl", "--version"])
    if version_result.return_code != 0:
        fail("Failed to execute curl --version:\n{}".format(version_result.stderr))

    # parse from
    # curl 8.1.2 (x86_64-apple-darwin22.0) libcurl/8.1.2 (SecureTransport) LibreSSL/3.3.6 zlib/1.2.11 nghttp2/1.51.0
    # Release-Date: 2023-05-30
    # ...
    curl_version = version_result.stdout.split(" ")[1]

    headers_output_path = str(rctx.path(".output/header.txt"))
    output_path = str(rctx.path(".output/{}".format(output)))
    command = [
        "curl",
        url,
        "--write-out",
        "%{http_code}",
        "--location",
        "--request",
        method,
        "--create-dirs",
        "--output",
        output_path,
        "--dump-header",
        headers_output_path,
    ]

    # Detect more flags which may be supported based on changelog:
    # https://curl.se/changes.html
    if versions.is_at_least("7.67.0", curl_version):
        command.append("--no-progress-meter")

    for (name, value) in headers.items():
        command.append("--header")
        command.append("{}: {}".format(name, value))

    command.extend(_auth_to_header(url, auth))
    rctx.file(headers_output_path)

    result = rctx.execute(command)
    _debug("""\nSTDOUT\n{}\nSTDERR\n{}""".format(result.stdout, result.stderr))

    if result.return_code != 0:
        if allow_fail:
            return struct(success = False)
        else:
            fail("Failed to execute curl {} (version {}): {}".format(url, curl_version, result.stderr))

    status_code = int(result.stdout.strip())
    if status_code >= 400:
        if allow_fail:
            return struct(success = False)
        else:
            fail("curl {} returned non-success status code {}".format(url, status_code))

    cache_it = rctx.download(
        url = "file://{}".format(output_path),
        output = output,
        executable = executable,
        allow_fail = allow_fail,
        canonical_id = canonical_id,
        integrity = integrity,
        sha256 = sha256,
    )

    return cache_it

# A dummy function that uses bazel downloader.
#  Caveats
#   - Doesn't support setting custom headers
def _bazel_download(
        rctx,
        # custom features
        method = "GET",
        headers = {},
        # passthrough
        **kwargs):
    return rctx.download(**kwargs)

download = struct(
    curl = _download,
    bazel = _bazel_download,
)
