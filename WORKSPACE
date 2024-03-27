# Declare the local Bazel workspace.
# This is *not* included in the published distribution.
workspace(name = "rules_oci")

# Fetch deps needed only locally for development
load(":internal_deps.bzl", "rules_oci_internal_deps")

rules_oci_internal_deps()

### Setup rules_oci
load("//oci:dependencies.bzl", "rules_oci_dependencies")

rules_oci_dependencies()

load("//oci:repositories.bzl", "LATEST_CRANE_VERSION", "LATEST_ZOT_VERSION", "oci_register_toolchains")

oci_register_toolchains(
    name = "oci",
    crane_version = LATEST_CRANE_VERSION,
    zot_version = LATEST_ZOT_VERSION,
)

### Setup rules_oci cosign
load("//cosign:repositories.bzl", "cosign_register_toolchains")

cosign_register_toolchains(name = "oci_cosign")

### Setup rules_go
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.17.2")

### Setup gazelle
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

gazelle_dependencies()

### Setup stardoc
load("@io_bazel_stardoc//:setup.bzl", "stardoc_repositories")

stardoc_repositories()

### Setup rules_pkg
load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

rules_pkg_dependencies()

### Setup aspect_bazel_lib
load("@aspect_bazel_lib//lib:repositories.bzl", "aspect_bazel_lib_dependencies")

aspect_bazel_lib_dependencies()

### Setup testing

load("@bazel_skylib//lib:unittest.bzl", "register_unittest_toolchains")

register_unittest_toolchains()

load("@container_structure_test//:repositories.bzl", "container_structure_test_register_toolchain")

container_structure_test_register_toolchain(name = "container_structure_test")

new_local_repository(
    name = "empty_image",  # for sign_external test
    build_file = "//examples/sign_external:BUILD.template",
    path = "examples/sign_external/workspace",
)

new_local_repository(
    name = "example_sbom",  # for attest_external test
    build_file = "//examples/attest_external:BUILD.template",
    path = "examples/attest_external/workspace",
)

# Fetching various images
load(":fetch.bzl", "fetch_images")

fetch_images()
