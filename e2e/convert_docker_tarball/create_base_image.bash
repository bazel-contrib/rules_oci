#!/bin/bash

set -o errexit -o nounset

cd "$(dirname "${BASH_SOURCE[0]}")"

# Export image
docker build . -t temp --no-cache
docker save temp -o image.tar

