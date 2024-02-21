<!-- Generated with Stardoc: http://skydoc.bazel.build -->

A repository rule to pull image layers using Bazel's downloader.

Typical usage in `WORKSPACE.bazel`:

```starlark
load("@rules_oci//oci:pull.bzl", "oci_pull")

# A single-arch base image
oci_pull(
    name = "distroless_java",
    digest = "sha256:161a1d97d592b3f1919801578c3a47c8e932071168a96267698f4b669c24c76d",
    image = "gcr.io/distroless/java17",
    platforms = ["linux/amd64"],  # Optional
)

# A multi-arch base image
oci_pull(
    name = "distroless_static",
    digest = "sha256:c3c3d0230d487c0ad3a0d87ad03ee02ea2ff0b3dcce91ca06a1019e07de05f12",
    image = "gcr.io/distroless/static",
    platforms = [
        "linux/amd64",
        "linux/arm64",
    ],
)
```

Now you can refer to these as a base layer in `BUILD.bazel`.
The target is named the same as the external repo, so you can use a short label syntax:

```
oci_image(
    name = "app",
    base = "@distroless_static",
    ...
)
```

## Configuration

Docker specifies a standard location where registry credentials are stored:
&lt;https://docs.docker.com/engine/reference/commandline/cli/#configuration-files&gt;

We search for this file in several locations, following the logic at
https://github.com/google/go-containerregistry/tree/main/pkg/authn#tldr-for-consumers-of-this-package.

Set `--repo_env=DOCKER_CONFIG=/some/other/directory` to cause `oci_pull` to look for
`config.json` in this directory instead.

Finally, some less-common use cases are afforded with environment variables `XDG_RUNTIME_DIR` and `REGISTRY_AUTH_FILE`.
See the implementation of `_get_auth_file_path` in `/oci/private/auth_config_locator.bzl` for the complete reference.


## Authentication using credential helpers

By default oci_pull try to mimic `docker pull` authentication mechanism to allow users simply use `docker login` for authentication.

However, this doesn't always work due to some limitations of Bazel where response headers can't be read, which prevents us from
performing `WWW-Authenticate` challenges, as we don't know which endpoint to hit to complete the challenge. To workaround this
we keep a map of known registries that require us to perform www-auth challenge to acquire a temporary token for authentication.


Fortunately, Bazel supports running external programs to authenticate http requests using the `--credential_helper` command line flag.
When the credential helper flag passed, Bazel will call the external program before sending the request to allow additional headers to be set.

An example of this

.bazelrc
```
common --credential_helper=public.ecr.aws=%workspace%/tools/auth.sh
```

tools/auth.sh
```bash
input=$(cat)
uri=$(jq -r ".uri" &lt;&lt;&lt; $input)
host="$(echo $uri | awk -F[/:] '{print $4}')"
curl -fsSL https://$host/token | jq '{headers:{"Authorization": [("Bearer " + .token)]}}'
```

This tells bazel to run `%workspace%/tools/auth.sh` for any request sent to `public.ecr.aws` and add additional headers that may have been
printed to `stdout` by the external program.

For more information about the credential helpers checkout the [documentation](https://github.com/bazelbuild/proposals/blob/main/designs/2022-06-07-bazel-credential-helpers.md).

See the [examples/credential_helper](/examples/credential_helper/auth.sh) directory for an example of how this work.


<a id="oci_pull"></a>

## oci_pull

<pre>
oci_pull(<a href="#oci_pull-name">name</a>, <a href="#oci_pull-image">image</a>, <a href="#oci_pull-repository">repository</a>, <a href="#oci_pull-registry">registry</a>, <a href="#oci_pull-platforms">platforms</a>, <a href="#oci_pull-digest">digest</a>, <a href="#oci_pull-tag">tag</a>, <a href="#oci_pull-reproducible">reproducible</a>, <a href="#oci_pull-is_bzlmod">is_bzlmod</a>, <a href="#oci_pull-config">config</a>,
         <a href="#oci_pull-config_path">config_path</a>)
</pre>

Repository macro to fetch image manifest data from a remote docker registry.

To use the resulting image, you can use the `@wkspc` shorthand label, for example
if `name = "distroless_base"`, then you can just use `base = "@distroless_base"`
in rules like `oci_image`.

&gt; This shorthand syntax is broken on the command-line prior to Bazel 6.2.
&gt; See https://github.com/bazelbuild/bazel/issues/4385


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="oci_pull-name"></a>name |  repository with this name is created   |  none |
| <a id="oci_pull-image"></a>image |  the remote image, such as <code>gcr.io/bazel-public/bazel</code>. A tag can be suffixed with a colon, like <code>debian:latest</code>, and a digest can be suffixed with an at-sign, like <code>debian@sha256:e822570981e13a6ef1efcf31870726fbd62e72d9abfdcf405a9d8f566e8d7028</code>.<br><br>Exactly one of image or {registry,repository} should be set.   |  <code>None</code> |
| <a id="oci_pull-repository"></a>repository |  the image path beneath the registry, such as <code>distroless/static</code>. When set, registry must be set as well.   |  <code>None</code> |
| <a id="oci_pull-registry"></a>registry |  the remote registry domain, such as <code>gcr.io</code> or <code>docker.io</code>. When set, repository must be set as well.   |  <code>None</code> |
| <a id="oci_pull-platforms"></a>platforms |  a list of the platforms the image supports. Mandatory for multi-architecture images. Optional for single-architecture images, which expect a one-element list. This creates a separate external repository for each platform, avoiding fetching layers, and an alias that validates the presence of an image matching the target platform's cpu.   |  <code>None</code> |
| <a id="oci_pull-digest"></a>digest |  the digest string, starting with "sha256:", "sha512:", etc. If omitted, instructions for pinning are provided.   |  <code>None</code> |
| <a id="oci_pull-tag"></a>tag |  a tag to choose an image from the registry. Exactly one of <code>tag</code> and <code>digest</code> must be set. Since tags are mutable, this is not reproducible, so a warning is printed.   |  <code>None</code> |
| <a id="oci_pull-reproducible"></a>reproducible |  Set to False to silence the warning about reproducibility when using <code>tag</code>.   |  <code>True</code> |
| <a id="oci_pull-is_bzlmod"></a>is_bzlmod |  whether the oci_pull is being called from a module extension   |  <code>False</code> |
| <a id="oci_pull-config"></a>config |  Label to a <code>.docker/config.json</code> file.   |  <code>None</code> |
| <a id="oci_pull-config_path"></a>config_path |  Deprecated. use <code>config</code> attribute or DOCKER_CONFIG environment variable.   |  <code>None</code> |


