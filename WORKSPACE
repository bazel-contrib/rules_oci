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
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

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

load("@rules_oci//oci:pull.bzl", "oci_pull")

# A single-arch base image
oci_pull(
    name = "distroless_java",
    digest = "sha256:161a1d97d592b3f1919801578c3a47c8e932071168a96267698f4b669c24c76d",
    image = "gcr.io/distroless/java17",
)

# A multi-arch base image
oci_pull(
    name = "distroless_static",
    digest = "sha256:c3c3d0230d487c0ad3a0d87ad03ee02ea2ff0b3dcce91ca06a1019e07de05f12",
    image = "gcr.io/distroless/static",
    platforms = [
        "linux/amd64",
        "linux/arm",
        "linux/arm64",
        "linux/ppc64le",
        "linux/s390x",
    ],
)

# Show that the digest is optional.
oci_pull(
    name = "distroless_python",
    image = "gcr.io/distroless/python3",
    platforms = ["linux/amd64"],
    # Don't make a distroless_python_unpinned repo and print a warning about the tag
    reproducible = False,
    tag = "debug",
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

oci_pull(
    name = "aws_lambda_python",
    # tag = "3.8"
    digest = "sha256:46b3b8614b31761b24f56be1bb8c7ba191d9b9b4624bbf7f53ed7ddc696c928b",
    image = "public.ecr.aws/lambda/python",
)

oci_pull(
    name = "debian",
    image = "index.docker.io/library/debian",
    platforms = [
        "linux/arm64",
        "linux/amd64",
    ],
    # Don't print a warning about the tag
    reproducible = False,
    tag = "latest",
)
