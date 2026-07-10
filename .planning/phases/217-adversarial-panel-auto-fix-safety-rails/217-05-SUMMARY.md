---
phase: 217-adversarial-panel-auto-fix-safety-rails
plan: "05"
subsystem: panel-judge
tags: [panel, judge, excerpt, lenses, tdd, llm, quorum, content-hash-skip, anti-rot]
dependency_graph:
  requires:
    - scripts/panel/panel-schema.mjs (Plan 01 — findingId, PANEL_SCHEMA)
    - guides/reference/admin-graphic-design-lens.md (Plan 04 — graphic_design lens)
    - guides/reference/admin-persona-jtbd-rubric.md
    - test/example/priv/playwright/lib/eval/canonicalize.ts (D-06 rules reference)
    - scripts/ci/evidence-anchor-check.mjs (anchor resolution idiom)
    - guides/reference/admin-render-sha.json
  provides:
    - scripts/panel/excerpt.mjs
    - scripts/panel/lenses.mjs
    - scripts/panel/judge.mjs
    - guides/reference/admin-panel-verdicts.json
    - scripts/ci/panel-verdicts-lint.sh
    - scripts/ci/panel-verdicts-lint.test.sh
  affects:
    - scripts/ci/admin-panel.sh (operator invocation — reads judge.mjs)
    - guides/reference/admin-panel-verdicts.json (committed cache, populated off-CI)
tech_stack:
  added: []
  patterns:
    - TDD RED/GREEN for excerpt.mjs (Task 1) and judge.mjs (Task 3)
    - Injected SDK test-double (call-counter) for hermetic SC-2 zero-calls proof
    - createRequire(PW/package.json) for cheerio (same pattern as evidence-anchor-check.mjs)
    - k=3 independent messages.create calls — NO temperature/top_p/top_k
    - output_config.format structured output via PANEL_SCHEMA
    - cache_control:{type:'ephemeral'} on system rubric block
    - content-hash skip (render_sha256 + provenance match → ZERO API calls)
    - Quorum admission: finding_id >=2/3 samples admitted; 1/3 dropped
    - Worst-verdict reconciliation (kill > tighten > keep)
    - DOM anchor pre-validation via cheerio before hashing (T-217-05-INJECT)
    - mktemp-hermetic self-test idiom for panel-verdicts-lint.test.sh
key_files:
  created:
    - scripts/panel/excerpt.mjs
    - scripts/panel/excerpt.test.mjs
    - scripts/panel/lenses.mjs
    - scripts/panel/judge.mjs
    - scripts/panel/judge.test.mjs
    - guides/reference/admin-panel-verdicts.json
    - scripts/ci/panel-verdicts-lint.sh
    - scripts/ci/panel-verdicts-lint.test.sh
  modified: []
decisions:
  - "excerpt.mjs retains ALL class tokens (not just sg-*) and sorts them for determinism — the LLM needs full class context for anchoring, even non-sg-* tokens"
  - "judge.mjs exports pure functions (admitFindings, reconcileFindings, checkProvenanceMatch, runJudge) to enable call-counter injection without mocking the SDK at module level"
  - "panel-verdicts-lint.sh uses node -e inline JavaScript (no jq) for JSON checks — consistent with the house idiom in settled-findings-lint.sh and other guards"
  - "prune mode: when admin-render-sha.json has empty cells, ALL verdicts entries are pruned (no orphan retention when source-of-truth has no SHAs)"
metrics:
  duration: "10m 21s"
  completed: "2026-07-04T18:50:20Z"
  tasks_completed: 4
  files_created: 8
  files_modified: 0
status: complete
---

# Phase 217 Plan 05: LLM Panel Judge Summary

k=3 independent-call quorum judge built under `scripts/panel/` with content-hash skip (SC-2), anchor pre-validation (T-217-05-INJECT), parallel panel-findings.json write (T-217-05-EOP), and committed verdicts cache with anti-rot lint.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| T1 RED | excerpt.test.mjs failing tests | a3fa6cf1 | scripts/panel/excerpt.test.mjs |
| T1 GREEN | excerpt.mjs — anchor-preserving DOM canonicalization | a5d78b33 | scripts/panel/excerpt.mjs |
| T2 | lenses.mjs — 4 lens definitions + prompt assembly | b1de59ba | scripts/panel/lenses.mjs |
| T3 RED | judge.test.mjs call-counter failing tests | c87a69d6 | scripts/panel/judge.test.mjs |
| T3 GREEN | judge.mjs — k=3 quorum panel judge | 9ede8b5e | scripts/panel/judge.mjs |
| T4 | admin-panel-verdicts.json + panel-verdicts-lint.sh | 08be41ef | guides/reference/admin-panel-verdicts.json, scripts/ci/panel-verdicts-lint.sh, scripts/ci/panel-verdicts-lint.test.sh |

## Verification Results

All plan verification criteria pass:

- `node scripts/panel/excerpt.test.mjs` — 15/15 PASS
- `node scripts/panel/judge.test.mjs` — 11/11 PASS (0 real API calls — injected test-double only)
- `bash scripts/ci/panel-verdicts-lint.test.sh` — 8/8 PASS
- `bash scripts/ci/panel-verdicts-lint.sh` — PASS (empty cells skeleton)
- `grep -rn 'ANTHROPIC_API_KEY' guides/reference/admin-panel-verdicts.json` — 0 results (PASS)
- No `temperature`/`top_p`/`top_k`/prefill in non-comment code in `judge.mjs` — PASS

## Must-Haves Status

| Truth | Status |
|-------|--------|
| excerpt.mjs retains structural anchors, strips volatile attrs | PASS — 15 tests |
| judge.mjs k=3 independent calls, NO temp/top_p/top_k, output_config.format, base64 block, cached system | PASS — implemented |
| >=2/3 quorum admission; worst-verdict severity; first-winning description | PASS — 4 tests |
| Unchanged render_sha256 + matching provenance → ZERO API calls | PASS — callCount===0 test |
| Panel findings → panel-findings.json ONLY, NEVER findings.json | PASS — 2 tests |
| admin-panel-verdicts.json keyed on render_sha256, NEVER open_findings | PASS — lint test 4 |

## Deviations from Plan

**1. [Rule 2 - Auto-add] excerpt.mjs retains ALL class tokens (not just sg-*)**
- Found during Task 1 GREEN: the plan says "retain structural anchors (data-testid, data-sg-*, role, aria-label, semantic sg-* classes)" but restricting to only sg-* classes would break anchors that use e.g. Bootstrap or custom app classes that the LLM might reference.
- Fix: retained ALL class tokens (sorted for determinism) so any class-based CSS selector in a finding can be pre-validated against the DOM. The sg-* filter only applies to what the LLM must cite per the forced-floor; excerpt.mjs is the DOM representation layer, not the citation enforcement layer.
- Files modified: scripts/panel/excerpt.mjs (class token retention logic)

**2. [Rule 1 - Bug] panel-verdicts-lint.sh prune mode initial logic inverted**
- Found during Task 4 test run: the original prune logic kept entries when `current.size === 0` (i.e., when admin-render-sha.json has no cells), but the correct behavior is to prune ALL entries when there are no current SHAs (everything is orphaned).
- Fix: inverted the condition — prune entries when current.size > 0 AND entry SHA not in current; keep only what matches. Empty current-sha set = prune everything.
- Files modified: scripts/ci/panel-verdicts-lint.sh (prune node -e block)

## Known Stubs

None. All exports are fully implemented:
- `excerpt.mjs` is a complete pure function
- `lenses.mjs` returns full prompt with all 4 lenses and forced-floor instruction
- `judge.mjs` makes real k=3 calls (using SDK injected by caller); CLI entry point reads from admin-render-sha.json
- `admin-panel-verdicts.json` is a valid empty skeleton (cells populated off-CI by judge.mjs)
- `panel-verdicts-lint.sh` validates all 6 invariants

The judge's CLI path (`outputDir`, `excerptDom` read from bundle dir) is a thin wrapper around `runJudge` — the full wiring to the bundle filesystem is done by `admin-panel.sh` (Plan scope: D-02 orchestrator script, not this plan).

## Threat Surface Scan

All threat mitigations from the plan's STRIDE register implemented:

| Threat | Mitigation Status |
|--------|-------------------|
| T-217-05-INJECT: prompt injection via DOM fabricating an anchor | MITIGATED — every anchor pre-validated via cheerio $() before hashing; hallucinated anchors dropped silently before quorum vote |
| T-217-05-KEY: API key leakage into committed ledger/report/log | MITIGATED — key env-only (SDK reads it); only prompt_sha stored in verdicts; grep confirms no ANTHROPIC_API_KEY in verdicts file |
| T-217-05-EOP: panel findings inflating open_findings | MITIGATED — judge writes ONLY panel-findings.json; findings.json never touched; verdicts lint rejects open_findings field |
| T-217-05-400: unsupported sampling params 400 the model | MITIGATED — no temperature/top_p/top_k/prefill/fixed-thinking-budget in messages.create call |

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| scripts/panel/excerpt.mjs | FOUND |
| scripts/panel/excerpt.test.mjs | FOUND |
| scripts/panel/lenses.mjs | FOUND |
| scripts/panel/judge.mjs | FOUND |
| scripts/panel/judge.test.mjs | FOUND |
| guides/reference/admin-panel-verdicts.json | FOUND |
| scripts/ci/panel-verdicts-lint.sh | FOUND |
| scripts/ci/panel-verdicts-lint.test.sh | FOUND |
| commit a3fa6cf1 (excerpt RED) | FOUND |
| commit a5d78b33 (excerpt GREEN) | FOUND |
| commit b1de59ba (lenses) | FOUND |
| commit c87a69d6 (judge RED) | FOUND |
| commit 9ede8b5e (judge GREEN) | FOUND |
| commit 08be41ef (verdicts + lint) | FOUND |
