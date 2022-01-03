# https://devops.stackexchange.com/questions/2731/downloading-docker-images-from-docker-hub-without-using-docker


_attrs = {
    "base": attr.string(
        mandatory = True
    ),
}


def _impl(rctx):

    if "DOCKER_AUTH" not in rctx.os.environ:
        fail("env DOCKER_AUTH has to be provided.")


    rctx.report_progress("Fetching the manifest")

    r = rctx.execute(["crane", "manifest", "node",  "--platform",  "linux/arm64"])  

    rctx.file("BUILD.bazel", "")

    result = json.decode(r.stdout)

    for layer in result["layers"]:
        digest = layer["digest"]
        rctx.report_progress("Fetching blob (%s)" % digest)
        url = "https://index.docker.io/v2/library/node/blobs/%s" % digest
        rctx.download(
            url = url,
            output = "blobs/%s" % digest,
            sha256 = digest.replace("sha256:", ""),
            auth = {
                url: {
                    "type": "pattern",
                    "pattern":  "Bearer <password>",
                    "password": rctx.os.environ["DOCKER_AUTH"]
                },
               
            }
        )
        
container_pull = repository_rule(
    implementation = _impl,
    attrs = _attrs
)