"repository rule that locates the .docker/config.json or containers/auth.json file."

load("@aspect_bazel_lib//lib:base64.bzl", "base64")
load("@aspect_bazel_lib//lib:repo_utils.bzl", "repo_utils")
load(":util.bzl", "util")

_default_www_auth = [
    "index.docker.io",
    "public.ecr.aws",
    "ghcr.io",
    "cgr.dev",
    ".azurecr.io",
    "registry.gitlab.com",
    ".app.snowflake.com",
    "docker.elastic.co",
    "quay.io",
    "nvcr.io",
]

def _crane_binary(rctx, toolchain):
    arch = rctx.os.arch
    os = rctx.os.name
    if os.startswith("mac os"):
        os = "darwin"
    elif os.find("windows") != -1:
        os = "windows"
    else:
        os = "linux"

    if arch in ["arm", "armv7l"]:
        arch = "armv6"
    elif arch in ["aarch64", "arm64"]:
        arch = "arm64"
    elif arch in ["x86_64"]:
        arch = "i386"
    elif arch in ["x64", "amd64"]:
        arch = "amd64"

    suffix = "" if os != "windows" else ".exe"

    return "{}_crane_{}_{}//:crane{}".format(toolchain, os, arch, suffix)

def _strip_host(url):
    # TODO: a principled way of doing this
    return url.replace("http://", "").replace("https://", "").replace("/v1/", "")

# Path of the auth file is determined by the order described here;
# https://github.com/google/go-containerregistry/tree/main/pkg/authn#tldr-for-consumers-of-this-package
def _get_auth_file_path(rctx):
    HOME = repo_utils.get_env_var(rctx, "HOME", "ERR_NO_HOME_SET")

    # this is the standard path where registry credentials are stored
    # https://docs.docker.com/engine/reference/commandline/cli/#configuration-files
    DOCKER_CONFIG = "{}/.docker".format(HOME)

    # set DOCKER_CONFIG to $DOCKER_CONFIG env if present
    if "DOCKER_CONFIG" in rctx.os.environ:
        DOCKER_CONFIG = rctx.os.environ["DOCKER_CONFIG"]

    config_path = "{}/config.json".format(DOCKER_CONFIG)

    if util.file_exists(rctx, config_path):
        return config_path

    # https://docs.podman.io/en/latest/markdown/podman-login.1.html#authfile-path
    XDG_RUNTIME_DIR = "{}/.config".format(HOME)

    # set XDG_RUNTIME_DIR to $XDG_RUNTIME_DIR env if present
    if "XDG_RUNTIME_DIR" in rctx.os.environ:
        XDG_RUNTIME_DIR = rctx.os.environ["XDG_RUNTIME_DIR"]

    config_path = "{}/containers/auth.json".format(XDG_RUNTIME_DIR)

    # podman support overriding the standard path for the auth file via this special environment variable.
    # https://docs.podman.io/en/latest/markdown/podman-login.1.html#authfile-path
    if "REGISTRY_AUTH_FILE" in rctx.os.environ:
        config_path = rctx.os.environ["REGISTRY_AUTH_FILE"]

    if util.file_exists(rctx, config_path):
        return config_path

    return None

def _fetch_auth_via_creds_helper(rctx, raw_host, helper_name):
    executable = "{}.sh".format(helper_name)
    rctx.file(
        executable,
        content = """\
#!/usr/bin/env bash
exec "docker-credential-{}" get <<< "$1"
        """.format(helper_name),
    )
    result = rctx.execute([rctx.path(executable), raw_host])
    if result.return_code:
        fail("credential helper failed: \nSTDOUT:\n{}\nSTDERR:\n{}".format(result.stdout, result.stderr))

    response = json.decode(result.stdout)

    if response["Username"] == "<token>":
        fail("Identity tokens are not supported at the moment. See: https://github.com/bazel-contrib/rules_oci/issues/129")

    return {
        "type": "basic",
        "login": response["Username"],
        "password": response["Secret"],
    }

def _get_auth(rctx, state, registry):
    # if we have a cached auth for this registry then just return it.
    # this will prevent repetitive calls to external cred helper binaries.
    if registry in state["auth"]:
        return state["auth"][registry]

    pattern = {}
    config = state["config"]

    # first look into per registry credHelpers if it exists
    if "credHelpers" in config:
        for host_raw in config["credHelpers"]:
            host = _strip_host(host_raw)
            if host == registry:
                helper_val = config["credHelpers"][host_raw]
                pattern = _fetch_auth_via_creds_helper(rctx, host_raw, helper_val)

    # if no match for per registry credential helper for the host then look into auths dictionary
    if "auths" in config and len(pattern.keys()) == 0:
        for host_raw in config["auths"]:
            host = _strip_host(host_raw)
            if host == registry:
                auth_val = config["auths"][host_raw]

                if len(auth_val.keys()) == 0:
                    # zero keys indicates that credentials are stored in credsStore helper.
                    pattern = _fetch_auth_via_creds_helper(rctx, host_raw, config["credsStore"])

                elif "auth" in auth_val:
                    # base64 encoded plaintext username and password
                    raw_auth = auth_val["auth"]
                    login, sep, password = base64.decode(raw_auth).partition(":")
                    if not sep:
                        fail("auth string must be in form username:password")
                    pattern = {
                        "type": "basic",
                        "login": login,
                        "password": password,
                    }

                elif "username" in auth_val and "password" in auth_val:
                    # plain text username and password
                    pattern = {
                        "type": "basic",
                        "login": auth_val["username"],
                        "password": auth_val["password"],
                    }

    # cache the result so that we don't do this again unnecessarily.
    state["auth"][registry] = pattern

    return pattern

def _get_token(rctx, state, registry, repository, www_authenticate, toolchain):
    pattern = _get_auth(rctx, state, registry)
    basic_pattern = {}
    if pattern.get("type") == "basic":
        basic_pattern = pattern
    elif pattern:
        return pattern

    if not www_authenticate:
        for registry_pattern in _default_www_auth:
            if (registry == registry_pattern) or registry.endswith(registry_pattern):
                www_authenticate = True
                break
    if not www_authenticate:
        return pattern

    crane = "@{}".format(_crane_binary(rctx, toolchain)) if toolchain else "@@{}~oci~{}".format(Label(":authn.bzl").workspace_name or "_main", _crane_binary(rctx, "oci"))
    image = "{}/{}".format(registry, repository)
    result = rctx.execute([Label(crane), "auth", "token", image])
    if result.return_code != 0:
        if result.stderr.startswith('Error: challenge scheme ""'):
            if basic_pattern:
                # not bearer but found auth, determine to use basic auth
                return basic_pattern

            # no authorization required, conflict with whitelist config
            util.warning("registry does not require authentication: {}".format(registry))
            return {}
        fail("failed to fetch token from registry: {}".format(result.stderr))
    auth = json.decode(result.stdout)
    token = auth.get("access_token", "") or auth.get("token", "")
    if token == "":
        fail("could not find token in neither field 'token' nor 'access_token' in the response from the registry")
    pattern = {
        "type": "pattern",
        "pattern": "Bearer <password>",
        "password": token,
    }

    # put the token into cache so that we don't do the token exchange again.
    state["token"][image] = pattern
    return pattern

NO_CONFIG_FOUND_ERROR = """\
Could not find the `$HOME/.docker/config.json` and `$XDG_RUNTIME_DIR/containers/auth.json` file

Running one of `podman login`, `docker login`, `crane login` may help.
"""

def _explain(state):
    if not state["config"]:
        return NO_CONFIG_FOUND_ERROR
    return None

def _new_auth(rctx, www_authenticate, toolchain, config_path = None):
    if not config_path:
        config_path = _get_auth_file_path(rctx)
    config = {}
    if config_path:
        config = json.decode(rctx.read(config_path))
    state = {
        "config": config,
        "auth": {},
        "token": {},
    }
    return struct(
        get_token = lambda reg, repo: _get_token(rctx, state, reg, repo, www_authenticate, toolchain),
        explain = lambda: _explain(state),
    )

authn = struct(
    new = _new_auth,
    ENVIRON = [
        "DOCKER_CONFIG",
        "REGISTRY_AUTH_FILE",
        "XDG_RUNTIME_DIR",
        "HOME",
    ],
)
