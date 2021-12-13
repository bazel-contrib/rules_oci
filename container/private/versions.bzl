"""Mirror of release info

TODO: generate this file from GitHub API"""

# The integrity hashes can be computed with
# shasum -b -a 384 [downloaded file] | awk '{ print $1 }' | xxd -r -p | base64
TOOL_VERSIONS = {
    "7.0.1-rc1": {
        "darwin_arm64": "sha384-PMTl7GMV01JnwQ0yoURCuEVq+xUUlhayLzBFzqId8ebIBQ8g8aWnbiRX0e4xwdY1",
    },
}

# shasum -b -a 384 /Users/thesayyn/Downloads/go-containerregistry_Darwin_arm64.tar.gz | awk '{ print $1 }' | xxd -r -p | base64