"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("@aspect_bazel_lib//lib:repositories.bzl", "aspect_bazel_lib_dependencies", "aspect_bazel_lib_register_toolchains")
load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("@platforms//host:extension.bzl", "host_platform_repo")
load("@rules_shell//shell:repositories.bzl", "rules_shell_dependencies", "rules_shell_toolchains")

def http_archive(**kwargs):
    maybe(_http_archive, **kwargs)

def rules_oci_dependencies():
    http_archive(
        name = "bazel_skylib",
        sha256 = "bc283cdfcd526a52c3201279cda4bc298652efa898b10b4db0837dc51652756f",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
        ],
    )

    http_archive(
        name = "aspect_bazel_lib",
        sha256 = "53cadea9109e646a93ed4dc90c9bbcaa8073c7c3df745b92f6a5000daf7aa3da",
        strip_prefix = "bazel-lib-2.21.2",
        url = "https://github.com/bazel-contrib/bazel-lib/releases/download/v2.21.2/bazel-lib-v2.21.2.tar.gz",
    )

    http_archive(
        name = "bazel_features",
        sha256 = "95fb3cfd11466b4cad6565e3647a76f89886d875556a4b827c021525cb2482bb",
        strip_prefix = "bazel_features-1.10.0",
        url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.10.0/bazel_features-v1.10.0.tar.gz",
    )

    http_archive(
        name = "tar.bzl",
        sha256 = "29a3c99c28deca5f8245e2fc32ffdb99c1ea69316462718f3bebfff441d36e4a",
        strip_prefix = "tar.bzl-0.5.6",
        url = "https://github.com/bazel-contrib/tar.bzl/releases/download/v0.5.6/tar.bzl-v0.5.6.tar.gz",
    )

    # Required bazel-lib dependencies

    aspect_bazel_lib_dependencies()

    # Required rules_shell dependencies

    rules_shell_dependencies()

    rules_shell_toolchains()

    # Register bazel-lib toolchains

    aspect_bazel_lib_register_toolchains()

    # Create the host platform repository transitively required by bazel-lib

    maybe(
        host_platform_repo,
        name = "host_platform",
    )
