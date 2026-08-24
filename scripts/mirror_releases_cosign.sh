#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

JQ_FILTER=\
'map(select(.draft == false and .prerelease == false and (.tag_name | contains("-rc") | not)))
| [map(select(.tag_name | startswith("v3."))),
   map(select(.tag_name | startswith("v2.")))]
| flatten
| map(
  {
    "key": .tag_name,
    "value": .assets
        | map(select((.name | contains("cosign-")) and (.name | contains(".") | not) and (.name | contains("key") | not) ))
        | map({
            "key": .name,
            "value": .browser_download_url
        })
        | from_entries
  }
) | from_entries'

REPOSITORY=${1:-"sigstore/cosign"}
OUTPUT_FILE=${2:-"cosign/private/versions.bzl"}

VERSIONS=$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$REPOSITORY/releases?per_page=100" | jq "$JQ_FILTER")

# Replace URLs with their hash
for TAG in $(jq -r 'keys_unsorted | .[]' <<< "$VERSIONS"); do
  CHECKSUMS="$(curl -fsSL "https://github.com/$REPOSITORY/releases/download/$TAG/cosign_checksums.txt")"
  >&2 echo -n "$TAG "
  while read -r SHA256 FILENAME; do
    case "${FILENAME:-}" in
      cosign-*.* | *key* | "") continue ;;
      cosign-*) ;;
      *) continue ;;
    esac
    INTEGRITY="sha256-$(echo "$SHA256" | xxd -r -p | base64)"
    VERSIONS=$(jq --arg tag "$TAG" --arg filename "$FILENAME" --arg sha256 "$INTEGRITY" 'if (.[$tag] | has($filename)) then .[$tag][$filename] = $sha256 else . end' <<< "$VERSIONS")
    >&2 echo -n "."
  done <<< "$CHECKSUMS"
  >&2 echo ""
done

FORMATTED=$(
  jq --indent 4 'with_entries(.value |= with_entries(.key |= ltrimstr("cosign-")))' <<< "$VERSIONS" \
    | sed -E 's/^([[:space:]]+.*[^,{])$/\1,/'
)

cat << EOF > "$OUTPUT_FILE"
"Mirrored versions/integrity hashes of cosign binaries"

COSIGN_VERSIONS = $FORMATTED
EOF

echo "Successfully updated $OUTPUT_FILE"
