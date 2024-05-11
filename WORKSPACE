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

load("@container_structure_test//:repositories.bzl", "container_structure_test_register_toolchain")

## Setup container structure test
container_structure_test_register_toolchain(name = "container_structure_test")

## Setup rules_go
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.20.5")

## Setup gazelle
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

gazelle_dependencies()

## Setup rules_pkg
load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

rules_pkg_dependencies()

## Unit test repositories

# For sign_external test
new_local_repository(
    name = "empty_image",
    build_file = "//examples/sign_external:BUILD.template",
    path = "examples/sign_external/workspace",
)

# For attest_external test
new_local_repository(
    name = "example_sbom",
    build_file = "//examples/attest_external:BUILD.template",
    path = "examples/attest_external/workspace",
)

# For testing fetching from various registries
load(":fetch.bzl", "fetch_images")

fetch_images()

### Fetch buildx
load("//examples/dockerfile:buildx.bzl", "fetch_buildx")

fetch_buildx()
