#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

bazel --bazelrc=.github/workflows/ci.bazelrc --bazelrc=.bazelrc build //example/js:image //example/py:image
bazel --bazelrc=.github/workflows/ci.bazelrc --bazelrc=.bazelrc \
build --platforms=@io_bazel_rules_go//go/toolchain:linux_arm64  //example/go:image



rm -f py_bundle.tar
skopeo copy oci:bazel-bin/example/py/bundle_app docker-archive:py_bundle.tar --additional-tag pyimage:latest
podman load -i py_bundle.tar
podman run --rm pyimage:latest

rm -f go_bundle.tar
skopeo copy oci:bazel-bin/example/go/bundle_app docker-archive:go_bundle.tar --additional-tag goimage:latest
podman load -i go_bundle.tar
podman run --rm goimage:latest

rm -f js_bundle.tar
skopeo copy oci:bazel-bin/example/js/bundle_app docker-archive:js_bundle.tar --additional-tag jsimage:latest
podman load -i js_bundle.tar
podman run --rm jsimage:latest