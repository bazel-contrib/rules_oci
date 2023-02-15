# Image manifest lists

These are fetched from the remote registry using mirror.sh.

This allows a repository macro oci_pull to read the manifest list and know what platforms it contains,
then create an external repository for each platform.
