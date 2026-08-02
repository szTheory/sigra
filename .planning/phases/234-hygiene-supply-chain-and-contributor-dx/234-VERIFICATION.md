---
phase: 234-hygiene-supply-chain-and-contributor-dx
verified: 2026-08-02T14:36:32Z
status: gaps_found
next_action: "Repair the evidence-slot exact-set validator and add a production-transition mutation for an extra failed slot."
next_command: "/gsd-plan-phase 234 --gaps"
score: 6/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/7
  gaps_closed:
    - "Completion authorization now calls all six concrete receipt validators and rejects bare or partial success-shaped receipts."
    - "Command receipts now bind to reviewed_commit_sha and to the 30-minute reviewed_at freshness window."
    - "Playwright inventory rows now bind to their own direct spec marker or one of two exact, resolved harness mappings."
  gaps_remaining:
    - "The claimed exact six-slot evidence set accepts arbitrary extra slots, including a failed one, because the validator compares only an intersection."
  regressions: []
gaps:
  - truth: "Validation completion is fail-closed for the exact required evidence set, so no added, red, inferred, or unvalidated evidence slot can be silently ignored."
    status: failed
    reason: "validate_required_evidence!/1 claims to require an exact six-slot set but compares the required slots with an intersection (lines 637-642). A receipts map containing all six valid slots plus an extra failed or malformed slot passes that check and can authorize complete/true/true. No mutation test exercises this path."
    artifacts:
      - path: "test/sigra/planning/phase_234_evidence_contract_test.exs"
        issue: "The exact-set assertion permits extra keys; transition mutations cover required slots only."
    missing:
      - "Require MapSet.new(Map.keys(receipts)) to equal the required six-slot set."
      - "Add production-path mutations with an extra failed slot and an extra malformed/success-shaped slot; both must reject completion."
---

# Phase 234: Hygiene, Supply Chain, and Contributor DX Verification Report

**Phase Goal:** A contributor can reproduce the gate locally, and the repo's action/dependency surface stops drifting silently.
**Verified:** 2026-08-02T14:36:32Z
**Status:** gaps_found
**Re-verification:** Yes — after Plans 19–20 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A contributor can run the seven-leg `MIX_ENV=test mix ci` gate without dirtying `mix.lock`; CI invokes the same alias once. | ✓ VERIFIED | `mix.exs:143-162` declares the seven legs and `ci.yml:541` is the direct invocation. The focused parity suite passed (31 tests); `scripts/ci/test-sigra-dep-off.sh` passed all six success/failure cleanup assertions. The committed detached-worktree receipt records exit 0 and identical pre/post lock and status hashes. |
| 2 | Release-critical third-party Actions are immutable SHA pins with version comments. | ✓ VERIFIED | The action-pinning contract passed; all five scoped `uses:` entries in `release-please.yml` and `hex-publish.yml` are 40-character SHA pins with comments. The committed release receipt identifies a successful `Run Release Please` execution using the dereferenced v5 SHA. |
| 3 | Dependabot covers GitHub Actions, Mix, and npm with processed-service evidence. | ✓ VERIFIED | `.github/dependabot.yml` contains exactly the three required weekly ecosystems/directories. The passing contract reconciles manifests/locks, and `234-EVIDENCE.json` contains three shaped successful processed-job receipts. |
| 4 | Every live Playwright spec is inventory-owned by the exact CI invocation, including only documented harness indirection. | ✓ VERIFIED | The live-set contract passed (6 tests). It now rejects a sibling-marker swap and allows only the two explicit mappings, tracing both harness sources to `admin-eval.spec.ts` and `admin-generated.spec.ts`. Inventory contains 20 live specs. |
| 5 | SEED-006 is closed against a current real gallery execution or tracked residual. | ✓ VERIFIED | The evidence ledger records dispatch `30723701267`: gallery job `91431828624` succeeded with `126 passed (5.4m)`, zero retries, and the non-gating admin-eval failure is separately diagnosed. |
| 6 | Completion authorization validates concrete receipts and uses one reviewed, fresh command-receipt snapshot. | ✓ VERIFIED | `assert_transition_allowed!/3` invokes all six receipt validators at lines 1068-1106; production-path bare/partial receipt mutations, wrong-SHA, stale/future, and ordering mutations passed in the named `validation_signoff` test run (5 tests). |
| 7 | Validation completion is fail-closed for the exact required evidence set. | ✗ FAILED | `validate_required_evidence!/1` uses `MapSet.intersection` at lines 637-642 rather than equality, so unvalidated extra evidence is tolerated despite the stated exact-set contract. |

**Score:** 6/7 truths verified (0 present, behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `mix.exs`, `ci.yml`, `scripts/ci/sigra-dep-off.sh` | Safe, shared local/CI gate | ✓ VERIFIED | Substantive alias, sole direct CI owner, cleanup trap, and deterministic cleanup harness are wired. |
| `.formatter.exs` | Golden-safe format boundary | ✓ VERIFIED | Formatter and golden/idempotency command completed successfully; generated tree remained unchanged. |
| release workflows + pinning contract | Immutable release-action surface | ✓ VERIFIED | Source pin inventory and focused mutation contract pass. |
| `.github/dependabot.yml`, `234-EVIDENCE.json` | Exact three-ecosystem coverage | ✓ VERIFIED | Configuration, local manifests, and processed receipt tuples are substantive and reconciled. |
| `234-PLAYWRIGHT-INVENTORY.json`, ownership contract | Exact spec-to-lane ownership | ✓ VERIFIED | JSON is populated; direct and documented harness wiring is enforced by mutation tests. |
| `234-VALIDATION.md`, evidence contract | Exact fail-closed final authorization | ✗ STUBBED GUARD | Concrete validation and freshness checks are wired, but unvalidated extra evidence slots remain accepted. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `library_tests_shard` | `mix ci` | literal `MIX_ENV=test mix ci` | WIRED | One direct call at `ci.yml:541`; the focused contract proves sole suite ownership and required aggregation. |
| Dependabot config | evidence ledger | exact processed tuple receipts | WIRED | Three configured tuples match three successful slot receipts. |
| Playwright inventory | workflow/harness invocation | row spec passed to spec-aware validator | WIRED | Direct marker equality and two allowlisted harness traces are exercised by mutations. |
| evidence ledger | validation transition | concrete receipt validators | WIRED | `assert_transition_allowed!/3` calls `validate_required_evidence!/1`, which dispatches all six validators. |
| evidence slot set | validation transition | exact required-slot check | NOT_WIRED | The implemented intersection test does not reject an extra unvalidated slot. |
| validation receipt table | reviewed revision | SHA and 30-minute freshness binding | WIRED | Validator compares every command SHA to `reviewed_commit_sha`, timestamps to `reviewed_at`, and tests wrong/stale cases. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Dependabot evidence | `slots` | Authenticated GitHub update-job receipts | Yes | ✓ FLOWING |
| Playwright inventory | `specs[].lanes` | Live spec glob, workflow jobs, and two harness sources | Yes | ✓ FLOWING |
| Validation approval | receipts and command receipt table | `234-EVIDENCE.json` and `234-VALIDATION.md` | Required slots flow through concrete validators; extra slots bypass validation | ✗ HOLLOW |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Exact Playwright ownership | `mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` | 6 tests, 0 failures | ✓ PASS |
| Related Playwright topology | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` | 6 tests, 0 failures | ✓ PASS |
| Concrete receipt and snapshot transition | `mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff` | 5 tests, 0 failures | ✓ PASS |
| Final evidence shape | `mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only final_evidence` | 1 test, 0 failures | ✓ PASS |
| All focused Phase 234 contracts | six-file focused `mix test` command from validation receipt | 31 tests, 0 failures | ✓ PASS |
| Golden-safe formatter boundary | `mix format --check-formatted` plus golden/idempotency tests | Exit 0; no generated-tree diff | ✓ PASS |
| Contributor cleanup invariants | `bash scripts/ci/test-sigra-dep-off.sh` | 6 passed, 0 failed | ✓ PASS |

The ExUnit commands emitted expected unavailable-local-Postgres connection noise but no test failures; these planning contracts do not require a database connection.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| DX-01 | 01–05, 09, 11–16, 18, 20 | `mix ci` reproduces PR gate with formatting/lock checks | ✓ SATISFIED | Seven-leg alias, direct CI call, formatter/golden checks, cleanup harness, and recorded clean run. |
| DX-02 | 06, 10, 14, 18, 20 | Release-critical Actions use immutable SHAs | ✓ SATISFIED | Exact scoped pin inventory and passing contract; successful post-pin release receipt. |
| DX-03 | 07, 10, 14, 17–18, 20 | Dependabot covers Mix/npm/Actions | ✓ SATISFIED | Exact config and three processed service receipts. |
| DX-04 | 08, 10, 14, 18–20 | No Playwright spec is unowned | ✓ SATISFIED | Exact inventory-to-direct/harness invocation ownership is now mutation-protected. |
| DX-06 | 10, 14, 18, 20 | SEED-006 delivered or residual filed | ✓ SATISFIED | Current gallery evidence and isolated non-gating diagnostic are recorded. |

No Phase 234 requirement is orphaned: all five IDs occur in plan frontmatter. Phase 235 does not specifically schedule the remaining validation-authority repair, so it is not deferred.

### Review Adjudication

The five findings in `234-REVIEW.md` concern SSRF, atom exhaustion, Chimeway credentials, validation persistence, and refresh-token concurrency in application code. They are serious but are unrelated to this phase's hygiene/supply-chain/contributor-DX deliverables and are not used to decide this phase verdict. The prior Phase 234 verification findings CR-01, CR-02, and the unbound Playwright marker are closed by the current source and deterministic tests.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `phase_234_evidence_contract_test.exs` | 637–642 | Intersection presented as an exact evidence-set check | 🛑 BLOCKER | A new failed or malformed evidence slot can be ignored while completion is authorized. |
| Phase-owned contract/config files | — | `TBD` / `FIXME` / `XXX` markers | None | No unreferenced debt-marker blocker found. |

### Gaps Summary

The repaired artifacts substantively deliver the five roadmap outcomes, and every named deterministic test run passed. However, Phase 234's completion contract still contradicts its fail-closed evidence claim: it silently accepts an evidence map with additional unvalidated slots. This is a phase-goal blocker because the phase exists to prevent action/dependency evidence from drifting silently. Repair the equality check and add the two production-transition mutations before ratifying the phase.

---

_Verified: 2026-08-02T14:36:32Z_
_Verifier: the agent (gsd-verifier)_
