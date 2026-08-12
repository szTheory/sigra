# Phase 238: Generated Auth Runtime Proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Decisions are captured in `238-CONTEXT.md`.

**Date:** 2026-08-05
**Phase:** 238-generated-auth-runtime-proof
**Mode:** assumptions, automated

## Assumptions Presented

| Area | Assumption | Confidence | Evidence |
|---|---|---|---|
| Generated-host proof boundary | Test the fresh canonical B2C host, not `test/example` or direct source fixtures. | Confident | Phase 237 context; `scripts/ci/passkeys-opt-out-smoke.sh` |
| Email journey | Exercise the complete email journey through browser-visible generated routes and the mailbox fixture. | Confident | Core templates; `golden-path.spec.ts`; `fixtures/mailbox.ts` |
| Google proof | Use a deterministic local provider double through generated request/callback routes, including account-link collision. | Likely | OAuth controller/template, Google strategy, callback tests |
| Accessibility | Assert Axe, labels/controls, and duplicate IDs for every material auth state using deterministic locators. | Confident | `admin-generated.spec.ts`; auth templates; Playwright config |

## Auto-Resolved

- Applied the evidence-backed generated-host, provider-double, and accessibility defaults under the user's authorization to proceed automatically.

## Todo Triage

- Folded the generated-auth login-only coverage and missing generated-auth Axe coverage todos because they directly map to AUTH-01 and AUTH-03.
- Deferred keyword-only CI, release, admin, Crosswake, CSS, and passkey matches outside this B2C phase boundary.
