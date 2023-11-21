load("@aspect_bazel_lib//lib:transitions.bzl", "platform_transition_binary")
load("@aspect_bazel_lib//lib:testing.bzl", "assert_json_matches")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")
load("@rules_pkg//:pkg.bzl", "pkg_tar")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index", "oci_push", "oci_tarball")

go_library(
    name = "lib",
    srcs = ["main.go"],
    importpath = "main",
)

go_binary(
    name = "bin-x86_64",
    embed = [":lib"],
    goarch = "amd64",
    goos = "linux",
)

pkg_tar(
    name = "bin-x86_64_tar",
    srcs = [":bin-x86_64"],
    package_dir = "usr/local/bin",
)

go_binary(
    name = "bin-arm64",
    embed = [":lib"],
    goarch = "arm64",
    goos = "linux",
)

pkg_tar(
    name = "bin-arm64_tar",
    srcs = [":bin-arm64"],
    package_dir = "usr/local/bin",
)

oci_image(
    name = "image-x86_64",
    base = "@ubuntu_linux_amd64",
    entrypoint = ["/usr/local/bin/bin-x86_64"],
    tars = [":bin-x86_64_tar"],
)

repo_tags = [
    "gcr.io/empty_base:latest",
    "two:is_a_company",
    "three:is_a_crowd",
]

oci_tarball(
    name = "image-x86_64-tar",
    image = ":image-x86_64",
    repo_tags = repo_tags,
)

oci_image(
    name = "image-arm64",
    base = "@ubuntu_linux_arm64_v8",
    entrypoint = ["/usr/local/bin/bin-arm64"],
    tars = [":bin-arm64_tar"],
)

oci_image_index(
    name = "image-multiarch",
    images = [
        ":image-arm64",
        ":image-x86_64",
    ],
)

oci_tarball(
    name = "image-multiarch-tar",
    format = "oci",
    image = ":image-multiarch",
    repo_tags = repo_tags,
)

write_file(
    name = "expected_RepoTags",
    out = "expected_RepoTags.json",
    content = [str(repo_tags)],
)

genrule(
    name = "tar_multiarch_index",
    srcs = [":image-multiarch-tar"],
    outs = ["multiarch_index.json"],
    cmd = "tar -xOf ./$(location :image-multiarch-tar) index.json > $@",
)

assert_json_matches(
    name = "check_multiarch_tags",
    file1 = ":tar_multiarch_index",
    file2 = ":expected_RepoTags",
    filter1 = """.manifests[].annotations["org.opencontainers.image.ref.name"]""",
    filter2 = ".[]",
)

genrule(
    name = "tar_x86_64_index",
    srcs = [":image-x86_64-tar"],
    outs = ["x86_64_index.json"],
    cmd = "tar -xOf ./$(location :image-x86_64-tar) manifest.json > $@",
)

assert_json_matches(
    name = "check_x86_64_tags",
    file1 = ":tar_x86_64_index",
    file2 = ":expected_RepoTags",
    filter1 = ".[0].RepoTags",
)
