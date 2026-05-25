# Phase 120: PK-03 Bootstrap Proof Backfill - Research

**Researched:** 2026-05-24 [VERIFIED: codebase grep]
**Domain:** Retroactive phase verification, Nyquist backfill, and canonical browser proof for the confirmation -> bootstrap banner -> explicit passkey enrollment seam [VERIFIED: codebase grep]
**Confidence:** HIGH [VERIFIED: codebase grep]

<user_constraints>
## User Constraints (from CONTEXT.md)

- Phase 120 repairs missing proof for already-shipped Phase 116 behavior; it does not redesign passkey UX, recovery posture, or WebAuthn substrate semantics. [VERIFIED: `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md`]
- Proof authority for `PK-03` belongs to Phase 116, so the backfill must create `116-VERIFICATION.md` and `116-VALIDATION.md` rather than treating Phase 120 as the long-term proof home. [VERIFIED: `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md`]
- The required browser evidence is one canonical served-route lane from signup confirmation through the bootstrap banner into explicit passkey enrollment. It should not widen into a browser matrix or screenshot archive. [VERIFIED: `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md`]
- Active truth updates must stay bounded to live files that would otherwise misstate current `PK-03` status; broad milestone cleanup remains Phase 121 scope. [VERIFIED: `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md`]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PK-03 | Recovery-first passkey-primary posture is authoritatively closed by a Phase 116 verification artifact, with final evidence proving the browser path from signup confirmation through the bootstrap banner into explicit enrollment and a matching Nyquist artifact for Phase 116. [VERIFIED: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`] | The functional behavior is already on current HEAD across confirmation, MFA settings, login, generator tests, and Playwright. The gap is missing authority plus one missing end-to-end browser lane that starts before `/users/settings/mfa`. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`, codebase grep] |
</phase_requirements>

## Summary

`PK-03` is implemented but audit-orphaned in the same repaired-form sense `PK-02` was before Phase 119. Phase 116 shipped the recovery-first bootstrap posture, but its only implementation record is `116-01-SUMMARY.md`, which ends with `## Self-Check: FAILED` because example-runtime verification was blocked during OTP startup. The milestone audit explicitly calls that out as insufficient authority and separately flags that the final generated-host/browser proof starts at `/users/settings/mfa` instead of proving the full confirmation handoff path. [VERIFIED: `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md`, `.planning/v1.26-MILESTONE-AUDIT.md`]

Current HEAD already contains most of the needed evidence seams. The confirmation controller still carries the signup `enroll_passkey` intent into a sudo-gated return path, `passkey_settings_live_test.exs` already proves the bootstrap banner and explicit `Create passkey` / `Not now` interstitial at the ExUnit layer, generator tests pin the same posture in generated-host code, and the existing Playwright lanes already prove recovery-first login and settings-based enrollment on served routes. [VERIFIED: codebase grep]

What is still missing is:

1. an authoritative `116-VERIFICATION.md` that closes `PK-03` on current HEAD and explicitly supersedes `116-01-SUMMARY.md`,
2. a truthful `116-VALIDATION.md` that maps the existing proof seams to `PK-03`, and
3. one canonical browser lane that starts with confirmation-linked follow-through rather than a direct visit to `/users/settings/mfa`. [VERIFIED: `.planning/ROADMAP.md`, `.planning/v1.26-MILESTONE-AUDIT.md`, codebase grep]

**Primary recommendation:** split execution into two plans. Plan 01 backfills `116-VERIFICATION.md` and `116-VALIDATION.md` while adding or refining exactly one Playwright lane that proves confirmation -> bootstrap banner -> explicit passkey enrollment. Plan 02, dependent on Plan 01, reconciles only the active `PK-03` truth surfaces (`REQUIREMENTS.md`, `PROJECT.md`, `STATE.md`, the live v1.26 milestone audit, and the historical `116-01-SUMMARY.md` pointer) so maintainers stop reading `PK-03` as pending or authoritatively verified by a failed summary. [VERIFIED: phase context + Phase 119 precedent]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Authoritative `PK-03` closeout | Phase 116 planning artifacts | Existing runtime and browser seams | The missing deliverable is phase-local verification authority, not new runtime behavior. [VERIFIED: `.planning/ROADMAP.md`, `.planning/v1.26-MILESTONE-AUDIT.md`] |
| Confirmation -> bootstrap -> enrollment proof | Playwright served-route lane | Existing ExUnit/controller/LiveView seams | The audit explicitly says the browser bundle must prove the full path, not only the settings segment. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`] |
| Targeted behavioral proof | ExUnit controller/LiveView/generator tests | Verification doc | Existing focused tests already pin the bootstrap state machine and copy boundaries more precisely than browser evidence should. [VERIFIED: codebase grep] |
| Nyquist backfill for Phase 116 | Validation doc | Verification doc | `116-VALIDATION.md` should map the actual modern proof seams to `PK-03` rather than inventing hypothetical Wave 0 work. [VERIFIED: repaired-form precedent] |
| Active truth reconciliation | `REQUIREMENTS.md`, `PROJECT.md`, `STATE.md`, `v1.26-MILESTONE-AUDIT.md`, `116-01-SUMMARY.md` | Roadmap already scopes the pending phase accurately | These are the live or near-live files a maintainer will read first when asking whether `PK-03` is still unresolved. [VERIFIED: codebase grep] |

## Project Constraints

- Keep the backfill scoped to `PK-03` and the canonical proof seam. Do not reopen Phase 116 product decisions or expand into milestone-wide archive normalization. [VERIFIED: `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md`]
- Preserve the distinction between history and authority: `116-01-SUMMARY.md` remains implementation history, while `116-VERIFICATION.md` becomes the authoritative proof surface. [VERIFIED: repaired-form precedent from Phase 119]
- Use command-first receipts, not screenshots or transitive prose. The authoritative artifact should name exact rerunnable commands and honest outcomes. [VERIFIED: `.planning/phases/118-generated-host-proof-milestone-closeout/118-VERIFICATION.md`, `.planning/phases/115-last-passkey-safety-deletion-truth/115-VERIFICATION.md`]
- If the root runtime still exhibits the same startup problems seen during Phase 116, fall back to the documented `mix run --no-start` verification shape rather than fabricating a clean `mix test` pass. [VERIFIED: `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md`, `.planning/phases/115-last-passkey-safety-deletion-truth/115-VERIFICATION.md`] 

## Standard Stack

### Core
| Library / Tool | Version / Source | Purpose | Why Standard |
|----------------|------------------|---------|--------------|
| ExUnit / Phoenix test harness | repo-local | Focused proof for confirmation handoff, bootstrap banner, explicit enrollment interstitial, and fallback-copy invariants | These seams already exist and cover the fine-grained `PK-03` state transitions better than browser tests alone. [VERIFIED: codebase grep] |
| Playwright example proof | repo-local under `test/example/priv/playwright` | Canonical served-route proof for the confirmation -> bootstrap -> enrollment lane and visible login fallback posture | The milestone audit requires a real browser lane that starts earlier than the current settings-only proof. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`] |
| Markdown planning artifacts under `.planning/` | repo-local | Verification, validation, and truth reconciliation | The missing deliverables are authoritative planning artifacts whose value depends on exact file paths and receipts. [VERIFIED: codebase grep] |

### Supporting
| Library / Tool | Purpose | When to Use |
|----------------|---------|-------------|
| `rg` | Truth reconciliation and acceptance gates | Use to prove stale references to `116-01-SUMMARY.md` or missing `116-VERIFICATION.md` / `116-VALIDATION.md` have been replaced in live files. [VERIFIED: codebase grep] |
| `mix run --no-start` | Root verification fallback | Use if the old OTP-startup stall resurfaces during focused root/generator verification. [VERIFIED: `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md`] |

## Architecture Patterns

### Pattern 1: Original-Phase Backfill, Later-Phase Repair

**What:** Phase 120 should repair Phase 116’s missing authority by adding `116-VERIFICATION.md` and `116-VALIDATION.md`, not by creating a long-lived `120-VERIFICATION.md` authority. [VERIFIED: `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md`]

**When to use:** When the original phase shipped the behavior but failed to emit the verification/validation artifacts the workflow expects. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`]

**Example shape:** follow the same repaired-form posture as `115-VERIFICATION.md` / `115-VALIDATION.md`: explicit supersession, exact commands, clear Proved / Did Not Prove boundaries, and no broader milestone claims. [VERIFIED: Phase 119 artifacts]

### Pattern 2: Browser Proof Should Add One Missing Integration Seam, Not Replace Existing Targeted Tests

**What:** Keep ExUnit as the authority for controller/LiveView invariants and use Playwright only for the one end-to-end lane the audit says is still missing. [VERIFIED: `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md`]

**When to use:** When the code already has focused test coverage but milestone truth requires a real served-route confirmation of the whole user journey. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`]

**Example shape:** extend an existing Playwright file or add one narrow spec that registers a user, follows the confirmation-driven handoff into the `#passkeys` surface, sees `Add passkey now`, sees the `Create passkey` / `Not now` interstitial, and completes enrollment. [VERIFIED: current Playwright patterns in `passkey-login.spec.ts` and `passkey-options.spec.ts`]

### Pattern 3: Bounded Active-Truth Reconciliation After Authority Lands

**What:** Update only the current-state planning surfaces that would otherwise keep `PK-03` looking open or misleadingly “verified via 116-01-SUMMARY.md”. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/v1.26-MILESTONE-AUDIT.md`]

**When to use:** After `116-VERIFICATION.md` and `116-VALIDATION.md` exist and can be cited directly. [VERIFIED: repaired-form precedent]

**Anti-pattern:** rewriting broad milestone history, archived roadmap bundles, or unrelated requirements just because they mention passkeys. [VERIFIED: `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md`]

## Anti-Patterns to Avoid

- **Closing `PK-03` only by pointing at Phase 118:** this preserves the exact orphaned-authority problem the milestone audit called out. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`]
- **Treating the current Playwright settings lane as sufficient:** the audit explicitly says the final proof does not browser-exercise the confirmation -> bootstrap banner path. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`]
- **Overwriting `116-01-SUMMARY.md` history instead of superseding it:** this erases the fact that the original phase self-check failed and hides the repaired-form backfill story. [VERIFIED: repaired-form precedent]
- **Claiming broader milestone closure:** this phase closes `PK-03`, not all remaining v1.26 Nyquist or re-audit debt. [VERIFIED: `.planning/ROADMAP.md`, `.planning/STATE.md`]

## Common Pitfalls

### Pitfall 1: Proving Enrollment from Settings but Not the Confirmation Handoff

**What goes wrong:** Browser evidence still begins at `/users/settings/mfa`, so the user never sees the precise flow the roadmap names. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`]

**How to avoid:** Start the canonical browser lane from registration + confirmation-linked follow-through, then assert the bootstrap banner and the explicit interstitial before WebAuthn enrollment begins. [VERIFIED: `confirmation_controller_test.exs`, `passkey-login.spec.ts` patterns]

### Pitfall 2: Reusing the Failed Summary as If It Were Current Authority

**What goes wrong:** Maintainers keep opening `116-01-SUMMARY.md`, see `Self-Check: FAILED`, and miss the later authoritative backfill. [VERIFIED: `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md`]

**How to avoid:** Make `116-VERIFICATION.md` explicitly supersede the summary and add a short conspicuous pointer in the summary itself. [VERIFIED: Phase 119 summary-pointer pattern]

### Pitfall 3: Treating Validation Backfill as New Harness Work

**What goes wrong:** The plan invents Wave 0 tasks even though the focused proof files already exist. [VERIFIED: codebase grep]

**How to avoid:** Make `116-VALIDATION.md` a truthful evidence map over existing ExUnit, generator, and Playwright seams. [VERIFIED: Phase 115 and 118 validation shapes]

### Pitfall 4: Assuming the Original Runtime Blocker Is Gone Without Recording It

**What goes wrong:** The verification doc claims a clean `mix test` pass even if the same startup hang still exists in the current environment. [VERIFIED: `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md`]

**How to avoid:** Prefer the Phase 117 / Phase 119 `mix run --no-start` fallback if needed and record that receipt explicitly. [VERIFIED: `117-VERIFICATION.md`, `115-VERIFICATION.md`]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit, Phoenix.LiveViewTest / controller tests, raw generator assertions, Playwright, and planning-file grep gates. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs`, `test/example/test/test_helper.exs`, and `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: codebase grep] |
| Quick run command | `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/install/generator_passkey_primary_login_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)' && (cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/controllers/confirmation_controller_test.exs test/example_web/live/passkey_settings_live_test.exs)` [VERIFIED: current repo patterns] |
| Full suite command | `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/install/generator_passkey_primary_login_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)' && (cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/controllers/confirmation_controller_test.exs test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs) && (cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts --project=chromium) && rg -n "116-VERIFICATION|116-VALIDATION|PK-03|Superseded by 116-VERIFICATION|Phase 120" .planning/REQUIREMENTS.md .planning/PROJECT.md .planning/STATE.md .planning/v1.26-MILESTONE-AUDIT.md .planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md .planning/phases/116-recovery-first-passkey-bootstrap/116-VERIFICATION.md .planning/phases/116-recovery-first-passkey-bootstrap/116-VALIDATION.md` [VERIFIED: current repo patterns] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PK-03 | Generated-host login and management templates still encode the recovery-first bootstrap posture. [VERIFIED: `generator_passkey_primary_login_test.exs`, `generator_passkey_management_test.exs`] | generator | `MIX_ENV=test mix run --no-start -e 'Application.ensure_all_started(:telemetry); Application.ensure_all_started(:mox); Code.require_file("test/test_helper.exs"); Code.require_file("test/sigra/install/generator_passkey_primary_login_test.exs"); Code.require_file("test/sigra/install/generator_passkey_management_test.exs"); ExUnit.configure(max_cases: 1, trace: true); ExUnit.run(); System.halt(0)'` | ✅ [VERIFIED: codebase grep] |
| PK-03 | Confirmation handoff and bootstrap/interstitial states still hold on the example host. [VERIFIED: `confirmation_controller_test.exs`, `passkey_settings_live_test.exs`] | controller + LiveView | `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/controllers/confirmation_controller_test.exs test/example_web/live/passkey_settings_live_test.exs` | ✅ [VERIFIED: codebase grep] |
| PK-03 | Login fallback and MFA-specific recovery truth remain aligned with the shipped Phase 116 posture. [VERIFIED: Phase 116 summary + later proofs] | controller + LiveView | `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/controllers/passkey_session_controller_test.exs test/example_web/live/passkey_mfa_challenge_live_test.exs` | ✅ [VERIFIED: codebase grep] |
| PK-03 | Served-route browser proof now includes the confirmation -> bootstrap banner -> explicit enrollment lane. [VERIFIED: audit requirement] | Playwright | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-login.spec.ts --project=chromium` | ✅ existing file, but lane must be extended or refined [VERIFIED: codebase grep] |
| PK-03 | Active planning truth stops pointing at `116-01-SUMMARY.md` as authority. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/v1.26-MILESTONE-AUDIT.md`] | docs/grep | `rg -n "116-VERIFICATION|116-VALIDATION|Superseded by 116-VERIFICATION|PK-03|Phase 120" .planning/REQUIREMENTS.md .planning/PROJECT.md .planning/STATE.md .planning/v1.26-MILESTONE-AUDIT.md .planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md` | ✅ [VERIFIED: codebase grep] |

### Sampling Rate

- **After every task commit:** run the smallest focused seam command for the artifact being updated.
- **After Plan 01 completes:** run the full focused proof stack without the final truth-reconciliation grep if Plan 02 has not landed yet.
- **Before `$gsd-verify-work`:** run the full suite command including the final grep gate.

### Wave 0 Gaps

- None. Existing test and Playwright infrastructure already cover `PK-03`; the missing work is authoritative artifact creation plus one broader browser lane. [VERIFIED: codebase grep]

## Sources

### Primary (HIGH confidence)
- `.planning/ROADMAP.md` - Phase 120 goal, success criteria, and dependency chain. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md` - live `PK-03` traceability row and milestone constraints. [VERIFIED: codebase grep]
- `.planning/v1.26-MILESTONE-AUDIT.md` - authoritative statement of the orphaned `PK-03` gap, failed summary authority, and missing browser seam. [VERIFIED: codebase grep]
- `.planning/phases/120-pk-03-bootstrap-proof-backfill/120-CONTEXT.md` - locked scope, decisions, and bounded proof posture. [VERIFIED: codebase grep]
- `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md` - stale failed self-check that must be superseded. [VERIFIED: codebase grep]
- `.planning/phases/116-recovery-first-passkey-bootstrap/116-RESEARCH.md`, `116-CONTEXT.md`, `116-UI-SPEC.md` - original shipped design and exact bootstrap-copy contract. [VERIFIED: codebase grep]
- `.planning/phases/115-last-passkey-safety-deletion-truth/115-VERIFICATION.md`, `.planning/phases/115-last-passkey-safety-deletion-truth/115-VALIDATION.md`, and Phase 119 plan/summaries - repaired-form backfill precedent. [VERIFIED: codebase grep]
- `test/example/test/example_web/controllers/confirmation_controller_test.exs`, `test/example/test/example_web/live/passkey_settings_live_test.exs`, `test/example/test/example_web/controllers/passkey_session_controller_test.exs`, `test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs`, `test/example/priv/playwright/tests/passkey-login.spec.ts`, `test/sigra/install/generator_passkey_primary_login_test.exs`, `test/sigra/install/generator_passkey_management_test.exs` - concrete proof seams the backfill should cite. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)
- `.planning/PROJECT.md` and `.planning/STATE.md` - live milestone-status surfaces that will need bounded reconciliation after the authoritative Phase 116 artifacts land. [VERIFIED: codebase grep]
- `.planning/phases/118-generated-host-proof-milestone-closeout/118-VERIFICATION.md` and `118-VALIDATION.md` - shape precedent for command-first verification and Nyquist mapping with browser proof. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)
- None. This phase can be planned entirely from repo-local sources because the underlying product/design decisions were already settled in Phase 116 and the open work is evidence repair, not fresh domain exploration.

