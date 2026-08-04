---
phase: 234-hygiene-supply-chain-and-contributor-dx
verified: 2026-08-02T15:41:27Z
status: passed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 6/7
  gaps_closed:
    - "The completion transition now compares the admitted evidence-key set directly with the six required receipt slots and rejects both tested seventh-slot shapes."
    - "The Wave 12 validation row, reviewed snapshot, sign-off, and approval are parser-protected and refreshed for the exact-set repair."
    - "The Phoenix 1.8.8 install-golden fixture rebless is recorded against the implementation commit and remains inside the golden-safe formatter boundary."
  gaps_remaining: []
  regressions: []
---

# Phase 234: Hygiene, Supply Chain, and Contributor DX Verification Report

**Phase Goal:** A contributor can reproduce the gate locally, and the repo's action/dependency surface stops drifting silently.
**Verified:** 2026-08-02T15:41:27Z
**Status:** passed
**Re-verification:** Yes — after Wave 12 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A contributor can run the seven-leg `MIX_ENV=test mix ci` gate without dirtying `mix.lock`; CI invokes the same alias once. | ✓ VERIFIED | `mix.exs:143-162` declares the required legs; `.github/workflows/ci.yml:541` is the sole direct invocation under `library_tests_shard`. The parity/dependency contract group passed 17 tests. `234-EVIDENCE.json` contains a detached-worktree success receipt with equal pre/post lock and normalized-status hashes, and GitHub run `30722736494` is a successful PR run at the recorded SHA. |
| 2 | Release-critical third-party Actions are immutable SHA pins with version comments and the Release Please action actually executed. | ✓ VERIFIED | The action-pinning contract passed. Every scoped `uses:` line in `release-please.yml` and `hex-publish.yml` is a lowercase 40-character SHA with a same-line version comment; `release-please.yml:88` uses the dereferenced v5 SHA `45996ed…307cf7`. The ledger's successful run `30723565705` records the matching action ref, and its GitHub run resolves successfully. |
| 3 | Dependabot covers the exact GitHub Actions, Mix, and npm ecosystems, with processed-service evidence rather than a claimed absent PR. | ✓ VERIFIED | `.github/dependabot.yml` has exactly the three weekly tuples. The Dependabot contract passed and verifies manifest/lock reconciliation plus exact successful tuple receipts in `234-EVIDENCE.json`; all three include processed job IDs, timestamps, and GitHub URLs. |
| 4 | Every live Playwright spec has an exact CI owner, with harness indirection limited to documented mappings. | ✓ VERIFIED | `234-PLAYWRIGHT-INVENTORY.json` contains 20 live-spec rows. The inventory contract passed 6 tests, including exact-set, sibling-marker, and harness-mapping mutations; it resolves the two permitted harness sources to `admin-eval.spec.ts` and `admin-generated.spec.ts`. |
| 5 | SEED-006 is closed against a real current gallery execution or tracked residual. | ✓ VERIFIED | The gallery ledger entry points to run `30723701267`, job `91431828624`, with a successful 126-test gallery result and no retries. Direct GitHub inspection confirms the gallery job succeeded; the separately recorded admin-eval failure is non-gating and is not represented as a gallery success. |
| 6 | Completion authorization validates all concrete receipts and binds its command inventory to one fresh reviewed snapshot. | ✓ VERIFIED | `assert_transition_allowed!/3` invokes receipt validation before returning `:complete` (`phase_234_evidence_contract_test.exs:1136-1165`). The sign-off suite passed 7 tests, covering bare/partial evidence, six concrete receipt schemas, wrong SHA, stale/future timestamps, ordering, and receipt-inventory mutations. |
| 7 | Completion authorization is fail-closed for the exact six-slot evidence ledger; added failed or malformed success-shaped evidence cannot be ignored. | ✓ VERIFIED | `validate_required_evidence!/1` now checks `MapSet.new(Map.keys(Map.delete(receipts, "schema_version"))) == required` at lines 640-652. The production-transition test at lines 781-810 adds both `unexpected_failed` and `unexpected_malformed_success`, requires each to raise, and retains a green six-slot `:complete` assertion. |

**Score:** 7/7 truths verified (0 present, behavior-unverified).

### Plan Must-Have Regression Coverage

| Plans | Verified outcome | Evidence |
| --- | --- | --- |
| 01, 09, 15-16 | Contributor/CI parity, clean checkout, one suite owner, safe dependency-off cleanup | Current alias/workflow wiring, evidence receipt validation, and the 17-test cross-plan contract group. |
| 02-05, 11-13 | All scoped source/test formatting is clean and install-golden bytes are outside formatter ownership | `mix format --check-formatted` exited 0; `.formatter.exs` exclusion and golden/idempotency receipts are enforced by contracts. |
| 06 | Immutable release-action surface | Current workflow scan and passing action-pinning contract. |
| 07, 17 | Exact Dependabot configuration and processed service receipts | Current configuration, lock/manifest reconciliation, and receipt contract. |
| 08, 19 | Exact inventory-to-CI Playwright ownership | Current 20-row inventory and 6-test mutation-backed ownership contract. |
| 10, 14, 18, 20 | Managed-service evidence and ratification cannot be promoted from partial, stale, or malformed state | Full evidence-contract file passed (15 tests) and parser/transition checks are wired to the evidence and validation artifacts. |
| 21 | Exact six-slot authorization plus current Phoenix 1.8.8 golden baseline | Wave 12 mutations pass through the production transition; validation parser rejects every required-row mutation; commit-bound golden receipt is present for `46c56e0f`. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `mix.exs`, `ci.yml`, `scripts/ci/sigra-dep-off.sh` | Shared, non-destructive local/CI gate | ✓ VERIFIED | Seven-leg alias, one direct workflow owner, cleanup harness, and clean-worktree receipt all agree. |
| `.formatter.exs` and install golden fixture | Golden-safe format boundary and Phoenix 1.8.8 baseline | ✓ VERIFIED | Repository formatter check passed; fixture change is confined to stale scaffold output and the refreshed receipt is bound to commit `46c56e0f`. |
| Release workflows and pinning contract | Immutable release-action surface | ✓ VERIFIED | Substantive policy test and current scoped workflow pins are present. |
| `.github/dependabot.yml`, `234-EVIDENCE.json` | Exact three-ecosystem coverage and live processing evidence | ✓ VERIFIED | Real configuration plus populated, schema-validated receipts; no empty/static success response. |
| `234-PLAYWRIGHT-INVENTORY.json` and ownership contract | Exhaustive spec-to-lane map | ✓ VERIFIED | Populated 20-row dynamic inventory reconciles to the live spec set and workflow/harness sources. |
| `phase_234_evidence_contract_test.exs`, `234-VALIDATION.md` | Fail-closed completion authority and audited sign-off | ✓ VERIFIED | Artifact query reports both substantive; production transition, validation parser, Wave 12 row, receipt table, and approval are mutually checked by the passing suite. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `library_tests_shard` | `mix ci` | Literal `MIX_ENV=test mix ci` | WIRED | Present once at `ci.yml:541`; parity test guards one direct owner. |
| Dependabot configuration | evidence ledger | Exact processed tuple receipts | WIRED | Three config tuples reconcile to three non-empty receipt slots. |
| Playwright inventory | workflow/harness invocations | Exact marker or one of two allowlisted harness mappings | WIRED | Mutation tests demonstrate both direct and harness paths. |
| evidence ledger | completion transition | All six concrete validators | WIRED | `assert_transition_allowed!/3` calls `validate_required_evidence!/1` before `:complete`. |
| received evidence keys | required six-slot set | Direct `MapSet` equality | WIRED | Missing or added slots cannot reach completion; seventh-slot production mutations pass. |
| Wave 12 validation row | transition sign-off | Exact command tuple, green status, reviewed snapshot | WIRED | Parser mutation test rejects omitted, duplicated, substituted, and non-green `234-21-01` rows. |

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
| --- | --- | --- | --- | --- |
| Dependabot evidence | `slots` | Authenticated GitHub update-job receipts | Yes — job IDs, URLs, timestamps, and processed statuses are populated | ✓ FLOWING |
| Playwright inventory | `specs[].lanes` | Live spec glob, CI workflow, and two harness sources | Yes — 20 non-empty rows reconcile in both directions | ✓ FLOWING |
| Completion authorization | evidence receipt map and command receipt table | `234-EVIDENCE.json` and `234-VALIDATION.md` | Yes — validators consume the real populated entries; extra keys reject before completion | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Exact receipt authorization and Wave 12 row | `mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff` | 7 tests, 0 failures | ✓ PASS |
| Full receipt and final-evidence contract | `mix test test/sigra/planning/phase_234_evidence_contract_test.exs` | 15 tests, 0 failures | ✓ PASS |
| Exact Playwright ownership | `mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` | 6 tests, 0 failures | ✓ PASS |
| Cross-plan gate/pin/Dependabot contract regression | Named Phase 198, 233, and 234 parity/pinning/Dependabot tests | 17 tests, 0 failures | ✓ PASS |
| Repository formatting | `mix format --check-formatted` | Exit 0 | ✓ PASS |
| Phoenix 1.8.8 golden rebless | Golden/idempotency command in refreshed `234-VALIDATION.md` receipt | Exit 0, commit `46c56e0f`, sanitized output hash recorded | ✓ PASS (committed machine receipt) |

The test commands emit expected unavailable-local-Postgres connection noise in this environment; the deterministic planning contracts themselves completed successfully. The golden/idempotency subprocess suite needs that service and was not re-run here; its current, commit-bound zero-exit receipt is present and parsed by the passing evidence contract.

### Requirements Coverage

| Requirement | Source plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| DX-01 | 01-05, 09, 11-16, 18, 20-21 | `mix ci` reproduces the PR gate with formatting and lock checks | ✓ SATISFIED | Alias/workflow parity, complete formatting, clean-worktree receipt, and exact final authorization. |
| DX-02 | 06, 10, 14, 18, 20-21 | Release-critical Actions use immutable SHAs | ✓ SATISFIED | Current pins, mutation-backed pinning contract, and successful Release Please run. |
| DX-03 | 07, 10, 14, 17-18, 20-21 | Dependabot covers GitHub Actions, Mix, and npm | ✓ SATISFIED | Exact config, manifests/locks, and three processed update-job receipts. |
| DX-04 | 08, 10, 14, 18-21 | No live Playwright spec is unowned | ✓ SATISFIED | Exact inventory, CI/harness wiring, and mutation-backed reconciliation. |
| DX-06 | 10, 14, 18, 20-21 | SEED-006 is delivered or residual filed | ✓ SATISFIED | Current successful gallery job and isolated non-gating diagnostic. |

All five Phase 234 requirement IDs appear in plan frontmatter. No requirement mapped to Phase 234 is orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| Phase-owned Plan 21 files | — | `TBD` / `FIXME` / `XXX` markers | None | No unreferenced debt marker found. |
| `phase_234_evidence_contract_test.exs` | 640-652 | Former intersection-only exact-set check | Resolved | Replaced by direct equality and production-transition mutations. |

### Evidence Adjudication

The commit-bound receipts are not accepted solely because a SUMMARY claims they passed: the evidence JSON is populated, parsed by the passing contract, and its referenced PR, Release Please, and gallery GitHub run IDs resolve to the claimed outcomes. The cleaned Wave 12 contract explicitly models the only prior bypass (an unvalidated seventh key) and exercises it through the real authorization transition. No failed, absent, skipped, or partial receipt was promoted to success.

---

_Verified: 2026-08-02T15:41:27Z_
_Verifier: the agent (gsd-verifier)_
