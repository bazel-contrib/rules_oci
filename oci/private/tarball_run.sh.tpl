#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly IMAGE="{{image_path}}"
if [ -e "{{command}}" ]; then
    CONTAINER_CLI="{{command}}"
elif command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CLI="podman"
else
    echo >&2 "Neither docker or podman could be found."
    echo >&2 "If you wish to use another container runtime, you can pass command to oci_tarball(...)."
    exit 1
fi

"$CONTAINER_CLI" load --input "$IMAGE"
