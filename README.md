# Bazel rules for OCI container images

Bazel rules based on the Open Containers Initiative: <https://opencontainers.org/>

Please let us know about your success stories on our adoption discussion!
<https://github.com/bazel-contrib/rules_oci/discussions/299>

_Need help?_ This ruleset has support provided by https://aspect.dev.

## Comparison with rules_docker

This ruleset is not intended as a complete replacement for [rules_docker]!
Many use cases can be accomodated, and we know that many users have completely replaced rules_docker.
You can find a migration guide at <https://docs.aspect.build/guides/rules_oci_migration>.
However, some other use cases such as `container_run_and_*` rules have no equivalent.

[rules_docker] was largely unmaintained for 18 months, and as of October 2023 it has been archived.
See https://github.com/bazelbuild/rules_docker/discussions/2038.
You might still decide to use rules_docker, and perhaps even sign up as a maintainer so that it may be un-archived.

We started from first principles and avoided some pitfalls we learned from rules_docker:

- Use a toolchain consisting of off-the-shelf, pre-built layer and container manipulation tools.
- Don't write language-specific rules, as we cannot be experts on all languages, nor can users deal with the versioning issues
  that come with dependencies we would be forced to take on the rules for those languages.
- Don't be docker-specific, now that it has a commercial license and other container runtimes exist ([podman](https://podman.io/) for example).
- Use our toolchain hermetically: don't assume there is a docker pre-installed on the machine.
- Keep a tight complexity budget for the project so we are able to commit to effective maintenance.

[rules_docker]: https://github.com/bazelbuild/rules_docker

## Installation

See the install instructions on the release notes: <https://github.com/bazel-contrib/rules_oci/releases>

To use a commit rather than a release, you can point at any SHA of the repo.

With bzlmod, you can use `archive_override` or `git_override`. For `WORKSPACE`, you modify the `http_archive` call; for example to use commit `abc123` with a `WORKSPACE` file:

1. Replace `url = "https://github.com/bazel-contrib/rules_oci/releases/download/v0.1.0/rules_oci-v0.1.0.tar.gz"`
   with a GitHub-provided source archive like `url = "https://github.com/bazel-contrib/rules_oci/archive/abc123.tar.gz"`
1. Replace `strip_prefix = "rules_oci-0.1.0"` with `strip_prefix = "rules_oci-abc123"`
1. Update the `sha256`. The easiest way to do this is to comment out the line, then Bazel will
   print a message with the correct value.

> Note that GitHub source archives don't have a strong guarantee on the sha256 stability, see
> <https://github.blog/2023-02-21-update-on-the-future-stability-of-source-code-archives-and-hashes>

## Usage

rules_oci does not contain language-specific rules, but we do have limited documentation on how to accomplish typical tasks.

- [C/C++](docs/cpp.md)
- [Go](docs/go.md)
- [Java](docs/java.md)
- [JavaScript](docs/javascript.md)
- [Python](docs/python.md)
- [Rust](docs/rust.md)
- [Scala](docs/scala.md)
- [WASM](https://github.com/bazel-contrib/rules_oci/tree/main/e2e/wasm) (see https://docs.docker.com/desktop/wasm/)
- [Static Content](docs/static_content.md) (such as a html/javascript frontend)

> [!NOTE]
> Your language not listed above? Please contribute engineering resources or financially through our Sponsor link!

There are some generic examples of usage in the [examples](https://github.com/bazel-contrib/rules_oci/tree/main/examples) folder.
Note that these examples rely on the setup code in the `/WORKSPACE` file in the root of this repo.

## Public API Docs

### Build Base images

- Alpine: we recommend <https://github.com/chainguard-dev/rules_apko> to
  install [apk](https://wiki.alpinelinux.org/wiki/Package_management) packages
  using Chainguard's [apko](https://apko.dev).
- Debian: The `apt-get` utility installs `.deb` files, which are already archives
  that may be used directly as image layers. See `/examples/deb` in this repository.
  This solution is incomplete since `apt` does some other tasks which you may need.
  See https://github.com/bazel-contrib/rules_oci/issues/375 for details.
- RHEL/CentOS/Amazon Linux: we don't have any support for this yet. Please consider donating to the project!

### Construct image layers

- [oci_image](docs/image.md) Build an OCI compatible container image.
- [oci_image_index](docs/image_index.md) Build a multi-architecture OCI compatible container image.
- [oci_tarball](docs/tarball.md) Creates tarball from `oci_image` that can be loaded by runtimes.

### Pull and Push

- [oci_pull](docs/pull.md) Pull image layers using Bazel's downloader. Falls back to using `curl` in some cases.
- [oci_push](docs/push.md) Push an `oci_image` or `oci_image_index` to a remote registry.

### Testing

- We recommend [container_structure_test](https://github.com/GoogleContainerTools/container-structure-test#running-structure-tests-through-bazel) to run tests against an `oci_image` target (with `driver="docker"`) or an `oci_tarball` target (with `driver="tar"`).

### Signing

> [!WARNING]  
> Signing images is a developer preview, not part of public API yet.

- [cosign_sign](https://github.com/bazel-contrib/rules_oci/blob/main/cosign/private/sign.bzl): Sign an `oci_image` using `cosign` binary at a remote registry.
- [cosign_attest](https://github.com/bazel-contrib/rules_oci/blob/main/cosign/private/attest.bzl) Add an attachment to an `oci_image` at a remote registry using `cosign`.
