# Convert a docker tarball as a base image

In some cases, your legacy setup doesn't fetch a base image from a remote registry, instead you've produced your base image in a script and check or fetch the tarball.

To generate it run;

```bash
docker buildx build e2e/convert_docker_tarball --output=type=docker,dest=e2e/convert_docker_tarball/image.tar --builder=cool_swirles -t test:latest
```
