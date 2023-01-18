#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly YQ="{{yq_path}}"
readonly COREUTILS="{{coreutils_path}}"

function add_image() {
    local image_path="$1"
    local output_path="$2"

    local manifests=$("${YQ}" eval '.manifests[]' "${image_path}/index.json")

    for manifest in "${manifests}"; do
        local manifest_blob_path=$("${YQ}" '.digest | sub(":"; "/")' <<< ${manifest})
        local config_blob_path=$("${YQ}" '.config.digest | sub(":"; "/")' "${image_path}/blobs/${manifest_blob_path}")

        local platform=$("${YQ}" --output-format=json '{"os": .os, "architecture": .architecture, "variant": .variant, "os.version": .["os.version"], "os.features": .["os.features"]} | with_entries(select( .value != null ))' "${image_path}/blobs/${config_blob_path}")

        platform="${platform}" \
        manifest="${manifest}" \
        "${YQ}" --inplace --output-format=json '.manifests += [env(manifest) + {"platform": env(platform)}]' "${output_path}/manifest_list.json"
    done
}

function copy_blob() {
    local image_path="$1"
    local output_path="$2"
    local blob_image_relative_path="$3"
    local dest_path="${output_path}/${blob_image_relative_path}"
    "${COREUTILS}" mkdir -p "$(dirname "${dest_path}")"
    "${COREUTILS}" cat "${image_path}/${blob_image_relative_path}" > "${dest_path}"
}

function create_oci_layout() {
    local path="$1"
    "${COREUTILS}" mkdir -p "${path}"

    echo '{"imageLayoutVersion": "1.0.0"}' > "${path}/oci-layout" 
    echo '{"schemaVersion": 2, "manifests": []}' > "${path}/index.json"
    echo '{"schemaVersion": 2, "mediaType": "application/vnd.oci.image.index.v1+json", "manifests": []}' > "${path}/manifest_list.json"
}

CURRENT_IMAGE=""
OUTPUT=""

for ARG in "$@"; do
    case "$ARG" in
        (--output=*) OUTPUT="${ARG#--output=}"; create_oci_layout "$OUTPUT" ;;
        (--image=*) CURRENT_IMAGE="${ARG#--image=}"; add_image "$CURRENT_IMAGE" "$OUTPUT" ;;
        (--blob=*) copy_blob "${CURRENT_IMAGE}" "$OUTPUT" "${ARG#--blob=}" ;;
        (*) echo "Unknown argument ${ARG}"; exit 1;;
    esac
done


export checksum=$("${COREUTILS}" sha256sum "${OUTPUT}/manifest_list.json" | "${COREUTILS}" cut -f 1 -d " ")
export size=$("${COREUTILS}" wc -c < "${OUTPUT}/manifest_list.json")

"${YQ}" --inplace --output-format=json '.manifests += [{"mediaType": "application/vnd.oci.image.index.v1+json", "size": env(size), "digest": "sha256:" + env(checksum)}]' "$OUTPUT/index.json"

"${COREUTILS}" mv "${OUTPUT}/manifest_list.json" "$OUTPUT/blobs/sha256/${checksum}"