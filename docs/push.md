<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation details for the push rule

<a id="#oci_push"></a>

## oci_push

<pre>
oci_push(<a href="#oci_push-name">name</a>, <a href="#oci_push-default_tags">default_tags</a>, <a href="#oci_push-image">image</a>, <a href="#oci_push-repository">repository</a>)
</pre>

Push an oci_image or oci_image_index to a remote registry.

Pushing and tagging are performed sequentially which MAY lead to non-atomic pushes if one the following events occur;

- Remote registry rejects a tag due to various reasons. eg: forbidden characters, existing tags 
- Remote registry closes the connection during the tagging
- Local network outages

In order to avoid incomplete pushes oci_push will push the image by its digest and then apply the `default_tags` sequentially at
the remote registry. 

Any failure during pushing or tagging will be reported with non-zero exit code cause remaining steps to be skipped.


Push an oci_image to docker registry with latest tag

```starlark
oci_image(name = "image")

oci_push(
    image = ":image",
    repository = "index.docker.io/<ORG>/image",
    default_tags = ["latest"]
)
```

Push an oci_image_index to github container registry with a semver tag

```starlark
oci_image(name = "app_linux_arm64")

oci_image(name = "app_linux_amd64")

oci_image(name = "app_windows_amd64")

oci_image_index(
    name = "app_image",
    images = [
        ":app_linux_arm64",
        ":app_linux_amd64",
        ":app_windows_amd64",
    ]
)

oci_push(
    image = ":app_image",
    repository = "ghcr.io/<OWNER>/image",
    default_tags = ["0.0.0"]
)
```

Ideally the semver information is gathered from a vcs, like git, instead of being hardcoded to the BUILD files.
However, due to nature of BUILD files being static, one has to use `-t|--tag` flag to pass the tag at runtime instead of using `default_tags`.

example `bazel run //target:push -- --tag $(git tag)`


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_push-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_push-default_tags"></a>default_tags |  List of tags to apply to the image at remote registry.   | List of strings | optional | [] |
| <a id="oci_push-image"></a>image |  Label to an oci_image or oci_image_index   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="oci_push-repository"></a>repository |  Repository URL where the image will be signed at. eg: index.docker.io/&lt;user&gt;/image. digests and tags are disallowed.   | String | required |  |


