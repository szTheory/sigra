# API Coverage — Phase 246

## Generated direct-MFA HTTP surface

`POST /api/app-login/direct/mfa` accepts exactly the scalar JSON fields
`challenge`, `code`, and `factor`. The fixed controller allowlist maps only
`factor: "totp"` to `:totp` and `factor: "backup_code"` to `:backup_code`
before forwarding the trusted value to the host MFA facade. Missing, empty,
list-valued, unknown, or extra selector input follows the existing uniform
`401 {"error":"invalid_credentials"}` direct-credential failure response;
untrusted input cannot choose an atom or verifier callback.

## External-integration opt-out

No external API integration applies. This change is an existing first-party
generated Phoenix endpoint that uses Sigra, Ecto, Phoenix, and OTP primitives;
OAuth/OIDC authorization-server behavior and delegated integrations remain out
of scope.
