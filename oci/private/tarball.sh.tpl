#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly YQ="{{yq}}"
readonly TAR="{{tar}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly TARBALL_PATH="{{tarball_path}}"
readonly TAGS_FILE="{{tags}}"

# Write tar manifest in mtree format
# https://man.freebsd.org/cgi/man.cgi?mtree(8)
# so that tar produces a deterministic output.
mtree=$(mktemp)
function add_to_tar() {
    content=$1
    tar_path=$2
    echo >>"${mtree}" "${tar_path} uid=0 gid=0 mode=0755 time=1672560000 type=file content=${content}"
}

MANIFEST_DIGEST=$(${YQ} eval '.manifests[0].digest | sub(":"; "/")' "${IMAGE_DIR}/index.json" | tr  -d '"')
MANIFEST_BLOB_PATH="${IMAGE_DIR}/blobs/${MANIFEST_DIGEST}"

CONFIG_DIGEST=$(${YQ} eval '.config.digest  | sub(":"; "/")' ${MANIFEST_BLOB_PATH})
CONFIG_BLOB_PATH="${IMAGE_DIR}/blobs/${CONFIG_DIGEST}"
add_to_tar "${CONFIG_BLOB_PATH}" "blobs/${CONFIG_DIGEST}"

LAYERS=$(${YQ} eval '.layers | map(.digest | sub(":"; "/"))' ${MANIFEST_BLOB_PATH})
for LAYER in $(${YQ} ".[]" <<< $LAYERS); do 
    add_to_tar "${IMAGE_DIR}/blobs/${LAYER}" "blobs/${LAYER}.tar.gz"
done

# Replace newlines (unix or windows line endings) with % character.
# We can't pass newlines to yq due to https://github.com/mikefarah/yq/issues/1430 and
# we can't update YQ at the moment because structure_test depends on a specific version:
# see https://github.com/bazel-contrib/rules_oci/issues/212
manifest_json=$(mktemp)
repo_tags="$(tr -d '\r' < "${TAGS_FILE}" | tr '\n' '%')" \
config="blobs/${CONFIG_DIGEST}" \
layers="${LAYERS}" \
"${YQ}" eval \
        --null-input '.[0] = {"Config": env(config), "RepoTags": "${repo_tags}" | envsubst | split("%") | map(select(. != "")) , "Layers": env(layers) | map( "blobs/" + . + ".tar.gz") }' \
        --output-format json > "${manifest_json}"

add_to_tar "${manifest_json}" "manifest.json"

# We've created the manifest, now hand it off to tar to create our final output
"${TAR}" --create --file "${TARBALL_PATH}" "@${mtree}"
