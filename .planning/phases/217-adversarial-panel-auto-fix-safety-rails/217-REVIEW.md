---
phase: 217-adversarial-panel-auto-fix-safety-rails
reviewed: 2026-07-04T00:00:00Z
depth: standard
files_reviewed: 36
files_reviewed_list:
  - .github/workflows/ci.yml
  - guides/reference/admin-eval-runbook.md
  - guides/reference/admin-graphic-design-lens.md
  - guides/reference/admin-panel-verdicts.json
  - guides/reference/admin-render-sha.json
  - guides/reference/fix-queue.json
  - scripts/ci/admin-autofix-loop.sh
  - scripts/ci/admin-autofix-loop.test.sh
  - scripts/ci/admin-eval-harness.sh
  - scripts/ci/admin-panel.sh
  - scripts/ci/evidence-anchor-check.mjs
  - scripts/ci/fix-queue-build.mjs
  - scripts/ci/fix-queue-build.test.mjs
  - scripts/ci/fix-queue-lint.sh
  - scripts/ci/fix-queue-lint.test.sh
  - scripts/ci/lib/anchor.mjs
  - scripts/ci/lib/anchor.test.mjs
  - scripts/ci/panel-ci-isolation.test.sh
  - scripts/ci/panel-forced-floor-check.mjs
  - scripts/ci/panel-forced-floor-check.test.mjs
  - scripts/ci/panel-verdicts-lint.sh
  - scripts/ci/panel-verdicts-lint.test.sh
  - scripts/panel/copy-rules.json
  - scripts/panel/excerpt.mjs
  - scripts/panel/excerpt.test.mjs
  - scripts/panel/fix-apply.mjs
  - scripts/panel/fix-apply.test.mjs
  - scripts/panel/judge.mjs
  - scripts/panel/judge.test.mjs
  - scripts/panel/lenses.mjs
  - scripts/panel/panel-schema.mjs
  - scripts/panel/panel-schema.test.mjs
  - test/example/lib/example_web/live/admin/design_gallery_live.ex
  - test/example/priv/playwright/package-lock.json
  - test/example/priv/playwright/package.json
findings:
  critical: 2
  warning: 7
  info: 4
  total: 13
status: issues_found
---

# Phase 217: Code Review Report

**Reviewed:** 2026-07-04
**Depth:** standard
**Files Reviewed:** 36
**Status:** issues_found

## Summary

Reviewed the adversarial LLM panel (`judge.mjs`, `lenses.mjs`, `excerpt.mjs`,
`panel-schema.mjs`) plus the deterministic auto-fix pipeline (`fix-apply.mjs`,
`admin-autofix-loop.sh`, `fix-queue-build.mjs`) and the CI wiring.

**Security posture is largely sound.** The most dangerous surfaces are guarded
by construction: LLM anchors run through `cheerio $()` only (never eval/shell),
the API-key never leaves env, the loop reverts (never resets/force-pushes), and
CSS files are refused. I confirmed via `.github/workflows/ci.yml` that neither
`admin-autofix-loop.sh` nor `admin-panel.sh` is wired into any CI lane (only
their self-tests run) — the JUDGE-CI-01 guarantee holds.

**However, the auto-fix apply layer has two blocker-class defects that make it
unsafe or non-functional in practice:**

1. The copy-swap path is **not anchor-scoped** — it rewrites *every* text node in
   the whole target file, and its transforms corrupt technical terminology
   (`MFA`→`Mfa`, `API`→`Api`, `DEV ONLY`→`Dev Only`), directly violating the
   module's own "text-node-only, never technical terminology" contract.
2. The autofix loop's `git add -A` + post-commit re-render churns the git-tracked
   `fix-queue.json` / `admin-render-sha.json` ledgers into fix commits and leaks
   uncommitted ledger drift across iterations, defeating the "one fix per commit"
   invariant and corrupting the revert boundary.

There is also a material correctness gap: the token-swap path requires
`measured_px`/`scale_px` fields that `fix-queue-build.mjs` never emits, so every
real `token` finding is refused at apply time (the token auto-apply path is dead
on live data).

## Structural Findings (fallow)

No `<structural_findings>` block was provided with this review. This section is
intentionally empty; all findings below are narrative (direct code review).

## Critical Issues

### CR-01: Copy-swap mutates the entire file (not the finding's anchor) and corrupts acronyms/technical terms

**File:** `scripts/panel/fix-apply.mjs:254-376` (`applyCopySwap` / `applyCopyRule`)
**Issue:**
`applyCopySwap` never reads `finding.anchor`. It loads `copy-rules.json` and runs
every rule against **every text node in the whole file** via the global
`/>([^<]+)</g` pattern. Combined with `surface_to_file()` in
`admin-autofix-loop.sh:166-185` — which maps *all* `board-*` surfaces to the
single `design_gallery_live.ex` — a single copy finding rewrites unrelated copy
across the entire design gallery.

Worse, the `title_case` and `terminal_period` transforms match any node passing
`/^[A-Za-z ]+$/` and destroy technical terminology. Verified live:

```
title_case("MFA")      -> "Mfa"
title_case("API")      -> "Api"
title_case("DEV ONLY") -> "Dev Only"
```

`design_gallery_live.ex` contains `<dt class="sg-kv__term">MFA</dt>` (lines 1016,
1055) and `<span ...>DEV ONLY</span>` (line 30) — both would be silently
corrupted. This directly contradicts the file's own contract (line 8: "NEVER
touches component/judgment findings", line 291: "text-node-only") and
`copy-rules.json:60` (`_judgment_boundary`: "never affect technical
terminology"). An untrusted-verdict-driven copy fix therefore produces
incorrect, semantically damaging edits well outside its cited scope.

**Fix:** Scope copy edits to the finding's anchor subtree only, and add an
acronym/technical-term guard. Minimum viable fix:

```js
export function applyCopySwap(content, finding) {
  // ...existing eligibility checks...
  // 1. Only operate on the element(s) matched by finding.anchor, not the whole file.
  //    Parse with cheerio (already a dep), select finding.anchor, and transform
  //    only text nodes inside those elements.
  // 2. In title_case/sentence_case, skip tokens that are all-uppercase acronyms:
  //      if (/^[A-Z]{2,}$/.test(word)) return word;  // preserve MFA, API, SSO...
}
```

Until anchor-scoping lands, the loop must not route copy findings through a
shared multi-surface file. (Note: the *current* live `fix-queue.json` emits zero
`fix_class:"copy"` entries, so this is not yet firing — but the code is a live
foot-gun the moment a copy finding appears, and the self-test in
`fix-apply.test.mjs` Test 5 accepts the whole-file rewrite as passing.)

### CR-02: Autofix loop breaks the "one fix per commit" invariant — `git add -A` + re-render churns tracked ledgers

**File:** `scripts/ci/admin-autofix-loop.sh:371-393` (commit → re-render ordering)
**Issue:**
The loop commits the fix with `git add -A` (line 371) — staging the *entire*
working tree, not just `$TARGET_FILE`. Then, **after** committing, it re-renders
via `admin-eval-harness.sh` (line 387), which runs `fix-queue-build.mjs` — the
sole writer of the git-tracked files `guides/reference/fix-queue.json` and
`guides/reference/admin-render-sha.json` (both confirmed tracked via
`git ls-files`). This produces two concrete defects:

1. **Uncommitted ledger drift leaks across iterations.** The re-render rewrites
   `fix-queue.json` / `admin-render-sha.json` in the working tree *after* the fix
   commit. Those changes are never committed for this iteration, so the next
   iteration's `git add -A` sweeps the *previous* finding's re-render churn into
   the *next* finding's commit. Commits no longer correspond one-to-one to fixes.

2. **Revert boundary is corrupted.** On a rail trip, `git revert --no-edit HEAD`
   (line 402) reverts only the fix commit. The re-rendered ledger deltas sitting
   in the working tree are *not* reverted, so `open_findings` / queue state can be
   left inconsistent with the reverted source — precisely the "restore to
   baseline" property Rail 1/4 exist to guarantee. The self-test
   (`admin-autofix-loop.test.sh`) masks this by running with `--skip-render` and a
   post-commit `--amend` hook, so the real re-render ordering is never exercised.

**Fix:** Stage only the target file, and commit (or explicitly discard) the
re-render ledger churn as its own step:

```bash
# Instead of `git add -A`:
git -C "$ROOT" add -- "$TARGET_FILE"
git -C "$ROOT" commit -m "$COMMIT_MSG"
FIX_COMMIT=$(git -C "$ROOT" rev-parse --short HEAD)

# After re-render, commit the derived-ledger update as a SEPARATE, clearly-labeled
# commit (or `git checkout -- guides/reference/{fix-queue,admin-render-sha}.json`
# if the loop should not persist re-render output). Then on revert, also reset the
# working tree for those ledgers so the rail's "restore to baseline" holds:
git -C "$ROOT" revert --no-edit HEAD
git -C "$ROOT" checkout -- guides/reference/fix-queue.json guides/reference/admin-render-sha.json
```

## Warnings

### WR-01: Token-swap path is dead on real data — required `measured_px`/`scale_px` fields are never produced

**File:** `scripts/panel/fix-apply.mjs:142-202` and `scripts/ci/fix-queue-build.mjs:222-300`
**Issue:**
`applyTokenSwap` refuses unless the finding carries `measured_px` (line 152-155)
and reads `scale_px` for nearest-token matching. But `fix-queue-build.mjs` — the
sole producer of `fix-queue.json` — never emits either field (verified:
`grep -c "measured_px\|scale_px" fix-queue.json` → 0, across all 12 `token`
entries). Every real token finding therefore hits `no measured_px values` and is
refused. The entire token auto-apply class is non-functional on live queue data;
it only "works" in `fix-apply.test.mjs`, which hand-constructs findings with those
fields inline. This is a producer/consumer contract mismatch.
**Fix:** Have `fix-queue-build.mjs` populate `measured_px` and `scale_px` from the
probe `facts.json` when classifying an `off-scale-radius-shadow-control` finding
as `token`, or explicitly document token as human-queue-only and remove the dead
apply branch.

### WR-02: Token-swap regex replaces only the FIRST occurrence per style attribute and can emit invalid CSS

**File:** `scripts/panel/fix-apply.mjs:172-185, 209-236`
**Issue:**
Two problems in the token replacement:
(a) The pattern `(style=["'][^"']*?)\bNpx(\s*!important)?([^"']*)` captures the
rest of the attribute in the greedy `([^"']*)` "post" group and re-emits it
verbatim. So in `style="padding: 4px 12px"`, only the first `4px` is swapped;
a second matching value in the same attribute is silently skipped (verified via
reproduction). (b) `resolveTokenRef` (line 235) fallback returns
`var(--sg-token-12px/* nearest token at 12px */)` — this is **invalid
CSS/HEEx**: an unterminated `var()` with an embedded comment inside a bare inline
style, which would break the rendered attribute if the fallback branch is ever
reached (any radius-vs-control ambiguity, or a non-space/non-4-entry scale).
**Fix:** Iterate all occurrences (drop the trailing `[^"']*` capture; use a
value-boundary-anchored replace), and make `resolveTokenRef`'s fallback refuse
(return the value unchanged + downgrade to judgment) rather than emit malformed
CSS.

### WR-03: Copy `replace` rule uses a stateful global regex with `.test()` — fragile lastIndex dependence

**File:** `scripts/panel/fix-apply.mjs:360-366`
**Issue:**
`const matchRe = new RegExp(escapeRegex(rule.match_pattern), 'g')` is reused
across every text node, and `matchRe.test(text)` advances `matchRe.lastIndex`.
The subsequent `text.replace(matchRe, ...)` happens to reset `lastIndex`, so it
currently works by accident of control flow — but any refactor that adds a
non-matching branch (a `.test()` without a following `.replace()`) will start
skipping valid matches intermittently. This is a latent correctness landmine.
**Fix:** Don't use `.test()` on a `/g` regex for a boolean check; either construct
a non-global copy for the test, or reset `matchRe.lastIndex = 0` before each
`.test()`, or drop the `.test()` guard entirely and set `applied` based on whether
`.replace()` changed the string.

### WR-04: `checkApplySurface` allows non-admin example LiveViews, widening the auto-edit blast radius

**File:** `scripts/panel/fix-apply.mjs:62-71`
**Issue:**
`APPLY_SURFACE_PATTERNS` includes `/test\/example\/lib\/[^/]+_web\/live\/.*\.(heex|ex)$/`
— i.e. *any* example LiveView, not just `.../live/admin/...`. The module docstring
(lines 24-27) claims the surface is "admin LiveView .heex ... and test/example
only", implying admin-scoped. A finding whose `surface` mis-maps (or a future
`surface_to_file` entry) could drive a deterministic edit into a non-admin example
LiveView (auth flows, account hub, etc.) outside the intended admin scope.
**Fix:** Tighten the example patterns to `.../live/admin/...` only, matching the
library-side pattern, unless non-admin example surfaces are an intentional target
(then document it).

### WR-05: `stripVsn` "double-&" cleanup runs once and can leave a malformed URL

**File:** `scripts/panel/excerpt.mjs:84-92`
**Issue:**
After removing `[?&]vsn=...` segments, the cleanup
`.replace(/&&/g, '&').replace(/\?&/, '?').replace(/&$/, '')` uses non-global
replaces for `\?&` and does a single `&&`→`&` pass. A URL with three consecutive
stripped params (`?vsn=a&vsn=b&vsn=c&x=1`) can collapse to `&&&x=1`; the single
`/&&/g` pass turns `&&&` into `&&` (overlapping matches aren't handled), and only
the first `?&` is fixed. The excerpt feeds the LLM and the `prompt_sha`, so a
malformed-but-deterministic href only risks prompt quality, not security — hence
WARNING not BLOCKER. **Fix:** Loop the collapse (`while (/&&|\?&/.test(...))`) or
parse with `URL`/`URLSearchParams` and re-serialize.

### WR-06: `fix-queue-build.mjs` trusts `finding.finding_id` from bundle JSON instead of always recomputing

**File:** `scripts/ci/fix-queue-build.mjs:189-190`
**Issue:**
`const fid = finding.finding_id || findingId(surface, klass, anchor)` trusts a
pre-existing `finding_id` in the bundle when present. Bundles under
`eval/<sha>/...` are gitignored and regenerated, but the whole point of the D-12
"never trust a typed bit" principle (applied correctly for `auto_eligible` at line
225) is undermined here: a stale or malformed bundle `finding_id` that doesn't
match `(surface, class, anchor)` would flow into `fix-queue.json`, mis-key the
settled-set subtraction, and could smuggle a poisoned/settled finding back into
the open queue. `evidence-anchor-check.mjs` validates anchor presence but not
`finding_id` consistency at this stage.
**Fix:** Always recompute: `const fid = findingId(surface, klass, anchor);` and, if
you want to detect drift, assert it matches any provided `finding.finding_id`.

### WR-07: `admin-panel.sh` interpolates surface/sha strings into inline `node -e` scripts

**File:** `scripts/ci/admin-panel.sh:99-104, 122-130, 154-171`
**Issue:**
Surface names and render-shas read from `admin-render-sha.json` are string-
interpolated directly into `node -e "... '$surface' ..."` bodies. These values are
currently controlled (committed JSON, and shas are hex-validated elsewhere), so
this is not an exploitable injection today — but a surface key containing a single
quote would break out of the JS string literal and execute arbitrary JS in the
node process. Since this script is operator-run with a live API key, defense in
depth matters. **Fix:** Pass values via `process.argv`/env instead of
interpolation, e.g. `node -e '...' "$surface"` and read `process.argv[1]`, so the
shell value can never terminate a JS literal. The same idiom appears in
`admin-autofix-loop.sh` (`load_eligible`, per-finding `node -e "... $i ..."`) but
there the interpolated values are numeric indices / JSON blobs passed as argv, so
it is lower risk.

## Info

### IN-01: Dead/immediately-overwritten import bindings in `fix-queue-lint.sh`

**File:** `scripts/ci/fix-queue-lint.sh:48`
**Issue:** `const { readFileSync } = require("node:crypto") ? require : { readFileSync: require("node:fs").readFileSync };`
is a confusing no-op: `require("node:crypto")` is always truthy, so this always
binds `readFileSync = require` (a function, not `readFileSync`), and the binding is
never used — the code uses `fs.readFileSync` throughout. Dead, misleading code.
**Fix:** Delete the line.

### IN-02: `judge.mjs` queue/CLI mode is a non-functional stub

**File:** `scripts/panel/fix-apply.mjs:524-538` and `scripts/panel/judge.mjs:609`
**Issue:** `fix-apply.mjs` `--queue` mode loops over eligible findings but only
prints a "no target file in queue mode" warning and reports `0 applied` (the
`applied` counter is never incremented). Separately, `judge.mjs` CLI passes
`excerptDom: ''` with a literal `// TODO: read from bundle dir` (line 609), so the
direct CLI path judges against an empty DOM (no anchor validation possible). Both
are acknowledged stubs but ship as if wired.
**Fix:** Either implement or clearly mark these entrypoints as non-operational to
avoid a false sense of coverage.

### IN-03: `reconcileFindings` "worst verdict" ignores `keep` samples silently

**File:** `scripts/panel/judge.mjs:130-158`
**Issue:** `winningSamples` filters by `findingId`, but `keep` cells always carry
`findingId: null` (parseSampleFindings line 217), so they can never be winning
samples — fine — but the default fallback `{ severity: 'keep', ... }` (line 133)
returns `keep` with empty anchor/description for a `findingId` that had no winning
samples, which then flows into `admittedFindings` with `severity: severity ||
'tighten'` (line 517) → silently becomes `tighten`. Only reachable if `admitted`
contains an id absent from `allSamples` (shouldn't happen), but the defaulting is
brittle. **Fix:** Assert `winningSamples.length > 0` for any admitted id.

### IN-04: Magic numbers and duplicated finding-id formula across three files

**File:** `scripts/panel/panel-schema.mjs:68-77`, `scripts/ci/fix-queue-build.mjs:64-68`, `scripts/ci/panel-verdicts-lint.sh:189-198`
**Issue:** The `sha256(surface \0 class \0 anchor)` finding-id formula and the
anchor quote-canonicalization regex are re-implemented independently in three
places (a shared JS lib, an inline builder copy, and an inline bash-embedded node
copy). They agree today, but any change must be made in lockstep or finding-ids
silently diverge and the settled-set/poison-set stops matching. **Fix:** Import
`findingId` from `panel-schema.mjs` in `fix-queue-build.mjs`; for the bash lint,
shell out to a tiny shared node helper instead of re-embedding the formula.

---

_Reviewed: 2026-07-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
