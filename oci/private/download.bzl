"Downloader functions "

def _auth_to_header(url, auth):
    for auth_url in auth:
        if auth_url == url:
            auth_val = auth[auth_url]

            # TODO: basic type
            if auth_val["type"] == "pattern":
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

    headers_output_path = str(rctx.path(".output/header.txt"))
    output_path = str(rctx.path(".output/{}".format(output)))
    command = [
        "curl",
        url,
        "--fail-with-body",
        "--location",
        "--no-progress-meter",
        "--request",
        method,
        "--create-dirs",
        "--output",
        output_path,
        "--dump-header",
        headers_output_path,
    ]
    for (name, value) in headers.items():
        command.append("--header")
        command.append("{}: {}".format(name, value))

    command.extend(_auth_to_header(url, auth))
    rctx.file(headers_output_path)

    result = rctx.execute(command)

    _debug("""\nSTDOUT\n{}\nSTDERR\n{}""".format(result.stdout, result.stderr))

    if result.return_code != 0 and allow_fail:
        return struct(success = False)
    elif result.return_code != 0 and not allow_fail:
        fail("Failed to fetch {} {}".format(url, result.stderr))

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
