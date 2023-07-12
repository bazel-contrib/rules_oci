#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly IMAGE="{{image_path}}"
if command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CLI="docker"
else
    echo "Neither docker or podman could be found."
    exit 1
fi

"$CONTAINER_CLI" load --input "$IMAGE"
