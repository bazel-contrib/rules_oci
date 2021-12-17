#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
RAW=$(mktemp)

(
  curl --silent \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/thesayyn/go-containerregistry/releases?per_page=20 \
    | jq -f $SCRIPT_DIR/filter.jq
) > $RAW

FIXED=$(mktemp)
# Replace URLs with their hash
for tag in $(jq -r 'keys | .[]' < $RAW); do

  checksums=$(curl --silent -L https://github.com/thesayyn/go-containerregistry/releases/download/$tag/checksums.txt)
  while read -r sha256 filename; do
    integrity="sha256-$(echo $sha256 | xxd -r -p | base64)"
    #escaped=$(printf '%s\n' "$integrity" | sed -e 's/[\/&]/\\&/g')
    # sed -i "s/$filename/$escaped/" $RAW
    jq ".[\"$tag\"] |= with_entries(.value = (if .value == \"$filename\" then \"$integrity\" else .value end))" < $RAW > $FIXED
    mv $FIXED $RAW
  done <<< "$checksums"
done

echo '"Mirror of release info"'
echo -n "TOOL_VERSIONS = "
cat $RAW
