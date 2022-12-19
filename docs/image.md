<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation details for image rule

<a id="#oci_image"></a>

## oci_image

<pre>
oci_image(<a href="#oci_image-name">name</a>, <a href="#oci_image-architecture">architecture</a>, <a href="#oci_image-base">base</a>, <a href="#oci_image-cmd">cmd</a>, <a href="#oci_image-entrypoint">entrypoint</a>, <a href="#oci_image-env">env</a>, <a href="#oci_image-os">os</a>, <a href="#oci_image-tars">tars</a>, <a href="#oci_image-user">user</a>, <a href="#oci_image-variant">variant</a>, <a href="#oci_image-workdir">workdir</a>)
</pre>

Build an OCI compatible container image.

It takes number of tar files as layers to create image filesystem. 
For incrementality, use more fine grained tar files to build up the filesystem.

```starlark
oci_image(
    tars = [
        "rootfs.tar",
        "appfs.tar",
        "libc6.tar",
        "passwd.tar,
    ]
)
```

To base an oci_image on another oci_image, the `base` attribute MAYBE used.

```starlark
oci_image(
    base = "//sys:base",
    tars = [
        "appfs.tar"
    ]
)
```

To combine `env` with environment variables from the `base`, bash style variable syntax MAYBE used. 

```starlark
oci_image(
    name = "base",
    env = {"PATH": "/usr/bin"}
)

oci_image(
    name = "app",
    base = ":base",
    env = {"PATH": "/usr/local/bin:$PATH"}
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_image-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_image-architecture"></a>architecture |  The CPU architecture which the binaries in this image are built to run on. eg: <code>arm64</code>, <code>arm</code>, <code>amd64</code>, <code>s390x</code>. See $GOARCH documentation for possible values: https://go.dev/doc/install/source#environment   | String | optional | "" |
| <a id="oci_image-base"></a>base |  Label to an oci_image target to use as the base.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="oci_image-cmd"></a>cmd |  Default arguments to the <code>entrypoint</code> of the container. These values act as defaults and may be replaced by any specified when creating a container.   | List of strings | optional | [] |
| <a id="oci_image-entrypoint"></a>entrypoint |  A list of arguments to use as the <code>command</code> to execute when the container starts. These values act as defaults and may be replaced by an entrypoint specified when creating a container.   | List of strings | optional | [] |
| <a id="oci_image-env"></a>env |  Default values to the environment variables of the container. These values act as defaults and are merged with any specified when creating a container. Entries replace the base environment variables if any of the entries has conflicting keys. To merge entries with keys specified in the base, <code>${KEY}</code> or <code>$KEY</code> syntax may be used.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="oci_image-os"></a>os |  The name of the operating system which the image is built to run on. eg: <code>linux</code>, <code>windows</code>. See $GOOS documentation for possible values: https://go.dev/doc/install/source#environment   | String | optional | "" |
| <a id="oci_image-tars"></a>tars |  List of tar files to add to the image as layers.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="oci_image-user"></a>user |  The <code>username</code> or <code>UID</code> which is a platform-specific structure that allows specific control over which user the process run as.  This acts as a default value to use when the value is not specified when creating a container.  For Linux based systems, all of the following are valid: <code>user</code>, <code>uid</code>, <code>user:group</code>, <code>uid:gid</code>, <code>uid:group</code>, <code>user:gid</code>.  If <code>group/gid</code> is not specified, the default group and supplementary groups of the given <code>user/uid</code> in <code>/etc/passwd</code> from the container are applied.   | String | optional | "" |
| <a id="oci_image-variant"></a>variant |  The variant of the specified CPU architecture. eg: <code>v6</code>, <code>v7</code>, <code>v8</code>. See: https://github.com/opencontainers/image-spec/blob/main/image-index.md#platform-variants for more.   | String | optional | "" |
| <a id="oci_image-workdir"></a>workdir |  Sets the current working directory of the <code>entrypoint</code> process in the container. This value acts as a default and may be replaced by a working directory specified when creating a container.   | String | optional | "" |


