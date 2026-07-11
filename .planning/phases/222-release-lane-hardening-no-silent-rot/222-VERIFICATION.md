---
phase: 222-release-lane-hardening-no-silent-rot
verified: 2026-07-11T00:00:00Z
status: passed
score: 3/3 must-haves verified
behavior_unverified: 0
overrides_applied: 1
operator_waiver:
  - item: "Live red-probe of the release-lane loud signal"
    decision: "Waived by operator (Jon) on 2026-07-11 — offline proof accepted as sufficient to close the phase."
    rationale: "All 3 must-haves VERIFIED (3/3). The notify script logic is unit-proven (notify-failure-issue.test.sh 3/3) and the workflow wiring is structurally proven (phase_222 tests); the hex-publish dry-run is live-green. The only unexercised path is a live GitHub Issues API round-trip that requires deliberately reddening main — inherently destructive, intentionally classified Manual-Only by the phase, and non-blocking for goal achievement. Documented as the operator red-probe in MAINTAINING.md §3 for on-demand exercise."
human_verification:
  - test: "Red-probe the loud signal: force a failing ci-gate on main (throwaway commit that fails a required check) and confirm notify_release_lane_rot opens/updates the release-lane-rot GitHub Issue against the live Issues API."
    expected: "A single GitHub Issue labeled release-lane-rot is created (or commented on if one is already open) with the run URL, commit SHA, and failing surface."
    why_human: "Requires dispatching a real failing run against GitHub's live Issues API with a real GITHUB_TOKEN. Cannot be proven offline/hermetically — the phase itself classified this Manual-Only (222-VALIDATION) and documented it as the operator red-probe in MAINTAINING.md. The script logic is unit-proven (create-once/comment-once/fail-closed) and the wiring is structurally proven; only the live end-to-end API call is unexercised."
---

# Phase 222: Release-Lane Hardening (No Silent Rot) Verification Report

**Phase Goal:** The release lane can no longer silently strand a release — the `Upgrade smoke` gate is made un-rot-able and release-please auto-publish is proven to fire on a green gate (or fail loudly), with the recovery path documented.
**Verified:** 2026-07-11
**Status:** passed (operator-waived the one Manual-Only live red-probe; offline proof accepted — see `operator_waiver` frontmatter)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 (HARD-01) | The `Upgrade smoke` gate can no longer rot unnoticed — un-rot-able resolver OR a red result on main raises a loud, discoverable signal | ✓ VERIFIED | Resolver hardening behaviorally proven offline (`upgrade-smoke.test.sh` 4/4 PASS: default exclusion picks real GA 1.3.0 over stray 1.20.0, comma-configurable, fail-closed, series-scoped); D-13 pin removed (`grep -c SIGRA_UPGRADE_SMOKE_START_VERSION ci.yml` = 0) while escape hatch + `resolve_latest_sigra_source` survive in `upgrade-smoke.sh`; `notify_release_lane_rot` job present, wired to shared script, gated `event_name != pull_request && ci-gate.result == 'failure'`, job-level `issues: write`, and absent from `ci-gate.needs` (structural test 222-01 passes). Live signal-firing is an operator red-probe — see Human Verification. |
| 2 (HARD-02) | release-please auto-publish verified end-to-end on a green ci-gate OR fails loudly (not silently) when blocked | ✓ VERIFIED | Dry-run readiness proof confirmed **live** via `gh run view 29132375168`: conclusion `success`; `Dry run Hex publish` = success while `Publish to Hex`, `Verify version on Hex.pm`, `Verify HexDocs source links`, `Upload release post-publish evidence` all = **skipped** (no Hex write). `hex-publish.yml` guards confirmed (`Publish to Hex` has `if: inputs.dry_run != true`). Fail-loudly branch: `notify-release-failure` job present, `needs: [release-please, gate-ci-green, publish-hex]`, gated on `release_created == 'true'` and failed/cancelled gate/publish, uses workflow-level `issues: write`, invokes shared script (structural test 222-03 passes). notify script logic unit-proven (`notify-failure-issue.test.sh` 3/3 PASS). |
| 3 (HARD-02) | The recovery / manual-dispatch runbook (hex-publish.yml workflow_dispatch with tag + release_version + dry_run) is documented | ✓ VERIFIED | `MAINTAINING.md` §"Release-lane rot signals & recovery (HARD-01/HARD-02)" (line 278) documents verbatim `gh workflow run "Hex publish (manual recovery)" -f tag=<tag> -f release_version=<version> -f dry_run=true`, when to use it vs auto-publish, how to read a `gate-ci-green` ~30-min timeout, where the `release-lane-rot` tracking Issue surfaces, the red-probe pattern, and cross-references `docs/release-runbook-v1-0.md` without duplicating the matrix. Structural test 222-04 passes (heading, inputs, label, cross-ref, insertion point). |

**Score:** 3/3 truths verified (1 operator red-probe deferred to human verification)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/ci/lib/resolve-sigra-source.sh` | Sourceable resolver with durable stray-exclusion | ✓ VERIFIED | Exact-line fixed-string `grep -vxF` via `SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS` (default 1.20.0); fail-closed on empty candidate set; array-split (shellcheck-clean). Sourced by `upgrade-smoke.sh:15`. |
| `scripts/ci/upgrade-smoke.test.sh` | Offline 4-case hermetic self-test | ✓ VERIFIED | Runs; 4 passed / 0 failed. Wired into `fast_checks`. |
| `scripts/ci/notify-failure-issue.sh` | Shared idempotent secret-safe tracking-issue script | ✓ VERIFIED | Reads LABEL/TITLE/BODY/GH_TOKEN (fail-closed via `:?`); find-open-by-label → comment-or-create; never echoes token. |
| `scripts/ci/notify-failure-issue.test.sh` | Offline 3-case self-test | ✓ VERIFIED | Runs; 3 passed / 0 failed (create-once / comment-once / fail-closed). Wired into `fast_checks`. |
| `test/sigra/planning/phase_222_release_lane_hardening_test.exs` | Structural coverage of both consumers + runbook | ✓ VERIFIED | 4 tests (222-01..04) pass. |
| `MAINTAINING.md` | Recovery runbook subsection | ✓ VERIFIED | Subsection present at line 278 with all required content. |

### Key Link Verification

| From | To | Via | Status |
| --- | --- | --- | --- |
| `upgrade-smoke.sh` | `lib/resolve-sigra-source.sh` | `source` at :15 | ✓ WIRED |
| `ci.yml notify_release_lane_rot` | `notify-failure-issue.sh` | `bash scripts/ci/notify-failure-issue.sh` | ✓ WIRED |
| `release-please.yml notify-release-failure` | `notify-failure-issue.sh` | `bash scripts/ci/notify-failure-issue.sh` | ✓ WIRED |
| `notify_release_lane_rot` | `ci-gate` | `needs: [ci-gate]` (NOT in ci-gate.needs) | ✓ WIRED / correctly not-required |
| `ci.yml fast_checks` | both `*.test.sh` self-tests | `run: bash ...test.sh` | ✓ WIRED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Resolver picks GA over stray, fail-closed, series-scoped | `bash scripts/ci/upgrade-smoke.test.sh` | 4 passed, 0 failed | ✓ PASS |
| Notify script create-once/comment-once/fail-closed | `bash scripts/ci/notify-failure-issue.test.sh` | 3 passed, 0 failed | ✓ PASS |
| Structural workflow/runbook shape | `mix test phase_222 + phase_147` | 7 tests, 0 failures | ✓ PASS |
| Dry-run publish path green, no Hex write | `gh run view 29132375168` | conclusion success; Publish to Hex skipped | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| HARD-01 | 222-01, 222-02 | Upgrade smoke gate can no longer rot unnoticed | ✓ SATISFIED | Resolver un-rot-able + pin retired + loud red-main tracking Issue mechanism |
| HARD-02 | 222-02, 222-03 | Auto-publish verified-or-fails-loudly + recovery runbook | ✓ SATISFIED | Live green dry-run + notify-release-failure aggregator + MAINTAINING.md runbook |

Both requirement IDs from PLAN frontmatter accounted for; both marked `[x]` Complete in REQUIREMENTS.md. No orphaned requirements.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX` debt markers in any changed file. Two shellcheck adjustments in Plan 01 (SC2086 array-split, scoped SC2329 false-positive disable) are documented and behavior-neutral. Five pre-existing, unrelated actionlint/shellcheck warnings in `ci.yml` were confirmed present on baseline `main` and logged to `deferred-items.md` (out of scope, not regressions).

### Human Verification Required

**1. Live red-probe of the loud signal**

**Test:** Force a failing `ci-gate` on `main` (throwaway commit failing a required check) and confirm `notify_release_lane_rot` opens/updates the `release-lane-rot` GitHub Issue.
**Expected:** A single Issue labeled `release-lane-rot` is created (or commented if already open) carrying the run URL, commit SHA, and failing surface.
**Why human:** Requires a real failing run against GitHub's live Issues API with a real `GITHUB_TOKEN` — not offline-provable. The phase deliberately classified this Manual-Only (222-VALIDATION) and documented it as the operator red-probe in MAINTAINING.md §3. The script behavior (create-once/comment-once/fail-closed) and the workflow wiring are already proven by the hermetic self-test and the structural test; only the live API round-trip is unexercised.

### Gaps Summary

No blocking gaps. All three ROADMAP success criteria are substantively delivered and verified at the buildable + testable level:

- **SC1 (HARD-01)** — the specific rot vector (stray `1.20.0` out-sorting the GA + the hand-maintained `SIGRA_UPGRADE_SMOKE_START_VERSION` pin masking it) is durably and behaviorally eliminated offline; the loud red-main signal mechanism is present, wired, and unit-proven.
- **SC2 (HARD-02)** — the OR-branch is honestly delivered: the `hex-publish.yml dry_run=true` readiness proof against v1.3.0 was independently re-confirmed **live** (run 29132375168, publish steps skipped = no Hex write), and `notify-release-failure` converts a silent 30-min stall into a durable tracking Issue.
- **SC3 (HARD-02)** — the recovery/manual-dispatch runbook exists in MAINTAINING.md, is structurally tested, and cross-references the canonical runbook.

The single outstanding item — a live red-probe confirming the notify job actually writes an Issue against GitHub's Issues API — is an inherently operator-side check the phase intentionally deferred and documented. It does not block goal achievement; it raises status to `human_needed` per the verification decision tree.

---

_Verified: 2026-07-11_
_Verifier: Claude (gsd-verifier)_
