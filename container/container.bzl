load("//container/private:container.bzl", _container_lib = "container")

_container = rule(
    implementation = _container_lib.implementation,
    attrs = _container_lib.attrs,
    toolchains = _container_lib.toolchains
)


def container(name, **kwargs):
    _container(
        name =  name,
        **kwargs
    )