"Public API"

load("//cosign/private:sign.bzl", _cosign_sign = "cosign_sign")
load("//cosign/private:attach.bzl", _cosign_attach = "cosign_attach")

cosign_sign = _cosign_sign
cosign_attach = _cosign_attach
