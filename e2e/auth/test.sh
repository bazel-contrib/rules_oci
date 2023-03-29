#!/usr/bin/env bash

set -o errexit -o pipefail

bzlmod_flag="$1"
assert=$(mktemp)
echo "{}" > $assert
bazel run :auth $assert &
trap "kill $!" EXIT

bazel run @oci_crane_darwin_amd64//:crane -- cp gcr.io/distroless/static@sha256:c3c3d0230d487c0ad3a0d87ad03ee02ea2ff0b3dcce91ca06a1019e07de05f12 localhost:1447/distroless/static

# Iterate over tests
for dir in .authn/*; do
    echo ""
    echo "# Case: $dir $bzlmod_flag"
    echo ""
    absolute_dir=$(pwd)/$dir
    tmp=$(mktemp -d)
    assert_config="$dir/assert.json"
    cat $assert_config > $assert

    exit_code=0
    PATH="$PATH:$absolute_dir" DOCKER_CONFIG="$absolute_dir" bazel build @distroless_static//... --repository_cache=$tmp $bzlmod_flag &> "$tmp/output.log" || exit_code=$?

    if [[ ! -f "$absolute_dir/failure.log" ]]; then 
        if [[ $exit_code -ne 0 ]]; then 
            echo "FAIL."
            echo ""
            cat "$tmp/output.log"
            exit 1
        fi
       
    else
        output=$(cat "$tmp/output.log")
        expected=$(cat "$absolute_dir/failure.log")
        if [[ "$output" != *$expected* ]]; then 
            echo ""
            echo "FAIL: $dir"
            echo "expected"
            echo ""
            echo "$output"
            echo ""
            echo "to contain"
            echo ""
            echo "$expected"
            exit 1
        fi
    fi
done