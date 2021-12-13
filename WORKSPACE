# Declare the local Bazel workspace.
# This is *not* included in the published distribution.
workspace(
    # If your ruleset is "official"
    # (i.e. is in the bazelbuild GitHub org)
    # then this should just be named "rules_container"
    # see https://docs.bazel.build/versions/main/skylark/deploying.html#workspace
    name = "rules_container",
)

load(":internal_deps.bzl", "rules_container_internal_deps")

# Fetch deps needed only locally for development
rules_container_internal_deps()

load("//container:repositories.bzl", "container_register_toolchains", "rules_container_dependencies")

# Fetch our "runtime" dependencies which users need as well
rules_container_dependencies()

container_register_toolchains(
    name = "container1_14",
    crane_version = "7.0.1-rc1",
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