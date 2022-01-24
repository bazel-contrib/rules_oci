# Desing


## Why not rules_docker
We have reasons not to use rules_docker. While some of are performance related, others are related to its complexity. for the sake of those who does not know 
how rules_docker work, i will keep it simple. 

- it is huge in terms of written lines which makes it handle to maintain and understand if you are not familiar with it already.
- it has 5 years of accumulated complexity. this is heavy and makes it even harder to add new features.
- it supports both OCI and Docker v2 image format which sounds good but it's not. see: https://github.com/bazelbuild/rules_docker/issues/1885
- it uses its tooling to build container layers and manifests. this is not easy thing to get right and keep in line with the up-to-date image spec.

## Why not just fix rules_docker
It is not that easy to fix a project with this amount of accumulated complexity. You can't really predict what you are gonna break when you change a particular code. 
Given that enormous thought went into rules_docker, one can't simply understand how it behaves vs how it supposed to behave. Basically, it is just a black box.


## Why it is a good time to move away from docker v2 images
we can all agree that docker revolutionized the container technology and changed the way we deploy. but this does not mean that we have to stick with it. there are other 
container runtimes as well, such as cri-o, containerd (extracted from dockerd), youki which implements oci-runtime spec (which in turn targets oci-image-spec) rather than docker v2 image spec. 

docker v2 spec which preceded docker v1 is the widely used container format out there. One downside is that they still inherits some properties of old dockerd such as HEALTHCHECK, RESOURCE LIMITS, but these properties not easily portable.

open container initiative has started https://github.com/opencontainers/image-spec standardize how container image should be built. docker v2 images almost identical to oci counterparts except that they use different media types and contains some docker specific configuration properties. but nevertheless we want to stick with OCI format to avoid maintaining things that are specific to docker. for instance: https://github.com/bazelbuild/rules_docker/pull/1742

the OCI image-spec format has been widely adopted by container runtimes and supported by all major distribution registries. so there is not point in supporting something that is preceded by OCI image-spec. Also, this makes our jobs a lot easier since we know what features to built and conform.

Blog posts and docs to read:
https://docs.docker.com/registry/spec/manifest-v2-2/
https://kubernetes.io/blog/2020/12/02/dont-panic-kubernetes-and-docker/

## What we do different than rules_docker
From users perspective, not much if we are being honest. In fact users gonna be pissed off because we won't have 100% percent feature parity with rules_docker but this is for the best. we will drop anything that is docker specific. we won't have rules such as `container_run_and_extract` due to lack of a running runtime
deamon available to us.

Instead of maintaining programs that builds the images ourselves, we will always rely on existing tools such as `crane` or `umoci`, `skopeo` whenever possible. these tools are great candidate for usage with bazel since they directly work with in-disk CAS store which gives us great ability to build image without needing a running runtime deamon or remote registries. 

These tools will give us the ability to be more inline with the container ecosystem because they are maintained by gifted people who also drive the image spec and container industry. On the other hand, with the time spared from not having to maintain these tools by ourselves, we could give back to these great tools.

Unlike rules_docker, we rely on pkg_tar to build layers. This also another thing that we different from rules_docker. we make tar files first class citizen in rules_container. this gives us great flexibility as we know so little about your layers. your layers could be an output of a genrule that invokes `rkt` or `docker` and captures a layer or could be a rule fetches files over the network and creates a tar file. you are limited by your imagination.

We want to make layering in rules_container more incremental and fine-grained depending on the language specific image rule. the idea of putting every workspace in the runfiles into their own layer could be a good start. we already have a helper macro `expand_runfiles` that puts runfiles into its own layer but we want to spread them across individual layers.

To ease layer manipulation operations we are going to provide helper macros like `whiteout("path/to/file/to/remove")` `symlink("/from/", "/to")` which in turn calls `pkg_tar` to generate a layer which contains these entries. these instructions are applied when the image is extracted by the runtime.

## How about docker hub, can i still use docker images as the base image
The reality of docker v2 images being the widely distributed image format, we can't simply drop it. we still have to have an interopability with docker v2 images. so in order to do that we will use `container_pull` rule to automatically convert docker images to oci images so that you can still use them. `skopeo` is a great tool that is capable of converting images between formats. beware that anything that is docker specific will be dropped in the conversion process.


## Multi platform images

## Performance

There is one thing that rules_container does better than rules_docker which affects cold build time greatly. that is rules_container uses `repository_ctx.download` to download blobs from the registry. this helps bazel beware of the remote blobs and their hashes. when blobs go through bazels downloader, they are automatically cached and stored in remote/disk cache. which makes subsequent builds order of magnitude faster. external repositories could get evicted easily for a number of reasons. an example would be changing the base image from `node:12` to `node:13`. when this happens the repository cache gets evicted and bazel invokes fetchs the external repository again. but since we have downloaded some of the blobs previously, bazel won't go the trouble downloading them again. it will only download what has been changed between `node:12` and `node:13`.

this also helps us with building mutli-arch images as well. imagine building a nodejs image with support for linux/amd64, linux/arm64;
they could potentially share a blob with each other. this is less likely to happen for non-jvm languages because their binary bytes differ per platform. but this is likely to happen for jvm languages. for instance a base image that invokes a jar via java jvm; in this case only jvm will be downloaded for each platform but the tool will be shared because it is platform independent.

thanks to OCI format, we can manipulate the base image without ever extracting the base layers. when rules_container told to put a layer into the base image, it just appends the new layer into blobs directory and updates the manifest/config.

```
├── blobs
│   └── sha256
│       ├── 32fb5f0ba6f2fefab5609b466212d425b013f5a2a7919ad0675249bd86d109bc
│       ├── 4e006612027a38a3b68ccfa956010194b6c0cf3031821c47c14b14d34cc23ec6
│       ├── 6bf4ffb24b8e68c48dea37b1e0d3a818ded4842150fa9c3a2a100c4efbf0c88b
│       ├── 83585c627da28ca48edb5fc008cc4af1e9c083e21069ac941e509b20f5c4d4d5 <- updated manifest includes the new layer
│       ├── 841dd868500b6685b6cda93c97ea76e817b427d7a10bf73e9d03356fac199ffd <- updated config
│       ├── 94a23d3cb5be24659b25f17537307e7f568d665244f6a383c1c6e51e31080749
│       ├── aa9c5b49b9db3dd2553e8ae6c2081b77274ec0a8b1f9903b0e5ac83900642098
│       ├── ac9d381bd1e98fa8759f80ff42db63c8fce4ac9407b2e7c8e0f031ed9f96432b
│       ├── d203f5bdf7b84ba8fa76e56e1357a1457e69cc064ce0f2a68d49ec6b810c2b9d
│       ├── d4bb9078a4a2954fb77553c7f66912068fb62ff7cf431160389ebd36fab5c7ad
│       └── ea9c843455b257dc04302139b66098ebe563847f4f1ea3d75e3242012f5db8f7 <- your new layer
├── index.json
└── oci-layout
```

when you push the image, we will only push those layers that are not already present in the remote registry. which would consist of these three layers we have built earlier.