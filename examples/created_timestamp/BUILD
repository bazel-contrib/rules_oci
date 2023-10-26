load("@aspect_bazel_lib//lib:expand_template.bzl", "expand_template")
load("@aspect_bazel_lib//lib:jq.bzl", "jq")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("//oci:defs.bzl", "oci_image")

pkg_tar(
    name = "app",
    srcs = ["app.sh"],
)

write_file(
    name = "build_timestamp_tmpl",
    out = "build_timestamp.txt.tmpl",
    content = [
        "BUILD_TIMESTAMP",
    ],
)

expand_template(
    name = "build_timestamp",
    out = "build_timestamp.txt",
    stamp_substitutions = {"BUILD_TIMESTAMP": "{{BUILD_TIMESTAMP}}"},
    substitutions = {"BUILD_TIMESTAMP": "946684800"},
    template = ":build_timestamp_tmpl",
)

jq(
    name = "created_timestamp",
    srcs = [":build_timestamp"],
    out = "created_timestamp.txt",
    args = ["-r"],
    filter = "todate",
)

oci_image(
    name = "image_timestamp_file",
    base = "@ubuntu",
    cmd = ["test.sh"],
    created_timestamp = ":created_timestamp",
    tars = ["app.tar"],
)
