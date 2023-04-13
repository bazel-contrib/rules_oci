"Public API"

load("//oci/private:tarball.bzl", _oci_tarball = "oci_tarball")
load("//oci/private:image.bzl", _oci_image = "oci_image")
load("//oci/private:image_index.bzl", _oci_image_index = "oci_image_index")
load("//oci/private:push.bzl", _oci_push = "oci_push")
load("//oci/private:structure_test.bzl", _structure_test = "structure_test")
load("@bazel_skylib//lib:types.bzl", "types")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

oci_tarball = _oci_tarball
oci_image = _oci_image
oci_image_index = _oci_image_index
oci_push_rule = _oci_push
structure_test = _structure_test

def oci_push(name, repotags = None, repository = None, repository_file = None, **kwargs):
    """Macro wrapper around [oci_push_rule](#oci_push_rule).

    Allows the tag attribute to be a list of strings in addition to a text file.
    Also allows repository as a string, which is written to a generated repository_file.

    Args:
        name: name of resulting oci_push_rule
        repository: the repository URL where the image is pushed e.g. `index.docker.io/myuser/myimage`
        repository_file: label of a file ending with '.txt' which contains a value for 'repository'
        repotags: a list of tags to apply to the image after pushing,
            or a label of a file containing tags one-per-line.
            See [stamped_tags](https://github.com/bazel-contrib/rules_oci/blob/main/examples/push/stamp_tags.bzl)
            as one example of a way to produce such a file.
        **kwargs: other named arguments to [oci_push_rule](#oci_push_rule).
    """
    if repository and repository_file:
        fail("Only one of repository or repository_file should be set")
    if not repository and not repository_file:
        fail("One of repository or repository_file must be set")

    if repository:
        repository_file = "_{}_write_repository".format(name)
        write_file(
            name = repository_file,
            out = "_{}.repository.txt".format(name),
            content = [repository],
        )

    if types.is_list(repotags):
        tags_label = "_{}_write_tags".format(name)
        write_file(
            name = tags_label,
            out = "_{}.tags.txt".format(name),
            content = repotags,
        )
        repotags = tags_label

    oci_push_rule(
        name = name,
        repotags = repotags,
        repository = repository_file,
        **kwargs
    )
