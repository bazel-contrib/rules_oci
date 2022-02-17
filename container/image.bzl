"Public API re-exports"

load("//container/private:image.bzl", _image_lib = "image")

_container_image = rule(
    implementation = _image_lib.implementation,
    attrs = _image_lib.attrs,
    toolchains = _image_lib.toolchains
)


def container_image(name, base, cmd = [], entrypoint = [], labels = [], layers = [], tag = None):
    """Create a OCI container image

    See documentation about the OCI format: https://github.com/opencontainers/image-spec

    Args:
        name: A name for the target.
        base: Name of base image. eg node:12
        cmd: Default arguments to the entrypoint of the container.
        entrypoint: A list of arguments to use as the command to execute when the container starts.
        layers: TODO
        labels: TODO
        tag: TODO
    """
    _container_image(
        name =  name,
        base = base,
        cmd = cmd,
        entrypoint = entrypoint,
        labels = labels,
        layers = layers,
        tag = tag
    )