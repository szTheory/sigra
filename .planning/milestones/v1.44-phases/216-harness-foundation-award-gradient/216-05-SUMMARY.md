---
phase: 216-harness-foundation-award-gradient
plan: 05
subsystem: ci-guards
tags: [award-guard, verify-then-climb, probe-ids, ratchet, ci]
dependency_graph:
  requires: [216-01, 216-02]
  provides: [award-guard, eval-probe-ids, award-guard-test]
  affects: [ci.yml fast_checks, admin-award-ledger.json]
tech_stack:
  added: []
  patterns: [hermetic-node-mjs-self-test, git-show-base-ref-diff, ordinal-band-comparison]
key_files:
  created:
    - scripts/ci/lib/eval-probe-ids.mjs
    - scripts/ci/award-guard.mjs
    - scripts/ci/award-guard.test.mjs
  modified: []
decisions:
  - Shared probe-id registry in eval-probe-ids.mjs exports PROBE_IDS (9 ids) + resolveEvidenceRef; imported by award-guard and designed to be imported by Plan 06 probes.ts
  - resolveEvidenceRef validates probe:<known> (exact match), test:<anything> and conformance:<anything> (prefix-only until Plans 06/07 populate those registries)
  - award-guard.mjs reads HEAD ledger from working tree; reads BASE via git show (mirrors quality-ledger-monotonic.sh idiom); skips with INFO on initial commit
  - Guard recomputes min(axes) using A0=0..A3=3 ordinal; never trusts the typed band field
  - Self-test is pure Node ESM (not bash + jq); uses spawnSync to call the real guard binary inside a hermetic mktemp git repo
metrics:
  duration: ~4 minutes
  completed: 2026-07-03
  tasks_completed: 3
  files_created: 3
status: complete
---

# Phase 216 Plan 05: Award Guard + Probe IDs Summary

Award verify-then-climb guard (D-20) built and self-tested. Probe-id shared registry lives in one module. All four D-20 FAIL conditions enforced; no-change and legitimate climbs pass; 14/14 self-test assertions green.

## What Was Built

### Task 1: eval-probe-ids.mjs (ff287006)

`scripts/ci/lib/eval-probe-ids.mjs` is the single source of truth for the nine canonical visual probe ids:

- `off-token-spacing`, `misalignment`, `size-weight-budget`, `ember-reserved-for`, `off-scale-radius-shadow-control`, `target-size`, `focus-ring`, `card-in-card`, `below-fold-primary`

Exports:
- `PROBE_IDS` — frozen array of 9 ids
- `resolveEvidenceRef(ref)` — validates `probe:<known>` (exact), `test:<anything>` and `conformance:<anything>` (prefix-only; exact registries populated by Plans 06/07)

Shared by `award-guard.mjs` (this plan) and `probes.ts` / `admin-eval.spec.ts` (Plan 06) — D-12 anti-drift: one source, never duplicate.

### Task 2: award-guard.mjs (c1d07beb)

`scripts/ci/award-guard.mjs` enforces the D-20 verify-then-climb anti-gaming invariant over `guides/reference/admin-award-ledger.json`.

**FAIL conditions:**
- `(a)` Any axis rose vs merge-base but `verified_at_sha` did not change → "climb without fresh render"
- `(b)` `band != min(axes)` — guard recomputes `min()` using `A0=0..A3=3` ordinal; never trusts the typed band
- `(c)` Any raised axis has `rendered:false` OR an `evidence_ref` that `resolveEvidenceRef()` rejects
- `(d)` Any axis band decreased vs merge-base

**Passes on:** no-change run; legitimate climb (axis up + fresh `verified_at_sha` + `rendered:true` + resolving evidence)

**Mirrors quality-ledger-monotonic.sh idiom:** reads BASE via `git show <base>:${LEDGER_REL}`; skips with INFO when base file is absent (initial commit); accepts `--base <ref>` arg (defaults to `HEAD`).

### Task 3: award-guard.test.mjs (be532397)

`scripts/ci/award-guard.test.mjs` is a hermetic Node self-test covering all five D-20 cases. Uses `spawnSync` to invoke the real guard binary inside a `mkdtempSync` throwaway git repo; cleans up on exit.

| Case | Ledger Mutation | Expected | Result |
|------|----------------|----------|--------|
| 1 | axis A1→A2 + SAME verified_at_sha | FAIL climb-without-render | PASS |
| 2 | band hand-typed A2, axes min = A1 | FAIL band!=min | PASS |
| 3 | axis rose + rendered:false | FAIL rendered is not true | PASS |
| 3b | axis rose + bogus `probe:does-not-exist` | FAIL evidence_ref does not resolve | PASS |
| 4 | axis A1→A0 (decrease) | FAIL decreased vs merge-base | PASS |
| 5a | no-change | PASS | PASS |
| 5b | legit climb (fresh sha + valid refs) | PASS | PASS |

14/14 assertions green.

## Verification

```
PROBE_IDS_OK                              # eval-probe-ids: 9 ids, resolver correct
award-guard: PASS (2 cells checked vs HEAD)  # all-A0 pilot ledger passes
award-guard.test: PASS                    # 14/14 assertions green
```

## Deviations from Plan

None — plan executed exactly as written.

## Threat Mitigations Confirmed

| Threat ID | Mitigation | Self-test Case |
|-----------|-----------|----------------|
| T-216-05-CLIMB | FAILs axis rise with unchanged verified_at_sha | Case 1 |
| T-216-05-FAKEEV | FAILs bogus/unresolvable evidence_ref + rendered:false | Cases 3, 3b |
| T-216-05-BAND | FAILs band != recomputed min(axes) | Case 2 |
| T-216-05-DOWN | FAILs axis decrease vs merge-base | Case 4 |

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced.

## Known Stubs

None — `resolveEvidenceRef` defers `test:` and `conformance:` to prefix-only validation intentionally; Plans 06/07 populate those registries. This is documented, not a stub.

## Self-Check: PASSED

- `scripts/ci/lib/eval-probe-ids.mjs` exists: FOUND
- `scripts/ci/award-guard.mjs` exists: FOUND
- `scripts/ci/award-guard.test.mjs` exists: FOUND
- Commit ff287006: FOUND
- Commit c1d07beb: FOUND
- Commit be532397: FOUND
