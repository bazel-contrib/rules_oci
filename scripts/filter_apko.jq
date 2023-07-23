map(
    {
        "key": .tag_name,
        "value": .assets
            | map(select(.name | endswith("tar.gz")))
            | map({
                # convert apko_0.9.0_darwin_amd64.tar.gz -> darwin_amd64
                "key": .name | rtrimstr(".tar.gz") | split("_")[2:] | join("_"),
                # We'll replace the url with the shasum of that referenced file in a later processing step
                "value": .browser_download_url | split("/")[-1]
            })
            | from_entries
    }
) | from_entries
