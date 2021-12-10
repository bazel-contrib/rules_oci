# Template for Bazel rules

Copy this template to create a Bazel ruleset.

Features:

- follows the official style guide at https://docs.bazel.build/versions/main/skylark/deploying.html
- includes Bazel formatting as a pre-commit hook (using [buildifier])
- includes typical toolchain setup
- CI configured with GitHub Actions
- Release on GitHub Actions when pushing a tag

See https://docs.bazel.build/versions/main/skylark/deploying.html#readme

[buildifier]: https://github.com/bazelbuild/buildtools/tree/master/buildifier#readme

Ready to get started? Copy this repo, then

1. search for "com_myorg_rules_mylang" and replace with the name you'll use for your workspace
1. search for "mylang" and replace with the language/tool your rules are for
1. rename directory "mylang" similarly
1. run `pre-commit install` to get lints (see CONTRIBUTING.md)
1. if you don't need to fetch platform-dependent tools, then remove anything toolchain-related.
1. delete this section of the README (everything up to the SNIP).

---- SNIP ----

# Bazel rules for mylang

## Installation

Include this in your WORKSPACE file:

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "com_myorg_rules_mylang",
    url = "https://github.com/myorg/rules_mylang/releases/download/0.0.0/rules_mylang-0.0.0.tar.gz",
    sha256 = "",
)

load("@com_myorg_rules_mylang//mylang:repositories.bzl", "mylang_rules_dependencies")

# This fetches the rules_mylang dependencies, which are:
# - bazel_skylib
# If you want to have a different version of some dependency,
# you should fetch it *before* calling this.
# Alternatively, you can skip calling this function, so long as you've
# already fetched these dependencies.
rules_mylang_dependencies()
```

> note, in the above, replace the version and sha256 with the one indicated
> in the release notes for rules_mylang
> In the future, our release automation should take care of this.
