"Public API"

load("//cosign/private:sign.bzl", _cosign_sign = "cosign_sign")
load("//cosign/private:attest.bzl", _cosign_attest = "cosign_attest")

cosign_sign = _cosign_sign
cosign_attest = _cosign_attest
