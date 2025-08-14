bats_load_library "bats-support"
bats_load_library "bats-assert"

setup_file() {
  cd "$BATS_TEST_DIRNAME/$WKSP"
}

teardown_file() {
  echo "# cleaning up" >&3
  bazel shutdown
}

setup() {
  bazel clean
}

@test "local oci_load works" {
    # Test the local oci_load directly 
    run bazel run //:local_load $BAZEL_FLAGS
    assert_success
    # Check that the output contains the expected load message (may have other bazel output)
    assert_output --partial "Loaded image: local:latest"
}

@test "external oci_load works" {
    # Test the external oci_load directly
    run bazel run @external_lib//:load $BAZEL_FLAGS
    assert_success
    # Check that the output contains the expected load message (may have other bazel output)
    assert_output --partial "Loaded image: external:latest"
}
