---
phase: 194-caching-correctness-micro-job-consolidation
plan: "02"
subsystem: ci-infrastructure
tags: [ci, github-actions, job-consolidation, documentation]
status: complete

dependencies:
  requires:
    - "194-01 (precision cache keys + MAINTAINING.md foundation)"
  provides:
    - "fast_checks consolidated job (6 guards in 1 runner, single checkout + base-ref resolve)"
    - "Rewired ci-gate aggregation (fast_checks replaces snapshot_drift_guard + quality_ledger_monotonic)"
    - "MAINTAINING.md stale required-check docs fully corrected (both occurrences of stale string)"
  affects:
    - ".github/workflows/ci.yml"
    - "MAINTAINING.md"

tech-stack:
  added: []
  patterns:
    - "Single checkout + single base-ref resolve shared across 6 guard steps (D-13)"
    - "Installer-audit detect gate ported as id: detect step + if: steps.detect.outputs.run == 'true' (LANDMINE honored)"
    - "ci-gate aggregation via FAST_CHECKS env var + loop entry (D-14)"

key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"
    - "MAINTAINING.md"

decisions:
  - "D-03 gate re-executed at execution time (2026-06-20): exactly 5 required contexts confirmed, no ci-gate, no guard jobs"
  - "D-11: 6 leaf guards folded into one fast_checks job (milestone/installer/contracts/snapshot/ledger)"
  - "D-12: release_ref_guard kept standalone (no-checkout DAG gate for heavy lanes)"
  - "D-13: fast_checks = single fetch-depth:0 checkout + one Resolve base ref (id: base) + 6 distinct named run: steps"
  - "D-14: ci-gate.needs rewired — snapshot_drift_guard + quality_ledger_monotonic dropped, fast_checks added; env block + loop updated"
  - "D-15: MAINTAINING.md stale string swept from both locations (Note on install golden + Ship table row)"
  - "Net coverage increase: 4 guards never previously in ci-gate.needs (milestone_verification_gate, installer_milestone_audit, getting_started_uat_contract, phase_34_uat_contract) now enter ci-gate via fast_checks — equal-or-greater signal"

metrics:
  duration: "~4 minutes"
  completed: "2026-06-20"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 2
  files_created: 0
---

# Phase 194 Plan 02: Micro-Job Consolidation (CACHE-02) Summary

Consolidated 6 trivial leaf guard jobs into one `fast_checks` job (single checkout, single base-ref resolve, 6 distinct named steps), cutting ~6 runner cold-starts per CI run; rewired `ci-gate` aggregation in lockstep; and swept all remaining stale required-check references from MAINTAINING.md.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Re-read live ruleset (D-03) + fold 6 guards into fast_checks (D-11/D-12/D-13) | 4c9226ed | .github/workflows/ci.yml |
| 2 | Rewire ci-gate.needs + aggregation loop (D-14) | 4c9226ed | .github/workflows/ci.yml |
| 3 | Reconcile MAINTAINING.md required-check docs to live ruleset (D-15) | 05f3a5b9 | MAINTAINING.md |

## Task 1: D-03 Live Ruleset Re-read

Re-read `gh api repos/szTheory/sigra/rulesets/14941512` at execution time (2026-06-20).

**Verbatim live required-check contexts (executor-time ground truth):**

1. `Library tests`
2. `Example unit smoke (ExUnit + ConnTest)`
3. `Install smoke (fresh phx.new + sigra.install)`
4. `Example HTTP smoke (boot + curl critical routes)`
5. `Example Playwright smoke (full lifecycle)`

**Confirmed:** Exactly 5 contexts. All 5 match D-01 byte-for-byte. `ci-gate` is NOT in the list. None of the 7 micro-guard jobs is in the list.

**D-03 gate: PASSED.** Proceeded with ci.yml edits.

## Task 1+2: fast_checks Job Structure (D-11/D-12/D-13 + D-14)

### fast_checks job anatomy

```
fast_checks:
  name: Fast checks (milestone/installer/contracts/snapshot/ledger guards)
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout (fetch-depth: 0)          # single checkout
    - name: Resolve base ref                            # id: base — once
    - name: Milestone verification gate
    - name: Detect installer-related changes (PRs only) # id: detect (LANDMINE)
    - name: Installer milestone audit (INT-01..03)      # if: steps.detect.outputs.run == 'true'
    - name: Getting started doc contract
    - name: Phase 34 UAT contracts
    - name: Snapshot drift guard (canary allowlist)     # uses steps.base.outputs.ref
    - name: Snapshot drift guard — design lane          # second sub-step preserved
    - name: Quality ledger monotonic guard              # uses steps.base.outputs.ref
```

### Installer-audit LANDMINE port (D-13)

The installer-audit PR-path detect gate is ported faithfully:
- `id: detect` step runs path-diff grep against the shared `fetch-depth: 0` + base-ref fetch (no redundant standalone fetch needed)
- Installer audit `run:` step gated with `if: steps.detect.outputs.run == 'true'`
- Exact path pattern preserved: `^priv/templates/sigra\.install/|^lib/sigra/install/|^lib/sigra/mfa(\.ex|/)|^lib/sigra/oauth(\.ex|/)|^lib/sigra/account(\.ex|/)|^lib/sigra/passkeys(\.ex|/)`

### release_ref_guard (D-12)

Kept as a standalone no-checkout job. Folding it into `fast_checks` would add checkout latency in front of every heavy lane's `needs:` gate — intentional exclusion per D-12.

### ci-gate rewire (D-14)

**Before:**
```
needs: [... snapshot_drift_guard, quality_ledger_monotonic]
env: { SNAPSHOT_DRIFT_GUARD: ..., QUALITY_LEDGER_MONOTONIC: ... }
loop: [..., SNAPSHOT_DRIFT_GUARD, QUALITY_LEDGER_MONOTONIC]
```

**After:**
```
needs: [... fast_checks]
env: { FAST_CHECKS: ${{ needs.fast_checks.result }} }
loop: [..., FAST_CHECKS]
```

### Net coverage increase (noted for SUMMARY per plan)

4 guards previously NOT in `ci-gate.needs` now enter via `fast_checks`:
- `milestone_verification_gate`
- `installer_milestone_audit`
- `getting_started_uat_contract`
- `phase_34_uat_contract`

This is a net increase in ci-gate coverage (equal-or-greater signal per plan requirements). Acceptable and intentional.

## Task 3: MAINTAINING.md Stale Required-Check Doc Correction (D-15)

### Stale occurrences found

`grep -n 'Install golden + idempotency contract' MAINTAINING.md` returned **2 occurrences** before Task 3:

1. **Line 120** (Note on install golden): Appeared in the corrected branch-protection section from 194-01, but still contained the old job name string.
2. **Line 216** (Ship table row): "Installer + merge gate" cell still asserted `branch protection must require \`Install golden + idempotency contract (subprocess harness)\`` on `main`.

### Fixes applied

1. **Line 120**: Rewrote Note to omit the job name string; clarified the job flows into `ci-gate` (internal aggregator), is NOT independently required.
2. **Line 216**: Rewrote "Ship (artifact truth)" table row to point at live ruleset 14941512 + the corrected branch-protection section instead of the stale single-check string.

### Verification

- `grep -c 'Install golden + idempotency contract' MAINTAINING.md` = **0** (stale string fully swept)
- All 5 live required-check names present verbatim
- `ci-gate` internal aggregator note present
- Ruleset 14941512 reference present

## Deviations from Plan

None. Plan executed exactly as written:
- D-03 gate re-run before any job-topology edit
- 6 guards folded into fast_checks with all structural requirements met
- release_ref_guard kept standalone
- LANDMINE (installer-audit detect gate) ported faithfully
- Both snapshot sub-steps present
- ci-gate rewired in lockstep
- MAINTAINING.md stale string swept from both locations

## Threat Flags

None. This phase edits only CI workflow YAML and documentation. No new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check: PASSED

- `.github/workflows/ci.yml` exists: FOUND
- `MAINTAINING.md` exists: FOUND
- `194-02-SUMMARY.md` exists: FOUND
- Commit `4c9226ed` exists: FOUND
- Commit `05f3a5b9` exists: FOUND
- `actionlint .github/workflows/ci.yml` exits 0: PASS
- `fast_checks` count == 1: PASS
- 6 folded job keys absent (count == 0): PASS
- `release_ref_guard` present (count == 1): PASS
- installer detect gate present (`if: steps.detect.outputs.run == 'true'`): PASS
- `fast_checks` in `ci-gate.needs`: PASS
- `FAST_CHECKS` env var in ci-gate: PASS
- `needs.snapshot_drift_guard.result` references == 0: PASS
- `needs.quality_ledger_monotonic.result` references == 0: PASS
- MAINTAINING.md stale string count == 0: PASS
- All 5 protected lane names unchanged: PASS
- `phx_new 1.8.7` steps unchanged: PASS
