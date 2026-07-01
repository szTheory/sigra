---
created: 2026-07-01T00:00:00.000Z
status: pending
title: Phase 209 code-review deferred findings — canary recapture premise, unwired panel-schema-check, validator nits
area: ci
files:
  - .github/workflows/ci.yml
  - scripts/ci/panel-schema-check.sh
source: Phase 209 execute-phase code_review_gate (209-REVIEW.md). IN-01 (dead @summary_posture assign) was FIXED in commit 8f56f64e. These are the Warning/Info findings intentionally deferred as design-/scope-level (not guess-fixable at phase close).
---

## What

Advisory code-review findings from Phase 209 that were deferred rather than
guess-fixed. None block the phase (copy/IA remediations + REVIEW verified all 6
LiveView diffs clean). Captured so they aren't lost:

1. **WR-01 — `admin_checkpoint_recapture` delete-before-recapture premise may be
   wrong for `--base HEAD` (ci.yml:1785-1861).** The reviewer argues the
   impersonation-banner canary PNGs are tracked at HEAD (`git ls-files`), so
   deleting + recreating them in the working tree yields `modified` (guard-forbidden,
   ci.yml:104), NOT `added`. The "added" trick only holds against a base where the
   file is absent. **Cross-check with 209-06:** the SUMMARY itself acknowledges the
   canary remains `modified` vs `origin/main` and claims the post-merge CI run makes
   `origin/main` carry the post-WCAG baseline (so PR #63's diff vs the *new*
   origin/main then shows unchanged). Whether that resolution actually holds is only
   verifiable when `admin_checkpoint_recapture` runs post-merge on ubuntu. **Action:
   validate the mechanism end-to-end on the first real CI run; if the guard trips on
   `modified`, the delete-before-recapture logic needs rework (e.g. allowlist the
   canary for that one run, or base the "added" claim on the correct absent-at-base
   comparison).** This is the highest-value deferred item — it gates the D-10 / SC-4
   baseline obligation.

2. **WR-02 — `panel-schema-check.sh` is never invoked by CI.** The validator ships
   under 209-02 `provides` but `grep` finds no reference in ci.yml. A schema guard
   that never runs enforces nothing; future persona-panel-doc schema breaks pass CI
   silently. **Action:** decide whether it's intended as a local-only helper (then
   document that) or wire it into a CI lane (net-new scope — evaluate which job/gate).

3. **IN-02 — validator column guard covers only the kill-count column.** The awk
   guard in `panel-schema-check.sh` scans `$4` (kill count) but not `$5` (tighten
   count), despite the stated intent to bar bare integers in both.

4. **IN-03 — inconsistent stream for FAIL diagnostics.** Python FAIL messages go to
   stdout while `fail()` uses stderr. Exit propagation is correct; cosmetic only.

5. **IN-04 — CI warmup readiness loop can't fail the job when the app never boots
   (pre-existing, cloned from the design-recapture lane).** Not introduced by 209 —
   inherited pattern; fix in the shared prelude if addressed.

## Why deferred

WR-01 requires a live CI run to validate (can't be confirmed locally — the
`--base origin/main` canary diff can't pass on darwin by design). WR-02 is a
scope decision (wire-in vs document-as-local). IN-02/03/04 are low-severity
validator/CI nits. Per the review-gate-remediation policy: fix verified-clean
findings now (IN-01, done), defer uncertain/design-level ones to a tracked todo.

Batch into a future quick task touching `scripts/ci/` + `.github/workflows/ci.yml`,
ideally right after the first post-merge `admin_checkpoint_recapture` run confirms
or refutes WR-01.
