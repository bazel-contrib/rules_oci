# oci_tarball with an incremental loader

Currently rules_oci doesn't have incremental loader for docker tarball for reasons specified in https://github.com/bazel-contrib/rules_oci/issues/454#issuecomment-1875920593

This an example demonstrating a hack different than the rules_docker and https://github.com/google/go-containerregistry/pull/559

- Spawns a local registry on Docker
- Uses crane to push the tarball efficiently to the local registry. (loses the repo_tags)
- Pulls the image from the local registry to Docker daemon.