#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

# This shell script creates a partial `descriptor` for the given archive to be later used by image.sh.
# Partial in this context means that not all properties are in the final state, it must be processed 
# again by the image.sh wrapper to create a final descriptor. That said all expensive work, such as 
# `diffid` and `digest` calculation is already done here, there is not much left to do in image.sh 
# other than figuring out `mediaType` field by looking the base image media type and use an appropriate
# `mediaType` for the new layer. 
# 
# See: https://github.com/opencontainers/image-spec/blob/main/descriptor.md

# shellcheck disable=SC2153
archive="$1"
output="$2"
label="$3"

readonly ZSTD="{{zstd_path}}"
readonly JQ="{{jq_path}}"
readonly REGCTL="{{regctl_path}}"
readonly COREUTILS="{{coreutils_path}}"

digest=$(${REGCTL} digest <"$archive")
diffid="$digest"
size=$(${COREUTILS} wc -c "$archive" | ${COREUTILS} cut -f1 -d' ')
compression=

if [[ $(${COREUTILS} od -An -t x1 --read-bytes 2 "$archive") == " 1f 8b" ]]; then
    compression="gzip"
    diffid=$(${ZSTD} --decompress --format=gzip <"$archive" | ${REGCTL} digest)
elif zstd -t <"$archive" 2>/dev/null; then
    compression="zstd"
    diffid=$(${ZSTD} --decompress --format=zstd <"$archive" | ${REGCTL} digest)
fi

${JQ} -n \
    --arg compression "$compression" \
    --arg diffid "$diffid" \
    --arg digest "$digest" \
    --argjson size "$size" \
    --arg label "$label" \
'{
    digest: $digest, 
    diffid: $diffid, 
    compression: $compression, 
    size: $size,
    history: {
        created: "1970-01-01T00:00:00Z",
        created_by: "bazel build \($label)"
    }
}' >"$output"
