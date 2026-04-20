# SEED-2 — Account lifecycle email templates (machine closure)

Per `docs/uat-ci-coverage.md`, **merge-blocking** HTML checks cover the seven
lifecycle-style templates without manual mail clients.

## Automated substitute

- **Tests:** `test/example/test/example/accounts/emails_lifecycle_html_test.exs`
  (`Example.Accounts.EmailsLifecycleHtmlTest`).
- **CI job:** `example_unit_smoke` — `mix test --include example_app` in
  `test/example/`.

## Local reproduction

```bash
cd test/example
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test \
  mix test test/example/accounts/emails_lifecycle_html_test.exs
```
