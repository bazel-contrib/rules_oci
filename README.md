Experimental fork of `rules_oci` with support for Chainguard Images.

- Has upstream PRs included to address authentication issues: 
   - https://github.com/bazel-contrib/rules_oci/pull/237
   - https://github.com/bazel-contrib/rules_oci/pull/238
- Contains Go & Java examples - see `examples/`
  - Also has `distroless` targets for comparison
- `fetch.bzl` knows about example base images, such as `@chainguard_static`

