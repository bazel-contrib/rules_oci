<!-- Generated with Stardoc: http://skydoc.bazel.build -->

creates tarball from oci_image that can be loaded by runtimes such as podman and docker

<a id="#oci_tarball"></a>

## oci_tarball

<pre>
oci_tarball(<a href="#oci_tarball-name">name</a>, <a href="#oci_tarball-image">image</a>, <a href="#oci_tarball-repotags">repotags</a>)
</pre>

Creates tarball from OCI layouts that can be loaded into docker daemon without needing to publish the image first.

Passing anything other than oci_image to the image attribute will lead to build time errors.

example;

```shell
bazel build //target
docker load --input $(bazel cquery --output=files //target)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_tarball-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_tarball-image"></a>image |  Label to an oci_image target   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="oci_tarball-repotags"></a>repotags |  List of tags to apply to the loaded image   | List of strings | required |  |


