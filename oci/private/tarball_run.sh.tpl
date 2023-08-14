#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly IMAGE="{{image_path}}"
if command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CLI="podman"
else
    echo >&2 "Neither docker or podman could be found."
    echo >&2 "If you wish to use another container runtime, please comment on https://github.com/bazel-contrib/rules_oci/issues/295."
    exit 1
fi

"$CONTAINER_CLI" load --input "$IMAGE"
