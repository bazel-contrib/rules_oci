<!-- Generated with Stardoc: http://skydoc.bazel.build -->

A repository rule (used in WORKSPACE) to pull image layers using Bazel's downloader

<a id="#oci_alias_rule"></a>

## oci_alias_rule

<pre>
oci_alias_rule(<a href="#oci_alias_rule-name">name</a>, <a href="#oci_alias_rule-platforms">platforms</a>, <a href="#oci_alias_rule-repo_mapping">repo_mapping</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_alias_rule-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_alias_rule-platforms"></a>platforms |  -   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | optional | {} |
| <a id="oci_alias_rule-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |


<a id="#oci_pull_rule"></a>

## oci_pull_rule

<pre>
oci_pull_rule(<a href="#oci_pull_rule-name">name</a>, <a href="#oci_pull_rule-digest">digest</a>, <a href="#oci_pull_rule-image">image</a>, <a href="#oci_pull_rule-platform">platform</a>, <a href="#oci_pull_rule-repo_mapping">repo_mapping</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_pull_rule-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_pull_rule-digest"></a>digest |  The digest of the manifest file   | String | required |  |
| <a id="oci_pull_rule-image"></a>image |  The name of the image we are fetching, e.g. gcr.io/distroless/static   | String | required |  |
| <a id="oci_pull_rule-platform"></a>platform |  platform in <code>os/arch</code> format, for multi-arch images   | String | optional | "" |
| <a id="oci_pull_rule-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |


<a id="#pull_latest"></a>

## pull_latest

<pre>
pull_latest(<a href="#pull_latest-name">name</a>, <a href="#pull_latest-image">image</a>, <a href="#pull_latest-repo_mapping">repo_mapping</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="pull_latest-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="pull_latest-image"></a>image |  -   | String | optional | "" |
| <a id="pull_latest-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |


<a id="#oci_pull"></a>

## oci_pull

<pre>
oci_pull(<a href="#oci_pull-name">name</a>, <a href="#oci_pull-image">image</a>, <a href="#oci_pull-platforms">platforms</a>, <a href="#oci_pull-digest">digest</a>)
</pre>

Repository rule to fetch image manifest data from a remote docker registry.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="oci_pull-name"></a>name |  repository with this name is created   |  none |
| <a id="oci_pull-image"></a>image |  the remote image without a tag, such as gcr.io/bazel-public/bazel   |  none |
| <a id="oci_pull-platforms"></a>platforms |  for multi-architecture images, a dictionary of the platforms it supports This creates a separate external repository for each platform, avoiding fetching layers.   |  <code>None</code> |
| <a id="oci_pull-digest"></a>digest |  the digest string, starting with "sha256:", "sha512:", etc. If omitted, instructions for pinning are provided.   |  <code>None</code> |


