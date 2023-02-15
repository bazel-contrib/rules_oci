<!-- Generated with Stardoc: http://skydoc.bazel.build -->

A repository rule (used in WORKSPACE) to pull image layers using Bazel's downloader

<a id="#oci_alias_rule"></a>

## oci_alias_rule

<pre>
oci_alias_rule(<a href="#oci_alias_rule-name">name</a>, <a href="#oci_alias_rule-repo_mapping">repo_mapping</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_alias_rule-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_alias_rule-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |


<a id="#oci_pull_rule"></a>

## oci_pull_rule

<pre>
oci_pull_rule(<a href="#oci_pull_rule-name">name</a>, <a href="#oci_pull_rule-image">image</a>, <a href="#oci_pull_rule-index">index</a>, <a href="#oci_pull_rule-reference">reference</a>, <a href="#oci_pull_rule-repo_mapping">repo_mapping</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_pull_rule-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_pull_rule-image"></a>image |  The name of the image we are fetching, e.g. gcr.io/distroless/static   | String | optional | "" |
| <a id="oci_pull_rule-index"></a>index |  content of the index.json file   | String | optional | "" |
| <a id="oci_pull_rule-reference"></a>reference |  The digest of the manifest   | String | optional | "" |
| <a id="oci_pull_rule-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |


<a id="#oci_pull"></a>

## oci_pull

<pre>
oci_pull(<a href="#oci_pull-name">name</a>, <a href="#oci_pull-manifest">manifest</a>)
</pre>

Generate an oci_pull rule for each platform.

Creates repositories like [name]_linux_amd64 containing an :image target.
Each of these is an OCI layout directory.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="oci_pull-name"></a>name |  name of resulting repository with an alias target that selects per-platform.   |  none |
| <a id="oci_pull-manifest"></a>manifest |  a dictionary matching the manifest list structure, mirrored from remote, see docs.   |  none |


