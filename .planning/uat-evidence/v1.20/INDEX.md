# UAT evidence — Sigra v1.20 (GAUAT-01 + GAUAT-02 — Phase 86 email visual regression)

This folder holds **text-first** evidence, hero PNGs, and machine-readable manifests for **v1.20** GAUAT items. The canonical Phase 86 evidence is produced by the `email_visual_regression` CI lane in `.github/workflows/ci.yml` and committed here per D-86-06.

**Machine closure:** All outcomes are merge-blocking CI per `docs/uat-ci-coverage.md` (SEED-1/SEED-2 updated to reference the `email_visual_regression` job). On tag `v1.20.0` the same bundle is promoted to the GitHub release asset without rebuilding.

## Sigra version anchor

- **Git SHA:** `6ce3cd3` (phase-close wave-3 base)
- **Hex version:** 0.2.5
- **CI workflow:** `.github/workflows/ci.yml` — job `email_visual_regression`
- **CI coverage doc:** `docs/uat-ci-coverage.md` — see SEED-1/SEED-2 rows

## Evidence directories

- [email-phase-04](email-phase-04/README.md) — GAUAT-01: Phase 04 security templates (`lockout_notification_email`, `suspicious_login_email`) — 8 hero PNGs, manifest, contrast + byte-budget reports
- [email-phase-08](email-phase-08/README.md) — GAUAT-02: Phase 08 lifecycle templates (7 templates) — 28 hero PNGs, manifest, contrast + byte-budget reports

## Hero PNG naming contract (D-86-06)

All hero PNGs follow the pattern:

```
{template-slug}__{engine}__{theme}__sha-{short-sha}.png
```

Examples:
- `email-phase-04/snapshots/lockout-notification__chromium__light__sha-6ce3cd3.png`
- `email-phase-04/snapshots/suspicious-login__webkit__dark__sha-6ce3cd3.png`
- `email-phase-08/snapshots/email-change-confirmation__chromium__light__sha-6ce3cd3.png`

The `short-sha` matches the wave-3 merge-base commit (`6ce3cd3`) for both phase-04 and phase-08 bundles. Source baselines live under `test/example/priv/playwright/__snapshots__/email-visual.spec.ts/` using single-dash separators (Playwright `{arg}` sanitization); hero PNG destinations use double-underscore separators per D-86-06.

## Snapshot count

| Phase | Templates | Cells | Hero PNGs |
|-------|-----------|-------|-----------|
| 04    | 2         | 8     | 8         |
| 08    | 7         | 28    | 28        |
| **Total** | **9** | **36** | **36** |

## Residual policy (D-86-09)

The following are explicitly out of scope for CI-automated evidence:
- Legacy Outlook desktop Word engine rendering (Microsoft EOL Oct 2026)
- Subjective copy tone
- Spam-folder placement

See `docs/uat-ci-coverage.md` SEED-1/SEED-2 residual columns for the locked residual-only policy.
