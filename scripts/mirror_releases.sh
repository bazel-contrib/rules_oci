#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
RAW=$(mktemp)

REPOSITORY=${1:-"thesayyn/go-containerregistry"}

# per_page=1 to just miror the most recent release
(
  curl --silent \
    --header "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/${REPOSITORY}/releases?per_page=4 \
    | jq -f $SCRIPT_DIR/filter.jq
) > $RAW

FIXED=$(mktemp)
# Replace URLs with their hash
for tag in $(jq -r 'keys | .[]' < $RAW); do
  checksums="$(curl --silent --location https://github.com/${REPOSITORY}/releases/download/$tag/checksums.txt)"
  while read -r sha256 filename; do
    integrity="sha256-$(echo $sha256 | xxd -r -p | base64)"
    jq ".[\"$tag\"] |= with_entries(.value = (if .value == \"$filename\" then \"$integrity\" else .value end))" < $RAW > $FIXED
    mv $FIXED $RAW
  done <<< "$checksums"
done

echo -n "CRANE_VERSIONS = "
cat $RAW

echo ""
echo "Copy the version info into oci/private/versions.bzl"
