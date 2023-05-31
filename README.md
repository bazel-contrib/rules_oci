# Bazel rules for OCI containers

This is a "barebones" alternative to [rules_docker](https://github.com/bazelbuild/rules_docker).

We start from first principles and avoided some pitfalls we learned in maintaining that repo:

- Use a toolchain consisting of off-the-shelf, pre-built layer and container manipulation tools.
- Don't write language-specific rules, as we cannot be experts on all languages, nor can users deal with the versioning issues
  that come with dependencies we would be forced to take on the rules for those languages.
- Don't be docker-specific, now that it has a commercial license and other container runtimes exist ([podman](https://podman.io/) for example).
- Use our toolchain hermetically: don't assume there is a docker pre-installed on the machine.
- Keep a tight complexity budget for the project so we are able to commit to effective maintenance.

_Need help?_ This ruleset has support provided by https://aspect.dev.

## Installation

- Bazel >= 6.2.0 with `--enable_bzlmod`: start from <https://registry.bazel.build/modules/rules_oci>
- Others: Copy the WORKSPACE snippet into your `WORKSPACE` file from a release: <https://github.com/bazel-contrib/rules_oci/releases>

To use a commit rather than a release, you can point at any SHA of the repo.

For example to use commit `abc123`:

1. Replace `url = "https://github.com/bazel-contrib/rules_oci/releases/download/v0.1.0/rules_oci-v0.1.0.tar.gz"`
   with a GitHub-provided source archive like `url = "https://github.com/bazel-contrib/rules_oci/archive/abc123.tar.gz"`
1. Replace `strip_prefix = "rules_oci-0.1.0"` with `strip_prefix = "rules_oci-abc123"`
1. Update the `sha256`. The easiest way to do this is to comment out the line, then Bazel will
   print a message with the correct value.

> Note that GitHub source archives don't have a strong guarantee on the sha256 stability, see
> <https://github.blog/2023-02-21-update-on-the-future-stability-of-source-code-archives-and-hashes>

## Usage

rules_oci does not contain language-specific rules, but we do have limited documentation on how to accomplish typical tasks, and how to migrate from the language-specific rules in rules_docker.

- [C/C++](docs/cpp.md)
- [Go](docs/go.md)
- [Java](docs/java.md)
- [JavaScript](docs/javascript.md)
- [Python](docs/python.md)
- [Rust](docs/rust.md)
- [Scala](docs/scala.md)
- [WASM](https://github.com/bazel-contrib/rules_oci/tree/main/e2e/wasm) (see https://docs.docker.com/desktop/wasm/)
- [Static Content](docs/static_content.md) (such as a html/javascript frontend)

> Your language not listed above? Please contribute engineering resources or financially through our Sponsor link!

There are some generic examples of usage in the [examples](https://github.com/bazel-contrib/rules_oci/tree/main/examples) folder.
Note that these examples rely on the setup code in the `/WORKSPACE` file in the root of this repo.

### Choosing between zot or crane as the local registry

rules_oci supports two different registry implementation for the temporary storage within actions spawned by bazel.

1. By default we recommend using `zot` as it stores blobs on disk, however it doesn't support `Docker`-format images.
2. `crane` is memory hungry as it stores blobs in memory, leading to high memory usage.
   However it supports both `OCI` and `Docker` formats which is quite useful for using `Docker` images pulled from the registries such as DockerHub.

## Public API Docs

### Construct image layers

- [oci_image](docs/image.md) Build an OCI compatible container image.
- [oci_image_index](docs/image_index.md) Build a multi-architecture OCI compatible container image.
- [oci_tarball](docs/tarball.md) Creates tarball from `oci_image` that can be loaded by runtimes.

### Pull and Push

- [oci_pull](docs/pull.md) Pulls image layers using Bazel's downloader.
- [oci_push](docs/push.md) Push an oci_image or oci_image_index to a remote registry.

### Testing

- We recommend [container_structure_test](https://github.com/GoogleContainerTools/container-structure-test#running-structure-tests-through-bazel) to run tests against an `oci_image` or `oci_tarball` target.

<!-- Currently undocumented, as it's not public API in 1.0

### Signing

- [cosign_sign](docs/cosign_sign.md) Sign an `oci_image` using `cosign` binary at a remote registry.
- [cosign_attest](docs/cosign_attest.md) Add an attachment to an `oci_image` at a remote registry using `cosign`.

-->
