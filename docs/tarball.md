<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Create a tarball from oci_image that can be loaded by runtimes such as podman and docker.

For example, given an `:image` target, you could write

```
oci_tarball(
    name = "tarball",
    image = ":image",
    repo_tags = ["my-repository:latest"],
)
```

and then run it in a container like so:

```
bazel build //path/to:tarball
docker load --input $(bazel cquery --output=files //path/to:tarball)
docker run --rm my-repository:latest
```


<a id="#oci_tarball"></a>

## oci_tarball

<pre>
oci_tarball(<a href="#oci_tarball-name">name</a>, <a href="#oci_tarball-image">image</a>, <a href="#oci_tarball-repo_tags">repo_tags</a>)
</pre>

Creates tarball from OCI layouts that can be loaded into docker daemon without needing to publish the image first.

Passing anything other than oci_image to the image attribute will lead to build time errors.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_tarball-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_tarball-image"></a>image |  Label of a directory containing an OCI layout, typically <code>oci_image</code>   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="oci_tarball-repo_tags"></a>repo_tags |  a file containing repo_tags, one per line.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


