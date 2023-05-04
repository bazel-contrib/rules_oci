<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="#oci_push_rule"></a>

## oci_push_rule

<pre>
oci_push_rule(<a href="#oci_push_rule-name">name</a>, <a href="#oci_push_rule-default_tags">default_tags</a>, <a href="#oci_push_rule-image">image</a>, <a href="#oci_push_rule-repository">repository</a>)
</pre>

Push an oci_image or oci_image_index to a remote registry.

Internal rule used by the [oci_push macro](/docs/push.md#oci_push).

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

Push a multi-architecture image to github container registry with a semver tag

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

# This is defined in our /examples/push
stamp_tags(
    name = "stamped",
    default_tags = ["""($stamp.BUILD_EMBED_LABEL // "0.0.0")"""],
)

oci_push(
    image = ":app_image",
    repository = "ghcr.io/<OWNER>/image",
    tags = ":stamped",
)
```

When running the pusher, you can pass flags:
- Override `repository`: `-r|--repository` flag. e.g. `bazel run //myimage:push -- --repository index.docker.io/<ORG>/image`
- Additional `default_tags`: `-t|--tag` flag, e.g. `bazel run //myimage:push -- --tag latest`


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_push_rule-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_push_rule-default_tags"></a>default_tags |  a .txt file containing tags, one per line.         These are passed to [<code>crane tag</code>](         https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_tag.md)   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="oci_push_rule-image"></a>image |  Label to an oci_image or oci_image_index   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="oci_push_rule-repository"></a>repository |  Repository URL where the image will be signed at, e.g.: <code>index.docker.io/&lt;user&gt;/image</code>.         Digests and tags are not allowed.   | String | required |  |


<a id="#oci_push"></a>

## oci_push

<pre>
oci_push(<a href="#oci_push-name">name</a>, <a href="#oci_push-default_tags">default_tags</a>, <a href="#oci_push-kwargs">kwargs</a>)
</pre>

Macro wrapper around [oci_push_rule](#oci_push_rule).

Allows the default_tags attribute to be a list of strings in addition to a text file.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="oci_push-name"></a>name |  name of resulting oci_push_rule   |  none |
| <a id="oci_push-default_tags"></a>default_tags |  a list of tags to apply to the image after pushing, or a label of a file containing tags one-per-line. See [stamped_tags](https://github.com/bazel-contrib/rules_oci/blob/main/examples/push/stamp_tags.bzl) as one example of a way to produce such a file.   |  <code>[]</code> |
| <a id="oci_push-kwargs"></a>kwargs |  other named arguments to [oci_push_rule](#oci_push_rule).   |  none |


