# Phase 242: Close gap: XW-01/XW-02 — add rendered Crosswake start control - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-11
**Phase:** 242-close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
**Mode:** assumptions
**Areas analyzed:** Authenticated Host Surface, User-visible Control Design, Protocol and Security Preservation, Deterministic Closure Evidence

## Assumptions Presented

### Authenticated Host Surface

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The rendered start control belongs on the existing authenticated example-host `/app` LiveView and submits a normal CSRF-protected HTTP `POST /crosswake/start`, without a new route, controller template, generated-host feature, or LiveView event flow. | Confident | `test/example/lib/example_web/router.ex`; `test/example/lib/example_web/live/app_live.ex`; `test/example/lib/example_web/controllers/crosswake_controller.ex`; Phase 240.3 D-02 |

### User-visible Control Design

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The control is an obvious, accessible Tasklane/example-host form/button on `/app`, with no user-supplied Crosswake fields; exact placement and wording remain host-UI discretion. | Likely | `test/example/lib/example_web/live/app_live.ex`; `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts`; `.planning/v1.48-MILESTONE-AUDIT.md` |

### Protocol and Security Preservation

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The form supplies only CSRF mechanics; continuation, state, PKCE, session, binding, route, and destination values remain server-owned, and existing controller/evaluator/denial/fixed-`/app` semantics remain unchanged. | Confident | `test/example/lib/example_web/controllers/crosswake_controller.ex`; `test/example/test/example_web/controllers/crosswake_controller_test.exs`; `scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs`; Phase 240.3 D-04 through D-11 |

### Deterministic Closure Evidence

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Replace Playwright's fabricated form with role-based interaction against the rendered control while retaining the real-cookie-jar, Referer, final-state, and non-disclosure assertions. | Confident | `.planning/v1.48-MILESTONE-AUDIT.md`; `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts`; `test/example/priv/playwright/playwright.config.ts`; `scripts/ci/hosted-session-interop-proof.sh`; Phase 238 D-04; Phase 240.3 D-14 |

## Corrections Made

No corrections — all assumptions confirmed.

