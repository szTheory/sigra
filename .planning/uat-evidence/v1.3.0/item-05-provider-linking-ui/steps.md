# SEED-5 — Provider linking / last-method unlink (machine closure)

## Template contract (merge-blocking `library_tests`)

- `test/sigra/oauth/oauth_settings_template_contract_test.exs` asserts the
  generated `oauth_settings_live.ex` template retains D-03 last-provider unlink
  guard and “Set a password first…” copy.

## Local reproduction

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test \
  mix test test/sigra/oauth/oauth_settings_template_contract_test.exs
```

Tooltip timing and host CSS are **residual** per `docs/uat-ci-coverage.md`.
