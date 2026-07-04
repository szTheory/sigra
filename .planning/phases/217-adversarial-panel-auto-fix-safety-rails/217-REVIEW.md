---
phase: 217-adversarial-panel-auto-fix-safety-rails
reviewed: 2026-07-04T00:00:00Z
depth: standard
files_reviewed: 34
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
  - test/example/priv/playwright/package.json
findings:
  critical: 2
  warning: 7
  info: 5
  total: 14
status: issues_found
---

# Phase 217: Code Review Report

**Reviewed:** 2026-07-04
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

This phase adds an adversarial LLM panel judge (`judge.mjs` + `lenses.mjs` + `excerpt.mjs` + `panel-schema.mjs`), a deterministic fix queue (`fix-queue-build.mjs`), a deterministic auto-apply engine (`fix-apply.mjs`), an operator auto-fix loop with four safety rails (`admin-autofix-loop.sh`), and several anti-rot lints. The safety-rail architecture is generally sound: the LLM is kept out of the apply path, `git revert` is used instead of reset/force-push, and CI-isolation is negatively asserted.

Two BLOCKER-class correctness bugs undermine the identity-keyspace guarantee the whole system depends on:

1. **finding_id keyspace split** — `fix-queue-build.mjs` computes finding_id WITHOUT anchor canonicalization, while `panel-schema.mjs` / `judge.mjs` / `panel-verdicts-lint.sh` compute it WITH canonicalization. For any single-quoted attribute anchor, the same finding gets two different IDs, silently breaking settled-findings suppression, poison-set never-retry, and panel↔probe dedup — the exact cross-system linkage D-07/AUTOFIX-01 promises.

2. **schema_version enum mismatch** — the PANEL_SCHEMA constrains `schema_version` to `'217-01'`, but `judge.mjs` stamps admitted findings/verdicts with `'217-05'`. Under structured output (`output_config.format`) an LLM sample that echoes the version is rejected as schema-invalid and degrades to an empty sample, silently weakening quorum.

The most serious quality problem is that the deterministic anti-rot lints and self-tests introduced this phase are largely **not wired into the merge-blocking `fast_checks` job**: `fix-queue-lint.sh`, `panel-verdicts-lint.sh`, and seven new `*.test.*` files never run on the merge path (or run only inside a `continue-on-error: true` off-merge job). The lints' own headers claim they run "on every CI run" — they do not.

## Critical Issues

### CR-01: finding_id keyspace split — fix-queue-build.mjs does not canonicalize the anchor before hashing

**File:** `scripts/ci/fix-queue-build.mjs:64-68` (vs `scripts/panel/panel-schema.mjs:68-77`, `scripts/ci/panel-verdicts-lint.sh:184-198`)

**Issue:** The whole phase rests on one shared finding_id key space so that panel findings, probe findings, `settled-findings.tsv` waivers, and the poison-set all line up (D-07 / AUTOFIX-01, stated verbatim in `panel-schema.mjs:52-56`). But there are two divergent implementations of the "byte-identical" formula:

- `panel-schema.mjs:findingId` calls `canonicalizeAnchor` first (trim + `[attr='v']` → `[attr="v"]`) — line 69.
- `panel-verdicts-lint.sh` recompute canonicalizes too (lines 184-187).
- `judge.mjs` canonicalizes at parse time (lines 242/290) before `computeFindingId`.
- `fix-queue-build.mjs:findingId` (lines 64-68) does **NOT** canonicalize — it hashes the raw `finding.anchor` straight from the bundle.

For any finding whose anchor uses single quotes or has surrounding whitespace (e.g. `[data-testid='mg-5-populated']`), the panel/verdicts side and the fix-queue side produce **different 64-char IDs for the same finding**. Consequences:

- A finding waived in `settled-findings.tsv` (keyed by the canonicalized ID from the panel path) is **not** subtracted by `fix-queue-build.mjs` (`loadSettled` compares against the non-canonical ID) → a settled finding re-enters the auto-fix queue.
- The auto-fix loop's poison-set (finding_ids from the queue) never matches an ID the panel later emits → "never retry" leaks.
- Panel dedup vs probe dedup diverges.

The committed `fix-queue.json` currently uses only double-quoted anchors, so the divergence is latent today — but it is a correctness landmine that fires the moment any producer emits a single-quoted or whitespace-padded anchor, and nothing in CI would catch it (the recompute in `panel-verdicts-lint.sh` uses the *other*, canonicalizing formula).

**Fix:** Make `fix-queue-build.mjs` import and use the single canonical helper instead of re-deriving it:
```js
// fix-queue-build.mjs — replace the local findingId (lines 60-68) with:
import { findingId } from '../panel/panel-schema.mjs';
```
and delete the local non-canonicalizing copy. Add a self-test asserting `fix-queue-build`'s ID for `[a='b']` equals `panel-schema`'s ID for the same anchor. (`systemicGroup` at lines 74-76 has the same latent bug — it hashes raw `class + NUL + anchor`; canonicalize the anchor there too so systemic collapse groups single- and double-quoted variants together.)

### CR-02: PANEL_SCHEMA schema_version enum ('217-01') contradicts the value judge.mjs writes ('217-05')

**File:** `scripts/panel/panel-schema.mjs:114,125` (enum `['217-01']`) vs `scripts/panel/judge.mjs:59,529` (`SCHEMA_VERSION = '217-05'`)

**Issue:** `PANEL_SCHEMA` is passed to the SDK as `output_config.format.schema` (judge.mjs:478-480) to *constrain* the model's JSON. Each cell's finding branch allows `schema_version` only from the enum `['217-01']` (panel-schema.mjs:114) and the keep branch likewise (line 125). But everything downstream stamps `'217-05'`:
- `judge.mjs:59` `SCHEMA_VERSION = '217-05'`, written onto every admitted finding (line 529).
- `admin-panel-verdicts.json` top-level `"schema_version": "217-05"`.
- `judge.test.mjs:100` fake cache entry uses `'217-05'`.

With structured output enforced, if the model emits `schema_version: "217-05"` in any cell (a natural thing to do given the surrounding artifacts all say 217-05), that response violates the enum and is rejected/repaired — in the worst case `JSON.parse` sees a degraded body, the catch at judge.mjs:493 sets `responseObj = null`, and the sample contributes zero finding_ids. That silently erodes the k=3 quorum (a real finding present in all 3 samples could be dropped if 2 samples get schema-rejected). At minimum the enum and the emitted constant are internally inconsistent for a value that is supposed to be a stable provenance marker.

**Fix:** Pick one version string and use it everywhere. Since the rest of Plan 05's artifacts use `217-05`, update the schema enum:
```js
// panel-schema.mjs, both branches:
schema_version: { type: 'string', enum: ['217-05'] },
```
Alternatively drop `schema_version` from the LLM-facing CELL_SCHEMA entirely (the model has no reason to author it — it is a harness-owned provenance field) so it can never be a source of schema-rejection.

## Warnings

### WR-01: Anti-rot lints (fix-queue-lint, panel-verdicts-lint) are not on the merge-blocking path despite claiming to be

**File:** `.github/workflows/ci.yml` (fast_checks job, ~lines 120-162) ; `scripts/ci/panel-verdicts-lint.sh:11` ; `guides/reference/admin-panel-verdicts.json:3`

**Issue:** `panel-verdicts-lint.sh:11` and the `admin-panel-verdicts.json` notes both state: *"Anti-rot triad: panel-verdicts-lint.sh validates this file on every CI run."* Grepping the workflow, `panel-verdicts-lint.sh` is invoked **nowhere**. `fix-queue-lint.sh` is invoked only inside `admin-eval-harness.sh` (ci.yml:2037), which runs in the `admin_eval_render` job with `continue-on-error: true` (ci.yml:2034) and is explicitly off the merge gate (comment ci.yml:2030). So a hand-edit that tampers `auto_eligible`, injects `open_findings` into the verdicts cache (the T-217-05-EOP invariant), or desyncs finding_ids can merge without any blocking check firing. The lints exist and are correct; they are simply unwired.

**Fix:** Add merge-blocking steps to `fast_checks`:
```yaml
- name: Fix-queue lint
  run: bash scripts/ci/fix-queue-lint.sh
- name: Panel verdicts lint
  run: bash scripts/ci/panel-verdicts-lint.sh
```
and correct the "every CI run" claim in the two headers if they are intentionally kept out of the gate.

### WR-02: Seven Phase-217 self-tests are never executed in CI

**File:** `.github/workflows/ci.yml`

**Issue:** Only `panel-forced-floor-check.test.mjs`, `panel-ci-isolation.test.sh`, `fix-apply.test.mjs`, and `admin-autofix-loop.test.sh` are wired (ci.yml:149,153,157,162). The following self-tests written this phase never run on any lane, so a regression in the module they cover ships green:
- `scripts/ci/lib/anchor.test.mjs`
- `scripts/panel/panel-schema.test.mjs` (note it only tests `panel-schema` internally — it would NOT have caught CR-01 as written, because it never asserts cross-module ID equality with fix-queue-build)
- `scripts/panel/judge.test.mjs`
- `scripts/panel/excerpt.test.mjs`
- `scripts/ci/fix-queue-build.test.mjs`
- `scripts/ci/fix-queue-lint.test.sh`
- `scripts/ci/panel-verdicts-lint.test.sh`

**Fix:** Add each to `fast_checks` (they are hermetic — no DB, no browser, no API key). Example:
```yaml
- run: node scripts/ci/lib/anchor.test.mjs
- run: node scripts/panel/panel-schema.test.mjs
- run: node scripts/panel/excerpt.test.mjs
- run: node scripts/panel/judge.test.mjs
- run: node scripts/ci/fix-queue-build.test.mjs
- run: bash scripts/ci/fix-queue-lint.test.sh
- run: bash scripts/ci/panel-verdicts-lint.test.sh
```

### WR-03: resolveTokenRef mislabels control-scale tokens as radius tokens (documented, but still ships a wrong CSS var)

**File:** `scripts/panel/fix-apply.mjs:217-244`

**Issue:** `resolveTokenRef` distinguishes token families only by array length. Space scale = 10 entries → `--sg-space-N`. Any other 4-entry scale → `--sg-radius-{xs,sm,md,lg}` (lines 235-238). The CR-01 comment inside the file (lines 228-234) admits the control scale is *also* 4 entries and therefore cannot be told apart from radius — yet the 4-entry branch still unconditionally emits `var(--sg-radius-*)`. So an off-scale **control** value that reaches this branch is rewritten to a **radius** token. That is a semantically wrong, silently-committed edit (it passes the +/-1.0px arithmetic and the write happens before any re-render). The rails would only catch it if the wrong token happens to perturb geometry/PNG; a visually-plausible-but-wrong token can pass all four rails.

**Fix:** Do not guess family by length. Carry a `token_family` (or `scale_id`) hint on the fix-queue finding (the harness knows which probe emitted it) and switch on that. Until then, restrict the 4-entry branch to radius *only when the finding is radius-specific*, and return `null` (refuse → judgment) otherwise:
```js
if (idx !== -1 && scalePx.length === 4 && finding?.token_family === 'radius') {
  return `var(--sg-radius-${RADIUS_KEYS[idx]})`;
}
return null;
```

### WR-04: fix-apply queue mode is dead code that always reports "0 applied"

**File:** `scripts/panel/fix-apply.mjs:532-546`

**Issue:** In `--queue` mode the loop over eligible findings never calls `applyFinding` — it only prints a "no target file in queue mode" line (lines 542-544) and `applied` stays `0` (initialized at line 538). The final summary `${applied} applied, ${toApply.length - applied} skipped` (line 546) therefore always claims 0 applied regardless of input. The mode is documented in the usage banner (lines 31, 505) as if functional. This is misleading dead code: an operator running `fix-apply.mjs --queue ...` directly gets a success exit with "0 applied" and no error, masking that the mode does nothing.

**Fix:** Either implement the surface→file mapping in queue mode (or exit non-zero pointing at `admin-autofix-loop.sh`), or remove the `--queue` branch and the banner entry so the only supported entrypoints are single-finding mode and the loop script.

### WR-05: --dry-run uses `git checkout -- <file>` which cannot restore a newly-created file and silently swallows failures

**File:** `scripts/ci/admin-autofix-loop.sh:363-367`

**Issue:** In dry-run, after `fix-apply.mjs` mutates the target in the working tree, the script restores via `git -C "$ROOT" checkout -- "$TARGET_FILE" 2>/dev/null || true` (line 366). Two problems: (a) `checkout -- path` only restores a *tracked* file to its index/HEAD state; if the target were untracked it would not be cleaned, leaving the dry-run non-idempotent; (b) `2>/dev/null || true` swallows any restore failure, so a dry run that fails to revert the edit leaves a dirty tree with no warning — the operator's next real run then commits an unintended change. Target files here are tracked, so (a) is latent, but the silent-swallow in (b) is a real robustness hole for an operator tool whose entire value proposition is "never leave a dirty tree."

**Fix:** Fail loudly if restore does not clean the tree:
```bash
git -C "$ROOT" checkout -- "$TARGET_FILE"
if ! git -C "$ROOT" diff --quiet -- "$TARGET_FILE"; then
  echo "admin-autofix-loop: FATAL: dry-run could not restore ${TARGET_FILE}" >&2
  exit 1
fi
```

### WR-06: admin-autofix-loop `git add -A` stages unrelated working-tree changes into the "one fix per commit" commit

**File:** `scripts/ci/admin-autofix-loop.sh:371-379`

**Issue:** Safety ruleset item (1) is "One fix per commit." The implementation stages with `git add -A` (line 371), which sweeps **every** modified/untracked file in the tree — including the re-render side effects written by `admin-eval-harness.sh` and any incidental operator edits — into the fix commit. A subsequent `git revert` (line 407) then reverts all of them together, so a rail trip can silently roll back re-render ledger updates or unrelated changes that happened to be dirty, and the poison/waive bookkeeping is attributed to a single finding. The atomicity guarantee is weaker than the header claims.

**Fix:** Stage only the file the fix touched (and, if a ledger delta must be part of the same commit, the specific ledger files) rather than the whole tree:
```bash
git -C "$ROOT" add -- "$TARGET_FILE"
```
Keep the re-render after the commit (it already runs after, lines 384-393) and commit any ledger delta separately or via a deliberate amend — do not fold arbitrary `-A` state into the fix commit.

### WR-07: Rail 3 (deterministic gate) is fully skipped whenever --skip-render is set, but the loop still prints "all 4 rails green"

**File:** `scripts/ci/admin-autofix-loop.sh:264-283,396-398`

**Issue:** The header advertises "FOUR RAILS (any one trips → git revert)". But rail 3 (fix-queue-lint + evidence-anchor-check) is guarded by `if [[ "$SKIP_RENDER" -eq 0 ]]` (line 266). `--skip-render` is documented as a flag (line 65) and is used by the self-test. With `--skip-render`, a fix that breaks an anchor or corrupts the fix-queue passes the loop because rail 3 never runs — yet rails 1, 2, 4 still run and the loop reports "all 4 rails green" (line 397) even though only 3 executed. The success message overstates coverage.

**Fix:** Rail 3's `fix-queue-lint.sh` and `evidence-anchor-check.mjs` read committed state and do not require a live render — decouple them from `SKIP_RENDER` and run them unconditionally. Only gate the *re-render* on `SKIP_RENDER`. If a sub-check genuinely needs fresh bundles, report "3 of 4 rails ran (render skipped)" instead of "all 4 rails green."

## Info

### IN-01: judge.mjs CLI path passes empty excerptDom/factsJson to a real (paid) API call

**File:** `scripts/panel/judge.mjs:612-628`

**Issue:** The CLI entrypoint calls `runJudge` with `excerptDom: ''` and `factsJson: '{}'` and a `// TODO: read from bundle dir` comment (line 617). When invoked via `admin-panel.sh` with a real key this makes k=3 paid API calls per cache-miss cell with no DOM and no facts — `anchorResolvesInDom` drops everything against the empty DOM and every cell degrades to keep. This burns tokens for zero signal. Not a defect in the pure functions, but the operator-facing path is not actually functional yet.

**Fix:** Read `dom.html` / `facts.json` from the bundle output dir before the call, or hard-refuse to call the API when `excerptDom` is empty.

### IN-02: excerpt.mjs class-attr comment contradicts the code

**File:** `scripts/panel/excerpt.mjs:27,137-147`

**Issue:** The comment at line 137 says "Keep only semantic (sg-*) + layout tokens" and the header (line 27) implies "class tokens that begin with sg-*", but the code keeps **all** class tokens (lines 140-142: `tokens.sort().join(' ')` with no filter). The keep-all behavior is defensible for anchor resolution, but the comments describe a filter that does not exist and will mislead the next editor.

**Fix:** Update the comment to state that all class tokens are retained (sorted) for anchor fidelity, and remove the "keep only sg-*" language from the header.

### IN-03: stripVsn regex ordering can leave a stray `?`/`&` in constructed edge cases

**File:** `scripts/panel/excerpt.mjs:84-92`

**Issue:** The cleanup chain (`/\?$/`, `/&&/g`, `/\?&/`, `/&$/`) is single-pass and order-dependent. For multi-`vsn` or interleaved query strings it can leave a dangling separator. Output stays deterministic (pure), so this is cosmetic for the excerpt, but the canonical form is not guaranteed minimal.

**Fix:** Parse with `URL`/`URLSearchParams` (delete `vsn`, re-serialize), or add a final `.replace(/[?&]$/,'')`.

### IN-04: admin-autofix-loop interpolates values straight into inline `node -e` programs and shell args

**File:** `scripts/ci/admin-autofix-loop.sh:110-119,124-130`

**Issue:** `finding_id` (line 114) and elsewhere `anchor` are interpolated into inline `node -e "..."` strings and into `settled-findings-lint.sh --add` args. finding_ids are 64-hex and safe, but `anchor` originates from LLM/probe output. This is an operator-only, off-CI tool (not a remote attack surface), so severity is low, but interpolating semi-trusted strings into `node -e`/shell would break on an anchor containing a quote or backtick and is a latent injection shape if the queue source ever becomes less trusted.

**Fix:** Pass values via `process.argv` / env rather than string interpolation:
```bash
node -e 'const [p,id]=process.argv.slice(1); /* ... */' "$STATE_FILE" "$finding_id"
```

### IN-05: admin-autofix-loop.test.sh treats "REFUSED/SKIP" as a passing outcome, so the end-to-end revert path may never be exercised

**File:** `scripts/ci/admin-autofix-loop.test.sh:264-280`

**Issue:** The fixture seeds `measured_px=[13]` against `scale_px=[8,12,16,24]` (delta to 12 = exactly 1.0px, the band edge that `findNearestToken` *admits* per `fix-apply.test.mjs:75-79`). The test accepts *either* a real revert commit *or* a `REFUSED/SKIP` from fix-apply as "pass" (lines 268-280), with a comment claiming "13px is >1.0px from 12" (line 276) — which is wrong arithmetic (13−12 = 1.0). Because the branch tolerates refusal, the loop's actual apply→commit→rail-trip→revert chain (the SC-4 proof) can silently go unexercised while the test still reports PASS. The direct rail-1 check (Test A-ii) is real, but the integrated loop proof is soft.

**Fix:** Use an unambiguously in-band fixture value (e.g. a style literal `12.5px` with `measured_px=[12.5]`) so the fix always applies, then assert a Revert commit exists rather than accepting refusal as equivalent.

---

_Reviewed: 2026-07-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
