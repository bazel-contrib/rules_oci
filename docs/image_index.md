<!-- Generated with Stardoc: http://skydoc.bazel.build -->

To load these rules, add this to the top of your `BUILD` file:

```starlark
load("@rules_oci//oci:defs.bzl", ...)
```

<a id="oci_image_index_rule"></a>

## oci_image_index_rule

<pre>
oci_image_index_rule(<a href="#oci_image_index_rule-name">name</a>, <a href="#oci_image_index_rule-images">images</a>)
</pre>

Build a multi-architecture OCI compatible container image.

It takes number of `oci_image`s  to create a fat multi-architecture image.

Requires `wc` and either `sha256sum` or `shasum` to be installed on the execution machine.

```starlark
oci_image(
    name = "app_linux_amd64"
)

oci_image(
    name = "app_linux_arm64"
)

oci_image_index(
    name = "app",
    images = [
        ":app_linux_amd64",
        ":app_linux_arm64"
    ]
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_image_index_rule-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="oci_image_index_rule-images"></a>images |  List of labels to oci_image targets.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="oci_image_index"></a>

## oci_image_index

<pre>
oci_image_index(<a href="#oci_image_index-name">name</a>, <a href="#oci_image_index-kwargs">kwargs</a>)
</pre>

Macro wrapper around [oci_image_index_rule](#oci_image_index_rule).

Produces a target `[name].digest`, whose default output is a file containing the sha256 digest of the resulting image.
This is the same output as for the `oci_image` macro.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="oci_image_index-name"></a>name |  name of resulting oci_image_index_rule   |  none |
| <a id="oci_image_index-kwargs"></a>kwargs |  other named arguments to [oci_image_index_rule](#oci_image_index_rule) and [common rule attributes](https://bazel.build/reference/be/common-definitions#common-attributes).   |  none |


