load("@aspect_bazel_lib//lib:jq.bzl", "jq")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("//oci:defs.bzl", "oci_image")

pkg_tar(
    name = "app",
    srcs = ["app.sh"],
)

jq(
    name = "created_timestamp",
    srcs = [],
    out = "created_timestamp.txt",
    args = ["-r"],
    filter = """$ARGS.named.STAMP as $stamp | ($stamp.BUILD_TIMESTAMP // "946684800") | tonumber | todate""",
)

oci_image(
    name = "image_timestamp_file",
    base = "@ubuntu",
    cmd = ["test.sh"],
    created_timestamp = ":created_timestamp",
    tars = ["app.tar"],
)
