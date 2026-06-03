# Plan 35-01 Summary

**Objective:** Generator emission audit (SC1).

**Delivered:** `test/sigra/templates/generator_emission_audit_test.exs` scans `priv/templates/sigra.install/**/*.ex` for `<%= web_module %>.…` module chains, resolves coverage against the union of `Core|Admin|Organizations|Passkeys.files/1` for canonical + expanded bindings, with a small host-only allowlist and path hints for known renames (`AuthErrorHandler`, `SessionHTML`, `PageLive`).

**Verify:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/generator_emission_audit_test.exs`
