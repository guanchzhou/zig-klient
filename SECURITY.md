# Security Policy

## Supported versions

zig-klient is pre-1.0. Only the latest tagged release receives security fixes.

| Version | Supported |
| ------- | --------- |
| latest `0.7.x` | ✅ |
| older | ❌ |

## Reporting a vulnerability

Please report security issues **privately** rather than opening a public issue:

- Use GitHub's [private vulnerability reporting](https://github.com/guanchzhou/zig-klient/security/advisories/new), or
- email the maintainer (see the GitHub profile for `guanchzhou`).

Include a description, affected version/commit, and a reproduction if possible.
You can expect an initial acknowledgement within a few days.

## Verifying releases

Release artifacts are checksummed (`SHA256SUMS`) and signed with **cosign keyless**
(Sigstore). Verify a downloaded artifact:

```sh
cosign verify-blob \
  --bundle SHA256SUMS.cosign.bundle \
  --certificate-identity-regexp 'https://github.com/guanchzhou/zig-klient/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  SHA256SUMS
shasum -a 256 -c SHA256SUMS   # then verify the SBOM against the signed checksums
```

## Scope notes

- The library treats the kubeconfig and the target cluster as trusted inputs, but
  guards against credential mishandling and a malicious cluster *response*.
- TLS server-certificate verification is always enforced (`insecure_skip_verify` is
  not wired into the request path).
- Bearer tokens are only ever sent as `Authorization` headers over the configured
  connection and are dropped on the plaintext-proxy fallback path.
