# Declare the local Bazel workspace.
# This is *not* included in the published distribution.
workspace(name = "aspect_rules_oci")

load(":internal_deps.bzl", "rules_oci_internal_deps")

# Fetch deps needed only locally for development
rules_oci_internal_deps()

load("//oci:repositories.bzl", "oci_register_toolchains", "rules_oci_dependencies")

# Fetch our "runtime" dependencies which users need as well
rules_oci_dependencies()

oci_register_toolchains(
    name = "container",
    crane_version = "v0.7.1-thesayyn",
)

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
    sha256 = "e8576a74a7e80b873179514cf1ad48b62b18ae024e74200ecd40ae6dc00c515a",
    strip_prefix = "rules_js-0.3.0",
    url = "https://github.com/aspect-build/rules_js/archive/v0.3.0.tar.gz",
)

load("@aspect_rules_js//js:repositories.bzl", "rules_js_dependencies")

rules_js_dependencies()

load("@rules_nodejs//nodejs:repositories.bzl", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "node16",
    node_version = "16.9.0",
)

load("@aspect_rules_js//js:npm_import.bzl", "npm_import")

npm_import(
    integrity = "sha512-ULr0LDaEqQrMFGyQ3bhJkLsbtrQ8QibAseGZeaSUiT/6zb9IvIkomWHJIvgvwad+hinRAgsI51JcWk2yvwyL+w==",
    package = "acorn",
    version = "8.4.0",
    deps = [],
)

# PYTHON
http_archive(
    name = "rules_python",
    sha256 = "cd6730ed53a002c56ce4e2f396ba3b3be262fd7cb68339f0377a45e8227fe332",
    url = "https://github.com/bazelbuild/rules_python/releases/download/0.5.0/rules_python-0.5.0.tar.gz",
)

load("@rules_python//python:pip.bzl", "pip_install")

# Create a central external repo, @my_deps, that contains Bazel targets for all the
# third-party packages specified in the requirements.txt file.
pip_install(
    name = "my_deps",
    requirements = "//example/py:requirements.txt",
)
