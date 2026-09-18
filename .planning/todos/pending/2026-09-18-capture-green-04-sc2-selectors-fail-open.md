---
created: 2026-09-18T19:10:00.000Z
status: pending
title: "capture-green-04-evidence.sh SC-2 job selectors fail open: an anchored regex matching zero jobs yields null, which flake_attributable_red_count silently drops, so genuinely-red runs can report 0"
area: ci
files:

  - scripts/ci/capture-green-04-evidence.sh
  - scripts/ci/capture-green-04-evidence.test.sh

severity: high
source: Phase 240 code review (240-REVIEW.md, CR-01) — operator dispositioned as tracked follow-up 2026-09-18, confirmed by 240-VERIFICATION.md
---

## What

`ci_gate_conclusion` and `generated_admin_smoke_conclusion` (`scripts/ci/capture-green-04-evidence.sh:249-250`, consumed at `:312`) are built as:

```
[ ... | select(.name | test($re)) | .conclusion ] | first
```

`first` over an empty array is `null`. `flake_attributable_red_count` then counts only entries `== "failure"`, so a `null` is silently dropped rather than failing the capture.

Reproduced during review against a recording `gh` stub: two `main` runs whose `Generated admin Playwright smoke` job concluded `failure`, with only the job `name:` altered, produce `{"run_count": 2, "flake_attributable_red_count": 0}` at **exit 0** — versus the control `{"run_count": 2, "flake_attributable_red_count": 2}`.

`CI_JOB_NAME` is a hardcoded pin to a `ci.yml` job name that can be renamed at any time, which is exactly how the zero-match case arises in practice.

## Why it matters

SC-1 already defends against this class — a payload of bare, unsuffixed names is rejected with the `no_matrix_suffix` token (`:194-196`) rather than silently yielding zero legs. SC-2 has no analog. A collector that reports "zero red runs" because it matched zero jobs is the precise "green gate that verified nothing" pattern the v1.48 milestone exists to retire.

## Not a falsification of Phase 240's evidence

This did not fire on the shipped capture. All 8 runs in `240-GREEN-04-EVIDENCE.json` carry non-null values for **both** SC-2 selectors, and `240-VERIFICATION.md` re-derived every SC-1 fact directly from the GitHub API without using this tool. The GREEN-04 claim on issue #231 stands. This is a latent fail-open path in the tool, to be closed before the next capture.

Note: `run_conclusion` for run `35377012499` IS null, but that is the run-level field the receipt deliberately never uses (D-08) — it is not one of the two CR-01 selectors.

## Fix sketch

Give SC-2 a named failure token symmetrical with SC-1's `no_matrix_suffix` — e.g. `sc2_job_not_found` — raised when either selector matches zero jobs for a run that is otherwise in scope. Distinguish "job absent" from "job present, conclusion null" (see the sibling todo on conclusion-completeness). Assert both arms RED in `capture-green-04-evidence.test.sh`.

## Related

- Sibling: `2026-09-18-capture-green-04-empty-window-clean-receipt.md` (CR-02)
- Sibling: `2026-09-18-capture-green-04-selftest-has-no-ci-caller.md` — the natural home for the coverage
