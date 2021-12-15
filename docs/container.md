<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API re-exports

<a id="#container"></a>

## container

<pre>
container(<a href="#container-name">name</a>, <a href="#container-base">base</a>, <a href="#container-cmd">cmd</a>, <a href="#container-entrypoint">entrypoint</a>, <a href="#container-labels">labels</a>, <a href="#container-layers">layers</a>, <a href="#container-tag">tag</a>)
</pre>

Create an OCI container

See documentation about the OCI format: https://github.com/opencontainers/image-spec/blob/main/config.md#properties


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="container-name"></a>name |  A name for the target.   |  none |
| <a id="container-base"></a>base |  Name of base image. eg node:12   |  none |
| <a id="container-cmd"></a>cmd |  Default arguments to the entrypoint of the container.   |  <code>[]</code> |
| <a id="container-entrypoint"></a>entrypoint |  A list of arguments to use as the command to execute when the container starts.   |  <code>[]</code> |
| <a id="container-labels"></a>labels |  TODO   |  <code>[]</code> |
| <a id="container-layers"></a>layers |  TODO   |  <code>[]</code> |
| <a id="container-tag"></a>tag |  TODO   |  <code>None</code> |


