# Using rules_oci with a custom registry implementation.

rules_oci uses `crane` to build container images which needs to talk to a registry in order to perform operations. for this reason rules_oci
runs a local registry instance with each action and performs operation within that registry. by default this is done by using
[zot](https://github.com/project-zot/zot) which only supports oci media types. this becomes a problem if other image formats are used such as `docker v2` and `docker v1`

This example demonstrates usage of an alternative registry implementation that allows both `oci` and `docker` specs, allowing seamless usage of docker images.
Since there's no prebuilt binaries available for go-containerregistrys registry implementation, it has to be built using rules_go and a small main script.

## references

https://github.com/project-zot/zot/issues/724
https://github.com/google/go-containerregistry/issues/1579
https://github.com/distribution/distribution/issues/3714
