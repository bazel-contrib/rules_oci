#!/usr/bin/env bash
set -o pipefail -o errexit -o nounset

readonly CRANE="/Users/thesayyn/Documents/go-containerregistry/main"

$CRANE blob calculate $2 > $3
