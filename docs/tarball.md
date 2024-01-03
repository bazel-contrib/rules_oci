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
bazel run :tarball
docker run --rm my-repository:latest
```


<a id="oci_tarball"></a>

## oci_tarball

<pre>
oci_tarball(<a href="#oci_tarball-name">name</a>, <a href="#oci_tarball-format">format</a>, <a href="#oci_tarball-image">image</a>, <a href="#oci_tarball-loader">loader</a>, <a href="#oci_tarball-repo_tags">repo_tags</a>)
</pre>

Creates tarball from OCI layouts that can be loaded into docker daemon without needing to publish the image first.

Passing anything other than oci_image to the image attribute will lead to build time errors.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_tarball-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="oci_tarball-format"></a>format |  Format of image to generate. Options are: docker, oci. Currently, when the input image is an image_index, only oci is supported, and when the input image is an image, only docker is supported. Conversions between formats may be supported in the future.   | String | optional | <code>"docker"</code> |
| <a id="oci_tarball-image"></a>image |  Label of a directory containing an OCI layout, typically <code>oci_image</code>   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="oci_tarball-loader"></a>loader |  Alternative target for a container cli tool that will be             used to load the image into the local engine when using <code>bazel run</code> on this oci_tarball.<br><br>            By default, we look for <code>docker</code> or <code>podman</code> on the PATH, and run the <code>load</code> command.<br><br>            &gt; Note that rules_docker has an "incremental loader" which has better performance, see             &gt; Follow https://github.com/bazel-contrib/rules_oci/issues/454 for similar behavior in rules_oci.<br><br>            See the _run_template attribute for the script that calls this loader tool.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="oci_tarball-repo_tags"></a>repo_tags |  a file containing repo_tags, one per line.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


