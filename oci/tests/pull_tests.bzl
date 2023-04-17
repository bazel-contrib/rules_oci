"Unit tests for oci_pull implementation"

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//oci/private:pull.bzl", "lib")

def _parse_image_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", None, None),
        lib.parse_image("debian"),
    )
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", None, None),
        lib.parse_image("docker.io/library/debian"),
    )
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", None, "latest"),
        lib.parse_image("debian:latest"),
    )
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", "sha256:deadbeef", None),
        lib.parse_image("debian@sha256:deadbeef"),
    )
    asserts.equals(
        env,
        ("https", "index.docker.io", "library/debian", None, None),
        lib.parse_image("https://docker.io/library/debian"),
    )
    asserts.equals(
        env,
        ("http", "localhost:8080", "some/image", None, "stable"),
        lib.parse_image("http://localhost:8080/some/image:stable"),
    )
    return unittest.end(env)

parse_image_test = unittest.make(_parse_image_test_impl)
