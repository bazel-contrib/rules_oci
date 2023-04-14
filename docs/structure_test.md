<!-- Generated with Stardoc: http://skydoc.bazel.build -->

test rule running structure_test against an oci_image.

<a id="#structure_test"></a>

## structure_test

<pre>
structure_test(<a href="#structure_test-name">name</a>, <a href="#structure_test-configs">configs</a>, <a href="#structure_test-driver">driver</a>, <a href="#structure_test-image">image</a>)
</pre>

Tests an oci_image by using [container-structure-test](https://github.com/GoogleContainerTools/container-structure-test).

By default, it relies on the container runtime already installed and running on the target.
By default, container-structure-test uses the socket available at /var/run/docker.sock. If the installation
creates the socket in a different path, use --test_env=DOCKER_HOST='unix://<path_to_sock>'.

To avoid putting this into the commandline or to instruct bazel to read it from terminal environment, 
simply drop `test --test_env=DOCKER_HOST` into the .bazelrc file.

Alternatively, use the `driver = "tar"` attribute to avoid the need for a container runtime, see
https://github.com/GoogleContainerTools/container-structure-test#running-file-tests-without-docker


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="structure_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="structure_test-configs"></a>configs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="structure_test-driver"></a>driver |  See https://github.com/GoogleContainerTools/container-structure-test#running-file-tests-without-docker   | String | optional | "docker" |
| <a id="structure_test-image"></a>image |  Label of an oci_image or oci_tarball target.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


