---
phase: 217-adversarial-panel-auto-fix-safety-rails
fixed_at: 2026-07-04T22:00:00Z
review_path: .planning/phases/217-adversarial-panel-auto-fix-safety-rails/217-REVIEW.md
iteration: 2
findings_in_scope: 14
fixed: 14
skipped: 0
status: all_fixed
---

# Phase 217: Code Review Fix Report

**Fixed at:** 2026-07-04
**Source review:** .planning/phases/217-adversarial-panel-auto-fix-safety-rails/217-REVIEW.md
**Iteration:** 2

> Note: this report supersedes the iteration-1 fix report from the earlier review
> round (which addressed a different, now-historical set of same-numbered findings).
> The IDs below refer to the current `217-REVIEW.md` (14 findings).

**Summary:**
- Findings in scope: 14 (fix_scope=all — Critical + Warning + Info)
- Fixed: 14
- Skipped: 0

All fixes were verified with the relevant hermetic self-tests (13 Phase-217
self-tests + both live anti-rot lints all green) and per-file syntax checks
(`node --check`, `bash -n`, YAML parse). Several fixes are logic-affecting and
are flagged below as **requires human verification**.

## Fixed Issues

### CR-01: finding_id keyspace split — fix-queue-build.mjs did not canonicalize the anchor

**Files modified:** `scripts/ci/fix-queue-build.mjs`, `scripts/panel/panel-schema.mjs`
**Commit:** 18703fa4
**Applied fix:** Exported `canonicalizeAnchor` from `panel-schema.mjs`; `fix-queue-build.mjs`
now imports the single canonical `findingId` helper (deleting its local non-canonicalizing
copy) and canonicalizes the anchor inside `systemicGroup` before hashing. Verified that
`[data-testid='mg-5-populated']` (single-quoted) and its double-quoted form now produce the
same 64-char ID, so settled-findings suppression, the poison-set, and panel↔probe dedup share
one key space. **Requires human verification** — cross-module ID identity is a correctness
invariant; a dedicated cross-module equality assertion (suggested by the review) is a
recommended follow-on but was not added as a new test.

### CR-02: PANEL_SCHEMA schema_version enum ('217-01') contradicted judge.mjs ('217-05')

**Files modified:** `scripts/panel/panel-schema.mjs`
**Commit:** 83fd27f2
**Applied fix:** Updated both `CELL_SCHEMA` branches (finding + keep) so
`schema_version` enum is `['217-05']`, matching `judge.mjs SCHEMA_VERSION`,
`admin-panel-verdicts.json`, and `judge.test.mjs`. No `217-01` references remain.
`panel-schema.test.mjs` passes (12/12).

### WR-01: Anti-rot lints not on the merge-blocking path

**Files modified:** `.github/workflows/ci.yml`
**Commit:** c2fa9adf
**Applied fix:** Added merge-blocking `fast_checks` steps invoking `fix-queue-lint.sh`
and `panel-verdicts-lint.sh` (both read committed state only). This makes the "every
CI run" claim in their headers true. Both lints verified passing on committed state.

### WR-02: Seven Phase-217 self-tests never executed in CI

**Files modified:** `.github/workflows/ci.yml`
**Commit:** eeac655c
**Applied fix:** Wired all seven into `fast_checks`. Adapted the review's suggestion:
five (`anchor`, `panel-schema`, `fix-queue-build`, `fix-queue-lint`, `panel-verdicts-lint`)
are fully hermetic and run on the default node with zero setup cost. **The review's claim
that all seven are hermetic was inaccurate** — `excerpt.test.mjs` and `judge.test.mjs`
transitively require `cheerio` (loaded from the Playwright subproject `node_modules`), so
for those two I added a pinned `setup-node` + scoped `npm ci --ignore-scripts` in the
playwright dir before running them, keeping them on the merge path. All seven verified
passing (with cheerio installed for the latter two).

### WR-03: resolveTokenRef mislabeled control-scale tokens as radius tokens

**Files modified:** `scripts/panel/fix-apply.mjs`, `scripts/panel/fix-apply.test.mjs`
**Commit:** c5ce9c55
**Applied fix:** `resolveTokenRef` now receives the `finding` and only resolves a 4-entry
scale to a radius token when `finding.token_family === 'radius'`; otherwise it returns
`null` (refuse → judgment) rather than guessing radius for an off-scale control value.
Updated the Test 1 radius fixture to declare `token_family: 'radius'` and added Test 1e/1f
proving a 4-entry scale without the hint is refused (content unchanged). fix-apply.test.mjs
passes 41/41. **Requires human verification** — this changes apply behavior: upstream
producers (`fix-queue-build.mjs` / probes) do not yet emit `token_family`, so real radius
findings will be refused (safe fallback → judgment) until that hint is threaded through.
Emitting `token_family` on fix-queue entries is a recommended follow-on.

### WR-04: fix-apply --queue mode was dead code that always reported "0 applied"

**Files modified:** `scripts/panel/fix-apply.mjs`
**Commit:** 63987008
**Applied fix:** `--queue` mode now refuses loudly (exit 2) and redirects the operator to
`admin-autofix-loop.sh` (which owns the surface→file mapping) instead of silently printing
"0 applied" and exiting 0. Updated the usage banner and header docs accordingly. Verified
`node fix-apply.mjs --queue ...` exits 2 with the redirect message.

### WR-05: --dry-run restore swallowed failures and could leave a dirty tree

**Files modified:** `scripts/ci/admin-autofix-loop.sh`
**Commit:** c5ddc0fd
**Applied fix:** Removed the `2>/dev/null || true` swallow on the dry-run restore; the
script now runs `git checkout -- "$TARGET_FILE"` and hard-fails (`exit 1`) if
`git diff --quiet` still shows the file dirty, honoring the "never leave a dirty tree"
guarantee.

### WR-06: `git add -A` staged unrelated changes into the "one fix per commit" commit

**Files modified:** `scripts/ci/admin-autofix-loop.sh`
**Commit:** c5ddc0fd
**Applied fix:** Changed `git add -A` to `git add -- "$TARGET_FILE"` so each fix commit
contains only the file the fix touched. Re-render side effects and ledger deltas (which run
after the commit) are no longer folded in, restoring true per-fix atomicity for `git revert`.
Verified by the loop self-test, which now produces a real single-file autofix commit followed
by a clean revert.

### WR-07: Rail 3 skipped under --skip-render but loop still printed "all 4 rails green"

**Files modified:** `scripts/ci/admin-autofix-loop.sh`
**Commit:** c5ddc0fd
**Applied fix:** Removed the `SKIP_RENDER` guard around rail 3 (`fix-queue-lint.sh` +
`evidence-anchor-check.mjs`) since both read committed state and need no live render. All
four rails now run unconditionally, so the "all 4 rails green" message is accurate; only the
re-render itself remains gated on `SKIP_RENDER`. Loop self-test passes (9/9).

> WR-05, WR-06, and WR-07 all touch `scripts/ci/admin-autofix-loop.sh`; because the
> commit tool stages by file path (not hunk), they landed together in commit c5ddc0fd.

### IN-01: judge.mjs CLI passed empty excerptDom/factsJson to a real (paid) API call

**Files modified:** `scripts/panel/judge.mjs`
**Commit:** af7ddd5b
**Applied fix:** The CLI path now reads `dom.html` / `facts.json` from the bundle output dir
(`outputDir` override or `eval/<sha>/<surface>/<cell>`) and hard-refuses (exit 1) when the DOM
excerpt is empty, instead of firing k paid API calls against an empty DOM that would degrade
every cell to keep. judge.test.mjs passes (11/11). **Requires human verification** — the
bundle dir path convention should be confirmed against the actual harness output layout.

### IN-02: excerpt.mjs class-attr comment contradicted the code

**Files modified:** `scripts/panel/excerpt.mjs`
**Commit:** 4c9592d6
**Applied fix:** Updated the header and inline comments to state that ALL class tokens are
retained (sorted) for anchor fidelity, removing the misleading "keep only sg-*/semantic
tokens" language that described a filter the code does not perform.

### IN-03: stripVsn regex ordering could leave a stray `?`/`&`

**Files modified:** `scripts/panel/excerpt.mjs`
**Commit:** 4c9592d6
**Applied fix:** Reworked the cleanup chain to collapse runs of `&`, normalize `?&`→`?`, and
added a final `.replace(/[?&]$/, '')` guaranteeing no trailing dangling separator. Behavior on
normal single-vsn URLs is unchanged; canonical form is now minimal at the boundary.
excerpt.test.mjs passes (15/15).

> IN-02 and IN-03 both touch `scripts/panel/excerpt.mjs` and landed together in commit 4c9592d6.

### IN-04: admin-autofix-loop interpolated values into inline `node -e` programs

**Files modified:** `scripts/ci/admin-autofix-loop.sh`
**Commit:** a9f2c0ff
**Applied fix:** The poison-set update and `load_eligible` inline node programs now receive the
state-file path, finding_id, poison-set JSON, and max via `process.argv` (single-quoted program
bodies) rather than shell interpolation — including the previously raw-JS-spliced
`new Set(${POISON_IDS})`. The `settled-findings-lint.sh --add` call already passed values as
separate quoted args. Loop self-test passes (9/9).

### IN-05: loop self-test accepted REFUSED/SKIP as pass, so the revert path could go unexercised

**Files modified:** `scripts/ci/admin-autofix-loop.test.sh`
**Commit:** 0196b322
**Applied fix:** Replaced the ambiguous band-edge fixture (`measured_px=[13]` vs
`scale_px=[8,12,16,24]`) with an unambiguously in-band space-scale fixture
(`padding: 12.5px`, `measured_px=[12.5]`, `scale_px=[1..8,10,12]` → `var(--sg-space-12)`),
chosen because space tokens resolve without a `token_family` hint (unlike the now-refused
4-entry radius/control scale from WR-03). The assertion now REQUIRES a Revert commit — a
REFUSED/SKIP outcome is a genuine failure. Verified the full apply→commit→rail-1-trip→revert
chain fires (COMMITTED then REVERTED). Also corrected the wrong-arithmetic comment. This
strengthens the SC-4 integrated-loop proof and doubles as end-to-end validation of the WR-06
single-file staging change. **Requires human verification** — confirm this in-band fixture is
the intended long-term SC-4 proof shape.

---

_Fixed: 2026-07-04_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
