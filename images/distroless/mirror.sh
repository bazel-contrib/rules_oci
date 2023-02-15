#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# see https://github.com/GoogleContainerTools/distroless#what-images-are-available
for img in static base base-nossl cc python3 java-base java11 java17 nodejs14 nodejs16 nodejs18
do
    # Ask the registry for the latest manifest list for this image
    curl --silent https://gcr.io/v2/distroless/$img/manifests/latest >> $SCRIPTPATH/$img.json

    # Stamp the output file with provenance info
    echo "\"Fetched from https://gcr.io/v2/distroless/$img/manifests/latest on $(date)\"" > $SCRIPTPATH/$img.bzl

    # Insert the name of the image, which is otherwise lost.
    # We'll need this in the repository rule that reads the data.
    # Note, we could instead make some wrapper .bzl file that contains a map of image name to
    # manifest content.
    jq ".image=\"gcr.io/distroless/$img\"" < $SCRIPTPATH/$img.json >> $SCRIPTPATH/$img.bzl

    # Convert JSON to starlark
    sed -i '.bak' '2s/^/MF = /g' $SCRIPTPATH/$img.bzl

    # Cleanup temp files
    rm $SCRIPTPATH/$img.{json,bzl.bak}
done
