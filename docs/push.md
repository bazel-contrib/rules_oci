<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API

<a id="#oci_push_rule"></a>

## oci_push_rule

<pre>
oci_push_rule(<a href="#oci_push_rule-name">name</a>, <a href="#oci_push_rule-image">image</a>, <a href="#oci_push_rule-image_tags">image_tags</a>, <a href="#oci_push_rule-repository">repository</a>)
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
    image_tags = ["latest"]
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

stamped_tags(
    name = "stamped",
    image_tags = ["""($stamp.BUILD_EMBED_LABEL // "0.0.0")"""],
)

oci_push(
    image = ":app_image",
    repository = "ghcr.io/<OWNER>/image",
    tags = ":stamped",
)
```

When running the pusher, you can pass flags:
- Override `repository`: `-r|--repository` flag. e.g. `bazel run //myimage:push -- --repository index.docker.io/<ORG>/image`
- Additional `image_tags`: `-t|--tag` flag, e.g. `bazel run //myimage:push -- --tag latest`


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_push_rule-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_push_rule-image"></a>image |  Label to an oci_image or oci_image_index   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="oci_push_rule-image_tags"></a>image_tags |  a .txt file containing tags, one per line.         These are passed to [<code>crane tag</code>](         https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_tag.md)   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="oci_push_rule-repository"></a>repository |  Repository URL where the image will be signed at, e.g.: <code>index.docker.io/&lt;user&gt;/image</code>.         Digests and tags are not allowed.   | String | required |  |


<a id="#oci_push"></a>

## oci_push

<pre>
oci_push(<a href="#oci_push-name">name</a>, <a href="#oci_push-image_tags">image_tags</a>, <a href="#oci_push-kwargs">kwargs</a>)
</pre>

Macro wrapper around [oci_push_rule](#oci_push_rule).

Allows the tags attribute to be a list of strings in addition to a text file.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="oci_push-name"></a>name |  name of resulting oci_push_rule   |  none |
| <a id="oci_push-image_tags"></a>image_tags |  a list of tags to apply to the image after pushing, or a label of a file containing tags one-per-line. See [stamped_tags](#stamped_tags) as one example of a way to produce such a file.   |  <code>None</code> |
| <a id="oci_push-kwargs"></a>kwargs |  other named arguments to [oci_push_rule](#oci_push_rule).   |  none |


<a id="#stamped_tags"></a>

## stamped_tags

<pre>
stamped_tags(<a href="#stamped_tags-name">name</a>, <a href="#stamped_tags-image_tags">image_tags</a>, <a href="#stamped_tags-kwargs">kwargs</a>)
</pre>

Wrapper macro around the [jq](https://docs.aspect.build/rules/aspect_bazel_lib/docs/jq) rule.

Produces a text file that can be used with the `image_tags` attribute of [`oci_push`](#oci_push).

Each entry in `image_tags` is typically either a constant like `latest`, or a stamp expression.
The latter can use any key from `bazel-out/stable-status.txt` or `bazel-out/volatile-status.txt`.
See https://docs.aspect.build/rules/aspect_bazel_lib/docs/stamping/ for details.

The jq `//` default operator is useful for returning an alternative value for unstamped builds.

For example, if you use the expression `($stamp.BUILD_EMBED_LABEL // "0.0.0")`, this resolves to
"0.0.0" if stamping is not enabled. When built with `--stamp --embed_label=1.2.3` it will
resolve to `1.2.3`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="stamped_tags-name"></a>name |  name of the resulting jq target.   |  none |
| <a id="stamped_tags-image_tags"></a>image_tags |  list of jq expressions which result in a string value, see docs above   |  none |
| <a id="stamped_tags-kwargs"></a>kwargs |  additional named parameters to the jq rule.   |  none |


