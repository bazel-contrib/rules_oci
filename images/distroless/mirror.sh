#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# see https://github.com/GoogleContainerTools/distroless#what-images-are-available
for img in static base base-nossl cc python3 java-base java11 java17 nodejs14 nodejs16 nodejs18
do
    curl --silent https://gcr.io/v2/distroless/$img/manifests/latest >> $SCRIPTPATH/$img.json

    echo "\"Fetched from https://gcr.io/v2/distroless/$img/manifests/latest on $(date)\"" > $SCRIPTPATH/$img.bzl
    jq ".image=\"gcr.io/distroless/$img\"" < $SCRIPTPATH/$img.json >> $SCRIPTPATH/$img.bzl
    sed -i '.bak' '2s/^/MF = /g' $SCRIPTPATH/$img.bzl
    rm $SCRIPTPATH/$img.{json,bzl.bak}
done
