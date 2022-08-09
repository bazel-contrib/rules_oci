# Bazel rules for OCI containers

**EXPERIMENTAL** This ruleset is highly experimental and not yet fit for production use.
We might abandon it at any time, there is no guarantee of support or stability.

This is a speculative alternative to rules_docker.

We start from first principles and plan to avoid some pitfalls learned in maintaining that repo:

- Use a toolchain consisting of off-the-shelf, pre-built layer and container manipulation tools.
- Don't write language-specific rules, as we cannot be experts on all languages, nor can users deal with the versioning issues
  that come with dependencies we might take on the rules for those languages.
- Don't be docker-specific, now that it has a commercial license and other container runtimes exist.
- Use our toolchain hermetically: don't assume there is a docker pre-installed on the machine.
- Keep a tight complexity budget for the project so we are able to commit to effective maintenance.

_Need help?_ This ruleset has support provided by https://aspect.dev.

## Installation

From the release you wish to use: <https://github.com/bazel-contrib/rules_oci/releases>
copy the WORKSPACE snippet into your `WORKSPACE` file.

## Usage

See the API documentation in the [docs](docs/) folder and the example usage in the [example](example/) folder.
Note that the example relies on the setup code in the `/WORKSPACE` file in the root of this repo.
