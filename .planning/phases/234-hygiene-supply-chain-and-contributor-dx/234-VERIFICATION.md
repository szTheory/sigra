---
phase: 234-hygiene-supply-chain-and-contributor-dx
verified: 2026-08-02T03:26:33Z
status: gaps_found
score: 4/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/7
  gaps_closed:
    - "The dep-off leg restores mix.lock and dependency state; a clean detached mix ci receipt is now present."
    - "Dependabot has exact successful processed-job receipts for github-actions, mix, and npm."
    - "The command receipt inventory is now exactly five rows and is shared by parsing and transition authorization."
  gaps_remaining:
    - "Completion authorization accepts malformed bare success evidence slots."
    - "Command receipts are not bound to the reviewed revision or a freshness window."
    - "A Playwright spec can borrow another spec's valid command marker."
  regressions: []
gaps:
  - truth: "No empty, partial, inferred, skipped, red, malformed, or stale evidence set authorizes complete/true/true."
    status: failed
    reason: "assert_transition_allowed!/3 checks only that each slot is a map whose status is success. Its own green test supplies six bare %{\"status\" => \"success\"} maps and is authorized complete, bypassing the concrete receipt validators."
    artifacts:
      - path: test/sigra/planning/phase_234_evidence_contract_test.exs
        issue: "Lines 529-543 demonstrate malformed receipt acceptance; lines 741-745 never call local, PR, release, Dependabot, gallery, or historical-gallery validators."
    missing:
      - "Validate every concrete evidence slot in assert_transition_allowed!/3 and add malformed-success mutations through that production transition path."
  - truth: "234-VALIDATION.md changes to complete/true/true only after structural, local-command, and GitHub-service evidence is currently green."
    status: failed
    reason: "The five command rows have syntax, order, exit, and hash checks, but no receipt commit SHA, equality-to-reviewed-revision check, or freshness limit. A historical green table can authorize a changed revision."
    artifacts:
      - path: test/sigra/planning/phase_234_evidence_contract_test.exs
        issue: "validate_command_receipts!/1 at lines 706-730 accepts any syntactically valid UTC timestamp; the stale mutation at lines 571-575 changes command text rather than time or revision."
    missing:
      - "Bind every command receipt to the reviewed commit and reject stale timestamps; add wrong-SHA and stale-timestamp transition mutations."
  - truth: "Every Playwright inventory row names a CI lane that invokes that exact spec, and changed lane ownership fails closed."
    status: failed
    reason: "validate_spec!/3 discards spec and validate_lane!/3 only tests whether the marker occurs anywhere in the job. Swapping admin-theme.spec.ts for another existing marker in the same job remains valid."
    artifacts:
      - path: test/sigra/planning/phase_234_playwright_inventory_contract_test.exs
        issue: "Lines 159-162 call validate_lane!/3 without spec; line 197 uses unbound job =~ command_marker."
    missing:
      - "Pass the spec to lane validation, require the exact spec invocation except documented harness cases, and add a swapped-existing-marker mutation."
---

# Phase 234: Hygiene, Supply Chain, and Contributor DX Verification Report

**Phase Goal:** A contributor can reproduce the gate locally, and the repo's action/dependency surface stops drifting silently.
**Verified:** 2026-08-02T03:26:33Z
**Status:** gaps_found
**Re-verification:** Yes — after Plans 15–18 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A contributor can run the seven-leg `MIX_ENV=test mix ci` gate without dirtying `mix.lock`; CI invokes the same alias once. | ✓ VERIFIED | `mix.exs:143-162` defines all seven legs; `ci.yml:493-541` has the sole owner and one literal invocation. `bash scripts/ci/test-sigra-dep-off.sh` passed all six cleanup assertions; local receipt records clean pre/post hashes and exit 0. |
| 2 | Release-critical third-party actions are immutable SHA pins with version comments. | ✓ VERIFIED | The focused action-pinning contract passed; its explicit live universe is `release-please.yml` and `hex-publish.yml`, and Release Please uses `45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0`. |
| 3 | Dependabot covers GitHub Actions, Mix, and npm with processed-service evidence. | ✓ VERIFIED | Config hash is exactly `a689…44e0`; `234-EVIDENCE.json` has three ordered successful tuple receipts with numeric job IDs, UTC timestamps, GitHub URLs, and 64-char sanitized hashes. Dependabot contract passed. |
| 4 | Every live Playwright spec is inventory-owned by a lane that actually invokes that exact spec, and drift fails closed. | ✗ FAILED | The current 20-row inventory is present, but its verifier permits a row to borrow another spec's marker in the same job. This fails the required drift-proof, not merely a cosmetic test detail. |
| 5 | SEED-006 is closed against a current real gallery execution or tracked residual. | ✓ VERIFIED | The seed’s Phase 234 closeout cites run `30723701267`, gallery job `91431828624`, `126 passed (5.4m)`, zero retries, and correctly isolates the non-gating admin-eval failure. |
| 6 | Validation completion is fail-closed against malformed/inferred evidence. | ✗ FAILED | `assert_transition_allowed!/3` authorizes six bare success maps rather than concrete, validated receipts. This is the review’s CR-01, independently confirmed from current lines 529-543 and 741-745. |
| 7 | Validation completion uses current evidence for the reviewed state. | ✗ FAILED | Exact five-row cardinality is repaired, but command receipts carry neither revision identity nor a freshness bound. CR-02 remains valid. |

**Score:** 4/7 truths verified (0 present, behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `mix.exs`, `ci.yml`, `scripts/ci/sigra-dep-off.sh` | One safe local/CI gate | ✓ VERIFIED | Substantive alias, direct CI call-through, and harness are wired. |
| `.formatter.exs` | Golden-safe formatting boundary | ✓ VERIFIED | Inputs enumerate intended sources without the generated golden tree; the recorded formatter receipt exits 0. |
| release workflows + pinning contract | Immutable release-action surface | ✓ VERIFIED | Focused contract passes and source refs are 40-character SHAs with comments. |
| `.github/dependabot.yml`, evidence ledger | Exact three-ecosystem coverage | ✓ VERIFIED | Config, manifest links, receipts, and receipt schema are substantive and matched. |
| `234-PLAYWRIGHT-INVENTORY.json`, ownership contract | Exact spec-to-executable-lane mapping | ✗ STUBBED GUARD | Inventory is populated and current, but the guard's key spec-to-marker link is not bound. |
| `234-VALIDATION.md`, evidence contract | Current fail-closed authorization | ✗ STUBBED GUARD | Shared command validator is wired, but receipt-schema and freshness validation are omitted from the transition. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `library_tests_shard` | `mix ci` | literal `MIX_ENV=test mix ci` | WIRED | One direct call at `ci.yml:541`; protected `Library tests` aggregate consumes it. |
| Dependabot config | evidence ledger | exact tuple receipts | WIRED | Three configured tuples match three successful ledger slots; config hash matches current file. |
| Playwright inventory | workflow command | per-spec marker | NOT_WIRED | The validator only proves a marker exists in the job, not that it is the inventory spec. |
| evidence ledger | validation transition | concrete receipt validators | NOT_WIRED | Transition checks status strings only, allowing fabricated malformed receipts. |
| validation receipt table | reviewed revision | revision/freshness binding | NOT_WIRED | No command receipt SHA or age policy exists. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Dependabot evidence | `slots` | Authenticated GitHub update-job identifiers | Yes | ✓ FLOWING |
| Playwright inventory | `specs[].lanes` | Live spec glob plus workflow/config markers | Current values populated, ownership binding absent | ✗ HOLLOW |
| Validation approval | command/evidence receipts | Markdown table and JSON evidence | Can be supplied by stale or malformed success-shaped values | ✗ DISCONNECTED from fail-closed claim |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Receipt inventory mutation suite | `mix test …phase_234_evidence_contract_test.exs --only validation_signoff` | 3 tests, 0 failures; nevertheless fixture demonstrates bare-success bypass | ✗ FAIL (test is insufficient) |
| Playwright ownership reconciliation | `mix test …phase_234_playwright_inventory_contract_test.exs` | 4 tests, 0 failures; source inspection proves swapped valid marker is untested/accepted | ✗ FAIL (test is insufficient) |
| Contributor dep-off cleanup | `bash scripts/ci/test-sigra-dep-off.sh` | 6 passed, 0 failed | ✓ PASS |
| Alias, library owner, action pin, Dependabot contracts | focused four-file `mix test` run | 17 tests, 0 failures | ✓ PASS |

The focused ExUnit runs emitted expected unavailable-local-Postgres connection noise, but all listed planning tests passed and do not require a database assertion.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| DX-01 | 01–05, 09, 11–18 | `mix ci` reproduces PR gate with formatting/lock checks | ✓ SATISFIED | Safe alias, CI direct call, cleanup regression, and green detached receipt. |
| DX-02 | 06, 10, 14, 18 | Release-critical Actions use immutable SHAs | ✓ SATISFIED | Source inventory and passing focused mutation contract. |
| DX-03 | 07, 10, 14, 17–18 | Dependabot covers Mix/npm/Actions | ✓ SATISFIED | Exact config plus three processed GitHub receipts. |
| DX-04 | 08, 10, 14, 18 | No Playwright spec is unowned | ✗ BLOCKED | Present inventory has 20 rows, but missing spec-to-marker binding means the required anti-drift guarantee is not enforceable. |
| DX-06 | 10, 14, 18 | SEED-006 delivered or residual filed | ✓ SATISFIED | Current and historical gallery evidence is recorded in the seed and ledger. |

No Phase 234 requirement is orphaned: each listed DX ID appears in PLAN frontmatter. Phase 235 does not specifically schedule any of these repairs, so none are deferred.

### Review Adjudication

| Finding | Verdict | Independent evidence |
| --- | --- | --- |
| CR-01 bare-success completion authorization | 🛑 BLOCKER — valid | Current test constructs `green_evidence` from bare success maps and expects `:complete`; production transition performs only the same status check. |
| CR-02 stale/unbound command receipts | 🛑 BLOCKER — valid | Current rows/validator lack a commit SHA and freshness window; the alleged stale mutation changes only command text. |
| WR-01 unbound Playwright command marker | 🛑 BLOCKER — escalated from warning | Current validator discards the spec before testing `job =~ command_marker`; it cannot prevent silent reassignment of a row to another real marker. This invalidates DX-04’s anti-drift purpose. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| `phase_234_evidence_contract_test.exs` | 532–543, 741–745 | Bare-map success authorization | 🛑 BLOCKER | Malformed or fabricated evidence can ratify completion. |
| `phase_234_evidence_contract_test.exs` | 706–730 | No revision/freshness validation | 🛑 BLOCKER | Historical receipts can ratify a changed state. |
| `phase_234_playwright_inventory_contract_test.exs` | 159–162, 197 | Spec-disconnected marker lookup | 🛑 BLOCKER | Future loss of browser coverage can be represented as owned. |
| Phase-owned files | — | `TBD` / `FIXME` / `XXX` markers | None | No unreferenced debt-marker blocker found. |

### Gaps Summary

Plans 15–18 genuinely closed the original local-safety, Dependabot-evidence, and empty-command-list gaps. The phase remains blocked because its final authorization can be fooled by malformed or stale evidence, and its Playwright inventory lacks the exact ownership link that prevents silent coverage loss. These are deterministic code/test defects; no human verification can close them.

---

_Verified: 2026-08-02T03:26:33Z_
_Verifier: the agent (gsd-verifier)_
