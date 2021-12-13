map(
    {
        "key": .tag_name,
        "value": .assets
            | map(select(.name | contains("tar.gz")))
            | map({
                # convert go-containerregistry_Darwin_arm64.tar.gz -> android-arm64
                "key": .name | split(".")[0] | ltrimstr("go-containerregistry_") | ascii_downcase,
                # We'll replace the url with the shasum of that referenced file in a later processing step
                "value": .browser_download_url | split("/")[-1]
            })
            | from_entries
    }
) | from_entries
