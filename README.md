# Bazel rules for OCI containers

This is an alternative to [rules_docker](https://github.com/bazelbuild/rules_docker).

We start from first principles and avoided some pitfalls we learned in maintaining that repo:

- Use a toolchain consisting of off-the-shelf, pre-built layer and container manipulation tools.
- Don't write language-specific rules, as we cannot be experts on all languages, nor can users deal with the versioning issues
  that come with dependencies we would be forced to take on the rules for those languages.
- Don't be docker-specific, now that it has a commercial license and other container runtimes exist ([podman](https://podman.io/) for example).
- Use our toolchain hermetically: don't assume there is a docker pre-installed on the machine.
- Keep a tight complexity budget for the project so we are able to commit to effective maintenance.

_Need help?_ This ruleset has support provided by https://aspect.dev.

## Installation

From the release you wish to use: <https://github.com/bazel-contrib/rules_oci/releases>
copy the WORKSPACE snippet into your `WORKSPACE` file.

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

rules_oci does not contain language-specific rules, but we do document how to accomplish typical tasks, and migrate from the language-specific rules in rules_docker.

- [**Go**](docs/go.md): [Example](https://github.com/bazel-contrib/rules_oci/tree/main/e2e/go)
- **JavaScript**: [Docs](docs/javascript.md)
- [**WASM**](https://docs.docker.com/desktop/wasm/): [Example](https://github.com/bazel-contrib/rules_oci/tree/main/e2e/wasm)

> Your language not listed above? See https://github.com/bazel-contrib/rules_oci/issues/55

There are more examples of usage in the [examples](https://github.com/bazel-contrib/rules_oci/tree/main/examples) folder.
Note that the examples rely on the setup code in the `/WORKSPACE` file in the root of this repo.

# Public API

## Construct image layers

- [oci_image](docs/image.md) Build an OCI compatible container image.
- [oci_image_index](docs/image_index.md) Build a multi-architecture OCI compatible container image.
- [oci_tarball](docs/tarball.md) Creates tarball from `oci_image` that can be loaded by runtimes.

## Pull and Push

- [oci_pull](docs/pull.md) Pulls image layers using Bazel's downloader.
- [oci_push](docs/push.md) Push an oci_image or oci_image_index to a remote registry.

## Testing

- [structure_test](docs/structure_test.md) Test rule running [container_structure_test](https://github.com/GoogleContainerTools/container-structure-test) against an oci_image.

## Signing

- [cosign_sign](docs/cosign_sign.md) Sign an `oci_image` using `cosign` binary at a remote registry.
- [cosign_attest](docs/cosign_attest.md) Add an attachment to an `oci_image` at a remote registry using `cosign`.
