bazel build //example/py:image
rm -f py_bundle.tar
skopeo copy oci:bazel-bin/example/py/bundle_app docker-archive:py_bundle.tar --additional-tag pyimage:latest
podman load -i py_bundle.tar
podman run --rm docker.io/library/pyimage:latest