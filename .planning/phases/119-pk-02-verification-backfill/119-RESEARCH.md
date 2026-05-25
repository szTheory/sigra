# Phase 119: PK-02 Verification Backfill - Research

**Researched:** 2026-05-24 [VERIFIED: codebase grep]
**Domain:** Retroactive phase verification, Nyquist backfill, and bounded planning-truth reconciliation for passkey lifecycle evidence [VERIFIED: codebase grep]
**Confidence:** HIGH [VERIFIED: codebase grep]

<user_constraints>
## User Constraints (from CONTEXT.md)

No `119-CONTEXT.md` exists for this phase; scope is locked by `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/v1.26-MILESTONE-AUDIT.md`, and the already-shipped Phase 115/117/118 artifacts. [VERIFIED: codebase grep]

This is a gap-closure phase, not a fresh product-design phase. It should author the missing authoritative records for `PK-02`, not redesign passkey deletion semantics or reopen the bounded lifecycle posture settled in Phases 115 through 118. [VERIFIED: codebase grep]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PK-02 | Last-passkey safety is closed by a Phase 115 verification artifact plus Nyquist coverage, and active truth no longer treats `115-01-SUMMARY.md` as authoritative proof. [VERIFIED: codebase grep] | The runtime behavior is already present on current HEAD and later proof exists in Phase 117 targeted tests and Phase 118 Playwright. Phase 119 should backfill `115-VERIFICATION.md`, create `115-VALIDATION.md`, and reconcile the active v1.26 truth set without widening into unrelated milestone archaeology. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

`PK-02` is functionally shipped but audit-orphaned. The v1.26 milestone audit already proves the important technical fact pattern: the library computes delete posture in `lib/sigra/passkeys.ex`, the example host consumes that result in `test/example/lib/example/accounts.ex`, the last-passkey warning and post-delete fallback truth render through `test/example/lib/example_web/live/mfa_settings_live.ex` and `test/example/lib/example_web/controllers/session_controller.ex`, and later evidence in Phase 117 targeted tests plus Phase 118 Playwright exercises the real surfaces. [VERIFIED: codebase grep]

What is missing is authority, not implementation. Phase 115 never produced `115-VERIFICATION.md` or `115-VALIDATION.md`, and `115-01-SUMMARY.md` still records a runtime verification gap. The best Phase 119 approach is therefore:

1. create an authoritative `115-VERIFICATION.md` that explicitly closes `PK-02` on current HEAD and supersedes `115-01-SUMMARY.md` as proof,
2. create a truthful `115-VALIDATION.md` that maps `PK-02` to the current focused test and browser-proof commands, and
3. reconcile only the live v1.26 truth surfaces that still describe `PK-02` as pending or orphaned. [VERIFIED: codebase grep]

The phase should stay narrow. It should not alter passkey behavior, broaden the milestone proof into new browser flows, or rewrite archived history wholesale. The precedent is Phase 102 and Phase 107: add the missing authoritative artifact, then update the active truth set so maintainers stop reading stale closure state as if it were current. [VERIFIED: codebase grep]

**Primary recommendation:** split execution into two plans. Plan 01 backfills the missing Phase 115 verification and validation artifacts. Plan 02, dependent on Plan 01, reconciles `REQUIREMENTS.md`, `PROJECT.md`, `STATE.md`, the live milestone audit, and the historical `115-01-SUMMARY.md` pointer so `PK-02` is clearly closed by the new Phase 115 artifacts. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Authoritative `PK-02` closeout | Planning / verification docs | Existing test and browser evidence | The gap is the absence of a phase-local verification artifact, not missing runtime behavior. [VERIFIED: codebase grep] |
| Focused evidence reruns | ExUnit / Playwright | planning docs | The closeout must cite replayable commands rather than only transitive claims from later summaries. [VERIFIED: codebase grep] |
| Nyquist backfill for Phase 115 | Validation doc | Verification doc | `115-VALIDATION.md` should become the living map of `PK-02` evidence and mark the phase Nyquist-complete instead of leaving the milestone audit with a missing-file blocker. [VERIFIED: codebase grep] |
| Active truth reconciliation | `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/v1.26-MILESTONE-AUDIT.md` | `115-01-SUMMARY.md` note | These are the files a future maintainer will read first when asking whether `PK-02` is still open. [VERIFIED: codebase grep] |
| Historical implementation record | `115-01-SUMMARY.md` | `115-VERIFICATION.md` | The summary should remain historical but cease being interpreted as the last word on verification state. [VERIFIED: codebase grep] |

## Project Constraints

- Treat existing passkey CRUD, delete semantics, and generated-host copy as shipped foundation; Phase 119 is evidence repair, not feature work. [VERIFIED: `.planning/REQUIREMENTS.md`]
- Prefer bounded reconciliation of active truth surfaces over repo-wide cleanup. [VERIFIED: `.planning/phases/118-generated-host-proof-milestone-closeout/118-CONTEXT.md`]
- Keep the distinction explicit: Phase 115 implemented `PK-02`; Phase 119 backfills the missing verification and Nyquist authority. [VERIFIED: codebase grep]
- Do not claim fresh milestone closure beyond `PK-02`; `PK-03` and the remaining v1.26 audit debt stay Phase 120/121 scope. [VERIFIED: `.planning/ROADMAP.md`, `.planning/v1.26-MILESTONE-AUDIT.md`]
- Verification must stay replayable and concrete. If any focused rerun fails, the backfill artifacts must record the failure honestly rather than silently inheriting Phase 118 confidence. [VERIFIED: codebase grep]

## Standard Stack

### Core
| Library / Tool | Version / Source | Purpose | Why Standard |
|----------------|------------------|---------|--------------|
| ExUnit / Phoenix test harness | repo-local | Focused proof for library, generator, and example-host seams | The required `PK-02` behaviors are already covered by existing test modules; Phase 119 should reuse them rather than inventing new probes. [VERIFIED: codebase grep] |
| Playwright example proof | repo-local under `test/example/priv/playwright` | Served-route proof for last-passkey consequences | Phase 118 already established `passkey-options.spec.ts` as the canonical browser proof for last-passkey behavior on real routes. [VERIFIED: codebase grep] |
| Markdown planning artifacts under `.planning/` | repo-local | Verification, validation, and truth reconciliation | The missing deliverables are documentation artifacts whose authority comes from exact file paths and command receipts. [VERIFIED: codebase grep] |

### Supporting
| Library / Tool | Purpose | When to Use |
|----------------|---------|-------------|
| `rg` | Active-truth reconciliation and acceptance greps | Use to prove stale references to `115-01-SUMMARY.md` or “missing 115-VERIFICATION.md” have been removed from live files. [VERIFIED: codebase grep] |
| `gsd-sdk query state.planned-phase` | Update planning state after plan creation | Use after plans are written so `STATE.md` reflects that Phase 119 is ready to execute. [VERIFIED: workflow docs] |

## Architecture Patterns

### Pattern 1: Phase-Local Verification Supersedes an Implementation Summary

**What:** Keep `115-01-SUMMARY.md` as implementation history, but create `115-VERIFICATION.md` as the authoritative `PK-02` closure artifact. [VERIFIED: codebase grep]

**When to use:** When a phase shipped behavior but never produced the verification document later milestone truth expects. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`]

**Example shape:** mirror the direct, replayable style used by `117-VERIFICATION.md` and `118-VERIFICATION.md`, but scoped to `PK-02` and Phase 115. [VERIFIED: codebase grep]

### Pattern 2: Bounded Active-Truth Reconciliation

**What:** Update only the files a maintainer would read as present-tense truth: `REQUIREMENTS.md`, `PROJECT.md`, `STATE.md`, and the live v1.26 milestone audit. [VERIFIED: `.planning/phases/118-generated-host-proof-milestone-closeout/118-CONTEXT.md`]

**When to use:** After the missing authoritative artifact exists and stale files would otherwise continue to advertise a closed gap as open. [VERIFIED: codebase grep]

**Anti-pattern:** rewriting archived milestone bundles or broad retrospective files merely because they mention the old state. [VERIFIED: `.planning/phases/118-generated-host-proof-milestone-closeout/118-CONTEXT.md`]

### Pattern 3: Validation Backfill Is an Evidence Map, Not a New Test Plan

**What:** `115-VALIDATION.md` should describe the actual focused `PK-02` proof commands and mark their status honestly. [VERIFIED: codebase grep]

**When to use:** When Nyquist validation is enabled but the phase already shipped and the test files already exist. [VERIFIED: `.planning/config.json`, `.planning/v1.26-MILESTONE-AUDIT.md`]

**Why:** The missing file is itself the blocker; Phase 119 should not pretend there is undiscovered Wave 0 work if the evidence seams already exist. [VERIFIED: codebase grep]

## Anti-Patterns to Avoid

- **Treating Phase 118 proof as sufficient without a Phase 115 artifact:** this leaves `PK-02` orphaned exactly as the milestone audit reports it. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`]
- **Marking `115-VALIDATION.md` compliant without explicit command mapping:** Nyquist closure requires a real verification map, not just a frontmatter flip. [VERIFIED: codebase grep]
- **Rewriting all of `v1.26-MILESTONE-AUDIT.md` as if it never found gaps:** the audit should remain historical, but the `PK-02` portions need a clear supersession note or updated disposition. [VERIFIED: codebase grep]
- **Reopening passkey semantics in code:** this phase should not change `lib/sigra/passkeys.ex`, generated templates, or passkey UX copy unless a focused rerun proves they are currently broken. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Closing `PK-02` with transitive prose instead of replayable commands

**What goes wrong:** The new verification doc merely says “Phase 118 already proved this” without rerunnable command receipts or exact evidence links. [VERIFIED: codebase grep]

**How to avoid:** Include the exact focused ExUnit and Playwright commands, their outcomes, and the specific files they prove. [VERIFIED: `117-VERIFICATION.md`, `118-VERIFICATION.md`]

### Pitfall 2: Updating `REQUIREMENTS.md` before the backfill artifact exists

**What goes wrong:** The live requirement row claims `PK-02` is verified while `115-VERIFICATION.md` is still absent. [VERIFIED: codebase grep]

**How to avoid:** Make the truth-reconciliation plan depend on the verification/validation backfill plan. [VERIFIED: phase design]

### Pitfall 3: Leaving `115-01-SUMMARY.md` unqualified after backfill

**What goes wrong:** A reader opens the summary first, sees “NOT VERIFIED,” and misses the new authoritative closeout. [VERIFIED: codebase grep]

**How to avoid:** Add a short supersession pointer in the summary or another immediately adjacent active surface so the reader is redirected to `115-VERIFICATION.md`. [VERIFIED: phase design]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit, Phoenix.LiveViewTest / controller tests, Playwright, and planning-file grep gates. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs`, `test/example/test/test_helper.exs`, and `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: codebase grep] |
| Quick run command | `MIX_ENV=test mix test test/sigra/passkeys_test.exs test/sigra/install/generator_passkey_management_test.exs --no-color && (cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs)` [VERIFIED: codebase grep] |
| Full suite command | `MIX_ENV=test mix test test/sigra/passkeys_test.exs test/sigra/install/generator_passkey_management_test.exs --no-color && (cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs) && (cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-options.spec.ts --project=chromium) && rg -n "115-VERIFICATION|115-VALIDATION|PK-02|Superseded by .*115-VERIFICATION|Phase 119" .planning/REQUIREMENTS.md .planning/PROJECT.md .planning/STATE.md .planning/v1.26-MILESTONE-AUDIT.md .planning/phases/115-last-passkey-safety-deletion-truth/115-01-SUMMARY.md .planning/phases/115-last-passkey-safety-deletion-truth/115-VERIFICATION.md .planning/phases/115-last-passkey-safety-deletion-truth/115-VALIDATION.md` [VERIFIED: codebase grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PK-02 | Library-owned delete posture remains correct on current HEAD. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`] | unit | `MIX_ENV=test mix test test/sigra/passkeys_test.exs --no-color` | ✅ [VERIFIED: codebase grep] |
| PK-02 | Generated-host templates still render the bounded last-passkey delete truth. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`] | generator | `MIX_ENV=test mix test test/sigra/install/generator_passkey_management_test.exs --no-color` | ✅ [VERIFIED: codebase grep] |
| PK-02 | Example-host settings and controller surfaces still prove the delete warning and post-delete fallback posture. [VERIFIED: `.planning/v1.26-MILESTONE-AUDIT.md`] | controller + LiveView | `cd test/example && CLOAK_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --trace --max-cases 1 test/example_web/live/passkey_settings_live_test.exs test/example_web/controllers/passkey_session_controller_test.exs` | ✅ [VERIFIED: codebase grep] |
| PK-02 | Served-route browser proof still exercises the last-passkey flow on the generated host. [VERIFIED: `118-VERIFICATION.md`] | Playwright | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/passkey-options.spec.ts --project=chromium` | ✅ [VERIFIED: codebase grep] |
| PK-02 | Active planning truth stops pointing at `115-01-SUMMARY.md` as authority. [VERIFIED: `.planning/ROADMAP.md`, `.planning/v1.26-MILESTONE-AUDIT.md`] | docs/grep | `rg -n "115-VERIFICATION|115-VALIDATION|Superseded by .*115-VERIFICATION|Phase 119" .planning/REQUIREMENTS.md .planning/PROJECT.md .planning/STATE.md .planning/v1.26-MILESTONE-AUDIT.md .planning/phases/115-last-passkey-safety-deletion-truth/115-01-SUMMARY.md` | ✅ [VERIFIED: codebase grep] |

### Sampling Rate
- **After every task commit:** run the smallest focused seam command for the artifact being updated. [VERIFIED: phase design]
- **After Plan 01 completes:** run the full suite command without the final `rg` gate if truth files are not reconciled yet. [VERIFIED: phase design]
- **Before `$gsd-verify-work`:** run the full suite command including the final `rg` gate. [VERIFIED: phase design]

### Wave 0 Gaps
- None. Existing test and proof files already cover the `PK-02` behavior; the gap is missing authoritative documentation, not missing harness infrastructure. [VERIFIED: codebase grep]

## Sources

### Primary (HIGH confidence)
- `.planning/ROADMAP.md` - Phase 119 goal, success criteria, and dependency chain. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md` - live `PK-02` requirement row and current pending-gap wording. [VERIFIED: codebase grep]
- `.planning/v1.26-MILESTONE-AUDIT.md` - authoritative statement of the orphaned `PK-02` gap and the current-head evidence already available. [VERIFIED: codebase grep]
- `.planning/phases/115-last-passkey-safety-deletion-truth/115-01-SUMMARY.md` - current stale proof pointer that must be superseded. [VERIFIED: codebase grep]
- `.planning/phases/115-last-passkey-safety-deletion-truth/115-RESEARCH.md` - original design and validation architecture for `PK-02`. [VERIFIED: codebase grep]
- `.planning/phases/117-cross-device-rp-id-trust-rails/117-VERIFICATION.md` - later targeted proof that already exercises the last-passkey flow on current HEAD. [VERIFIED: codebase grep]
- `.planning/phases/118-generated-host-proof-milestone-closeout/118-VERIFICATION.md` - browser-proof precedent and current generated-host evidence for `PK-02`. [VERIFIED: codebase grep]
- `test/sigra/passkeys_test.exs`, `test/sigra/install/generator_passkey_management_test.exs`, `test/example/test/example_web/live/passkey_settings_live_test.exs`, `test/example/test/example_web/controllers/passkey_session_controller_test.exs`, `test/example/priv/playwright/tests/passkey-options.spec.ts` - concrete proof seams the backfill should cite. [VERIFIED: codebase grep]
- `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md` and `.planning/phases/107-webhook-policy-operator-truth/107-03-PLAN.md` - bounded truth-reconciliation precedents. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)
- `.planning/PROJECT.md` - current milestone narrative that should reflect the repaired `PK-02` closure state. [VERIFIED: codebase grep]
- `.planning/STATE.md` - current operator handoff state that must stop advertising Phase 119 as only “planned” once execution lands. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)
- None. This phase can be planned entirely from repo-local evidence. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:** [VERIFIED: codebase grep]
- Runtime behavior: HIGH - already evidenced in the live milestone audit and later verification files. [VERIFIED: codebase grep]
- Artifact design: HIGH - strong precedents exist for backfilled verification plus bounded truth reconciliation. [VERIFIED: codebase grep]
- Remaining risk: MEDIUM - the example-host and Playwright reruns still depend on local environment availability, so execution must record failures honestly if they occur. [VERIFIED: codebase grep]

**Research date:** 2026-05-24 [VERIFIED: codebase grep]
**Valid until:** 2026-06-23 [VERIFIED: codebase grep]
