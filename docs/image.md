<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation details for container rule

<a id="#oci_image"></a>

## oci_image

<pre>
oci_image(<a href="#oci_image-name">name</a>, <a href="#oci_image-architecture">architecture</a>, <a href="#oci_image-base">base</a>, <a href="#oci_image-cmd">cmd</a>, <a href="#oci_image-entrypoint">entrypoint</a>, <a href="#oci_image-env">env</a>, <a href="#oci_image-os">os</a>, <a href="#oci_image-tars">tars</a>, <a href="#oci_image-user">user</a>, <a href="#oci_image-variant">variant</a>, <a href="#oci_image-workdir">workdir</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="oci_image-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="oci_image-architecture"></a>architecture |  The CPU architecture which the binaries in this image are built to run on.   | String | optional | "" |
| <a id="oci_image-base"></a>base |  TODO   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="oci_image-cmd"></a>cmd |  Default arguments to the entrypoint of the container. These values act as defaults and may be replaced by any specified when creating a container. If an Entrypoint value is not specified, then the first entry of the Cmd array SHOULD be interpreted as the executable to run.   | List of strings | optional | [] |
| <a id="oci_image-entrypoint"></a>entrypoint |  A list of arguments to use as the command to execute when the container starts. These values act as defaults and may be replaced by an entrypoint specified when creating a container.   | List of strings | optional | [] |
| <a id="oci_image-env"></a>env |  Default values to the environment variables of the container. These values act as defaults and are merged with any specified when creating a container. Entries replace the base environment variables if any of the entries has the same key. To merge entries with keys specified in the base, <code>${KEY}</code> or <code>$KEY</code> syntax may be used.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="oci_image-os"></a>os |  The name of the operating system which the image is built to run on.   | String | optional | "" |
| <a id="oci_image-tars"></a>tars |  List of tar files to add to the image as layers.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="oci_image-user"></a>user |  The username or UID which is a platform-specific structure that allows specific control over which user the process run as.  This acts as a default value to use when the value is not specified when creating a container.  For Linux based systems, all of the following are valid: user, uid, user:group, uid:gid, uid:group, user:gid.  If group/gid is not specified, the default group and supplementary groups of the given user/uid in /etc/passwd from the container are applied.   | String | optional | "" |
| <a id="oci_image-variant"></a>variant |  The variant of the specified CPU architecture.   | String | optional | "" |
| <a id="oci_image-workdir"></a>workdir |  Sets the current working directory of the entrypoint process in the container. This value acts as a default and may be replaced by a working directory specified when creating a container.   | String | optional | "" |


