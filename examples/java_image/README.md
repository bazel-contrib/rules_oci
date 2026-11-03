# Java application in an OCI container

This example shows how to package a Java application into an OCI container image.

A `java_binary` target provides an implicit `<name>_deploy.jar` output containing the application classes and all runtime dependencies bundled together.
This deploy jar is packaged into a tar layer using the `tar` rule from `tar.bzl`, and then added to a distroless base image (such as `gcr.io/distroless/java17`) with `oci_image`.

## Build and Load

Build and load the OCI image into Docker:

```shell
bazel run //examples/java_image:load
```

## Run

Run the container:

```shell
docker run --rm example/java:latest
```

## Test

Run tests:

```shell
bazel test //examples/java_image:all
```
