# https://devops.stackexchange.com/questions/2731/downloading-docker-images-from-docker-hub-without-using-docker


_attrs = {
    "base": attr.string(
        mandatory = True
    ),
}

def _ls(rctx, dir):
    print("listing %s" % dir)
    r = rctx.execute(["ls", "-l", dir])    
    print(r.stdout)

# TODO:
#  - introduce skopeo to toolchain (no available prebuilt binaries though )
#  - introduce umoci to toolchain (see: https://github.com/opencontainers/umoci/pull/409)
#  - remove crane completely

def _impl(rctx):

    if "DOCKER_AUTH" not in rctx.os.environ:
        fail("env DOCKER_AUTH has to be provided.")

    image = "library/node:latest"

    output_dir = "library/node"

    rctx.report_progress("Fetching the manifest")

    r = rctx.execute(["crane", "manifest", image,  "--platform",  "linux/arm64"])  

    result = json.decode(r.stdout)

    for layer in result["layers"]:
        digest = layer["digest"]
        rctx.report_progress("Fetching blob (%s)" % digest)
        url = "https://index.docker.io/v2/library/node/blobs/%s" % digest

        rctx.download(
            url = url,
            output = "library/node/blobs/%s" % digest.replace(":", "/"),
            sha256 = digest.replace("sha256:", ""),
            auth = {
                url: {
                    "type": "pattern",
                    "pattern":  "Bearer <password>",
                    "password": rctx.os.environ["DOCKER_AUTH"]
                },
               
            }
        )

    rctx.report_progress("Validating blobs")

    rctx.execute(["skopeo", "copy", "docker://%s" % image, "oci:./%s" % image, "--override-os", "linux"])


    content = """
filegroup(
    name = "image",
    srcs = ["%s"],
    visibility = ["//visibility:public"]
)
""" % output_dir

    rctx.file("BUILD.bazel", content)
    
container_pull = repository_rule(
    implementation = _impl,
    attrs = _attrs
)