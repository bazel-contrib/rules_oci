"""Our "development" dependencies

Users should *not* need to install these. If users see a load()
statement from these, that's a bug in our distribution.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def http_archive(**kwargs):
    maybe(_http_archive, **kwargs)

def rules_oci_internal_deps():
    "Fetch deps needed for local development"

    http_archive(
        name = "io_bazel_rules_go",
        sha256 = "80a98277ad1311dacd837f9b16db62887702e9f1d1c4c9f796d0121a46c8e184",
        urls = [
            "https://github.com/bazelbuild/rules_go/releases/download/v0.46.0/rules_go-v0.46.0.zip",
        ],
    )

    http_archive(
        name = "bazel_gazelle",
        sha256 = "de69a09dc70417580aabf20a28619bb3ef60d038470c7cf8442fafcf627c21cb",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.24.0/bazel-gazelle-v0.24.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.24.0/bazel-gazelle-v0.24.0.tar.gz",
        ],
    )

    # Override bazel_skylib distribution to fetch sources instead
    # so that the gazelle extension is included
    # see https://github.com/bazelbuild/bazel-skylib/issues/250
    http_archive(
        name = "bazel_skylib",
        sha256 = "07b4117379dde7ab382345c3b0f5edfc6b7cff6c93756eac63da121e0bbcc5de",
        strip_prefix = "bazel-skylib-1.1.1",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/archive/1.1.1.tar.gz",
        ],
    )

    http_archive(
        name = "bazel_skylib_gazelle_plugin",
        sha256 = "0a466b61f331585f06ecdbbf2480b9edf70e067a53f261e0596acd573a7d2dc3",
        urls = ["https://github.com/bazelbuild/bazel-skylib/releases/download/1.4.1/bazel-skylib-gazelle-plugin-1.4.1.tar.gz"],
    )

    http_archive(
        name = "io_bazel_stardoc",
        sha256 = "dfbc364aaec143df5e6c52faf1f1166775a5b4408243f445f44b661cfdc3134f",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/stardoc/releases/download/0.5.6/stardoc-0.5.6.tar.gz",
            "https://github.com/bazelbuild/stardoc/releases/download/0.5.6/stardoc-0.5.6.tar.gz",
        ],
    )

    http_archive(
        name = "container_structure_test",
        sha256 = "2da13da4c4fec9d4627d4084b122be0f4d118bd02dfa52857ff118fde88e4faa",
        strip_prefix = "container-structure-test-1.16.0",
        urls = ["https://github.com/GoogleContainerTools/container-structure-test/archive/v1.16.0.zip"],
    )

    http_archive(
        name = "rules_pkg",
        urls = [
            "https://github.com/bazelbuild/rules_pkg/releases/download/0.7.0/rules_pkg-0.7.0.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/rules_pkg/releases/download/0.7.0/rules_pkg-0.7.0.tar.gz",
        ],
        sha256 = "8a298e832762eda1830597d64fe7db58178aa84cd5926d76d5b744d6558941c2",
    )
