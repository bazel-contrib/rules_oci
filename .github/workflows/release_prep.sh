#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
TAG=${GITHUB_REF_NAME}
# The prefix is chosen to match what GitHub generates for source archives
PREFIX="rules_oci-${TAG:1}"
ARCHIVE="rules_oci-$TAG.tar.gz"
git archive --format=tar --prefix=${PREFIX}/ ${TAG} | gzip > $ARCHIVE
SHA=$(shasum -a 256 $ARCHIVE | awk '{print $1}')

cat << EOF
## Using bzlmod with Bazel 6 or later:

- (Bazel 6) Add \`common --enable_bzlmod\` to \`.bazelrc\`.
- Add to your \`MODULE.bazel\` file:

\`\`\`starlark
bazel_dep(name = "rules_oci", version = "${TAG:1}")
# For testing, we also recommend https://registry.bazel.build/modules/container_structure_test

oci = use_extension("@rules_oci//oci:extensions.bzl", "oci")

# Declare external images you need to pull, for example: 
oci.pull(
    name = "distroless_base",
    # 'latest' is not reproducible, but it's convenient.
    # During the build we print a WARNING message that includes recommended 'digest' and 'platforms'
    # values which you can use here in place of 'tag' to pin for reproducibility.
    tag = "latest",
    image = "gcr.io/distroless/base",
    platforms = ["linux/amd64"],
)

# For each oci.pull call, repeat the "name" here to expose them as dependencies.
use_repo(oci, "distroless_base")
\`\`\`

## Using WORKSPACE:

\`\`\`starlark

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_oci",
    sha256 = "${SHA}",
    strip_prefix = "${PREFIX}",
    url = "https://github.com/bazel-contrib/rules_oci/releases/download/${TAG}/${ARCHIVE}",
)
EOF

awk 'f;/--SNIP--/{f=1}' e2e/smoke/WORKSPACE.bazel
echo "\`\`\`" 