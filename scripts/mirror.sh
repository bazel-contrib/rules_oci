#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo '"Mirror of release info"'
$SCRIPT_DIR/mirror_crane.sh
echo ""
$SCRIPT_DIR/mirror_umoci.sh