---
phase: "242"
slug: "hex-retire-docs-revert-pinned-install-adr-cut-1-5-1"
status: reconciled
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-20"
updated: "2026-09-25"
---

# Phase 242 — Validation Strategy

> Validation map reconciled to the final bounded source-install safeguard and safety closeout.
> The original registry mutation and publication scope was retired; no external outcome is implied.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Focused command** | `MIX_ENV=test mix test test/sigra/planning/phase_242_shift_left_contract_test.exs` |
| **Full suite command** | `MIX_ENV=test mix ci` |

## Final Scope and Status

The active Phase 242 goal is to keep the ten owned public installation snippets on
`{:sigra, "~> 1.5.0"}`, remove the retired phantom-remediation workflow path, preserve hash-linked
halt evidence, and state that the external registry/docs/release outcomes remain unproven. REL-03,
REL-04, and REL-06 remain superseded-not-satisfied. REL-05 is limited to this delivered source
safeguard; the ADR and registry-resolution outcomes in its original wording remain unfulfilled.

## Per-Goal Verification Map

| Goal | Requirement disposition | Automated command | Evidence / status |
|------|-------------------------|-------------------|------------------|
| All ten owned README/guide install snippets use the bounded maintained tuple and reject the stale 1.4 tuple. | REL-05 source safeguard | `MIX_ENV=test mix test test/sigra/planning/phase_242_shift_left_contract_test.exs` | `test/sigra/planning/phase_242_shift_left_contract_test.exs`, test "public install snippets use the bounded maintained line" — green (3 tests total, 0 failures, 2026-09-25). |
| The retired mutation workflow and its p22 guard are absent. | Safety boundary supporting REL-03/04; no claim of registry mutation | Same focused ExUnit command | Test "retired Hex mutation automation cannot be dispatched from this repository" — green. |
| Raw halt summaries retain their recorded SHA-256 links, and closeout/requirements do not claim external success. | REL-03/04/06 remain unsatisfied; REL-05 limited | Same focused ExUnit command | Test "safety closeout preserves raw halt evidence and makes no external success claim" — green. |
| No Phase 242 plan remains executable; superseded actions stay excluded. | Future-action boundary | `node ~/.codex/gsd-core/bin/gsd-tools.cjs query init.execute-phase 242 --raw` | Prior phase verification recorded eight live plans, eight summaries, no incomplete/runnable plans; plans 04–09 excluded as superseded. Re-run this command when checking current GSD routing. |

## External Outcomes — Not Acceptance Checks

Hex retirement (REL-03), HexDocs root revert (REL-04), and publication of 1.5.1 (REL-06) are
irreducibly external events and explicitly unsatisfied. The preserved halt summaries for runs
35554955828, 35709493996, and 35714147650 are evidence of failed bounded attempts, not evidence of
success. This phase requires no new dispatch, registry mutation, artifact retrieval, or release
publication. Future work requires a separately scoped phase and fresh explicit authorization.

## Verification Record

- Focused command run 2026-09-25: **3 tests, 0 failures**. Test startup emitted database connection-refused logs from unrelated app setup; all focused assertions completed successfully.
- Existing contract test is included in normal ExUnit discovery and was wired into CI by Plan 13.
- No new tests were needed: the final goal already has deterministic behavioral assertions for its source-controlled criteria.

**Validation status:** current bounded goal verified. Historical REL-03/04/06 outcomes remain unsatisfied and are not marked as passed.
