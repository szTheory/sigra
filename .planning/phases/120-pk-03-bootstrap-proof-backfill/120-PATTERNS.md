# Phase 120 — Pattern Map

**Generated:** 2026-05-24
**Phase:** 120 - PK-03 Bootstrap Proof Backfill

## Scope

This phase is a repaired-form backfill. It should reuse existing patterns for:

- authoritative `*-VERIFICATION.md` artifacts that supersede stale summaries
- truthful `*-VALIDATION.md` Nyquist maps over existing proof seams
- bounded active-truth reconciliation in live planning files
- canonical Playwright passkey lanes that use the served example host and a virtual authenticator

## File Pattern Map

| Target File | Role | Closest Analog | Why It Matches |
|-------------|------|----------------|----------------|
| `.planning/phases/116-recovery-first-passkey-bootstrap/116-VERIFICATION.md` | authoritative repaired-form verification | `.planning/phases/115-last-passkey-safety-deletion-truth/115-VERIFICATION.md` | Same repaired-form ownership model: later phase backfills proof for the original implementation phase with explicit supersession language and current-head receipts. |
| `.planning/phases/116-recovery-first-passkey-bootstrap/116-VALIDATION.md` | retroactive Nyquist map | `.planning/phases/115-last-passkey-safety-deletion-truth/115-VALIDATION.md` | Same need to map already-existing test/browser seams to a missing validation artifact instead of inventing Wave 0 work. |
| `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md` | historical summary supersession pointer | `.planning/phases/115-last-passkey-safety-deletion-truth/115-01-SUMMARY.md` | Same pattern: keep the summary as history but add a conspicuous pointer to the new verification authority. |
| `.planning/REQUIREMENTS.md` | live requirement traceability update | `.planning/phases/119-pk-02-verification-backfill/119-02-PLAN.md` target set | Same active-truth file that needs a pending backfill placeholder replaced with direct references to new authoritative artifacts. |
| `.planning/PROJECT.md` | live milestone-status reconciliation | `.planning/phases/119-pk-02-verification-backfill/119-02-PLAN.md` target set | Same present-tense project narrative that should mention what is now closed without claiming full milestone closure. |
| `.planning/STATE.md` | operator handoff update | `.planning/phases/119-pk-02-verification-backfill/119-02-PLAN.md` target set | Same current-focus / next-step surface that should advance from “prepare phase” to “phase closed; next remaining work is ...”. |
| `.planning/v1.26-MILESTONE-AUDIT.md` | bounded historical supersession note | Phase 119 plan 02 target set + existing PK-02 update style in the audit | Same need to preserve the fact that the audit found a real gap while adding an explicit later backfill note. |
| `test/example/priv/playwright/tests/passkey-login.spec.ts` | canonical browser lane | itself | Already owns login fallback visibility and settings enrollment. It is the nearest place to extend the flow upward into confirmation-driven bootstrap proof. |

## Verification Artifact Patterns

### Pattern A: Repaired-Form Verification

**Primary analog:** `.planning/phases/115-last-passkey-safety-deletion-truth/115-VERIFICATION.md`

**Reusable shape**

- frontmatter with `phase`, `slug`, `status`, `requirements`, `verified_at`
- opening line explicitly superseding the stale summary
- short explanation of why the backfill exists
- `## Closeout Goals`
- `## Evidence` with exact commands and outcomes
- `## Proved / Did Not Prove`
- `## Residuals`
- `## Status`

**Required adaptation for Phase 120**

- replace `PK-02` with `PK-03`
- explicitly name `116-01-SUMMARY.md`
- include the confirmation handoff/browser lane as a first-class proof seam
- keep scope bounded to `PK-03`, not full `v1.26`

### Pattern B: Validation Map Over Existing Seams

**Primary analogs:** `.planning/phases/115-last-passkey-safety-deletion-truth/115-VALIDATION.md`, `.planning/phases/118-generated-host-proof-milestone-closeout/118-VALIDATION.md`

**Reusable shape**

- frontmatter with `nyquist_compliant: true` and `wave_0_complete: true`
- `## Test Infrastructure`
- `## Sampling Rate`
- `## Per-Task Verification Map`
- explicit mapping from requirement to concrete commands and files
- sign-off that there are no missing placeholders

**Required adaptation for Phase 120**

- map `PK-03` to generator login/management tests, confirmation/bootstrap ExUnit tests, fallback tests, and one Playwright confirmation-driven lane
- note the `mix run --no-start` fallback if root runtime behavior still blocks plain `mix test`

## Active Truth Reconciliation Patterns

### Pattern C: Bounded Live-Truth Updates

**Primary analog:** `.planning/phases/119-pk-02-verification-backfill/119-02-PLAN.md`

**Reusable rules**

- update only current-state files
- replace pending/orphaned wording with direct references to new authoritative artifacts
- do not overclaim broader milestone closure
- preserve historical audit readability while adding explicit supersession notes

**Target files for Phase 120**

- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/v1.26-MILESTONE-AUDIT.md`
- `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md`

## Playwright Patterns

### Pattern D: Virtual Authenticator + Served Route Lifecycle Proof

**Primary analogs**

- `test/example/priv/playwright/tests/passkey-login.spec.ts`
- `test/example/priv/playwright/tests/passkey-options.spec.ts`

**Reusable building blocks**

- `addVirtualAuthenticator(page)` for Chromium WebAuthn
- `registerAndAuthenticateUser(page, email, password)` for account creation plus authenticated state
- `finishSudoForMfaSettings(page, password)` for entry into the passkeys settings route
- assertions on `Create passkey` / `Not now` before starting ceremony
- `Promise.all([... waitForResponse ..., click()])` around options and completion POSTs

**Required adaptation for Phase 120**

- start from the confirmation-linked bootstrap intent rather than a direct `/users/settings/mfa` visit
- assert the bootstrap card text before the enrollment interstitial
- keep one canonical Chromium lane only

## Concrete Excerpts To Reuse

### Supersession line

From `115-VERIFICATION.md`:

`Supersedes 115-01-SUMMARY.md as the authoritative PK-02 proof surface.`

Phase 120 should mirror this exactly in shape:

`Supersedes 116-01-SUMMARY.md as the authoritative PK-03 proof surface.`

### Historical summary redirect

From the Phase 119 target contract:

`Superseded by 115-VERIFICATION.md for authoritative PK-02 verification status.`

Phase 120 should mirror this exactly in shape:

`Superseded by 116-VERIFICATION.md for authoritative PK-03 verification status.`

### Browser interstitial assertions

From `passkey-login.spec.ts` and `passkey-options.spec.ts`:

- `await expect(page.getByText("Create a passkey")).toBeVisible();`
- `await expect(page.getByRole("button", { name: "Create passkey" })).toBeVisible();`
- `await expect(page.getByRole("button", { name: "Not now" })).toBeVisible();`

### Existing bootstrap server-side assertions

From `test/example/test/example_web/live/passkey_settings_live_test.exs`:

- `assert html =~ "Add passkey now"`
- `assert html =~ "Create passkey"`
- `assert html =~ "Not now"`

## Planning Guidance

- Prefer **2 plans** unless new evidence shows the browser lane and doc backfill cannot be kept cohesive.
- Plan 01 should own the new authority (`116-VERIFICATION.md`, `116-VALIDATION.md`) and the missing canonical Playwright proof.
- Plan 02 should own only bounded truth reconciliation after Plan 01 lands.
- Do not add implementation plans for product/UI changes; the shipped runtime behavior already exists.
