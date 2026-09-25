completed: 2026-09-18
---
created: 2026-09-18T19:10:00.000Z
status: pending
title: "capture-green-04-evidence.test.sh passes 36/36 but has no CI caller, so the collector's fail-closed guards are unprotected against regression"
area: ci
files:

  - .github/workflows/ci.yml
  - scripts/ci/capture-green-04-evidence.test.sh

severity: medium
source: Phase 240 verification (240-VERIFICATION.md, non-blocking warning) — filed 2026-09-18 alongside CR-01/CR-02
---

## What

`scripts/ci/capture-green-04-evidence.test.sh` passes 36/36 locally and exercises every one of the collector's fail-closed arms — `no_matrix_suffix`, `insufficient_legs`, `leg_without_conclusion`, `matrix_repeat_set_mismatch`, `foreign_run_id`, `dirty_tree`, `evidence_run_head_sha_is_not_final_committed_head`, plus the pagination and `total_count` reconciliation paths.

Nothing runs it. `grep -r capture-green-04-evidence .github/ scripts/ mix.exs` returns nothing outside the script pair itself.

Its sibling from the same phase, `scripts/ci/ensure-github-pages-legacy-branch.test.sh`, WAS wired into `fast_checks` (`ci.yml:262-267`) precisely so the self-test is executed rather than merely present. This one was not.

## Why it matters

An unexecuted self-test is a guard that cannot fail — the same shape of problem the guards themselves exist to prevent. Every fail-closed token above can silently regress with no signal.

Phase 240's plan-review record already noted that two `capture-*.test.sh` self-tests have no CI caller at all; this makes that concrete for the newest one.

## Extra value

This is where coverage for CR-01 and CR-02 naturally lands. Wiring the self-test and adding the two missing guards is one coherent piece of work rather than three.

## Fix sketch

Add a `fast_checks` step alongside `ci.yml:262-267`, modelled byte-for-byte on the Pages self-test step. It is hermetic (stub `gh` on PATH, throwaway git repo) — no token, no network, no Postgres — so it costs a few seconds and needs no new secrets. Do not add it to `ci-gate.needs` directly; `fast_checks` is already an entry there.

## Related

- `2026-09-18-capture-green-04-sc2-selectors-fail-open.md` (CR-01)
- `2026-09-18-capture-green-04-empty-window-clean-receipt.md` (CR-02)
