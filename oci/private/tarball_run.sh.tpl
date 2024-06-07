#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

if [ -e "{{loader}}" ]; then
    CONTAINER_CLI="{{loader}}"
elif command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CLI="podman"
else
    echo >&2 "Neither docker or podman could be found."
    echo >&2 "To use a different container runtime, pass an executable to the 'loader' attribute of oci_tarball."
    exit 1
fi


# The execroot detection code is copied from https://github.com/aspect-build/rules_js/blob/d4ac7025a83192d011b7dd7447975a538e34c49b/js/private/js_binary.sh.tpl#L169-L217
if [[ "$PWD" == *"/bazel-out/"* ]]; then
    bazel_out_segment="/bazel-out/"
elif [[ "$PWD" == *"/BAZEL-~1/"* ]]; then
    bazel_out_segment="/BAZEL-~1/"
elif [[ "$PWD" == *"/bazel-~1/"* ]]; then
    bazel_out_segment="/bazel-~1/"
fi

if [[ "${bazel_out_segment:-}" ]]; then
    # We are in runfiles and we don't yet know the execroot
    rest="${PWD#*"$bazel_out_segment"}"
    index=$((${#PWD} - ${#rest} - ${#bazel_out_segment}))
    if [ ${index} -lt 0 ]; then
        echo "No 'bazel-out' folder found in path '${PWD}'" >&2
        exit 1
    fi
    EXECROOT="${PWD:0:$index}"
else
    # We are in execroot or in some other context all or a manually run oci_tarball.
    EXECROOT="${PWD}"
fi


"$CONTAINER_CLI" load --input <(
    {{TAR}} --cd "$EXECROOT" --create --no-xattr --no-mac-metadata @"{{mtree_path}}"
)
