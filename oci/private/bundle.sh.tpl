#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly YQ="{{yq_path}}"
readonly COREUTILS="{{coreutils_path}}"

# Only crete the directory if it doesn't already exist.
# Otherwise we may attempt to modify permissions of an existing directory.
# See https://github.com/bazel-contrib/rules_oci/pull/271
function mkdirp() {
    test -d "$1" || "${COREUTILS}" mkdir -p "$1"
}

function copy_blob() {
    local image_path="$1"
    local output_path="$2"
    local blob_image_relative_path="$3"
    local dest_path="${output_path}/${blob_image_relative_path}"
    mkdirp "$(dirname "${dest_path}")"
    "${COREUTILS}" ln -f "${image_path}/${blob_image_relative_path}" "${dest_path}"
}

function create_oci_layout() {
    local path="$1"
    mkdirp "${path}"

    echo '{"imageLayoutVersion": "1.0.0"}' > "${path}/oci-layout" 
    echo '{"schemaVersion": 2, "manifests": []}' > "${path}/index.json"
}

function append_manifest() {
    local image_path="$1"
    local output_path="$2"
    local ref="$3"

    "${YQ}" --inplace --output-format=json ".manifests += $(${YQ} '.manifests' ${image_path}/index.json | ${YQ} eval "(.[].annotations[\"org.opencontainers.image.ref.name\"] | select(. == null)) |= \"${ref}\"" -M -o json -I 0)" "${output_path}/index.json"
}

CURRENT_IMAGE=""
OUTPUT=""

for ARG in "$@"; do
    case "$ARG" in
        (--output=*) OUTPUT="${ARG#--output=}"; create_oci_layout "$OUTPUT" ;;
        (--image=*) CURRENT_IMAGE="${ARG#--image=}";;
        (--blob=*) copy_blob "${CURRENT_IMAGE}" "$OUTPUT" "${ARG#--blob=}" ;;
        (--ref=*) append_manifest "${CURRENT_IMAGE}" "$OUTPUT" "${ARG#--ref=}";;
        (*) echo "Unknown argument ${ARG}"; exit 1;;
    esac
done
