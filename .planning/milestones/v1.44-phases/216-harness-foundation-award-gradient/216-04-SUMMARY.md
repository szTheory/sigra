---
phase: 216-harness-foundation-award-gradient
plan: "04"
subsystem: ci-guards
tags: [ci, guards, monotonic, ratchet, findings, anchor, tsv, bash, node, cheerio]
dependency_graph:
  requires:
    - "216-01: cheerio installed in playwright subproject"
    - "216-02: settled-findings.tsv + admin-render-sha.json + admin-eval-schema.md"
  provides:
    - quality-findings-monotonic.sh (D-21 findings-count down-ratchet guard)
    - settled-findings-lint.sh + --add regen helper (D-22 suppression-set integrity)
    - evidence-anchor-check.mjs (D-09 cite-and-flip prevention via cheerio)
  affects:
    - scripts/ci/ (3 guards + 3 self-tests)
tech_stack:
  added: []
  patterns:
    - quality-ledger-monotonic.sh clone + comparator inversion (D-21)
    - hermetic mktemp throwaway git repo self-test idiom (all .test.sh)
    - createRequire to resolve cheerio from playwright subproject (evidence-anchor-check.mjs)
key_files:
  created:
    - scripts/ci/quality-findings-monotonic.sh
    - scripts/ci/quality-findings-monotonic.test.sh
    - scripts/ci/settled-findings-lint.sh
    - scripts/ci/settled-findings-lint.test.sh
    - scripts/ci/evidence-anchor-check.mjs
    - scripts/ci/evidence-anchor-check.test.mjs
  modified: []
decisions:
  - "quality-findings-monotonic.sh uses node -e to parse admin-render-sha.json — avoids jq dep while keeping the bash-guard idiom"
  - "skip-on-empty-base divergence (D-08/D-21): skip ONLY when ledger file is absent at base; file-exists-with-0 compares, so increase from 0 is caught"
  - "settled-findings-lint.sh --add mode validates 64-char hex finding_id and disposition enum; checks for duplicate at add time"
  - "evidence-anchor-check.mjs resolves cheerio via createRequire from playwright subproject — no separate install, no duplicate dep"
  - "isStructuralAnchor rejects prose anchors before passing to cheerio: must start with ./#/[/: or a single lowercase tag name not followed by uppercase prose words"
  - "geometry-only classes (misalignment/below-fold/focus-ring) still require structural anchor in DOM; geometry value not re-evaluated post-capture (D-09/D-11)"
metrics:
  duration: ~15min
  completed: "2026-07-03"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 6
status: complete
---

# Phase 216 Plan 04: Three Forward-Only Integrity Guards Summary

Built the three deterministic merge-blocking guards: `quality-findings-monotonic.sh` (open-finding-count down-ratchet cloned from the existing tier guard with comparator inverted), `settled-findings-lint.sh` (sorted/deduped suppression-set enforcer with `--add` regen helper), and `evidence-anchor-check.mjs` (cheerio anchor-presence check defeating cite-and-flip). Each guard ships with a hermetic self-test that proved the invariant empirically.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | quality-findings-monotonic.sh + hermetic .test.sh (D-21) | adb2e198 | scripts/ci/quality-findings-monotonic.sh, scripts/ci/quality-findings-monotonic.test.sh |
| 2 | settled-findings-lint.sh + regen helper + hermetic .test.sh (D-22) | ab00cd4b | scripts/ci/settled-findings-lint.sh, scripts/ci/settled-findings-lint.test.sh |
| 3 | evidence-anchor-check.mjs + node self-test (D-09) | e17e2a2f | scripts/ci/evidence-anchor-check.mjs, scripts/ci/evidence-anchor-check.test.mjs |

## Verification Results

- `bash scripts/ci/quality-findings-monotonic.test.sh`: 7/7 pass — 3→4 FAIL, no-change PASS, 3→2 PASS, 0→1 FAIL (D-08/D-21 increase-from-0 caught)
- `bash scripts/ci/settled-findings-lint.test.sh`: 9/9 pass — sorted-empty PASS, unsorted FAIL, dup FAIL, --add round-trip PASS
- `bash scripts/ci/settled-findings-lint.sh`: PASS (no data rows — trivially valid against committed empty TSV)
- `node scripts/ci/evidence-anchor-check.test.mjs`: 10/10 pass — present PASS, absent exit 1, prose rejected, geometry+present PASS, geometry+absent exit 1

## Guard Details

### quality-findings-monotonic.sh (D-21)

Structural clone of `quality-ledger-monotonic.sh` with the comparator inverted:
- The tier guard FAILS when `head_tier < base_tier` (tier decreased)
- This guard FAILS when `head_count > base_count` (open findings increased)
- LEDGER = `guides/reference/admin-render-sha.json` (single authoritative source per eval-schema.md)
- Uses `node -e` to parse JSON into `<surface>/<cell>\t<count>` lines — avoids jq dependency
- skip-on-empty-base divergence (D-08/D-21): skips only when the ledger FILE is absent at base (true initial commit); when the file exists with cells at 0, an increase from 0 IS a regression and IS caught

### settled-findings-lint.sh (D-22)

Three invariants enforced:
1. Every data row has exactly 7 tab-separated columns
2. Rows are sorted by `finding_id` (column 1) — lexicographic ascending
3. No duplicate `finding_id` values

Empty data set (header-only) passes trivially. `--add <finding_id> --surface … --class … --anchor … --disposition <waived|resolved> [--waived-by X] [--note ...]` appends and re-sorts in place, so humans never hand-edit ordering. Validates `finding_id` is 64-char lowercase hex; validates disposition enum; rejects duplicate at add time.

### evidence-anchor-check.mjs (D-09)

For each bundle under `test/example/priv/playwright/eval/<sha>/**/`:
1. Reads `dom.html` + `findings.json`
2. Parses DOM with `cheerio.load(html)` in HTML mode (not xmlMode — D-09)
3. Validates each finding's `anchor` is a structural selector (starts with `.#[: or bare tag name`) — prose/line-number anchors rejected before cheerio (T-216-04-INJECT)
4. Asserts `$(finding.anchor).length > 0` — absent anchor → `FAIL` + `process.exitCode = 1`
5. Geometry-only classes (misalignment/below-fold/focus-ring) still require a structural anchor in the DOM; the geometry value itself is not re-evaluated here (D-09/D-11: no layout engine)
6. Anchors run through cheerio `$()` ONLY — never `eval` or shell-interpolated

cheerio is resolved via `createRequire` from `test/example/priv/playwright/package.json` (where cheerio ^1.2.0 was installed in Plan 01) — no separate install needed.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Implementation Notes

**Task 3 `isStructuralAnchor` iteration:** The initial regex allowed `"the Save button label"` to pass because the character class `[.#\[: >~+*,]` inadvertently included a literal space, causing `"the "` (tag + space) to match. Fixed by requiring selector-syntax characters after the tag name AND explicitly rejecting patterns where a lowercase tag-like word is followed by uppercase prose (`/^[a-z][a-z0-9-]+\s+[A-Z]/`). Final version correctly distinguishes `"div .sg-btn"` (valid descendant selector) from `"the Save button label"` (prose). Verified with 9 test cases covering good/bad anchors before and after fix.

**Hermetic test scaffold issue:** Initial `run_guard()` function in settled-findings-lint.test.sh captured the guard's stdout AND `echo "$code"` together via `$()`, causing "settled: unbound variable" when bash tried to interpret the guard's multi-line output as a variable. Fixed by running the guard with explicit stdout/stderr redirects to temp files and capturing the exit code via `$?` directly.

## Threat Mitigations Delivered

| Threat ID | Mitigation |
|-----------|------------|
| T-216-04-CITE | evidence-anchor-check asserts every finding's structural anchor exists in the CAPTURED DOM; absent anchor → exit 1. Self-test Test B proves this. |
| T-216-04-REGRESS | quality-findings-monotonic.sh FAILs on any per-cell open-count increase vs merge-base; increase-from-0 caught (Test D). |
| T-216-04-WAIVE | settled-findings-lint enforces sorted/deduped; --add prevents silent reordering. |
| T-216-04-INJECT | Anchors run through cheerio `$()` ONLY; finding JSON is parsed, never bash/eval-interpolated; prose anchors rejected before cheerio. |

## Self-Check: PASSED

Created files:
- scripts/ci/quality-findings-monotonic.sh: FOUND
- scripts/ci/quality-findings-monotonic.test.sh: FOUND
- scripts/ci/settled-findings-lint.sh: FOUND
- scripts/ci/settled-findings-lint.test.sh: FOUND
- scripts/ci/evidence-anchor-check.mjs: FOUND
- scripts/ci/evidence-anchor-check.test.mjs: FOUND

Commits:
- adb2e198: quality-findings-monotonic guard
- ab00cd4b: settled-findings-lint guard
- e17e2a2f: evidence-anchor-check guard

All self-tests green (7 + 9 + 10 = 26 assertions passing).
