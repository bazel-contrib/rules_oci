"Public API re-exports"

load("//oci/private:container.bzl", _container_lib = "container")

_container = rule(
    implementation = _container_lib.implementation,
    attrs = _container_lib.attrs,
    toolchains = _container_lib.toolchains,
)

def container(name, base, cmd = [], entrypoint = [], labels = [], layers = [], tag = None):
    """Create an OCI container

    See documentation about the OCI format: https://github.com/opencontainers/image-spec/blob/main/config.md#properties

    Args:
        name: A name for the target.
        base: Name of base image. eg node:12
        cmd: Default arguments to the entrypoint of the container.
        entrypoint: A list of arguments to use as the command to execute when the container starts.
        layers: TODO
        labels: TODO
        tag: TODO
    """
    _container(
        name = name,
        base = base,
        cmd = cmd,
        entrypoint = entrypoint,
        labels = labels,
        layers = layers,
        tag = tag,
    )
