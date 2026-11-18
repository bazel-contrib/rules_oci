#!/usr/bin/env bash
# Runs the oci_image_index script on two images that share a layer blob, with a
# coreutils wrapper whose `cp` keeps a read-only source read-only, as cp does on
# Windows. Copying the shared blob a second time then fails.
set -o pipefail -o errexit -o nounset

readonly TEMPLATE="$1"
readonly JQ="$PWD/${2/external\//../}"
readonly COREUTILS="$PWD/${3/external\//../}"
shift 3

# This relies on Bazel outputs being read-only and the test not running as root:
# with writable outputs the copy stays writable, and root can overwrite a
# read-only file anyway, so the test would pass even without the fix.
readonly SHIM="$TEST_TMPDIR/coreutils"
cat >"$SHIM" <<SHIM
#!/usr/bin/env bash
set -o errexit
"$COREUTILS" "\$@"
if [[ "\$1" == cp && ! -w "\${@: -2:1}" ]]; then
    chmod a-w "\${@: -1}"
fi
SHIM
chmod +x "$SHIM"

readonly SCRIPT="$TEST_TMPDIR/image_index.sh"
sed -e "s#{{jq_path}}#$JQ#" -e "s#{{coreutils_path}}#$SHIM#" "$TEMPLATE" >"$SCRIPT"
chmod +x "$SCRIPT"

readonly OUTPUT="$TEST_TMPDIR/index"
args=("--output=$OUTPUT")
for image in "$@"; do
    args+=("--image=$image")
    for blob in "$image"/blobs/sha256/*; do
        args+=("--blob=blobs/sha256/${blob##*/}")
    done
done

"$SCRIPT" "${args[@]}"

digest="$("$JQ" -r '.manifests[0].digest | sub(":"; "/")' "$OUTPUT/index.json")"
count="$("$JQ" '.manifests | length' "$OUTPUT/blobs/$digest")"
if [[ "$count" != 2 ]]; then
    echo "expected 2 manifests in the index, got $count" >&2
    exit 1
fi
