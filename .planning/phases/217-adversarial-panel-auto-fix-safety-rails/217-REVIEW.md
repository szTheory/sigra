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
  warning: 6
  info: 5
  total: 13
status: issues_found
---

# Phase 217: Code Review Report

**Reviewed:** 2026-07-04
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

Phase 217 adds an adversarial LLM panel (`judge.mjs` + `lenses.mjs` + `panel-schema.mjs`), a deterministic fix-queue builder/linter, and a rail-guarded auto-fix loop, all wired so the LLM path stays off the CI merge gate (JUDGE-CI-01). The security architecture is sound: anchors are pre-validated against the real DOM before hashing, the API key is never echoed, panel findings go to a parallel file (`panel-findings.json`, never `findings.json`), and the auto-fix path uses `git revert` (never reset/force-push). The model is correctly pinned to `claude-opus-4-8` with no `temperature`/`thinking`/prefill (all correct for that model per the Anthropic SDK).

However, the deterministic auto-fix code (`fix-apply.mjs`) has **two correctness bugs that can commit wrong or syntactically-invalid CSS into source files** via the auto-fix loop, and `judge.mjs` does **not** actually apply the structured-output schema its own docstring claims it uses — so the LLM is unconstrained and malformed responses silently degrade to empty samples. These are the load-bearing defects. The remaining findings are quality/robustness issues.

The auto-fix loop is not wired into CI (verified via `panel-ci-isolation.test.sh` and by inspecting `ci.yml`), so the Critical CSS-corruption bugs are gated behind an operator running `admin-autofix-loop.sh` manually — but rails 1–4 would **not** catch a syntactically-broken inline style (`fix-queue-lint`/anchor-check validate the queue/anchors, and the snapshot canary guards committed PNGs, not `.heex`/`.ex` byte validity), so a bad swap can pass all four rails and land in a commit.

## Critical Issues

### CR-01: `resolveTokenRef` emits invalid CSS and mislabels non-radius scales — auto-fix corrupts source files

**File:** `scripts/panel/fix-apply.mjs:209-236`
**Issue:** `resolveTokenRef(tokenPx, scalePx)` maps a resolved pixel value to a `--sg-*` custom-property name using only the scale array **length** as a discriminator. Two concrete failures, both confirmed by execution:

1. **Any 4-entry scale is assumed to be radius.** The control scale is also 4 entries (`xs/sm/md/lg`) but the code has no way to distinguish it from the radius scale, so a control-token finding is rewritten with a radius token:
   ```
   min-height: 32px   →   min-height: var(--sg-radius-sm)
   ```
   A radius variable applied to a size property is semantically wrong. The auto-fix loop commits this.

2. **The "ambiguous" fallback produces syntactically-invalid CSS.** When the scale length is neither `SPACE_STEPS.length` (10) nor 4, the fallback returns:
   ```js
   return `var(--sg-token-${tokenPx}px/* nearest token at ${tokenPx}px */)`;
   ```
   which renders as `var(--sg-token-12px/* nearest token at 12px */)` — a comment inside `var()` is not a valid custom-property name and breaks the entire declaration. Confirmed:
   ```
   gap: 12px   →   gap: var(--sg-token-12px/* nearest token at 12px */)
   ```
   No rail catches this: `fix-queue-lint`/`evidence-anchor-check` validate the queue/anchors, not the resulting inline style; the snapshot canary only guards committed PNGs.

**Fix:** Do not infer the token family from array length. Carry the token *name* (or family + step) explicitly in the fix-queue entry from the emitting probe, and refuse (downgrade to judgment) when the name cannot be resolved deterministically. Never emit a comment inside `var()`:
```js
function resolveTokenRef(tokenPx, scalePx, tokenName /* from finding */) {
  if (tokenName) return `var(${tokenName})`;
  return null; // caller must treat null as "not applied"
}
```
and have `applyTokenSwap` treat a `null` ref as `applied: false` rather than writing a fabricated/invalid `var(...)`.

### CR-02: `judge.mjs` never sends `output_config.format` — the LLM is unconstrained despite docstring/comments claiming otherwise

**File:** `scripts/panel/judge.mjs:33, 457-476` (false claims at `:4-7` and `:451`)
**Issue:** The module header states it calls `messages.create` with "`output_config.format` (structured JSON schema via `PANEL_SCHEMA`)", and the inline comment at line 451 repeats "`output_config.format`: JSON schema via `PANEL_SCHEMA`". But:
- `judge.mjs` imports only `{ findingId as computeFindingId }` from `panel-schema.mjs` (line 33) — it never imports `PANEL_SCHEMA`.
- The actual `messages.create({...})` call (lines 457-476) passes `model`, `max_tokens`, `system`, `messages` and **no `output_config` at all**.

Consequences: (1) the model output is not schema-constrained, so it can return prose or a differently-shaped object; (2) the parse path (`JSON.parse(textBlock.text)`, lines 480-488) catches the failure and silently sets `responseObj = null`, which yields an **empty sample** — a malformed response is counted as "no findings," quietly weakening quorum admission rather than erroring. `PANEL_SCHEMA` (built and tested in `panel-schema.mjs`/`panel-schema.test.mjs`) is dead code with respect to the live API call. Per the Anthropic SDK, structured output is opt-in via `output_config: { format: { type: 'json_schema', schema } }` — the model is not constrained unless it is passed.

**Fix:** Import and pass the schema:
```js
import { findingId as computeFindingId, PANEL_SCHEMA } from './panel-schema.mjs';
// ...
const response = await sdkClient.messages.create({
  model: MODEL,
  max_tokens: 8192,
  system: [{ type: 'text', text: system, cache_control: { type: 'ephemeral' } }],
  messages: [{ role: 'user', content: userContentBlocks }],
  output_config: { format: { type: 'json_schema', schema: PANEL_SCHEMA } },
});
```
If leaving the schema off is intentional, delete the false docstring/comment claims.

## Warnings

### WR-01: `applyCopyRule` ignores the `applies_to` scoping declared in `copy-rules.json`

**File:** `scripts/panel/fix-apply.mjs:294-376`
**Issue:** Every rule in `copy-rules.json` declares an `applies_to` element list (e.g. `title_case` → `["h1".."h4",".sg-section-heading",".sg-page-title"]`; `sentence_case` → `["button","a","[role=\"button\"]"]`). `applyCopyRule` never reads `applies_to` — it applies each rule to **every** text node matching the rule's text pattern, regardless of tag. Confirmed: `title_case` rewrites `<button>save changes</button>` → `<button>Save Changes</button>` even though buttons are scoped to `sentence_case`, not `title_case`. Copy is silently mis-transformed (heading-only title-casing leaks onto buttons/labels/cells).

**Fix:** Pass the enclosing element/tag to `applyCopyRule` (resolve via cheerio while walking the DOM instead of the flat `>([^<]+)<` regex) and gate each rule on `rule.applies_to`.

### WR-02: Copy-swap text-node regex can match inside `<script>`/`<style>`/`<pre>`/`<code>`

**File:** `scripts/panel/fix-apply.mjs:301` (`const textNodePattern = />([^<]+)</g;`)
**Issue:** Copy transforms run over raw `.heex`/`.ex` source via a flat `>text<` regex with no element-type exclusion. The `_judgment_boundary` note in `copy-rules.json` says "never modify code/pre/kbd content," but nothing enforces it. The `em-dash`/`ellipsis` `replace` rules match anywhere and would rewrite `...` or ` — ` inside a `<code>`/`<pre>` sample or a HEEx `~H` interpolation.

**Fix:** Parse with cheerio and skip `script`, `style`, `pre`, `code`, `kbd`, and nodes inside HEEx interpolation before applying copy rules — consistent with the stated judgment boundary.

### WR-03: `fix-queue-lint.sh` line 48 is dead/broken code (`readFileSync` const is always `undefined`)

**File:** `scripts/ci/fix-queue-lint.sh:48`
**Issue:**
```js
const { readFileSync } = require("node:crypto") ? require : { readFileSync: require("node:fs").readFileSync };
```
`require("node:crypto")` is always truthy, so the ternary evaluates to `require` (the function), and destructuring `readFileSync` off it yields `undefined` (confirmed). It's harmless only because the const is never used — line 49 re-imports `fs` and all reads use `fs.readFileSync`. This reads like a defensive fallback but is neither.

**Fix:** Delete line 48; the following `const fs = require("node:fs")` is the real import.

### WR-04: `admin-panel.sh` cost estimate diverges from `judge.mjs` cache logic (undercounts API calls)

**File:** `scripts/ci/admin-panel.sh:163-170`
**Issue:** The pre-run cache-hit probe only checks `prov.model === 'claude-opus-4-8' && prov.k === 3 && prov.quorum === 2`, but `judge.mjs::checkProvenanceMatch` (judge.mjs:78-87) also requires `rubric_version` **and** `prompt_sha` to match. So `admin-panel.sh` reports a cell as a cache **hit** (0 calls) when `judge.mjs` treats it as a **miss** (3 calls) after any rubric/prompt drift. The operator sees a low estimate, proceeds, and burns more API budget than shown — defeating the estimate's purpose (letting the operator abort before spend).

**Fix:** Reuse `judge.mjs`'s `checkProvenanceMatch` with the current `rubric_version`/`prompt_sha` instead of a hardcoded partial-key comparison.

### WR-05: `admin-autofix-loop.sh` does not handle `git revert` conflicts under `set -e`

**File:** `scripts/ci/admin-autofix-loop.sh:402`
**Issue:** On a tripped rail the loop runs `git revert --no-edit HEAD` with no failure handling under `set -euo pipefail`. A conflicting revert (e.g. after the re-render step's `git add -A` interactions leave the tree/index in an awkward state) exits non-zero, `set -e` aborts the whole loop mid-way, and the repo is left with a partially-applied revert and a dirty index — the opposite of the "auto-revert cleanly, poison, continue" guarantee in the SAFETY RULESET.

**Fix:** Wrap the revert in `set +e`/check-exit; on non-zero run `git revert --abort` and hard-fail with a clear operator message rather than aborting with a dirty tree. Assert a clean working tree before the revert.

### WR-06: `admin-eval-harness.sh` runs monotonic/award guards with `--base HEAD` (compares HEAD to itself)

**File:** `scripts/ci/admin-eval-harness.sh:95, 98`
**Issue:** `quality-findings-monotonic.sh --base HEAD` and `award-guard.mjs --base HEAD` diff the working tree against `HEAD`. The comment on line 30 says the guard checks "vs merge-base," but `--base HEAD` cannot detect a regression relative to the merge-base — so the harness's b4/b5 steps provide false assurance. (The merge-gate copies in `fast_checks` correctly use `steps.base.outputs.ref`, so the actual gate still holds.)

**Fix:** Pass the merge-base ref as `fast_checks` does, or re-comment the harness invocation to state it only checks working-tree-vs-committed consistency, not monotonicity.

## Info

### IN-01: Dead `TMP_LEDGER` mktemp+write+rm in `check_rails`

**File:** `scripts/ci/admin-autofix-loop.sh:220-222, 257`
**Issue:** `check_rails` creates `TMP_LEDGER` via `mktemp` and writes the pre-loop ledger to it, then never reads it — the rail-2 comparison inlines `${PRE_LOOP_LEDGER_JSON}` into the node script instead. `rm -f` cleans it up (no leak) but the whole block is dead code. **Fix:** delete the `TMP_LEDGER` lines.

### IN-02: `reconcileFindings` severity relies on two independent defaults lining up

**File:** `scripts/panel/judge.mjs:130-158, 505-523`
**Issue:** Keep-cell samples are pushed with `findingId: null` (parseSampleFindings:217-225), so an admitted (non-null) id always has non-keep winning samples and the `severity: 'keep'` empty-winners branch (line 133) is unreachable for admitted ids; the push site then defaults `severity || 'tighten'` (line 517). It works, but a future refactor of the filter could emit a nonsensical `keep` severity on an admitted finding. **Fix:** assert admitted findings never carry `keep`, or make the default explicit at the reconcile site.

### IN-03: CLI path of `judge.mjs` passes empty `excerptDom`/`factsJson` (TODO in shipped code) — anchor pre-validation inert on the operator path

**File:** `scripts/panel/judge.mjs:609` (`excerptDom: '', // TODO: read from bundle dir`)
**Issue:** When invoked as a CLI by `admin-panel.sh`, `judge.mjs` passes `excerptDom: ''` and `factsJson: '{}'`, so the real per-cell DOM/facts are never loaded — anchor pre-validation is skipped (`$` stays null) and the prompt gets `(no DOM excerpt provided)`. The T-217-05-INJECT anchor-validation guarantee is inert on the actual operator path; it only works when `runJudge` is called with a real `excerptDom` (as the tests do). **Fix:** wire the CLI to read `dom.html`/`facts.json` from `OUTPUT_DIR` and run `excerptHtml()` before calling `runJudge`.

### IN-04: `serializeEl` JSDoc parameter order does not match implementation

**File:** `scripts/panel/excerpt.mjs:172-180`
**Issue:** The JSDoc documents `serializeEl($el, $)` but the function is `serializeEl($, el)` and all call sites pass `($, child)`. Cosmetic — behavior is correct — but misleading. **Fix:** update the JSDoc to `@param {Function} $` then `@param {Object} el`.

### IN-05: `stripVsn` query-cleanup replaces only the first occurrence

**File:** `scripts/panel/excerpt.mjs:84-92`
**Issue:** `.replace(/\?&/, '?')` (no `g` flag) fixes only the first orphaned `?&`; a multi-param href could canonicalize inconsistently. Low risk for excerpt determinism. **Fix:** add the `g` flag or assemble the query string via `URL`.

---

_Reviewed: 2026-07-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
