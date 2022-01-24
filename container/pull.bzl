# https://devops.stackexchange.com/questions/2731/downloading-docker-images-from-docker-hub-without-using-docker
"Pulls an image from a registry"

_ATTRS = {
    "base": attr.string(
        mandatory = True
    ),
}

def _remove_tag(base):
    tag_index = base.find(":")
    if tag_index != -1:
        return base[:tag_index]
    return base



def _auth(rctx):
    params = "service=registry.docker.io&scope=repository:%s:pull" % _remove_tag(rctx.attr.base)
    rctx.download(
        url = "https://auth.docker.io/token?%s" % params,
        output = "auth.json",
    )  

    auth = json.decode(rctx.read("auth.json"))

    return {
        "type": "pattern",
        "pattern":  "Bearer <password>",
        "password": auth["token"]
    }

# TODO:
#  - introduce skopeo to toolchain (no available prebuilt binaries though)
#  - do not eager fetch
def _impl(rctx):

    image = _remove_tag(rctx.attr.base)
    output_dir = image

    rctx.report_progress("Authenticating")
    auth = _auth(rctx)

    rctx.report_progress("Fetching the manifest")
    r = rctx.execute(["skopeo", "inspect", "docker://%s" % image,  "--override-os",  "linux", "--no-tags"])  

    result = json.decode(r.stdout)

    for layer in result["Layers"]:
        digest = layer

        rctx.report_progress("Fetching blob (%s)" % digest)

        url = "https://index.docker.io/v2/%s/blobs/%s" % (image, digest)

        rctx.download(
            url = url,
            output = "%s/blobs/%s" % (output_dir, digest.replace(":", "/")),
            sha256 = digest.replace("sha256:", ""),
            auth = { url: auth }
        )

    rctx.report_progress("Pulling index")
    
    rctx.execute(["skopeo", "copy", "docker://%s" % rctx.attr.base, "oci:./%s" % rctx.attr.base, "--override-os", "linux"])

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
    attrs = _ATTRS
)