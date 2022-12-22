"Public API"

load("//oci/private:tarball.bzl", _oci_tarball = "oci_tarball")
load("//oci/private:image.bzl", _oci_image = "oci_image")
load("//oci/private:image_index.bzl", _oci_image_index = "oci_image_index")
load("//oci/private:structure_test.bzl", _oci_structure_test = "oci_structure_test")

oci_tarball = _oci_tarball
oci_image = _oci_image
oci_image_index = _oci_image_index
oci_structure_test = _oci_structure_test
