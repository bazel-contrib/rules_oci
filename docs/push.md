<!-- Generated with Stardoc: http://skydoc.bazel.build -->


To load these rules, add this to the top of your `BUILD` file:

```starlark
load("@rules_oci//oci:defs.bzl", ...)
```


<a id="oci_push_rule"></a>

## oci_push_rule

<pre>
oci_push_rule(<a href="#oci_push_rule-name">name</a>, <a href="#oci_push_rule-image">image</a>, <a href="#oci_push_rule-remote_tags">remote_tags</a>, <a href="#oci_push_rule-repository">repository</a>, <a href="#oci_push_rule-repository_file">repository_file</a>)
</pre>

Push an oci_image or oci_image_index to a remote registry.

Internal rule used by the [oci_push macro](/docs/push.md#oci_push).
Most users should use the macro.

Authorization
=============

By default, oci_push uses the standard authorization config file located on the host where `oci_push` is running.
Therefore the following documentation may be consulted:

- https://docs.docker.com/engine/reference/commandline/login/
- https://docs.podman.io/en/latest/markdown/podman-login.1.html
- https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_auth_login.md

Behavior
========

Pushing and tagging are performed sequentially which MAY lead to non-atomic pushes if one the following events occur;

- Remote registry rejects a tag due to various reasons. eg: forbidden characters, existing tags 
- Remote registry closes the connection during the tagging
- Local network outages

In order to avoid incomplete pushes oci_push will push the image by its digest and then apply the `remote_tags` sequentially at
the remote registry. 

Any failure during pushing or tagging will be reported with non-zero exit code and cause remaining steps to be skipped.

Usage
=====

When running the pusher, you can pass flags to `bazel run`.

1. Override `repository` by passing the `-r|--repository` flag.

e.g. `bazel run //myimage:push -- --repository index.docker.io/&lt;ORG&gt;/image`

2. Supply tags in addition to `remote_tags` by passing the `-t|--tag` flag.

e.g. `bazel run //myimage:push -- --tag latest`

Examples
========

Push an oci_image to docker registry with 'latest' tag

```starlark
oci_image(name = "image")

oci_push(
    image = ":image",
    repository = "index.docker.io/&lt;ORG&gt;/image",
    remote_tags = ["latest"]
)
```

Push a multi-architecture image to github container registry with a semver tag

```starlark
load("@aspect_bazel_lib//lib:expand_template.bzl", "expand_template_rule")

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

# Use the value of --embed_label under --stamp, otherwise use a deterministic constant
# value to ensure cache hits for actions that depend on this.
expand_template(
    name = "stamped",
    out = "_stamped.tags.txt",
    template = ["0.0.0"],
    stamp_substitutions = {"0.0.0": "{{BUILD_EMBED_LABEL}}"},
)

oci_push(
    image = ":app_image",
    repository = "ghcr.io/&lt;OWNER&gt;/image",
    remote_tags = ":stamped",
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_push_rule-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="oci_push_rule-image"></a>image |  Label to an oci_image or oci_image_index   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="oci_push_rule-remote_tags"></a>remote_tags |  a .txt file containing tags, one per line.         These are passed to [<code>crane tag</code>](         https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_tag.md)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="oci_push_rule-repository"></a>repository |  Repository URL where the image will be signed at, e.g.: <code>index.docker.io/&lt;user&gt;/image</code>.         Digests and tags are not allowed.   | String | optional | <code>""</code> |
| <a id="oci_push_rule-repository_file"></a>repository_file |  The same as 'repository' but in a file. This allows pushing to different repositories based on stamping.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |


<a id="oci_push"></a>

## oci_push

<pre>
oci_push(<a href="#oci_push-name">name</a>, <a href="#oci_push-remote_tags">remote_tags</a>, <a href="#oci_push-kwargs">kwargs</a>)
</pre>

Macro wrapper around [oci_push_rule](#oci_push_rule).

Allows the remote_tags attribute to be a list of strings in addition to a text file.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="oci_push-name"></a>name |  name of resulting oci_push_rule   |  none |
| <a id="oci_push-remote_tags"></a>remote_tags |  a list of tags to apply to the image after pushing, or a label of a file containing tags one-per-line. See [stamped_tags](https://github.com/bazel-contrib/rules_oci/blob/main/examples/push/stamp_tags.bzl) as one example of a way to produce such a file.   |  <code>None</code> |
| <a id="oci_push-kwargs"></a>kwargs |  other named arguments to [oci_push_rule](#oci_push_rule) and [common rule attributes](https://bazel.build/reference/be/common-definitions#common-attributes).   |  none |


