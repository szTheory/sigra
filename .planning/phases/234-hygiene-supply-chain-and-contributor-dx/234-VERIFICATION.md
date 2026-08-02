---
phase: 234-hygiene-supply-chain-and-contributor-dx
verified: 2026-08-02T01:40:59Z
status: gaps_found
score: 3/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "`mix ci` is a safe, reproducible local counterpart of the PR library gate, including formatter and generated-install-golden integrity checks."
    status: failed
    reason: "The current required golden/idempotency proof is red for generated `config/dev.exs` drift, and the documented alias destructively unlocks `threadline` and leaves `mix.lock` changed in a contributor worktree."
    artifacts:
      - path: "mix.exs"
        issue: "`sigra.dep_off` runs `deps.unlock threadline` without restoring the lockfile."
      - path: ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VALIDATION.md"
        issue: "The recorded golden/idempotency receipt exits 1 (generated `config/dev.exs` is 2,679 bytes vs 3,252-byte fixture)."
    missing:
      - "Make the dep-off leg restore `mix.lock`/dependency state or run it in an isolated workspace, with a non-dirty-worktree regression test."
      - "Reconcile the generated `config/dev.exs` golden/idempotency drift and make the required command exit 0."
  - truth: "Dependabot covers mix and npm as well as github-actions with GitHub-processed evidence for all three configured tuples."
    status: failed
    reason: "`234-EVIDENCE.json` records `dependabot.status: failed`; all three ecosystem slots lack authenticated GitHub job-log receipts. A valid YAML configuration alone is explicitly insufficient."
    artifacts:
      - path: ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json"
        issue: "github-actions:/, mix:/, and npm:/test/example/priv/playwright are each `failed` with `authenticated_browser_session_unavailable`."
    missing:
      - "Capture a successful processed Dependabot job ID, timestamp, status, log URL, and sanitized receipt hash for each exact ecosystem/directory tuple."
  - truth: "Validation remains fail-closed: only complete structural, command, and service evidence can authorize `complete`/`true` sign-off."
    status: failed
    reason: "`assert_transition_allowed!/3` sets `commands_green?` with `Enum.all?/2`; an empty command-receipt list is vacuously green and can authorize completion when evidence slots are green."
    artifacts:
      - path: "test/sigra/planning/phase_234_evidence_contract_test.exs"
        issue: "Line 516 does not require the exact non-empty receipt inventory; the tests cover a red row, but not no rows, missing rows, or malformed rows."
    missing:
      - "Require the exact expected command-receipt inventory and valid rows before completion, and add empty/missing/malformed receipt mutation tests."
  - truth: "When every listed command and evidence slot passes, 234-VALIDATION.md can record complete, nyquist_compliant true, wave_0_complete true, immutable evidence identifiers, and command results."
    status: failed
    reason: "The completion transition is unsound because it admits an empty command-receipt set; current validation correctly remains draft only because other residuals are red."
    artifacts:
      - path: "test/sigra/planning/phase_234_evidence_contract_test.exs"
        issue: "The sign-off test's hypothetical green case uses five in-memory rows but the production transition helper does not enforce that cardinality."
    missing:
      - "Share exact receipt-inventory validation between artifact parsing and transition authorization."
---

# Phase 234: Hygiene, Supply Chain, and Contributor DX Verification Report

**Phase Goal:** A contributor can reproduce the gate locally, and the repo's action/dependency surface stops drifting silently.
**Verified:** 2026-08-02T01:40:59Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | `mix ci` safely reproduces the PR library gate with formatter, lock, and golden integrity checks; CI invokes that same alias. | ✗ FAILED | `library_tests_shard` invokes literal `MIX_ENV=test mix ci` once and the structural contract passes, but `mix.exs` runs destructive `deps.unlock threadline`; the recorded golden/idempotency command exits 1 on `config/dev.exs` drift. |
| 2 | Every third-party release-critical action is SHA pinned with a version comment, and the pinned release action executed successfully on main. | ✓ VERIFIED | Release workflow uses 40-character refs including dereferenced Release Please SHA; action-pinning contract passed in the 29-test focused run; receipt names successful main run 30723565705/job 91431188895. |
| 3 | Dependabot covers github-actions, mix, and npm with processed-service evidence. | ✗ FAILED | `.github/dependabot.yml` has the exact three weekly tuples and its structural contract passes, but all three required service slots are `failed` in `234-EVIDENCE.json`. |
| 4 | Every live Playwright spec has an explicit executable CI-lane owner. | ✓ VERIFIED | `234-PLAYWRIGHT-INVENTORY.json` lists 20 sorted live specs; inventory contract reconciles files, workflow jobs, commands, and config seams and passed in the focused run. |
| 5 | SEED-006 is closed against a current real gallery run or has a durable residual. | ✓ VERIFIED | Seed contains Phase 234 delivered closeout and cites run 30723701267/job 91431828624: shared boot succeeded and 126 tests passed with zero retries; the separate non-gating admin-eval failure is identified. |
| 6 | Validation remains draft/non-compliant unless every structural, local, PR, release, Dependabot, inventory, gallery, and command-evidence requirement is green. | ✗ FAILED | Current frontmatter is correctly draft/false, but `Enum.all?([], ...)` in `assert_transition_allowed!/3` permits completion with no command receipts. |
| 7 | A fully green evidence set can authorize complete validation only with immutable IDs and valid command receipts. | ✗ FAILED | Artifact has IDs and five receipt rows, yet the transition helper does not require those rows; its green completion path is therefore not fail-closed. |

**Score:** 3/7 truths verified (0 present, behavior-unverified)

## All Plan Artifacts

All 14 PLAN/SUMMARY pairs were read; their claims were treated as leads only. Current artifact checks found the planned formatter boundary substantive (`mix format --check-formatted` exits 0) and the phase commits reachable through `876e315f`.

| Plans | Intended deliverable | Status | Codebase evidence |
| --- | --- | --- | --- |
| 01, 09 | Alias/CI parity and durable local/PR receipts | ✗ FAILED | Alias and CI call-through are wired, but its local safety and golden proof remain red. |
| 02–05, 11–13 | Golden-safe, repository-wide formatter cleanup | ⚠️ PARTIAL | Repository formatter check exits 0; the required golden/idempotency execution remains red. |
| 06 | Immutable release-action pins | ✓ VERIFIED | Focused mutation/structural contract passes; exact main release receipt exists. |
| 07 | Three Dependabot ecosystems | ✗ FAILED | Configuration/contract exists, but no successful managed-service processing evidence exists. |
| 08 | Full Playwright ownership inventory | ✓ VERIFIED | Exact-set inventory is live, substantive, and test-wired. |
| 10 | Release/Dependabot/gallery closeout | ✗ FAILED | Release and gallery receipts are good; Dependabot remains an explicit failed residual. |
| 14 | Fail-closed Nyquist sign-off | ✗ FAILED | Parser detects stale paths and red rows, but empty receipt lists bypass the completion gate. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `mix.exs` + `.github/workflows/ci.yml` | One local alias invoked by the PR library owner | ⚠️ PARTIAL | Exists, substantive, and wired at CI lines 493–541; `sigra.dep_off` changes a local lockfile. |
| `.formatter.exs` | Golden-safe formatter boundary | ✓ VERIFIED | Exists; full `mix format --check-formatted` passed; contract excludes generated golden-tree inputs. |
| `.github/workflows/release-please.yml` + action-pinning contract | Immutable release action inventory | ✓ VERIFIED | All release-workflow third-party `uses:` refs are SHA pins with semantic-version comments; focused contract passed. |
| `.github/dependabot.yml` + Dependabot contract | Exact three weekly dependency ecosystems | ⚠️ PARTIAL | Config and manifest links are substantive and contract-tested, but GitHub processing receipts are failed. |
| `234-PLAYWRIGHT-INVENTORY.json` + inventory contract | Exact live-spec-to-lane mapping | ✓ VERIFIED | 20 live specs reconcile against workflow command markers and Playwright config. |
| `234-EVIDENCE.json`, `234-VALIDATION.md`, evidence contract | Durable, fail-closed evidence sign-off | ✗ STUBBED GUARD | Files are substantive and parse/wiring tests pass, but completion authorization is vacuous for an empty receipt set. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `library_tests_shard` | `mix ci` | literal `MIX_ENV=test mix ci` | WIRED | Exactly once in workflow and in the owner job; focused contract passed. |
| release workflow | action-pinning contract | enumerated `uses:` lines | WIRED | Contract validates SHA form, comment, and forbidden annotated tag object. |
| Dependabot config | GitHub job-log evidence | three exact tuple receipts | NOT_WIRED | Config exists; all remote receipt slots explicitly failed. |
| Playwright inventory | CI workflow/config | job, seam, command marker, config seam | WIRED | Contract exercises both positive reconciliation and missing/stale/broken mutations. |
| evidence JSON | validation sign-off | all slots and receipts required before transition | PARTIAL | `:validation_signoff` parses artifact and stale-path mutation fails, but receipt cardinality is not enforced. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `234-PLAYWRIGHT-INVENTORY.json` | `specs` | globbed Playwright files plus CI/config seam tokens | Yes | ✓ FLOWING |
| `234-EVIDENCE.json` | service receipts | immutable run/job IDs and status fields | Dependabot rows are failed | ✗ HOLLOW for DX-03 |
| `234-VALIDATION.md` | command receipts/sign-off fields | parsed Markdown receipt table and JSON slots | Incomplete/unsound authorization | ✗ DISCONNECTED from fail-closed completion guarantee |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase structural contracts | `mix test` for the six Phase 234/related planning contracts | 29 tests, 0 failures | ✓ PASS |
| Validation stale/red handling | `mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff` | 3 tests, 0 failures | ✓ PASS (does not test empty receipts) |
| Repository formatter boundary | `mix format --check-formatted` | exit 0 | ✓ PASS |
| Golden/idempotency gate | `mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` | Current validation receipt records exit 1: generated `config/dev.exs` 2,679 bytes vs 3,252-byte fixture; direct local rerun could not complete without its required PostgreSQL service. | ✗ FAIL |

### Probe Execution

Step 7c: SKIPPED — no Phase 234 probe scripts were declared or discovered.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| DX-01 | 01–05, 09, 11–14 | `mix ci` reproduces the PR gate including formatting/lock checks | ✗ BLOCKED | CI call-through and formatting are verified, but local alias leaves `mix.lock` dirty and the required golden/idempotency proof is red. |
| DX-02 | 06, 10, 14 | Release-critical actions use immutable SHAs | ✓ SATISFIED | Pinning contract and successful post-pin main receipt. |
| DX-03 | 07, 10, 14 | Dependabot covers Hex/Mix and npm | ✗ BLOCKED | Configuration exists but all managed-service evidence slots are failed. |
| DX-04 | 08, 10, 14 | No Playwright spec is unowned | ✓ SATISFIED | Exact inventory/reconciliation contract passed. |
| DX-06 | 10, 14 | SEED-006 delivered or residual filed | ✓ SATISFIED | Current non-PR gallery execution and delivered seed closeout are present. |

No phase requirement is orphaned: every DX ID mapped to Phase 234 appears in at least one PLAN frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/sigra/planning/phase_234_evidence_contract_test.exs` | 516 | Vacuous `Enum.all?([])` acceptance | 🛑 BLOCKER | A supposedly fail-closed validation can authorize complete state without command receipts (CR-01). |
| `mix.exs` | 163–168 | Destructive local contributor alias | ⚠️ WARNING | `mix ci` can remove the `threadline` lock entry and leave a developer's worktree dirty (WR-01). |
| Phase-modified code | — | Unreferenced `TBD`/`FIXME`/`XXX` | None | No debt-marker blocker found in the scanned phase code. |

## Gaps Summary

Phase 234 is not achieved. The implementation correctly refuses to claim validation success today, but that is not a substitute for delivering the goal: DX-03 has no processed Dependabot proof, DX-01's required golden/idempotency proof is red and the advertised local command is destructive, and the sign-off mechanism itself has a completion bypass. Phase 235 only re-measures milestone outcomes; it does not specifically schedule these repairs, so none are deferred.

---

_Verified: 2026-08-02T01:40:59Z_
_Verifier: the agent (gsd-verifier)_
