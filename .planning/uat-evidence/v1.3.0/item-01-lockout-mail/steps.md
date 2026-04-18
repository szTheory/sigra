# SEED-1 — Lockout + suspicious-login email HTML (machine closure)

Per `docs/uat-ci-coverage.md`, **merge-blocking** HTML structure checks replace
per-client Gmail / Outlook / Apple Mail passes for GA.

## Automated substitute

- **Tests:** `test/example/test/example/accounts/emails_security_html_test.exs`
  (`Example.Accounts.EmailsSecurityHtmlTest`) — headings, IP/device/geo copy,
  reset CTA, table roles, footer.
- **CI job:** `example_unit_smoke` (`.github/workflows/ci.yml`) — runs
  `mix test --include example_app` in `test/example/` (includes these modules).

## Local reproduction

```bash
cd test/example
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test \
  mix test test/example/accounts/emails_security_html_test.exs
```

Residual client rendering remains optional per `docs/uat-ci-coverage.md`.
