# OCI image with a Java application

Illustrates a replacement for https://github.com/bazelbuild/rules_docker#java_image

This uses a simple method of building the `*_deploy.jar` from Bazel's `java_binary` rule, which is
a single file that has all the third-party dependencies built-in and includes a self-contained
classpath and launcher for the application.

A more sophisticated approach would require something similar to how rules_docker assembles a
classpath and invokes `java -cp [classpath] [main_class]`
https://github.com/bazelbuild/rules_docker/blob/8e70c6bcb584a15a8fd061ea489b933c0ff344ca/java/image.bzl#L178-L212
so that the third-party dependencies could be placed in a separate layer from the application,
which would optimize for network traffic required to update just the application layer.
