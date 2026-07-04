---
phase: 217-adversarial-panel-auto-fix-safety-rails
fixed_at: 2026-07-04T21:14:44Z
review_path: .planning/phases/217-adversarial-panel-auto-fix-safety-rails/217-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 5
skipped: 3
status: partial
---

# Phase 217: Code Review Fix Report

**Fixed at:** 2026-07-04T21:14:44Z
**Source review:** .planning/phases/217-adversarial-panel-auto-fix-safety-rails/217-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope (critical_warning): 8 (CR-01, CR-02, WR-01..WR-06)
- Fixed: 5 (CR-01, CR-02, WR-03, WR-05, WR-06)
- Skipped: 3 (WR-01, WR-02, WR-04)
- Out of scope (Info, not attempted): 5 (IN-01..IN-05)

## Fixed Issues

### CR-01: `resolveTokenRef` emits invalid CSS and mislabels non-radius scales

**Files modified:** `scripts/panel/fix-apply.mjs`
**Commit:** 56ca7585
**Applied fix:** `resolveTokenRef` no longer fabricates a `var(--sg-token-<px>/* comment */)` fallback — a comment inside `var()` is invalid CSS that silently corrupts the declaration. It now returns `null` when the token family/name cannot be resolved deterministically, and `applyTokenSwap` treats a `null` ref as "not applied" (downgrade to judgment, `continue`) rather than writing invalid/mislabeled CSS. The space-scale (10-entry) and radius (4-entry) branches that existing fixtures exercise are preserved, so the tightened band and !important-preservation tests still pass (39/39). **Requires human verification:** the second half of CR-01 (a 4-entry *control* scale being mislabeled as radius because array length can't distinguish them) is only fully closable by carrying the token *name* on the fix-queue entry from the emitting probe — a cross-component change to `fix-queue-build.mjs`/the probe/schema that is out of scope here. This commit closes the guaranteed-invalid-CSS half and makes the ambiguous half fail safe (refuse rather than write a fabricated var()); confirm the control-vs-radius provenance carry in a follow-up before relying on auto-apply for control tokens.

### CR-02: `judge.mjs` never sends `output_config.format` — LLM unconstrained

**Files modified:** `scripts/panel/judge.mjs`
**Commit:** 278fc154
**Applied fix:** Imported `PANEL_SCHEMA` alongside `computeFindingId` and added `output_config: { format: { type: 'json_schema', schema: PANEL_SCHEMA } }` to the `messages.create` call, per the Anthropic SDK structured-output contract (verified against the claude-api skill: `output_config.format` is the canonical structured-output parameter; the old `output_format` is deprecated). This constrains the model to the panel schema so a malformed response no longer parses to `null` → empty sample → silently weakened quorum admission. Syntax check (`node --check`) passes and the `PANEL_SCHEMA` import resolves to a valid object schema. **Requires human verification:** the judge test suite could not run to completion in this worktree because `test/example/priv/playwright/node_modules` (cheerio, a pre-existing module-load dependency of judge.mjs) is not installed — this failure predates the fix and is unrelated to it (the committed judge.mjs already imports cheerio at line 40). Confirm structured output behaves as intended against a live `claude-opus-4-8` run and that responses conform to `PANEL_SCHEMA`.

### WR-03: `fix-queue-lint.sh` line 48 dead/broken `readFileSync` const

**Files modified:** `scripts/ci/fix-queue-lint.sh`
**Commit:** f240426e
**Applied fix:** Deleted the dead line `const { readFileSync } = require("node:crypto") ? require : {...}`. `require("node:crypto")` is always truthy, so the ternary yielded `require` (the function) and destructuring `readFileSync` off it produced `undefined`; the const was never referenced (all reads use `fs.readFileSync`). The following `const fs = require("node:fs")` is the real import. Bash syntax check passes and the lint self-test (`fix-queue-lint.test.sh`) is 4/4 green, confirming the embedded node script still parses and runs.

### WR-05: `admin-autofix-loop.sh` does not handle `git revert` conflicts under `set -e`

**Files modified:** `scripts/ci/admin-autofix-loop.sh`
**Commit:** 1a4bf941
**Applied fix:** Wrapped the auto-revert (`git revert --no-edit HEAD`) in the file's existing `set +e`/capture-exit/`set -e` idiom. On a non-zero exit (conflicting revert) it now runs `git revert --abort` and `exit 1` with a clear operator message, so the loop never leaves a partially-applied revert + dirty index — restoring the SAFETY RULESET's clean auto-revert guarantee. Bash syntax check passes and `admin-autofix-loop.test.sh` is 9/9 green (the suite exercises the revert/poison/waive path).

### WR-06: `admin-eval-harness.sh` runs monotonic/award guards with `--base HEAD`

**Files modified:** `scripts/ci/admin-eval-harness.sh`
**Commit:** 1447890a
**Applied fix:** Applied the review's option (b) — corrected the misleading labeling rather than introducing a fragile local merge-base computation. `--base HEAD` compares the working tree against committed HEAD (a consistency check), not monotonicity vs the PR merge-base; the header comment falsely claimed "vs merge-base." Updated the header comment and the b4/b5 step echoes to state honestly that they check working-tree-vs-committed consistency, and noted that the authoritative merge-base regression gate is the `fast_checks` copy in `ci.yml` (which passes `steps.base.outputs.ref`). This orchestrator is the local/full-run driver, not the merge gate, so computing a real merge-base in an arbitrary local checkout would be fragile and was deliberately not added. Behavior unchanged; bash syntax check passes.

## Skipped Issues

### WR-01: `applyCopyRule` ignores the `applies_to` scoping declared in `copy-rules.json`

**File:** `scripts/panel/fix-apply.mjs:294-376`
**Reason:** skipped — requires a design decision (cheerio DOM rewrite) that exceeds the review's guidance and carries template-corruption risk. The review's fix ("pass the enclosing element and gate each rule on `rule.applies_to`, resolving via cheerio while walking the DOM") requires replacing the copy-swap path's deliberately regex-based approach with cheerio DOM parsing. `fix-apply.mjs` operates on raw `.heex`/`.ex` source containing HEEx template syntax (`~H`, `{...}` interpolations, `<%= %>`) that cheerio (an HTML parser, used elsewhere only on already-canonicalized excerpt DOM in `excerpt.mjs`) does not reliably parse — a cheerio rewrite could itself mangle templates, i.e. cause the exact class of source corruption the fix is meant to prevent. This is a high-risk architectural change I cannot verify correct without a broader design pass, so it is deferred rather than guessed at.
**Original issue:** `applyCopyRule` never reads `applies_to`, applying each rule to every text node matching its pattern regardless of tag (e.g. `title_case` rewrites `<button>save changes</button>` even though buttons are scoped to `sentence_case`), silently mis-transforming copy.

### WR-02: Copy-swap text-node regex can match inside `<script>`/`<style>`/`<pre>`/`<code>`

**File:** `scripts/panel/fix-apply.mjs:301`
**Reason:** skipped — same cheerio-rewrite design dependency and template-corruption risk as WR-01. The review's fix ("parse with cheerio and skip `script`/`style`/`pre`/`code`/`kbd` and HEEx interpolation") is the same architectural change to the regex-based copy-swap path, applied to the same raw HEEx/`.ex` source that cheerio cannot reliably parse. A narrower regex-only guard was considered, but reliably identifying "inside `<pre>`/`<code>`/HEEx `~H` interpolation" with flat regex over raw templates is itself error-prone and could skip or corrupt legitimate matches; a correct fix needs the same DOM-walking design as WR-01. Deferred to be resolved together with WR-01.
**Original issue:** The flat `>([^<]+)<` regex has no element-type exclusion, so `em-dash`/`ellipsis` `replace` rules could rewrite `...` or ` — ` inside a `<code>`/`<pre>` sample or a HEEx `~H` interpolation, violating the stated `_judgment_boundary` ("never modify code/pre/kbd content").

### WR-04: `admin-panel.sh` cost estimate diverges from `judge.mjs` cache logic

**File:** `scripts/ci/admin-panel.sh:163-170`
**Reason:** skipped — a faithful fix requires infrastructure that is out of scope and partly inert. The review's fix ("reuse `judge.mjs`'s `checkProvenanceMatch` with the current `rubric_version`/`prompt_sha`") requires `admin-panel.sh` to compute the current `prompt_sha`, which is `sha256(system)` where `system` is assembled per-cell by `assemblePrompt()` from `surface`/`cell`/`excerptDom`/`factsJson`/image — reproducing the entire prompt-assembly pipeline in the bash cost-probe. That per-cell DOM/facts is itself not wired on the CLI path (see IN-03: `excerptDom: ''`, a TODO in shipped code), so `prompt_sha` is presently `''` even inside `judge.mjs`'s CLI provenance. Adding only the `rubric_version` half (a hardcoded `'1.0'` constant) would still diverge from `checkProvenanceMatch` on `prompt_sha` and give false confidence that the gap is closed. A correct fix is coupled to wiring the CLI DOM (IN-03) and reproducing prompt assembly — a design-level change beyond the review's guidance and not verifiable without a live pipeline. Deferred.
**Original issue:** The pre-run cache-hit probe checks only `model`/`k`/`quorum`, but `judge.mjs::checkProvenanceMatch` also requires `rubric_version` and `prompt_sha`, so `admin-panel.sh` reports a cache hit (0 calls) where `judge.mjs` treats it as a miss (3 calls) after any rubric/prompt drift, undercounting estimated API calls.

## Out-of-Scope Findings (fix_scope = critical_warning)

The following Info findings were not attempted (Info tier excluded by scope). They remain open in 217-REVIEW.md:

- IN-01: Dead `TMP_LEDGER` mktemp+write+rm in `check_rails` (`admin-autofix-loop.sh:220-222,257`)
- IN-02: `reconcileFindings` severity relies on two independent defaults lining up (`judge.mjs:130-158,505-523`)
- IN-03: CLI path of `judge.mjs` passes empty `excerptDom`/`factsJson` — anchor pre-validation inert on the operator path (`judge.mjs:609`). Note: this is the root of WR-04's skip reason.
- IN-04: `serializeEl` JSDoc parameter order does not match implementation (`excerpt.mjs:172-180`)
- IN-05: `stripVsn` query-cleanup replaces only the first occurrence (`excerpt.mjs:84-92`)

---

_Fixed: 2026-07-04T21:14:44Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
