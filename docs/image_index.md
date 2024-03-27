<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation details for oci_image_index rule

<a id="oci_image_index"></a>

## oci_image_index

<pre>
oci_image_index(<a href="#oci_image_index-name">name</a>, <a href="#oci_image_index-image">image</a>, <a href="#oci_image_index-images">images</a>, <a href="#oci_image_index-platforms">platforms</a>)
</pre>

Build a multi-architecture OCI compatible container image.

It takes number of `oci_image`s  to create a fat multi-architecture image.

Requires `wc` and either `sha256sum` or `shasum` to be installed on the execution machine.

```starlark
oci_image(
    name = "app_linux"
)

oci_image_index(
    name = "app",
    image = ":app_linux",
    platforms = [
        "@io_bazel_rules_go//go/toolchain:linux_amd64",
        "@io_bazel_rules_go//go/toolchain:linux_arm64",
    ]
)
```

Deprecated use without platform transition:

```starlark
oci_image(
    name = "app_linux_amd64",
)

oci_image(
    name = "app_linux_arm64",
)

oci_image_index(
    name = "app",
    image = [
        ":app_linux_amd64",
        ":app_linux_arm64"
    ],
)
```

Another variant for transitioning away from the deprecated use:

```starlark
oci_image(
    name = "app_linux_amd64",
)

oci_image(
    name = "app_linux_arm64",
)

alias(
    name = "app_linux",
    actual = select({
        "@platforms//cpu:x86_64": ":app_linux_amd64",
        "@platforms//cpu:aarch64": ":app_linux_arm64",
    }),
)

oci_image_index(
    name = "app",
    image = ":app_linux",
    platforms = [
        "@io_bazel_rules_go//go/toolchain:linux_amd64",
        "@io_bazel_rules_go//go/toolchain:linux_arm64",
    ],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_image_index-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="oci_image_index-image"></a>image |  An oci_image target.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="oci_image_index-images"></a>images |  (Deprecated) List of labels to oci_image targets.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="oci_image_index-platforms"></a>platforms |  The platforms to build the index for. Defaults to <code>[]</code> which means that only the current target platform is used.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |


