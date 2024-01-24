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

@test "single platform oci_pull without platforms attribute fetches for any bazel platforms" {
    # The image is a single-platform arm64 but if the user doesn't specify the 'platforms'
    # attribute in oci_pull, we do not check against the Bazel platform.
    run bazel build @distroless_base_single_arch_no_platforms_attr//... --platforms=//platforms:linux_amd64 $BAZEL_FLAGS
    run bazel build @distroless_base_single_arch_no_platforms_attr//... --platforms=//platforms:macos_arm64 $BAZEL_FLAGS
    assert_success
}

@test "single platform oci_pull with correct platforms attribute succeeds" {
    # As long as the target platform has an arm64 cpu (regardless of target os constraint), fetching should work.
    run bazel build @distroless_base_single_arch_correct_arm64_platforms_attr//... --platforms=//platforms:linux_arm64 $BAZEL_FLAGS
    run bazel build @distroless_base_single_arch_correct_arm64_platforms_attr//... --platforms=//platforms:macos_arm64 $BAZEL_FLAGS
    assert_success
}

@test "single platform oci_pull with correct platforms attribute fails for incompatible target platform" {
    # If the target platform has a non-arm64 cpu, fetching should fail because the image is not compatible.
    run bazel build @distroless_base_single_arch_correct_arm64_platforms_attr//... --platforms=//platforms:linux_x86_64 $BAZEL_FLAGS
    assert_failure
}

@test "single platform oci_pull with incorrect platforms attribute fails, even for target platform compatible with attribute" {
    # Even if the target
    run bazel build @distroless_base_single_arch_wrong_amd64_platforms_attr//... --platforms=//platforms:linux_x86_64 $BAZEL_FLAGS
    assert_failure
}

@test "single platform oci_pull with incorrect platforms attribute fails, even for target platform compatible with image metadata" {
    # Even if the target
    run bazel build @distroless_base_single_arch_wrong_amd64_platforms_attr//... --platforms=//platforms:linux_arm64 $BAZEL_FLAGS
    assert_failure
}
