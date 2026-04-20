# UAT evidence — Sigra v1.3.0 (SEED-001 human GA gate)

This folder holds **text-first** evidence and waivers for the eight SEED-001 UAT items. The canonical status matrix is `.planning/v1.3-HUMAN-UAT.md`.

**Machine closure:** Outcomes are anchored to merge-blocking CI per `docs/uat-ci-coverage.md`. After merge, attach the GitHub Actions run URL(s) for your branch to this section for auditors.

## Sigra version anchor

- **Git SHA:** run `git rev-parse HEAD` at the repo root after checkout — use that value in audit narratives (rebases rewrite literals here).
- **CI workflow:** `.github/workflows/ci.yml` — jobs `library_tests`, `example_unit_smoke`, `example_playwright_smoke` (includes `ga-uat-shift-left.spec.ts`), `install_smoke`, `getting_started_uat_contract`.

## Item directories

- [item-01-lockout-mail](item-01-lockout-mail/) — SEED-1: lockout + suspicious-login mail HTML
- [item-02-lifecycle-mail](item-02-lifecycle-mail/) — SEED-2: seven account-lifecycle templates
- [item-03-gen-oauth-greenfield](item-03-gen-oauth-greenfield/) — SEED-3: `mix sigra.gen.oauth` greenfield
- [item-04-google-oauth-e2e](item-04-google-oauth-e2e/) — SEED-4: OAuth contracts + live-Google waiver
- [item-05-provider-linking-ui](item-05-provider-linking-ui/) — SEED-5: OAuth settings template contract
- [item-06-email-match-flash](item-06-email-match-flash/) — SEED-6: Playwright invitation email lock
- [item-07-backup-regenerate](item-07-backup-regenerate/) — SEED-7: Playwright MFA regenerate surface
- [item-08-getting-started](item-08-getting-started/) — SEED-8: getting-started structural contract + timing note

## Waiver records

- **SEED-4** live Google consent / refresh UX — [item-04-google-oauth-e2e/waiver.md](item-04-google-oauth-e2e/waiver.md) (compensating library + install automation).

## Blocked items accepted

_None — no Blocked rows in the master table._
