# UAT evidence — Sigra v1.20 (GAUAT-01..08)

This folder holds **text-first** evidence, hero PNGs, and machine-readable manifests for **v1.20** GAUAT items. Phase 86 (GAUAT-01/02) closed the email visual lane; Phase 87 added the OAuth install/register/link/email-match bundles for GAUAT-03..06; Phase 88 adds the MFA rotation and generated-host getting-started bundles for GAUAT-07/08.

**Machine closure:** All outcomes are intended to be merge-blocking CI per `docs/uat-ci-coverage.md`. The authoritative closure condition is: green CI plus populated evidence bundles on the release SHA/tag. Local bundles may exist before their `ci_run_url` frontmatter is populated.

## Sigra version anchor

- **Git SHA:** `367a164` (local Phase 87 evidence generation SHA)
- **Hex version:** 0.2.5
- **CI workflow:** `.github/workflows/ci.yml` — jobs `email_visual_regression`, `install_smoke`, `oauth_e2e_playwright`, `mfa_e2e_playwright`
- **CI coverage doc:** `docs/uat-ci-coverage.md` — see SEED-1/SEED-2 rows

## Evidence directories

- [email-phase-04](email-phase-04/README.md) — GAUAT-01: Phase 04 security templates (`lockout_notification_email`, `suspicious_login_email`) — 8 hero PNGs, manifest, contrast + byte-budget reports
- [email-phase-08](email-phase-08/README.md) — GAUAT-02: Phase 08 lifecycle templates (7 templates) — 28 hero PNGs, manifest, contrast + byte-budget reports
- [oauth-gen](oauth-gen/README.md) — GAUAT-03: install-smoke transcript + generated artifact inventory for `mix sigra.gen.oauth`
- [oauth-google](oauth-google/README.md) — GAUAT-04: OAuth register/login/re-login evidence manifest for the Playwright + test-issuer lane
- [oauth-link](oauth-link/README.md) — GAUAT-05: link/unlink evidence manifest + single disabled-tooltip hero PNG
- [oauth-email-match](oauth-email-match/README.md) — GAUAT-06: email-match flash/mailbox evidence manifest
- [mfa-backup-rotation](mfa-backup-rotation/README.md) — GAUAT-07: MFA backup-code rotation UI + invalidation + audit evidence
- [getting-started-clean-machine](getting-started-clean-machine/README.md) — GAUAT-08: generated-host getting-started install/runtime evidence

## Hero PNG naming contract (D-86-06)

All hero PNGs follow the pattern:

```
{template-slug}__{engine}__{theme}__sha-{short-sha}.png
```

Examples:
- `email-phase-04/snapshots/lockout-notification__chromium__light__sha-6ce3cd3.png`
- `email-phase-04/snapshots/suspicious-login__webkit__dark__sha-6ce3cd3.png`
- `email-phase-08/snapshots/email-change-confirmation__chromium__light__sha-6ce3cd3.png`
- `oauth-link/snapshots/oauth-link__disabled-tooltip__sha-367a164.png`

The `short-sha` matches the wave-3 merge-base commit (`6ce3cd3`) for both phase-04 and phase-08 bundles. Source baselines live under `test/example/priv/playwright/__snapshots__/email-visual.spec.ts/` using single-dash separators (Playwright `{arg}` sanitization); hero PNG destinations use double-underscore separators per D-86-06.

## Snapshot count

| Evidence bundle | Rows/Templates | Cells/Rows | Hero PNGs |
|-----------------|----------------|------------|-----------|
| email-phase-04 | 2 templates | 8 cells | 8 |
| email-phase-08 | 7 templates | 28 cells | 28 |
| oauth-gen | 4 manifest rows | 4 rows | 0 |
| oauth-google | 8 manifest rows | 8 rows | 0 |
| oauth-link | 4 manifest rows | 4 rows | 1 |
| oauth-email-match | 4 manifest rows | 4 rows | 0 |
| mfa-backup-rotation | 4 manifest rows | 4 rows | 0 |
| getting-started-clean-machine | 3 manifest rows | 3 rows | 0 |
| **Total** | **8 bundles** | **63 rows/cells** | **37** |

## Residual policy (D-86-09)

The following are explicitly out of scope for CI-automated evidence:
- Legacy Outlook desktop Word engine rendering (Microsoft EOL Oct 2026)
- Subjective copy tone
- Spam-folder placement

See `docs/uat-ci-coverage.md` SEED-1/SEED-2 residual columns for the locked residual-only policy.
