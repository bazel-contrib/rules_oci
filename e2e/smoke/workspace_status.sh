#!/bin/bash

# This serves as an example of how the workspace_status.sh script can be used to
# stamp the `created` attribute of an image.
BUILD_TIMESTAMP=${BUILD_TIMESTAMP:-$(date +%s)} # macOS specific
BUILD_ISO8601=$(date -u -r "$BUILD_TIMESTAMP" +"%Y-%m-%dT%H:%M:%SZ")
echo "BUILD_ISO8601 $BUILD_ISO8601"
