# Convert a docker tarball as a base image

In some cases, your legacy setup doesn't fetch a base image from a remote registry, instead you've produced your base image in a script and check or fetch the tarball.

To generate the `image.tar` file, first run `create_base_image.bash`. Then build the example normally.
