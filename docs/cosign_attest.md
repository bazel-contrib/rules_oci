<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation details for attest rule

<a id="#cosign_attest"></a>

## cosign_attest

<pre>
cosign_attest(<a href="#cosign_attest-name">name</a>, <a href="#cosign_attest-image">image</a>, <a href="#cosign_attest-predicate">predicate</a>, <a href="#cosign_attest-repository">repository</a>, <a href="#cosign_attest-type">type</a>)
</pre>

Attest an oci_image using cosign binary at a remote registry.

```starlark
oci_image(
    name = "image"
)

cosign_attest(
    name = "attest_spdx",
    type = "spdx"
    predicate = "image.sbom.spdx.json",
    repository = "index.docker.io/org/image"
)
```

`repository` attribute can be overridden using the `--repository` flag.

```starlark
oci_image(
    name = "image"
)

cosign_attest(
    name = "attest_spdx",
    type = "spdx"
    attestment = "image.sbom.spdx.json",
    repository = "index.docker.io/org/image"
)
```

via `bazel run :attest_spdx -- --repository=index.docker.io/org/test`


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cosign_attest-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="cosign_attest-image"></a>image |  Label to an oci_image   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="cosign_attest-predicate"></a>predicate |  Label to the predicate file. Only files are allowed. eg: sbom.spdx, in-toto.json   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="cosign_attest-repository"></a>repository |  Repository URL where the image will be signed at, e.g.: <code>index.docker.io/&lt;user&gt;/image</code>.         Digests and tags are not allowed.   | String | required |  |
| <a id="cosign_attest-type"></a>type |  Type of predicate. Acceptable values are (slsaprovenance|link|spdx|vuln|custom)   | String | required |  |


