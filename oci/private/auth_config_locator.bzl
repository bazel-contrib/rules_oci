"repository rule that locates the .docker/config.json or containers/auth.json file."

def _file_exists(rctx, path):
    result = rctx.execute(["stat", path])
    return result.return_code == 0

# Path of the auth file is determined by the order described here;
# https://github.com/google/go-containerregistry/tree/main/pkg/authn#tldr-for-consumers-of-this-package
def _get_auth_file_path(rctx):
    # this is the standard path where registry credentials are stored
    # https://docs.docker.com/engine/reference/commandline/cli/#configuration-files
    DOCKER_CONFIG = "{}/.docker".format(rctx.os.environ["HOME"])

    # set DOCKER_CONFIG to $DOCKER_CONFIG env if present
    if "DOCKER_CONFIG" in rctx.os.environ:
        DOCKER_CONFIG = rctx.os.environ["DOCKER_CONFIG"]

    config_path = "{}/config.json".format(DOCKER_CONFIG)

    if _file_exists(rctx, config_path):
        return config_path

    # https://docs.podman.io/en/latest/markdown/podman-login.1.html#authfile-path
    XDG_RUNTIME_DIR = "{}/.config".format(rctx.os.environ["HOME"])

    # set XDG_RUNTIME_DIR to $XDG_RUNTIME_DIR env if present
    if "XDG_RUNTIME_DIR" in rctx.os.environ:
        XDG_RUNTIME_DIR = rctx.os.environ["XDG_RUNTIME_DIR"]

    config_path = "{}/containers/auth.json".format(XDG_RUNTIME_DIR)

    # podman support overriding the standard path for the auth file via this special environment variable.
    # https://docs.podman.io/en/latest/markdown/podman-login.1.html#authfile-path
    if "REGISTRY_AUTH_FILE" in rctx.os.environ:
        config_path = rctx.os.environ["REGISTRY_AUTH_FILE"]

    if _file_exists(rctx, config_path):
        return config_path

    return None

def _oci_auth_config_locator_impl(rctx):
    config_path = _get_auth_file_path(rctx)
    if not config_path:
        # rctx.execute is cached between bazel invocations. prefer it over print
        # to avoid spamming terminal. Also rctx.execute has a nicer output.
        rctx.execute([
            "echo",
            "WARNING: Could not find the `$HOME/.docker/config.json` and `$XDG_RUNTIME_DIR/containers/auth.json` file.",
            "\n",
            "Running one of `podman login`, `docker login`, `crane login` may help.",
        ], quiet = False)
        rctx.file("config.json", "{}")
    else:
        rctx.symlink(config_path, "config.json")

    rctx.file("BUILD.bazel", """exports_files(["config.json"])""")

oci_auth_config_locator = repository_rule(
    implementation = _oci_auth_config_locator_impl,
    environ = [
        # These environment variables allow standard authorization file path to overridden with something else therefore
        # needs to be tracked as part of the repository cache key so that bazel refetches the repository when any of the variables change.
        # while docker uses DOCKER_CONFIG for the override, podman uses REGISTRY_AUTH_FILE environment variable, and
        # since rules_oci has no preference over the runtime, it has to support both.
        # See: https://github.com/google/go-containerregistry/tree/main/pkg/authn#tldr-for-consumers-of-this-package for go implementation.
        "DOCKER_CONFIG",
        "REGISTRY_AUTH_FILE",
    ],
)
