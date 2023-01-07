<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation details for attach rule

<a id="#cosign_attach"></a>

## cosign_attach

<pre>
cosign_attach(<a href="#cosign_attach-name">name</a>, <a href="#cosign_attach-attachment">attachment</a>, <a href="#cosign_attach-image">image</a>, <a href="#cosign_attach-repository">repository</a>, <a href="#cosign_attach-type">type</a>)
</pre>

Attach an attachment to an oci_image at a remote registry using cosign.

```starlark
oci_image(
    name = "image"
)

cosign_attach(
    name = "attach_sbom",
    type = "sbom"
    attachment = "image.sbom.spdx.json",
    repository = "index.docker.io/org/image"
)
```

`repository` attribute can be overridden using the `--repository` flag.

```starlark
oci_image(
    name = "image"
)

cosign_attach(
    name = "attach_sbom",
    type = "sbom"
    attachment = "image.sbom.spdx.json",
    repository = "index.docker.io/org/image"
)
```

via `bazel run :attach_sbom -- --repository=index.docker.io/org/test`


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cosign_attach-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="cosign_attach-attachment"></a>attachment |  Label to the attachment. Only files are allowed. eg: sbom.spdx, in-toto.json   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="cosign_attach-image"></a>image |  Label to an oci_image   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="cosign_attach-repository"></a>repository |  Repository URL where the image will be signed at, e.g.: <code>index.docker.io/&lt;user&gt;/image</code>.         Digests and tags are not allowed.   | String | required |  |
| <a id="cosign_attach-type"></a>type |  Type of attachment. Acceptable values are: <code>attestation</code>, <code>sbom</code>, and <code>signature</code>   | String | required |  |


