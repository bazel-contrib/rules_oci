#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly IMAGE="{{image_path}}"
if command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CLI="docker"
else
    echo "Neither docker or podman could be found. If you wish to use another container runtime, then you can modify the template for generating this script via the `run_template` attribute on the `oci_tarball` rule. See: https://github.com/bazel-contrib/rules_oci/blob/main/docs/tarball.md"
    exit 1
fi

"$CONTAINER_CLI" load --input "$IMAGE"
