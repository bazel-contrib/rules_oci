# Declare the local Bazel workspace.
# This is *not* included in the published distribution.
workspace(name = "rules_oci")

# Fetch deps needed only locally for development
load(":internal_deps.bzl", "rules_oci_internal_deps")

rules_oci_internal_deps()

## Stardoc
load("@io_bazel_stardoc//:setup.bzl", "stardoc_repositories")

stardoc_repositories()

## Setup rules_oci
load("//oci:dependencies.bzl", "rules_oci_dependencies")

rules_oci_dependencies()

load("//oci:repositories.bzl", "oci_register_toolchains")

oci_register_toolchains(name = "oci")

# Transitive dep for rules_multirun
load("@rules_python//python:repositories.bzl", "py_repositories")

py_repositories()

## Setup bazel-lib
load("@aspect_bazel_lib//lib:repositories.bzl", "aspect_bazel_lib_dependencies", "aspect_bazel_lib_register_toolchains")

aspect_bazel_lib_dependencies()

aspect_bazel_lib_register_toolchains()

## Setup cosign
load("//cosign:repositories.bzl", "cosign_register_toolchains")

cosign_register_toolchains(name = "oci_cosign")

## Setup skylib unittest
load("@bazel_skylib//lib:unittest.bzl", "register_unittest_toolchains")

register_unittest_toolchains()

## Setup rules_go
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.20.5")

## Setup gazelle
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

gazelle_dependencies()

## Setup test repositories
load(":fetch.bzl", "fetch_images", "fetch_test_repos")

fetch_images()

fetch_test_repos()

# Setup rules_pkg
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_pkg",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_pkg/releases/download/1.0.1/rules_pkg-1.0.1.tar.gz",
        "https://github.com/bazelbuild/rules_pkg/releases/download/1.0.1/rules_pkg-1.0.1.tar.gz",
    ],
    sha256 = "d20c951960ed77cb7b341c2a59488534e494d5ad1d30c4818c736d57772a9fef",
)
load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")
rules_pkg_dependencies()
