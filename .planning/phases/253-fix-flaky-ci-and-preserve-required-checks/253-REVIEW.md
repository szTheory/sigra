---
phase: 253-fix-flaky-ci-and-preserve-required-checks
reviewed: 2026-10-23T15:06:51Z
depth: standard
scope_base: 30b22bc16c0124151616e2dcab18ae25fdd1816a
files_reviewed: 42
files_reviewed_list:
  - .github/ci-skip-manifest.tsv
  - .github/workflows/ci.yml
  - MAINTAINING.md
  - config/config.exs
  - lib/sigra/auth.ex
  - scripts/ci/ci-browser-records.mjs
  - scripts/ci/ci-browser-records.test.mjs
  - scripts/ci/ci-gate-canary-recovery.test.py
  - scripts/ci/ci-gate-canary.sh
  - scripts/ci/ci-gate-canary.test.sh
  - scripts/ci/ci-git-publication.py
  - scripts/ci/ci-hermetic-live-audit.test.py
  - scripts/ci/ci-hosted-gate-verify.py
  - scripts/ci/ci-hosted-gate-verify.test.py
  - scripts/ci/ci-hosted-transport.py
  - scripts/ci/ci-hosted-transport.test.py
  - scripts/ci/ci-measure-workflow.test.mjs
  - scripts/ci/ci-playwright-load.test.mjs
  - scripts/ci/ci-playwright-report.test.mjs
  - scripts/ci/ci-pr-proof.test.sh
  - scripts/ci/ci-registration-control-audit.mjs
  - scripts/ci/ci-registration-control-audit.test.mjs
  - scripts/ci/ci-registration-recovery.mjs
  - scripts/ci/ci-registration-recovery.test.mjs
  - scripts/ci/ci-registration-repro.sh
  - scripts/ci/ci-registration-repro.test.sh
  - scripts/ci/ci-run-metrics.sh
  - scripts/ci/ci-run-metrics.test.sh
  - scripts/ci/ci_metrics_security.py
  - scripts/ci/honest-skip-verdict.sh
  - scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs
  - scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs
  - test/example/priv/playwright/helpers/registrationControls.mjs
  - test/example/priv/playwright/lib/eval/bundle.ts
  - test/example/priv/playwright/lib/eval/canonicalize.test.ts
  - test/example/priv/playwright/lib/eval/canonicalize.ts
  - test/example/priv/playwright/lib/reporters/failure-jsonl.mjs
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/tests/admin-eval.spec.ts
  - test/sigra/auth_test.exs
  - test/sigra/planning/phase_253_ci_static_runtime_test.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 253: Code Review Report

**Reviewed:** 2026-10-23T15:06:51Z  
**Depth:** standard  
**Files Reviewed:** 42  
**Scope base:** `30b22bc16c0124151616e2dcab18ae25fdd1816a`  
**Status:** issues_found

## Summary

Reviewed the 42 supplied paths, including the six later-added CI security and registration sources. No confirmed functional or security defects were found in the current code. The registration reproduction shell script retains a large unreachable implementation after unconditional exits, which makes the supported and retired paths harder to distinguish.

Visual UI audit applicability: not applicable. The changed browser files implement evaluation, reporting, and test infrastructure; no shipped visual UI was changed.

No tests or external systems were run for this read-only review. The provided phase context records prior offline results, including the controlled loader/reloader counterexample and current registration control evidence; this review does not independently rerun those checks or treat the original hosted schedule as observed.

## Warnings

### WR-01: Unreachable legacy runner remains after terminal exits

**Severity:** WARNING  
**File:** `scripts/ci/ci-registration-repro.sh:143-148`  
**Issue:** The script exits with status 3 at lines 145-146, so the remaining block beginning at line 148 is unreachable for every invocation. It still contains the old `--run-frozen` execution path and setup logic, while the live dispatcher now refuses that mode and directs callers to `--run-recovery`. Keeping both paths in the active source makes it difficult to tell which identity and execution checks govern supported runs; the dead path can also be accidentally reactivated without being brought in line with current evidence rules.
**Fix:** Remove the unreachable block after line 146, or move it into a separately named legacy tool with an explicit supported entry point and current validation.

---

_Reviewed: 2026-10-23T15:06:51Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
