"Downloader functions "

load("@aspect_bazel_lib//lib:base64.bzl", "base64")
load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:versions.bzl", "versions")
load(":util.bzl", "util")

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

# TODO(2.0): remove curl downloader
def _download(
        rctx,
        url,
        output,
        sha256 = "",
        allow_fail = False,
        auth = {},
        # ignored
        # buildifier: disable=unused-variable
        canonical_id = "",
        # unsupported
        executable = False,
        integrity = "",
        # custom features
        headers = {}):
    if executable or integrity:
        fail("executable and integrity attributes are unsupported.")

    version_result = rctx.execute(["curl", "--version"])
    if version_result.return_code != 0:
        fail("Failed to execute curl --version:\n{}".format(version_result.stderr))

    # parse from
    # curl 8.1.2 (x86_64-apple-darwin22.0) libcurl/8.1.2 (SecureTransport) LibreSSL/3.3.6 zlib/1.2.11 nghttp2/1.51.0
    # Release-Date: 2023-05-30
    # ...
    curl_version = version_result.stdout.split(" ")[1]

    command = [
        "curl",
        url,
        "--write-out",
        "%{http_code}",
        "--location",
        "--request",
        "GET",
        "--create-dirs",
        "--output",
        output,
    ]

    # Detect more flags which may be supported based on changelog:
    # https://curl.se/changes.html
    if versions.is_at_least("7.67.0", curl_version):
        command.append("--no-progress-meter")

    for (name, value) in headers.items():
        command.append("--header")
        command.append("{}: {}".format(name, value))

    command.extend(_auth_to_header(url, auth))

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
    checksum = util.sha256(rctx, output)
    if sha256 and checksum != sha256:
        fail("Checksum for url {} was {} but expected {}".format(url, checksum, sha256))
    return struct(
        success = True,
        sha256 = checksum,
    )

# A dummy function that uses bazel downloader.
#  Caveats
#   - Doesn't support setting custom headers
def _bazel_download(
        rctx,
        # custom features
        # buildifier: disable=unused-variable
        headers = {},
        # passthrough
        **kwargs):
    if bazel_features.external_deps.download_has_headers_param:
        return rctx.download(headers = headers, **kwargs)
    else:
        return rctx.download(**kwargs)

download = struct(
    curl = _download,
    bazel = _bazel_download,
)
