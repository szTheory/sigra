---
created: 2026-09-26T19:04:12Z
status: pending
title: "Defer Playwright 1.62.1 after complete paired measurement found visual drift"
area: dependencies
files:
  - test/example/priv/playwright/package.json
  - test/example/priv/playwright/package-lock.json
  - .github/actions/example-playwright-boot/action.yml
  - .github/workflows/ci.yml
source: Phase 244 Plan 04; PR #213 closed/unmerged; measurement run 36262576391
owner: unassigned
---

## What

Do not merge the Playwright 1.62.1 bump based on PR #213. If the dependency update is still desired, establish a new isolated candidate against current main, diagnose the measured differences without changing screenshot baselines, and require a complete same-runner paired measurement with exactly zero differing pixels plus fresh required checks before merge consideration.

## Why

The complete paired measurement recorded real visual drift. PR #213 is closed and unmerged, and its remote head branch no longer exists. There is no live candidate to refresh or merge. The old August 8 failure is stale cache-key evidence and does not establish visual drift.

## Evidence

- PR #213: closed, unmerged, mergeability reported as conflicting; last recorded head SHA 9f5150bd3a000dc122e8c185bf06c102ac720667; the corresponding remote branch ref is absent.
- Current main: 5a00b90d2314bc93f27aec4090b5928018743d1b. CI run 36220498815 has successful ci-gate and Example Playwright smoke checks on that SHA; latest CI observe run 36264551736 is successful.
- Measurement source SHA: 980812cba598781b0b95a763562aaafbd093afb8.
- Measurement run: 36262576391 (https://github.com/szTheory/sigra/actions/runs/36262576391); artifact identifier: phase-244-playwright-measurement-36262576391.
- Artifact verdict: drift. All 115 expected images were captured on both sides, with zero missing or extra paths. 30 images differed, totaling 380825 changed pixels.
- Playwright trios: render A 1.59.1 / 1.59.1 / 1.59.1; render B 1.62.1 / 1.62.1 / 1.62.1.
- Chromium identities: render A revision 1217, version 147.0.7727.15, manifest https://raw.githubusercontent.com/microsoft/playwright/v1.59.1/packages/playwright-core/browsers.json, SHA-256 469f17a82348978f79738981bc8af9b4e8516aac5a020018911fff39b755fe60.
- Chromium identities: render B revision 1234, version 151.0.7922.34, manifest https://raw.githubusercontent.com/microsoft/playwright/v1.62.1/packages/playwright-core/browsers.json, SHA-256 f306eed529599b1eaf2f8a85db9de2b23e1a3fe36c2b66434b7c9434fb627a99.
- August 8 run 31229468400: stale, failed cache-key guard and shards, not visual proof.
- Inspection artifact directory: /private/tmp/sigra-phase244-run-36262576391/phase-244-playwright-measurement-36262576391.

### Changed images

| Image path | Changed pixels |
| --- | ---: |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-sessions-admin-checkpoints-dark.png | 61567 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-sessions-admin-checkpoints-chromium.png | 60430 |
| test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-detail-demo-showcase-chromium.png | 43605 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-chromium.png | 32243 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-chromium.png | 24277 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-dark.png | 19522 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-chromium.png | 17430 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-dark.png | 15308 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-dark.png | 11485 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-dark.png | 10008 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-chromium.png | 9745 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-dark.png | 8476 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-mobile.png | 8289 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-mobile.png | 7949 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-mobile.png | 7715 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-dark.png | 7535 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-mobile.png | 6446 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-chromium.png | 5879 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-mobile.png | 5569 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-chromium.png | 5563 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-sessions-admin-checkpoints-mobile.png | 5049 |
| test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/audit-explorer-demo-showcase-chromium.png | 3745 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-dark.png | 1374 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-dark.png | 644 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-chromium.png | 641 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-mobile.png | 264 |
| test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-chromium.png | 25 |
| test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/board-mg-1-admin-design-dark.png | 18 |
| test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/board-skeleton-admin-design-dark.png | 15 |
| test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/board-mg-10-admin-design-chromium.png | 9 |

## Next action

Only if the bump remains desired, have a maintainer create or authorize a fresh isolated dependency candidate from current main. Diagnose the existing drift first; update no baseline as part of the investigation. Run current required CI and repeat the complete 115-image paired measurement against the new candidate SHA. Consider merge only if the measurement is exactly zero-drift, the PR has a live authorized head, its diff stays within the Playwright package/cache scope, and every required latest-head check passes.

Do not reopen or recreate PR #213 automatically. Do not claim the August 8 run as visual proof. Do not open a PNG recapture lane.