<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Create a tarball from oci_image that can be loaded by runtimes such as podman and docker.
Intended for use with `bazel run`.

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

### Outputs

The default output is an mtree specification file.
This is because producing the tarball in `bazel build` is expensive, and should typically not be an input to any other build actions,
so producing it only creates unnecessary load on the action cache.

If needed, the `tarball` output group allows you to depend on the tar output from another rule.

On the command line, `bazel build //path/to:my_tarball --output_groups=tarball`

or in a BUILD file:

```starlark
oci_tarball(
    name = "my_tarball",
    ...
)
filegroup(
    name = "my_tarball.tar",
    srcs = [":my_tarball"],
    output_group = "tarball",
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_tarball-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="oci_tarball-format"></a>format |  Format of image to generate. Options are: docker, oci. Currently, when the input image is an image_index, only oci is supported, and when the input image is an image, only docker is supported. Conversions between formats may be supported in the future.   | String | optional | <code>"docker"</code> |
| <a id="oci_tarball-image"></a>image |  Label of a directory containing an OCI layout, typically <code>oci_image</code>   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="oci_tarball-loader"></a>loader |  Alternative target for a container cli tool that will be             used to load the image into the local engine when using <code>bazel run</code> on this oci_tarball.<br><br>            By default, we look for <code>docker</code> or <code>podman</code> on the PATH, and run the <code>load</code> command.<br><br>            &gt; Note that rules_docker has an "incremental loader" which is faster than oci_tarball by design.             &gt; Something similar can be done for oci_tarball.              &gt; See [loader.sh](/examples/incremental_loader/loader.sh) and explanation about [how](/examples/incremental_loader/README.md) it works.<br><br>            See the _run_template attribute for the script that calls this loader tool.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="oci_tarball-repo_tags"></a>repo_tags |  a file containing repo_tags, one per line.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


