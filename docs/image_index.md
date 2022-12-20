<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation details for oci_image_index rule

<a id="#oci_image_index"></a>

## oci_image_index

<pre>
oci_image_index(<a href="#oci_image_index-name">name</a>, <a href="#oci_image_index-images">images</a>)
</pre>

Build a multi-architecture OCI compatible container image.

It takes number of `oci_image`s  to create a fat multi-architecture image.

Requires `wc` and `shasum` to be installed on the execution machine.

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
| <a id="oci_image_index-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_image_index-images"></a>images |  List of labels to oci_image targets.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |


