---
phase: 236-flake-root-cause-reproduce-name-fix
verified: 2026-09-19T22:13:09Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - .github/workflows/ci.yml
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-01-PLAN.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-01-SUMMARY.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-02-PLAN.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-02-SUMMARY.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-03-PLAN.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-03-SUMMARY.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-04-PLAN.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-04-SUMMARY.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-05-PLAN.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-05-SUMMARY.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-DIAGNOSIS.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-SECURITY.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-UAT.md
  - .planning/research/STACK.md
  - lib/sigra/admin/live/audit_index_live.ex
  - scripts/ci/prohibitions/p12-run-id-provenance.test.mjs
  - scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs
  - test/example/test/example_web/live/admin_audit_index_live_test.exs
  - test/fixtures/prohibitions/p12-phase236-claim-without-run-id.md
  - test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts
  - test/sigra/planning/phase_236_audit_url_ownership_test.exs
  - test/sigra/planning/phase_236_evidence_provenance_guard_test.exs
  - test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs
covered_digest: "v1:sha256:aacb60ca9cfa834fcdc360898e40d5bde7532961fb8f01c136e75d53b2530ad2"
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "If it is the product race, /admin/audit has exactly one owner of its URL: no plain <form method=\"get\"> / <a href> competing against handle_params/3 in lib/sigra/admin/live/audit_index_live.ex"
    reason: "D-30 scope boundary: the chip-remove and prev/next anchors are rendered by lib/sigra/admin/components.ex, shared with the two D-30-excluded views; converting them opens the forbidden PNG recapture lane. Export CSV remains a controller document navigation. Residue is tracked in .planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md."
    accepted_by: szTheory
    accepted_at: 2026-09-15T23:05:00Z
re_verification:
  previous_status: passed
  previous_score: 5/5
  gaps_closed:
    - "T-236-03: Phase 236 RED provenance is now guarded by p12 in Fast checks."
    - "T-236-15: the five-run GREEN claim is now guarded by p12 in Fast checks."
  gaps_remaining: []
  regressions: []
---

# Phase 236: Flake Root Cause — Reproduce, Name, Fix — Verification Report

**Phase Goal:** `main`'s aggregate gate stops flipping red on an unchanged SHA — because the `Generated admin Playwright smoke` failure has a named, fixed cause, not because it was retried into silence.

**Verified:** 2026-09-19T22:13:09Z
**Status:** passed
**Verification mode:** Initial-mode refresh: the preceding report had no `gaps:` block. This report independently includes the subsequent 236-05 provenance closure.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A captured RED exists for the `toHaveURL` assertion before the fix. | ✓ VERIFIED | Live GitHub log for run `35004420339`, job `104500542292`, shows the failing `admin-generated.spec.ts:459` `toHaveURL` assertion and an `actor=`-absent received URL. The recorded local trace is present, 2,005,798 bytes, and `unzip -t` reports no archive errors. |
| 2 | The differential names and fixes the cause without competing URL ownership on the failing path. | ✓ VERIFIED (accepted scope override) | `236-DIAGNOSIS.md` names a product race, rules out harness and DB alternatives, and records D-05 branch (a). `AuditIndexLive` has `phx-submit`, six patch links, a whitelisted `handle_event`, and no I/O outside `handle_params/3`; the LiveView contract test exercises submit → patch → filtered rows. The accepted D-30 exception is retained above. |
| 3 | The affected job repeatedly passes after the fix and the reproduction no longer reproduces. | ✓ VERIFIED | GitHub API now reports `Generated admin Playwright smoke: success` for all five recorded PR runs (`35029916498`, `35030710957`, `35031404780`, `35032086557`, `35034938082`), all completed. The five retained after-fix batch logs each report `10 passed`, and p12 preserves the run-backed claim. |
| 4 | Retry masking is mechanically rejected and the dead retry environment variable is gone. | ✓ VERIFIED | p17 passes on the real surface, fails its committed known-bad fixture with the named `process.env` retry message, and is reached by CI's Fast checks glob. The parsed ExUnit contract proves `PLAYWRIGHT_RETRIES` is absent while the target job's remaining environment persists. |
| 5 | Quarantine is used only if the root cause cannot be fixed. | ✓ VERIFIED — N/A contingency | The product-race fix and repeated target-job evidence hold. No phase change added a quarantine row; the fallback did not trigger. |

**Score:** 5/5 roadmap truths verified (0 present-but-behavior-unverified).

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `236-EVIDENCE.md` | Durable RED/GREEN provenance | ✓ VERIFIED | Exactly three captured slots; default p12 validates all run IDs, producing commands, and in-slot corroboration. |
| `236-DIAGNOSIS.md` | Falsifiable differential diagnosis | ✓ VERIFIED | Names product race and documents branch (a) plus evidence-based rule-outs. |
| `audit_index_live.ex` | Single owner for failing-path URL transitions | ✓ VERIFIED | Substantive LiveView implementation; behavioral seam test passes. |
| `p17-no-playwright-retry-wrapper.test.mjs` + fixture | Fail-first retry prohibition | ✓ VERIFIED | Clean control passes; committed bad fixture exits 1 for the intended violation. |
| `p12-run-id-provenance.test.mjs` + Phase 236 fixture | Dual-ledger provenance enforcement | ✓ VERIFIED | Default run: 12/12; both malformed ledger fixtures fail specifically for missing run provenance. |
| `phase_236_*_test.exs` contracts | Independent ownership, retry, and provenance checks | ✓ VERIFIED | 22 targeted ExUnit tests pass. |
| `236-SECURITY.md` | Authoritative closure of T-236-03/T-236-15 | ✓ VERIFIED | `status: verified`, `threats_open: 0`, both rows closed, and all required sign-off markers pass the deterministic closure check. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Filter form | `handle_params/3` | `handle_event` → `index_path` → `append_query(Map.take(...))` → `push_patch` | ✓ WIRED | `handle_event` builds only a scope-local path; `handle_params` is the sole `Explorer.list_events` loader. |
| `@filter_param_keys` | rendered filtered result | `Map.take/2` and patched URL | ✓ WIRED | The LiveView test submits an actor, observes `assert_patch`, then observes only that actor's row. |
| p17/p12 guards | Fast checks | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | ✓ WIRED | Exact glob remains in `.github/workflows/ci.yml`; full local glob passed 112/112. |
| Phase 236 ledger | p12 default table | `PHASE_236_LEDGER` / `DEFAULT_LEDGER_SPECS` | ✓ WIRED | Default p12 run validates Phase 230 and Phase 236, each with its own floors. |
| Security closure | provenance controls | T-236-03/T-236-15 closure after p12 and ExUnit contracts | ✓ WIRED | Deterministic security-closure check passes. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `AuditIndexLive` | `@rows`, `@meta`, `@current_params` | `handle_params/3` → `Explorer.list_events` → audit query/presenter | Inserted test audit events render through the connected LiveView; submit removes the non-matching row. | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Recorded CI RED | `gh run view 35004420339 --log --job 104500542292` | Exact `toHaveURL` / received URL at line 459 observed. | ✓ PASS |
| Five CI target-job repeats | `gh run view` for all five recorded IDs | All target jobs completed `success`; Fast checks also `success`. | ✓ PASS |
| Dual-ledger p12 default | `node --test --test-reporter=tap ...p12...` | 12/12 pass. | ✓ PASS |
| p12 clean substitutions | `GSD_PROHIB_SUBJECT=... node --test ...p12...` | Archived Phase 230 and live Phase 236 ledgers each pass 6/6. | ✓ PASS |
| p12 negative controls | Both committed malformed-ledger substitutions | Both exit 1 with named missing-run provenance failures, not parse floors. | ✓ PASS |
| p17 clean and negative controls | p17 default and fixture substitution | Clean 5/5; fixture exits 1 with the named `process.env` retry failure. | ✓ PASS |
| All prohibition guards | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | 112/112 pass. | ✓ PASS |
| Phase source contracts | `MIX_ENV=test mix test` for three Phase 236 modules | 22 tests, 0 failures. | ✓ PASS |
| Connected filter behavior | `cd test/example && MIX_ENV=test mix test test/example_web/live/admin_audit_index_live_test.exs` | 5 tests, 0 failures; exercises submit, patch, and reloaded rows. | ✓ PASS |
| Render-preservation guard | `bash scripts/ci/snapshot-canary-guard.sh --base origin/main` | PASS; zero changed slugs. | ✓ PASS |

## Probe Execution

SKIPPED — no Phase 236 `probe-*.sh` path is declared or present. The phase's runnable controls are the targeted ExUnit, Node, shell, and GitHub API checks above.

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| GREEN-01 | 236-01, 236-04, 236-05 | Capture and retain a falsifiable RED before accepting the fix. | ✓ SATISFIED | Direct CI log, valid local trace, branch-(a) diagnosis, and CI-wired p12 provenance checks. |
| GREEN-02 | 236-02, 236-03, 236-04, 236-05 | Fix the URL ownership race and prohibit retry masking. | ✓ SATISFIED | Connected LiveView behavioral test, repeated CI target-job green evidence, p17 fail-first fixture, and parsed workflow contract. |

No orphaned Phase 236 requirements: `REQUIREMENTS.md` maps only GREEN-01 and GREEN-02, and every plan declares one or both.

### Decision Coverage

`check.decision-coverage-verify` reports **26/26** trackable CONTEXT decisions honored; no decision is missing from the shipped artifacts.

### Test Quality Audit

| Test File | Linked Requirement | Active | Skipped | Circular | Assertion Level | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| `phase_236_audit_url_ownership_test.exs` | GREEN-02 | 9 | 0 | No | Value/source contract | Pass — supplemented by the connected LiveView behavioral test. |
| `admin_audit_index_live_test.exs` | GREEN-02 | 5 | 0 | No | Behavioral | Pass — real SQL-backed inserted events, URL patch, and rendered result assertions. |
| p17/p12 Node guards | GREEN-01/02 | 17 | 0 | No | Value + negative control | Pass — external fixtures fail on the intended checks. |
| `phase_236_evidence_provenance_guard_test.exs` | GREEN-01/02 | 5 | 0 | No | Value/source contract | Pass — direct Node execution independently supplies the runtime proof. |

Disabled tests on requirements: 0. Circular patterns: 0. Insufficient assertions: 0.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `.planning/research/STACK.md` | 195, 201, 204, 269 | Historical prose still describes deleted `PLAYWRIGHT_RETRIES: 1` as current. | ⚠️ Warning | Documentation is misleading, though `.github/workflows/ci.yml`, p17, and the parsed ExUnit contract prove the variable is absent. This does not weaken the shipped enforcement. |
| Phase implementation files | — | `TBD` / `FIXME` / `XXX` debt-marker scan | — | None found. `placeholder=` is a user-facing input attribute; p17's `return null` is the deliberate clean result of a pure checker. |

## Human Verification

N/A — all phase acceptance criteria, including the user-visible LiveView transition, were exercised by deterministic automated contracts and direct GitHub API evidence. No behavior-dependent truth remains unexercised.

## Gaps Summary

No blocking gaps. The aggregate run conclusion remained `failure` on the five repeat runs for separately tracked Phase 235 contract-test debt, but the affected `Generated admin Playwright smoke` job was independently `success` on every run. That is not a retry-derived green and does not contradict the Phase 236 success criteria. The one accepted D-30 residual URL-navigation scope exception remains documented and todo-backed.

---

_Verified: 2026-09-19T22:13:09Z_
_Verifier: Codex (gsd-verifier)_
