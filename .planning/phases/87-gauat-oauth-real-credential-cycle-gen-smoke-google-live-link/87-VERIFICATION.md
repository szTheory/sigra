---
status: local_pass_pending_ci_provenance
phase: 87
verified: 2026-04-28T11:45:00Z
goal_achieved: true
human_verification: []
overrides: []
deferred:
  - truth: "README frontmatter and manifest rows carry the actual GitHub Actions run URL for the phase-close SHA"
    addressed_in: "Push `367a164` and rerun `install_smoke` + `oauth_e2e_playwright`, then regenerate the OAuth evidence READMEs with `SIGRA_CI_RUN_URL` populated."
    evidence: "As of 2026-04-28, `gh run list --commit 367a164 --limit 20` returned no runs and `origin/main` was `5a88a99`, so the phase-close SHA still had no published GitHub Actions provenance."
---

# Phase 87 Verification Record

**Phase:** 87 — GAUAT OAuth automated end-to-end harness
**Date:** 2026-04-28
**Status:** LOCAL PASS, CI provenance pending

## Phase-Close SHA

`367a164`

This is the local phase-close SHA used for the OAuth evidence bundles under `.planning/uat-evidence/v1.20/oauth-{gen,google,link,email-match}/`.

## Evidence Metrics

| Metric | Value |
|--------|-------|
| Evidence directories | 4 |
| Manifest rows | 20 |
| Hero PNGs | 1 |
| Hero PNG path | `.planning/uat-evidence/v1.20/oauth-link/snapshots/oauth-link__disabled-tooltip__sha-367a164.png` |

## Provenance Status

- `gh run list --commit 367a164 --limit 20` returned no runs on 2026-04-28.
- `origin/main` was `5a88a99` on 2026-04-28, so the local phase-close SHA still had not produced a GitHub Actions run URL.
- The four OAuth evidence bundles therefore have blank `ci_run_url` frontmatter today. This is an external publication gap, not a failing local verification.

## Local Verification

- `MIX_ENV=test mix test test/sigra/install/oauth_smoketest_task_test.exs --no-color` — PASS
- `MIX_ENV=test mix test test/sigra/testing/oauth_issuer_test.exs --no-color` — PASS
- `cd test/example && CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' MIX_ENV=test mix test test/example_web/oauth_controller_test.exs --include example_app --no-color` — PASS
- `CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' GITHUB_WORKSPACE=$(pwd) scripts/ci/install-smoke.sh` — PASS, including `oauth-gen: 12/12 expected artifacts present, mix test green`
- `cd test/example/priv/playwright && CI=1 SIGRA_EXAMPLE_URL='http://localhost:4010' npx playwright test tests/oauth-register.spec.ts tests/oauth-link.spec.ts tests/oauth-email-match.spec.ts --project=chromium --reporter=line` — PASS (`4 passed`)
- `mix sigra.uat.report --phase=oauth-gen --check && mix sigra.uat.report --phase=oauth-google --check && mix sigra.uat.report --phase=oauth-link --check && mix sigra.uat.report --phase=oauth-email-match --check` — PASS

## GAUAT Attestations

### GAUAT-03 — PASS (local)

Evidence:
- `.planning/uat-evidence/v1.20/oauth-gen/transcript.log`
- `.planning/uat-evidence/v1.20/oauth-gen/reports/artifact-inventory.json`
- `.planning/uat-evidence/v1.20/oauth-gen/manifest.json`
- `.planning/uat-evidence/v1.20/oauth-gen/README.md`

### GAUAT-04 — PASS (local)

Evidence:
- `.planning/uat-evidence/v1.20/oauth-google/reports/playwright-trace.README.md`
- `.planning/uat-evidence/v1.20/oauth-google/manifest.json`
- `.planning/uat-evidence/v1.20/oauth-google/README.md`

### GAUAT-05 — PASS (local)

Evidence:
- `.planning/uat-evidence/v1.20/oauth-link/reports/db-probe-results.json`
- `.planning/uat-evidence/v1.20/oauth-link/snapshots/oauth-link__disabled-tooltip__sha-367a164.png`
- `.planning/uat-evidence/v1.20/oauth-link/manifest.json`
- `.planning/uat-evidence/v1.20/oauth-link/README.md`

### GAUAT-06 — PASS (local)

Evidence:
- `.planning/uat-evidence/v1.20/oauth-email-match/reports/flash-text-assertion.json`
- `.planning/uat-evidence/v1.20/oauth-email-match/reports/linked-email-mailbox.json`
- `.planning/uat-evidence/v1.20/oauth-email-match/manifest.json`
- `.planning/uat-evidence/v1.20/oauth-email-match/README.md`

## Close-Out

The local code and evidence surface for Phase 87 are complete and reproducible at `367a164`. The only remaining step before calling the phase fully CI-closed is to publish that SHA to the remote branch tip, let GitHub Actions produce the real `install_smoke` / `oauth_e2e_playwright` run URL, and regenerate the four OAuth READMEs so their `ci_run_url` fields are anchored to that remote run.
