<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation details for sign rule

<a id="#cosign_sign"></a>

## cosign_sign

<pre>
cosign_sign(<a href="#cosign_sign-name">name</a>, <a href="#cosign_sign-image">image</a>, <a href="#cosign_sign-repository">repository</a>)
</pre>

Sign an oci_image using cosign binary at a remote registry.

It sings the image by its digest determined beforehand.

```starlark
oci_image(
    name = "image"
)

cosign_sign(
    name = "sign",
    image = ":image",
    repository = "index.docker.io/org/image"
)
```

`repository` attribute can be overridden using the `--repository` flag.

```starlark
oci_image(
    name = "image"
)

cosign_sign(
    name = "sign",
    image = ":image",
    repository = "index.docker.io/org/image"
)
```

run `bazel run :sign -- --repository=index.docker.io/org/test`


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cosign_sign-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="cosign_sign-image"></a>image |  Label to an oci_image   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="cosign_sign-repository"></a>repository |  Repository URL where the image will be signed at. eg: index.docker.io/&lt;user&gt;/image. digests and tags are disallowed.   | String | required |  |


