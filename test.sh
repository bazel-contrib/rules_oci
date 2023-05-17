#!/usr/bin/env bash

set -o pipefail -o errexit -o nounset

echo "invalidate = \"$RANDOM\"" > test.bzl
echo '{"uri": "index.docker.io"}' | ./cred_helper.py
bazel build $1 --experimental_credential_helper=%workspace%/cred_helper.py --experimental_credential_helper_cache_duration=0