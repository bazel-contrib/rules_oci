"""A repository rule to pull image layers using Bazel's downloader.

Typical usage in `WORKSPACE.bazel`:

```starlark
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
        "linux/arm64",
    ],
)
```

Now you can refer to these as a base layer in `BUILD.bazel`.
The target is named the same as the external repo, so you can use a short label syntax:

```
oci_image(
    name = "app",
    base = "@distroless_static",
    ...
)
```
"""

load("//oci/private:pull.bzl", "oci_alias", "pin_tag", _oci_pull = "oci_pull")

# Note: there is no exhaustive list, image authors can use whatever name they like.
# This is only used for the oci_alias rule that makes a select() - if a mapping is missing,
# users can just write their own select() for it.
_DOCKER_ARCH_TO_BAZEL_CPU = {
    "amd64": "@platforms//cpu:x86_64",
    "arm": "@platforms//cpu:arm",
    "arm64": "@platforms//cpu:arm64",
    "ppc64le": "@platforms//cpu:ppc",
    "s390x": "@platforms//cpu:s390x",
}

def oci_pull(name, image, platforms = None, digest = None, tag = None, reproducible = True):
    """Repository macro to fetch image manifest data from a remote docker registry.

    To use the resulting image, you can use the `@wkspc` shorthand label, for example
    if `name = "distroless_base"`, then you can just use `base = "@distroless_base"`
    in rules like `oci_image`.

    > This shorthand syntax is broken on the command-line prior to Bazel 6.2.
    > See https://github.com/bazelbuild/bazel/issues/4385

    Args:
        name: repository with this name is created
        image: the remote image without a tag, such as gcr.io/bazel-public/bazel
        platforms: for multi-architecture images, a dictionary of the platforms it supports
            This creates a separate external repository for each platform, avoiding fetching layers.
        digest: the digest string, starting with "sha256:", "sha512:", etc.
            If omitted, instructions for pinning are provided.
        tag: a tag to choose an image from the registry.
            Exactly one of `tag` and `digest` must be set.
            Since tags are mutable, this is not reproducible, so a warning is printed.
        reproducible: Set to False to silence the warning about reproducibility when using `tag`.
    """

    if digest and tag:
        # Users might wish to leave tag=latest as "documentation" however if we just ignore tag
        # then it's never checked which means the documentation can be wrong.
        # For now just forbit having both, it's a non-breaking change to allow it later.
        fail("Only one of 'digest' or 'tag' may be set")

    if not digest and not tag:
        fail("One of 'digest' or 'tag' must be set")

    if tag and reproducible:
        pin_tag(name = name + "_unpinned", image = image, tag = tag)

        # Print a command - in the future we should print a buildozer command or
        # buildifier: disable=print
        print("""
WARNING: for reproducible builds, a digest is recommended.
Either set 'reproducible = False' to silence this warning,
or run the following command to change oci_pull to use a digest:

bazel run @{}_unpinned//:pin
""".format(name))
        return

    if platforms:
        select_map = {}
        for plat in platforms:
            plat_name = "_".join([name] + plat.split("/"))
            _, arch = plat.split("/", 1)
            _oci_pull(
                name = plat_name,
                image = image,
                identifier = digest or tag,
                platform = plat,
                target_name = plat_name,
            )
            select_map[_DOCKER_ARCH_TO_BAZEL_CPU[arch]] = "@" + plat_name
        oci_alias(
            name = name,
            platforms = select_map,
            target_name = name,
        )
    else:
        _oci_pull(
            name = name,
            image = image,
            identifier = digest or tag,
            target_name = name,
        )
