# SEED-7 — MFA backup regenerate surface (machine closure)

## Playwright (merge-blocking `example_playwright_smoke`)

- `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` — after TOTP
  enrollment, **Regenerate codes** opens `#mfa_regenerate_form` and the
  “Regenerate backup codes” heading (handler path to gate; submit/rotate proof
  still tracked against `Auth.mfa_regenerate_backup_codes/2` per docs).

## Residual

Old codes invalidating after real rotation — see `docs/uat-ci-coverage.md`
until `mfa_regenerate_backup_codes` ships.
