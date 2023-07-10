#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly IMAGE="{{image_path}}"
docker load --input "$IMAGE"
