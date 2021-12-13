# Bazel rules for container

## Installation

Include this in your WORKSPACE file:

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_container",
    url = "https://github.com/thesayyn/rules_container/releases/download/0.0.0/rules_container-0.0.0.tar.gz",
    sha256 = "",
)

load("@rules_container//container:repositories.bzl", "container_rules_dependencies")

# This fetches the rules_container dependencies, which are:
# - bazel_skylib
# If you want to have a different version of some dependency,
# you should fetch it *before* calling this.
# Alternatively, you can skip calling this function, so long as you've
# already fetched these dependencies.
rules_container_dependencies()
```

> note, in the above, replace the version and sha256 with the one indicated
> in the release notes for rules_container
> In the future, our release automation should take care of this.
