<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API re-exports

<a id="#container_image"></a>

## container_image

<pre>
container_image(<a href="#container_image-name">name</a>, <a href="#container_image-base">base</a>, <a href="#container_image-cmd">cmd</a>, <a href="#container_image-entrypoint">entrypoint</a>, <a href="#container_image-labels">labels</a>, <a href="#container_image-layers">layers</a>, <a href="#container_image-tag">tag</a>)
</pre>

Create a OCI container image

See documentation about the OCI format: https://github.com/opencontainers/image-spec


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="container_image-name"></a>name |  A name for the target.   |  none |
| <a id="container_image-base"></a>base |  Name of base image. eg node:12   |  none |
| <a id="container_image-cmd"></a>cmd |  Default arguments to the entrypoint of the container.   |  <code>[]</code> |
| <a id="container_image-entrypoint"></a>entrypoint |  A list of arguments to use as the command to execute when the container starts.   |  <code>[]</code> |
| <a id="container_image-labels"></a>labels |  TODO   |  <code>[]</code> |
| <a id="container_image-layers"></a>layers |  TODO   |  <code>[]</code> |
| <a id="container_image-tag"></a>tag |  TODO   |  <code>None</code> |


