#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly JQ="{{jq_path}}"
readonly COREUTILS="{{coreutils_path}}"

# Only crete the directory if it doesn't already exist.
# Otherwise we may attempt to modify permissions of an existing directory.
# See https://github.com/bazel-contrib/rules_oci/pull/271
function mkdirp() {
    test -d "$1" || "${COREUTILS}" mkdir -p "$1"
}

function add_image() {
    local image_path="$1"
    local output_path="$2"

    local manifests=$("${JQ}" -c '.manifests[]' "${image_path}/index.json")

    for manifest in "${manifests}"; do
        local manifest_blob_path=$("${JQ}" -r '.digest | sub(":"; "/")' <<< ${manifest})
        local config_blob_path=$("${JQ}" -r '.config.digest | sub(":"; "/")' "${image_path}/blobs/${manifest_blob_path}")

        local platform=$("${JQ}" -c '{"os": .os, "architecture": .architecture, "variant": .variant, "os.version": .["os.version"], "os.features": .["os.features"]} | with_entries(select( .value != null ))' "${image_path}/blobs/${config_blob_path}")
        "${JQ}" --argjson platform "${platform}" \
                --argjson manifest "${manifest}" \
                '.manifests += [$manifest + {"platform": $platform}]'\
                "${output_path}/manifest_list.json" > "${output_path}/manifest_list.new.json"
        "${COREUTILS}" cp --no-preserve=mode "${output_path}/manifest_list.new.json" "${output_path}/manifest_list.json"
    done
}

# Adds a blob of an image to the output, as a relative symlink when `link` is 1 and a copy otherwise.
# The rule decides which per image: a symlink only resolves in a runfiles tree when the image and
# the index share a configuration and a repository.
function add_blob() {
    local image_path="$1"
    local output_path="$2"
    local blob_image_relative_path="$3"
    local link="$4"
    local blob_path="${image_path}/${blob_image_relative_path}"
    local dest_path="${output_path}/${blob_image_relative_path}"
    # Blobs are content-addressed, so one that another image already contributed is the same blob.
    if [[ -e "${dest_path}" || -L "${dest_path}" ]]; then
        return
    fi
    local dest_dir
    dest_dir="$("${COREUTILS}" dirname "${dest_path}")"
    mkdirp "${dest_dir}"
    if [[ "${link}" == "1" ]]; then
        local relative
        relative="$("${COREUTILS}" realpath --no-symlinks --canonicalize-missing --relative-to="${dest_dir}" "${blob_path}")"
        "${COREUTILS}" ln --symbolic "${relative}" "${dest_path}"
    else
        "${COREUTILS}" cp --no-preserve=mode "${blob_path}" "${dest_path}"
    fi
}

function create_oci_layout() {
    local path="$1"
    mkdirp "${path}"

    echo '{"imageLayoutVersion": "1.0.0"}' > "${path}/oci-layout" 
    echo '{"schemaVersion": 2, "manifests": []}' > "${path}/index.json"
    echo '{"schemaVersion": 2, "mediaType": "application/vnd.oci.image.index.v1+json", "manifests": []}' > "${path}/manifest_list.json"
}

CURRENT_IMAGE=""
# Whether the blobs of CURRENT_IMAGE are symlinked (1) or copied (0).
LINK_BLOBS=0
OUTPUT=""
ANNOTATIONS=""

for ARG in "$@"; do
    case "$ARG" in
        (--output=*) OUTPUT="${ARG#--output=}"; create_oci_layout "$OUTPUT" ;;
        (--image=*) CURRENT_IMAGE="${ARG#--image=}"; LINK_BLOBS=0; add_image "$CURRENT_IMAGE" "$OUTPUT" ;;
        (--linked-image=*) CURRENT_IMAGE="${ARG#--linked-image=}"; LINK_BLOBS=1; add_image "$CURRENT_IMAGE" "$OUTPUT" ;;
        (--blob=*) add_blob "${CURRENT_IMAGE}" "$OUTPUT" "${ARG#--blob=}" "${LINK_BLOBS}" ;;
        (--annotations=*) ANNOTATIONS="${ARG#--annotations=}" ;;
        (*) echo "Unknown argument ${ARG}"; exit 1;;
    esac
done

if [[ -n "${ANNOTATIONS}" ]]; then
    "${JQ}" --rawfile annotations "${ANNOTATIONS}" \
            '.annotations += ([($annotations | split("\n") | .[] | select(. != ""))] | map(. | split("=")) | map({key: .[0], value: .[1:] | join("=")}) | from_entries)' \
            "${OUTPUT}/manifest_list.json" > "${OUTPUT}/manifest_list.new.json"
    "${COREUTILS}" cp --no-preserve=mode "${OUTPUT}/manifest_list.new.json" "${OUTPUT}/manifest_list.json"
fi

checksum=$("${COREUTILS}" sha256sum "${OUTPUT}/manifest_list.json" | "${COREUTILS}" cut -f 1 -d " ")
size=$("${COREUTILS}" wc -c < "${OUTPUT}/manifest_list.json")

"${JQ}" -n --arg checksum "${checksum}" --argjson size "${size}" \
        '.manifests = [{"mediaType": "application/vnd.oci.image.index.v1+json", "size": $size, "digest": ("sha256:" + $checksum) }]' > "$OUTPUT/index.json"

"${COREUTILS}" mv "${OUTPUT}/manifest_list.json" "$OUTPUT/blobs/sha256/${checksum}"
"${COREUTILS}" rm "${OUTPUT}/manifest_list.new.json"
