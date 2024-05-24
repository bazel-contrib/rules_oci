# Dockerfile + rules_oci

STOP before committing this atrocity. Here's some good reasons why you should not do what we have done here.

- Dockerfiles are fundamentally non-reproducible
- Reproducible builds are important for Bazel, Dockerfiles will lead to poor cache hits.
- `RUN` instruction is a perfect foot-gun for non-reprocubile builds, a simple command `RUN apt-get install curl` is non-hermetic by default.
- Building the same Dockerfile one month apart will yield different results.
- `FROM python:3.11.9-bullseye` is non-producible.

# Resources

https://reproducible-builds.org/
https://github.com/bazel-contrib/rules_oci/issues/35#issuecomment-1285954483
https://github.com/bazel-contrib/rules_oci/blob/main/docs/compare_dockerfile.md
https://github.com/moby/moby/issues/43124
https://medium.com/nttlabs/bit-for-bit-reproducible-builds-with-dockerfile-7cc2b9faed9f
