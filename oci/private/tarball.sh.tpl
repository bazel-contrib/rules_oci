#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly STAGING_DIR=$(mktemp -d)
readonly YQ="{{yq}}"
readonly IMAGE_DIR="{{image_dir}}"
readonly BLOBS_DIR="${STAGING_DIR}/blobs"
readonly TARBALL_PATH="{{tarball_path}}"
readonly TAGS_FILE="{{tags}}"

MANIFEST_DIGEST=$(${YQ} eval '.manifests[0].digest | sub(":"; "/")' "${IMAGE_DIR}/index.json" | tr  -d '"')
MANIFEST_BLOB_PATH="${IMAGE_DIR}/blobs/${MANIFEST_DIGEST}"

CONFIG_DIGEST=$(${YQ} eval '.config.digest  | sub(":"; "/")' ${MANIFEST_BLOB_PATH})
CONFIG_BLOB_PATH="${IMAGE_DIR}/blobs/${CONFIG_DIGEST}"

LAYERS=$(${YQ} eval '.layers | map(.digest | sub(":"; "/"))' ${MANIFEST_BLOB_PATH})

mkdir -p $(dirname "${BLOBS_DIR}/${CONFIG_DIGEST}")
cp "${CONFIG_BLOB_PATH}" "${BLOBS_DIR}/${CONFIG_DIGEST}"

for LAYER in $(${YQ} ".[]" <<< $LAYERS); do 
    cp -f "${IMAGE_DIR}/blobs/${LAYER}" "${BLOBS_DIR}/${LAYER}.tar.gz"
done

# Replace newlines (unix or windows line endings) with % character.
# We can't pass newlines to yq due to https://github.com/mikefarah/yq/issues/1430 and
# we can't update YQ at the moment because structure_test depends on a specific version:
# see https://github.com/bazel-contrib/rules_oci/issues/212
repo_tags="$(tr -d '\r' < "${TAGS_FILE}" | tr '\n' '%')" \
config="blobs/${CONFIG_DIGEST}" \
layers="${LAYERS}" \
"${YQ}" eval \
        --null-input '.[0] = {"Config": env(config), "RepoTags": "${repo_tags}" | envsubst | split("%") | map(select(. != "")) , "Layers": env(layers) | map( "blobs/" + . + ".tar.gz") }' \
        --output-format json > "${STAGING_DIR}/manifest.json"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  reproducible_flags="--mtime=2000-01-01 --owner=0 --group=0 --numeric-owner"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # FIXME: add necessary attributes or wait for tar toolchain.
  reproducible_flags=""
else
  # FIXME: add necessary attributes or wait for tar toolchain.
  reproducible_flags=""
fi

# TODO: https://github.com/bazel-contrib/rules_oci/issues/217
tar -C "${STAGING_DIR}" -cf "${TARBALL_PATH}" $reproducible_flags manifest.json blobs
