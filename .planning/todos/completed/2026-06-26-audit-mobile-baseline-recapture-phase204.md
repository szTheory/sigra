---
created: 2026-06-26T00:00:00.000Z
status: pending
title: recapture audit mobile checkpoint baselines (blocked on .vt-status-pill axe contrast)
area: admin-ui
files:
  - test/example/priv/static/assets/css/app.css
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/audit-explorer-admin-checkpoints-mobile.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-audit-admin-checkpoints-mobile.png
source: 202-VERIFICATION.md (SC-3 mobile leg, human_needed) + 202-UAT.md G1
resolves_phase: 204
---

## Why deferred

Phase 202 elevated both audit surfaces (`audit_index_live.ex`, `audit_user_live.ex`)
to a single-form + `<details>` composition. The code is verified award-grade and
byte-coherent, and the **chromium + dark** admin-checkpoint baselines were recaptured
clean. The **mobile** baselines for `user-audit` and `audit-explorer` are still dated
2026-06-17 (pre-Phase-202) and could not be recaptured.

Root cause (confirmed during 202 execution): `admin-checkpoints.spec.ts` runs all six
checkpoints as a **single linear test per project**. The two audit captures are the
last two steps, downstream of the `impersonation-banner` checkpoint — a `vt-*` Tasklane
demo page (`/organizations/:slug/members`) whose `.vt-status-pill` text color
(`color-mix(in oklab, var(--vt-color-caution) 62%, var(--vt-color-ink))`, ~3.33:1)
fails axe WCAG AA contrast (needs ≥4.5:1) at the mobile viewport. The axe gate in
`assertCheckpointScreenshot` throws there and aborts the test before reaching the audit
captures. The audit pages themselves are `sg-*` and carry no pill — the blocker is
pre-existing demo styling unrelated to the audit surfaces.

## How to apply (Phase 204 — Terminal Ratification)

Phase 204 is explicitly chartered to make the full surface axe-clean and recapture all
baselines through a clean gate with allowlists reset. As part of that:

1. Fix `.vt-status-pill` contrast in `test/example/priv/static/assets/css/app.css`
   (~line 1096) so the text mix hits ≥4.5:1 on both light and dark themes — increase
   the `--vt-color-ink` proportion (e.g. caution 45–50% + ink). Verify with the axe
   gate itself (it reports pass/fail), not by eyeballing. NOTE: this file has known
   stray-comment corruption that silently drops the next CSS rule — edit precisely and
   confirm the surrounding `.vt-status-pill--ok` / `.vt-table-panel` rules survive.
2. With the gate green, recapture the `admin-checkpoints-mobile` project. This refreshes
   `user-audit-...-mobile.png` + `audit-explorer-...-mobile.png` (the Phase 202 leg) and
   incidentally `impersonation-banner-...-mobile.png` (pixels change from the contrast
   fix). Restore any non-audit, non-pill mobile baselines that drift incidentally.
3. Verify zero-drift idempotency: re-run `admin-checkpoints-mobile` in compare mode
   (now clean) and confirm 0 diffs.
4. Confirm the SC-3 mobile award-grade leg for both audit surfaces is then proven by the
   refreshed baselines; close 202-UAT.md gap G1.

Boot note: example dev server on an alt PORT (4000 collides with Rulestead Docker);
pre-compile before launch to avoid the code-reload crash; set `SIGRA_EXAMPLE_URL`.
