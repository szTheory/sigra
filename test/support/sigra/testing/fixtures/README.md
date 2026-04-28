# Sigra.Testing.OAuthIssuer Fixtures

These PEM files are test fixtures for `Sigra.Testing.OAuthIssuer`.

- `oauth_issuer_rsa_kid1_private.pem` / `oauth_issuer_rsa_kid1_public.pem`
  Primary signing keypair for `kid=1`.
- `oauth_issuer_rsa_kid2_private.pem` / `oauth_issuer_rsa_kid2_public.pem`
  Secondary signing keypair used for multi-kid JWKS rotation coverage when
  `kid_count: 2`.

Regenerate them with:

```bash
mkdir -p test/support/sigra/testing/fixtures
for kid in 1 2; do
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
    -out test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid${kid}_private.pem
  openssl rsa -in test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid${kid}_private.pem \
    -pubout -out test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid${kid}_public.pem
done
```

Threat-model note: these keys are TEST FIXTURES ONLY and must never be reused
for production signing. This follows D-87-02 and mitigation T-87-03. Sigra's
Hex package file list in `mix.exs` excludes `test/`, so these fixtures do not
ship to adopters.
