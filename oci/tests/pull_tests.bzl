"Unit tests for oci_pull implementation"

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//oci/private:util.bzl", "util")

def _parse_image_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", None, None),
        util.parse_image("debian"),
    )
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", None, None),
        util.parse_image("docker.io/library/debian"),
    )
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", None, "latest"),
        util.parse_image("debian:latest"),
    )
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", "sha256:deadbeef", None),
        util.parse_image("debian@sha256:deadbeef"),
    )
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", None, None),
        util.parse_image("https://docker.io/library/debian"),
    )
    asserts.equals(
        env,
        ("http", "localhost:8080", "some/image", None, "stable"),
        util.parse_image("http://localhost:8080/some/image:stable"),
    )
    return unittest.end(env)

parse_image_test = unittest.make(_parse_image_test_impl)

def _windows_host(ctx):
    """Returns true if the host platform is windows.
    
    The typical approach using ctx.target_platform_has_constraint does not work for transitioned
    build targets. We need to know the host platform, not the target platform.
    """
    return ctx.configuration.host_path_separator == ";"

def _parse_www_authenticate_test_impl(ctx):
    env = unittest.begin(ctx)
    # TODO: enable on windows
    if not _windows_host(ctx):
        asserts.equals(
            env,
            {
                "Bearer": {"realm": "https://auth.docker.io/token", "service": "registry.docker.io", "scope": "repository:library/ubuntu:pull"},
                "Bearer2": {"realm": "https://auth.docker.io/token", "service": "registry.docker.io", "scope": "repository:library/ubuntu:pull"},
            },
            util.parse_www_authenticate('''\
    Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/ubuntu:pull" 
    Bearer2 realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/ubuntu:pull"
    '''),
        )
        asserts.equals(
            env,
            {"Bearer": {"realm": "https://auth.docker.io/token", "service": "registry.docker.io", "scope": "repository:library/ubuntu:pull"}},
            util.parse_www_authenticate('Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/ubuntu:pull"'),
        )
    return unittest.end(env)

parse_www_authenticate_test = unittest.make(_parse_www_authenticate_test_impl)
