# Phase 217: Adversarial Panel + Auto-Fix Safety Rails - Research

**Researched:** 2026-07-04
**Domain:** Off-CI LLM-panel quality harness (Anthropic `@anthropic-ai/sdk`) + deterministic auto-fix loop layered on the Phase-216 evidence substrate (Node `.mjs` guards + bash orchestrators + Playwright TS + committed forward-only ledgers). Elixir/Phoenix auth library; harness is repo-internal dev tooling under `scripts/` + `test/example/`, **never** shipped in `priv/templates/sigra.install/`.
**Confidence:** HIGH — CONTEXT.md D-01..D-18 verified against the live codebase and the bundled claude-api skill; every load-bearing idiom confirmed at its cited path with real excerpts. Two corrections and several landmines surfaced below.

## Summary

Phase 217 is **already deeply designed** — CONTEXT.md carries locked decisions D-01..D-18 from a 4-cluster research + claude-api verification session. This research VERIFIED the load-bearing technical claims against the live repo and the model contract, and its job is to (1) confirm the reusable idioms are accurate at their paths, (2) surface gaps/landmines for the planner, and (3) supply the required Validation Architecture mapping each of the 5 Success Criteria to a concrete off-CI-safe mechanism.

**Verification verdict: the CONTEXT.md is accurate.** Every named idiom exists as described: the `createRequire`-from-Playwright cheerio pattern in `evidence-anchor-check.mjs`, the `finding_id = sha256(surface \0 class \0 anchor)` NUL-delimited hash in `enrichFindingsForBundle`, the `min(axes)` band recompute in `award-guard.mjs`, the mktemp-hermetic self-test in `quality-findings-monotonic.test.sh`, the `onScale`/nearest-scale arithmetic in `probes.ts`, the 3 lockstep `sigra_admin.css` copies, and the retired `panel-schema-check.sh` shape. The `admin-eval-schema.md` "UNRESOLVED SEAM" section explicitly documents D-07's exact reconciliation path (`class = lens + ":" + question`). The claude-api skill confirms the D-08 model-contract correction: `claude-opus-4-8` **400s on `temperature`/`top_p`/`top_k`**, uses `output_config.format` structured outputs with the documented schema-constraint limits, takes base64 image blocks, forbids assistant prefill, and defaults to adaptive thinking.

**Primary recommendation:** Implement D-01..D-18 as written. Do NOT re-derive the decisions. Focus planning energy on the four landmines this research surfaces (§Common Pitfalls): the non-exported `isStructuralAnchor`, the `probe_class`-vs-`class` byte-identity seam for panel `finding_id`, the `open_findings` sole-writer refactor ordering, and the loop-never-touches-CI wiring proof. Every SC is provable by a committed-ledger diff or a hermetic `.test.sh` EXCEPT SC-2's "zero LLM calls" and the SC-4 live companion, which need one off-CI run under 216-09 SC-5 discipline (a call-counter test proves the wiring; the live run proves reality).

<user_constraints>
## User Constraints (from CONTEXT.md)

> CONTEXT.md is EXCEPTIONALLY detailed (D-01..D-18 + canonical refs + code context + external prior art). It is the primary spec. This section copies the binding constraints verbatim; the full decision text lives in `217-CONTEXT.md` and MUST be read before planning.

### Locked Decisions (D-01..D-18 — verbatim substance)

**A. Panel runtime, home & operator DX (PANEL-01)**
- **D-01:** Panel code home = `scripts/panel/` (plain `.mjs`, a SIBLING of — not inside — `scripts/ci/`). Files: `judge.mjs`, `lenses.mjs`, `panel-schema.mjs` (output schema + shared `finding_id` helper), `excerpt.mjs`. Reuse the Playwright subproject `node_modules` via `createRequire(path.join(PW,'package.json'))` — the SAME pattern `evidence-anchor-check.mjs` uses for cheerio. Add `@anthropic-ai/sdk` as a `devDependency` to `test/example/priv/playwright/package.json`. No new `package.json`, no TS build step. The `scripts/panel/` (advisory) vs `scripts/ci/` (deterministic gates) split encodes JUDGE-CI-01 in the filesystem.
- **D-02:** Operator invocation = a thin `scripts/ci/admin-panel.sh` cloned structurally from `admin-eval-harness.sh`. (a) resolves bundles by `app_git_sha = git rev-parse HEAD`, (b) **hard-degrades to `exit 0` (skip-with-warning) when `ANTHROPIC_API_KEY` is unset** (Hammer no-op idiom → structurally guarantees JUDGE-CI-01), (c) bundle-freshness precondition (warn/skip, not hard-fail, if stale vs HEAD), (d) defaults to pilot surfaces + requires `--all` to fan out (print estimated call count first), (e) **never writes any git-tracked ledger the deterministic guards read.** Rejected: a `mix` task and an `npm run` script.
- **D-03:** LLM call = `@anthropic-ai/sdk` `messages.create`, model pinned `claude-opus-4-8`, structured output via `output_config.format` JSON-schema (bands/verdicts as `enum`, `additionalProperties:false`, NO `minimum`/`maximum`/`minLength`/`maxLength`/`multipleOf`, no recursion), rubric in a `cache_control`-ed `system` prompt, response validated with `ajv`/Zod. Adaptive thinking default; **no assistant prefill** (400s on 4.8). Image fed as a base64 `image` content block. `ANTHROPIC_API_KEY` env-only.

**B. Panel input/output contract & forced-floor (PANEL-01)**
- **D-04:** One Anthropic call per (surface × cell), carrying all 4 lenses. Inputs: (1) a deterministic anchor-preserving DOM excerpt from `excerpt.mjs` (reuse 216 D-06 canonicalization BUT retain structural anchors: `data-testid`, `data-sg-*`, `role`, `aria-label`, semantic classes), (2) full `facts.json`, (3) committed `screenshot.png` base64. Image → graphic-design lens; DOM/facts → 3 persona lenses. `excerpt.mjs` is pure + `.test`-covered.
- **D-05:** Panel emits a PARALLEL `panel-findings.json` per cell, beside `findings.json` in the gitignored bundle dir — **NEVER** merged into `findings.json` (panel findings must not enter the deterministic `open_findings`). Shape = probe finding + `lens`, `question`, `verdict` (`keep|tighten|kill`), `none_searched_for`, `schema_version`. `admin-panel-report.md` rendered FROM the JSON, gitignored.
- **D-06:** Forced-finding floor enforced TWICE: (1) structurally in the `output_config.format` schema (each lens×question cell is EITHER a `verdict != keep` finding with structural `anchor` + `refutation`, OR a `keep` with non-empty `none_searched_for` = literal `NONE — searched for: <what>`); (2) at rest via a new `scripts/ci/panel-forced-floor-check.mjs` cloned in shape from retired `panel-schema-check.sh` — asserts the 12-cell grid (4 lenses × 3 questions), rejects empty/vague NONE, validates every non-`keep` anchor via shared `isStructuralAnchor` (reuse `evidence-anchor-check.mjs`).

**C. finding_id reconciliation, k=3 consensus & content-hash cache (PANEL-01/02)**
- **D-07:** `finding_id = sha256(surface + "\0" + class + "\0" + anchor)` — **byte-identical to 216** — with `class = "<lens>:<question>"` (e.g. `platform_admin:ia_muddy`, `graphic_design:salience`). Closes the schema-doc UNRESOLVED SEAM via path #1.
- **D-08 (CORRECTED — model contract):** k=3 = three independent LLM samples per cell, **NO `temperature`** (`temperature`/`top_p`/`top_k` **400 on `claude-opus-4-8`**). Sample diversity = model's inherent non-greedy sampling + adaptive thinking across independent requests — free, undialable. **Admit a finding iff its `finding_id` appears in ≥2 of 3 samples** (quorum on the KEY). Reconcile `severity` by worst-verdict (`kill > tighten > keep`); reconcile `description` by first winning sample. Pre-validate every anchor against the DOM before hashing. Canonicalize anchor quote-style/whitespace before hashing. Filter `NONE` out of finding_id space. Pilot task: measure inter-sample finding_id-set variance; if too agreeable, raise k or vary prompt/effort per sample — NEVER reach for temperature.
- **D-09:** Content-hash skip cache = committed `guides/reference/admin-panel-verdicts.json`, keyed on `render_sha256`. Per key: `admitted_findings[]`, `per_lens_disposition`, `surface_disposition`, `sample_key_sets`, `provenance {model, k, quorum, rubric_version, prompt_sha}`. READS `render_sha256` from `admin-render-sha.json`; **NEVER stores `open_findings`**. Committed (small derived forward-only signal). Cache-miss on `provenance` mismatch even when render_sha256 unchanged, and on cross-surface collision. Anti-rot triad (`panel-verdicts-lint.sh` + non-blocking `--prune`). Prove "unchanged → zero LLM calls" with a hermetic call-counter `.test` asserting `callCount === 0`.
- **D-10:** Diff-scoped critique for changed surfaces (PANEL-02): carry forward each prior admitted finding whose anchor still resolves + probe still fires (same finding_id, no new LLM call); mark resolved those whose anchor is gone/probe clean, writing a `resolved` row to `settled-findings.tsv` via the 216 D-22 regen helper; invoke the LLM ONLY for the "new regressions" scope with an exclusion list. Diff = set-difference on finding_ids BEFORE any LLM call. Add a staleness horizon so a pure-LLM taste finding carried across N renders is re-verified.
- **D-11:** `--changed-only` is default. Batch the 3 questions per lens into ONE structured call (~9N calls first run, not 27N). Re-runs on unchanged tree cost ~0. Persist per-cell incrementally (crashed run resumes; a completed cell is a cache hit); fail **non-zero with a partial-completion report** on API error mid-run — never a false-green partial.

**D. Fix queue, auto-fix safety rails & injected-regression test (AUTOFIX-01/02)**
- **D-12:** Fix queue = committed, derived, sorted `guides/reference/fix-queue.json`, built by new `scripts/ci/fix-queue-build.mjs` from `findings.json` bundles; the OPEN-set sibling of `settled-findings.tsv` (`open = built − settled`). Per-finding: `finding_id`, `surface`, `class`, `anchor`, `lens`, `severity`, `fix_class` (`copy|token|component|judgment`), `auto_eligible` (DERIVED == `fix_class ∈ {copy,token}`), `systemic_group = sha256(class + "\0" + anchor)`, `priority` (DERIVED). Systemic collapse: any anchor recurring across ≥2 surfaces → high-priority parent floated to top. **`fix-queue-build.mjs` also becomes the sole writer of `open_findings` in `admin-render-sha.json`** (one builder, two outputs). Guard: `fix-queue-lint.sh`. Class-chain-anchored findings are policy `judgment`.
- **D-13:** Safe-fix taxonomy — auto-apply = **COPY-SWAP + TOKEN-SWAP ONLY**; LLM strictly OUT of the apply path. `token` (auto): off-scale numeric CSS → nearest on-scale `--sg-*` token, computed deterministically from `facts.json` `scale_px` + the finding's `measured_px` (reuse the probe's own `onScale`/nearest logic, 216 D-12 — read the live scale). Apply only when nearest token within a tightened ±1.0px band; ties or >1.0px → downgrade to `judgment`. Preserve `!important`. `copy` (auto): text-node-only edit from a fixed `copy-rules.json` normalization ruleset. `component`/`judgment` → human queue, never auto. **CSS-token auto-apply SCOPED OUT of 217:** `sigra_admin.css` exists in 3 lockstep copies (tripping `golden_diff_test` + drift guard); 217 auto-applies only to admin LiveView `.heex` attributes/inline-`style=` and the example only. CSS-token fixes route to human.
- **D-14:** Auto-apply loop = bash `scripts/ci/admin-autofix-loop.sh` (Node at leaves: `fix-queue-build.mjs`, `fix-apply.mjs`). Per `auto_eligible` finding, highest-priority-first: `fix-apply.mjs` → `git add -A && git commit` (atomic, one fix per commit) → re-run `admin-eval-harness.sh`. **Auto-revert via `git revert --no-edit HEAD` (NEW commit — never `reset`/force-push, per the ruleset) if ANY of three rails trips:** (1) `quality-findings-monotonic.sh` count increase vs pre-loop sha, (2) per-surface award-band floor breach (reuse `award-guard.mjs` `min(axes)` vs a pre-loop `admin-award-ledger.json` snapshot), (3) any deterministic gate flips / cited anchor stops resolving. A reverted finding → `settled-findings.tsv` (`disposition=waived, waived_by=autofix-217`) + a persisted poison-set (`eval/autofix-state.json`, gitignored) so it is never retried. `--max-fixes N` bounds a run; loop resumable + idempotent. OFF the merge path; only committed ledger diffs gate.
- **D-15:** Injected-regression test (SC-4) = hermetic `scripts/ci/admin-autofix-loop.test.sh` cloned from `quality-findings-monotonic.test.sh` (mktemp throwaway git repo, real guard binaries, browser-free). Seed a count-delta and assert BOTH rails fire: (a) a `git revert` commit exists (`git log` shows `Revert "autofix...`, reflog clean = no force-push), ledger restored, finding in `settled-findings.tsv`; (b) `quality-findings-monotonic.sh` exits non-zero on the pre-revert commit — causally linked via a harness test-double. PLUS a live fixture-board companion (`board-autofix-seed` in `design_gallery_live.ex`) run through the real harness OFF-CI once (216-09 SC-5 discipline). The `.test.sh` slots into the existing `*.test.sh` self-test list; the loop itself never enters `fast_checks`.

**E. The new graphic-design lens (PANEL-01)**
- **D-16:** New sibling `guides/reference/admin-graphic-design-lens.md` (NOT appended to the persona rubric; mirrors 216 D-19 sibling-file discipline; must itself obey the column-4 integer prohibition). `class = "graphic_design:<key>"`, same forced-floor + `keep|tighten|kill` + `NONE — searched for:`. Three refutation questions: **Q1 `salience`** (does the eye land on the wrong thing first?), **Q2 `emphasis_ember`** (is emphasis — esp. ember — earning its meaning?), **Q3 `composition`** (does grouping/type-hierarchy/balance read coherently in BOTH themes?). Widens worst-verdict roll-up 3→4 lenses; **A3 award = all 4 lenses `clean`** (extends 216 D-17). Explicitly NOT: misalignment, radius/shadow/control-height, focus-ring, card-in-card, motion, responsive reflow — those stay deterministic.
- **D-17:** Lens inputs: the ONLY lens that REQUIRES `screenshot.png` (Q3 needs light AND dark PNGs); DOM fed for ANCHORING only; `facts.json` read-only ground truth (never recompute/contradict). Two-field finding shape: `observation` (perceptual prose) + `anchor` (structural selector from `data-testid`/`sg-*` BEM, validated by `evidence-anchor-check.mjs`) + `evidence_cell` (which PNG). Rejected: bounding-box coordinate anchors.
- **D-18:** Brand coherence: lens sensitive to 7 named Sigra pillars, each mapped to a question + brand-book v2 / `admin-ui-principles` citation (ember `#c2410c` light / `#fdba74` dark, Space Grotesk, Core Rails). Every finding references a named pillar.

### Claude's Discretion
- Exact leaf-script/field names (`fix-apply.mjs` internals, `copy-rules.json` shape, `admin-panel.sh` vs `admin-panel-harness.sh`, the on-disk `panel-findings.json` filename), and whether the report lives in the bundle dir vs a gitignored path under `guides/reference/`.
- Whether `fix-queue.json` and `admin-panel-verdicts.json` are two files or a consolidated committed JSON — as long as each guard reads ONE authoritative source and `open_findings` lives ONLY in `admin-render-sha.json`.
- The precise `--max-fixes` default and the staleness-horizon N for carried-forward taste findings.

### Deferred Ideas (OUT OF SCOPE)
- **CSS-token auto-apply** (fold installer/golden regen into the loop) → a later phase (D-13).
- **component-swap auto-apply** → not in scope; routes to the human queue.
- **Broad elevation across all 8 surfaces + L1/L2 fractal + UI-01/UI-02** → Phase 218.
- **Baseline recapture / canary reconciliation** → Phase 219.
- **A3 award for surfaces** → only earned once all 4 lenses (incl. graphic-design) read `clean`; the panel proposes, the deterministic ledger disposes.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PANEL-01 | 4-lens LLM panel (3 persona verbatim + 1 graphic-design) evaluates deterministically-clean surfaces from rendered evidence, under a forced-finding floor (cited DOM anchor OR literal `NONE — searched for: <what>`), emitting findings that round-trip the rubric schema. | Persona rubric structure + forced-floor + `keep\|tighten\|kill` verified in `admin-persona-jtbd-rubric.md`; retired `panel-schema-check.sh` supplies the forced-floor lint shape (D-06); `@anthropic-ai/sdk` structured-output shape verified against claude-api skill (D-03); graphic-design lens sibling grounded in verified brand-v2 ember colors (D-16/D-18). |
| PANEL-02 | k=3 ≥2/3 quorum; content-hash skip on unchanged surfaces; diff-scoped critique on changed; never in merge-blocking path. | `render_sha256` content-hash key present in `admin-render-sha.json` (D-09); `finding_id` set-difference substrate verified in `enrichFindingsForBundle` (D-10); k=3-without-temperature contract verified (D-08); off-CI split verified in ci.yml (harness in non-required `continue-on-error` job, guards in `fast_checks`). |
| AUTOFIX-01 | Findings dedup into a single prioritized fix queue keyed by stable `finding_id` (hash of surface+lens+question+anchor); cross-surface recurring anchors collapse into high-priority systemic findings. | `finding_id = sha256(surface \0 class \0 anchor)` verified byte-exact in `enrichFindingsForBundle` + `admin-eval-schema.md`; D-07 `class = lens:question` reconciliation is the schema-doc's own recommended path #1; `settled-findings.tsv` open-set sibling verified (7-col TSV). |
| AUTOFIX-02 | Auto-apply provably-safe classes (copy/token/component-swap) as atomic commits, re-render after each, auto-revert any fix that regresses a deterministic gate or already-elevated surface; judgment → human. Injected-regression test proves rails catch a deliberately-clunky change. | `award-guard.mjs` `min(axes)` floor + `quality-findings-monotonic.sh` count guard verified as the two committed-ledger rails (D-14); probe `onScale`/nearest logic verified in `probes.ts` for token-swap arithmetic (D-13); `quality-findings-monotonic.test.sh` mktemp-hermetic idiom verified as the SC-4 clone target (D-15); `settled-findings-lint.sh` 7-col waiver sink verified. |
</phase_requirements>

## Architectural Responsibility Map

> All work is repo-internal dev tooling (`scripts/` + `test/example/`), NOT shipped to host apps. "Tier" here means execution locus within the harness, not a web tier.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| LLM judging (4 lenses, k=3, forced floor) | `scripts/panel/*.mjs` (advisory, off-CI) | Playwright `node_modules` (SDK + ajv/Zod via `createRequire`) | Browser-free; the filesystem location (`scripts/panel/` not `scripts/ci/`) structurally encodes JUDGE-CI-01 — a `scripts/ci/*.mjs` glob can never sweep the judge into a lane. |
| Operator invocation + API-key gate | `scripts/ci/admin-panel.sh` (bash orchestrator) | `scripts/panel/judge.mjs` | House idiom (clone `admin-eval-harness.sh`); Hammer no-op degrade (`exit 0` when `ANTHROPIC_API_KEY` unset) makes a missing key structurally pass — the JUDGE-CI-01 guarantee. |
| DOM excerpt canonicalization | `scripts/panel/excerpt.mjs` (pure, `.test`-covered) | 216 `canonicalize.ts` D-06 rules | Anchor-preserving variant of the render_sha256 canonicalization; retains structural anchors so cited anchors round-trip `evidence-anchor-check.mjs`. |
| Forced-floor validation (at rest) | `scripts/ci/panel-forced-floor-check.mjs` (deterministic) | shared `isStructuralAnchor` | Reads JSON, not markdown — moots the column-4 integer hazard; clone shape from retired `panel-schema-check.sh`. |
| Fix queue build + `open_findings` write | `scripts/ci/fix-queue-build.mjs` (deterministic builder) | `settled-findings.tsv`, `findings.json` bundles | ONE builder → two authoritative outputs (`fix-queue.json` + `open_findings` in `admin-render-sha.json`); kills the hand-maintained-count drift. |
| Auto-apply loop | `scripts/ci/admin-autofix-loop.sh` (bash) | `fix-apply.mjs`, `admin-eval-harness.sh` re-run | House idiom (bash orchestrator, Node at leaves); `git revert` (new commit) per the ruleset; OFF the merge path. |
| Token-swap arithmetic | `fix-apply.mjs` reusing probe `onScale`/nearest logic | `facts.json` `scale_px` + finding `measured_px` | Read the LIVE `--sg-*` scale, never a forked constant table (216 D-12). |
| Deterministic rails (merge gates) | `fast_checks` job (committed-ledger guards) | — | Only `quality-findings-monotonic.sh`, probe findings, and committed ledger diffs gate. The panel + loop NEVER attach. |

## Standard Stack

### Core (already present, verified on disk)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| cheerio | (installed in Playwright subproject) | Browser-free DOM anchor resolution | Already resolved via `createRequire(path.join(PW,'package.json'))` in `evidence-anchor-check.mjs`; reuse verbatim `[VERIFIED: scripts/ci/evidence-anchor-check.mjs L42-46]` |
| parse5 | (installed in Playwright subproject) | `render_sha256` canonicalization | Feeds `canonicalize.ts` → `renderSha256()`; `excerpt.mjs` reuses its D-06 rules `[CITED: 216 canonicalize.ts]` |
| Playwright | (Playwright subproject) | Bundle capture (screenshot + DOM + axe + facts) | Existing 216 substrate; `admin-eval.spec.ts` produces `finding_id` `[VERIFIED: admin-eval.spec.ts]` |
| Node (built-in `node:crypto`, `node:module`, `node:child_process`, `node:fs`) | repo Node | Guard runtime | All 216 `.mjs` guards use built-ins only; no runtime deps `[VERIFIED: award-guard.mjs, evidence-anchor-check.mjs]` |

### Supporting (NEW devDeps — the only additions this phase)
| Library | Version | Purpose | When to Use | Provenance |
|---------|---------|---------|-------------|------------|
| `@anthropic-ai/sdk` | latest (verify — see below) | `messages.create` with `output_config.format` structured outputs, base64 image blocks, `cache_control` system prompt | The judge (`scripts/panel/judge.mjs`) only | `[ASSUMED]` — package name from CONTEXT.md; MUST run legitimacy gate before install |
| `ajv` OR Zod | latest (verify) | Validate the LLM structured-output response against the schema | Response validation in `judge.mjs`/`panel-schema.mjs` | `[ASSUMED]` — planner's call (D-03 says `ajv`/Zod); MUST run legitimacy gate |

**Installation (after legitimacy gate):**
```bash
# Both are devDependencies of the EXISTING Playwright package.json — no new lockfile (D-01).
cd test/example/priv/playwright && npm install --save-dev @anthropic-ai/sdk ajv   # or zod
```

**Version verification (REQUIRED before writing the Standard Stack version cells):**
```bash
npm view @anthropic-ai/sdk version    # confirm current; TS SDK is @anthropic-ai/sdk (per claude-api skill)
npm view ajv version                  # or: npm view zod version
npm view @anthropic-ai/sdk scripts.postinstall 2>/dev/null   # postinstall risk check
```
The claude-api skill confirms **`@anthropic-ai/sdk`** is the official TypeScript/Node SDK (`npm install @anthropic-ai/sdk`) `[CITED: bundled claude-api skill → typescript/claude-api/README.md]`. Zod integration ships as `@anthropic-ai/sdk/helpers/zod` (`zodOutputFormat`) — a strong argument for Zod over ajv if the planner wants the SDK-native parse path (`client.messages.parse()` with `output_config.format`). Note the SDK's TS `output_config.format` helpers auto-strip unsupported schema constraints client-side, matching D-03's constraint list.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@anthropic-ai/sdk` (Node, in Playwright subproject) | Python `anthropic` SDK + a mix task | Rejected D-02 — no Ecto/Sandbox payoff, drags the browser-free judge into the wrong runtime |
| ajv | Zod (`@anthropic-ai/sdk/helpers/zod`, `client.messages.parse()`) | Zod is SDK-native for structured outputs and auto-handles the unsupported-constraint stripping; ajv is a lighter standalone JSON-schema validator. Planner's call (D-03). |
| One giant batched panel call | Per-(surface×cell) call carrying all 4 lenses (D-04) | Per-cell is the granularity; batching all cells loses per-cell caching + diff-scoping |

## Package Legitimacy Audit

> **Required before install.** Run `gsd-tools query package-legitimacy check --ecosystem npm @anthropic-ai/sdk ajv zod`, then `npm view` per package, then the postinstall check. The two candidate packages have not been verified against an authoritative source in THIS session — they are `[ASSUMED]` and the planner MUST gate each install behind a `checkpoint:human-verify` task (or a legitimacy-gate task mirroring 216-01's `parse5/cheerio` legitimacy checkpoint).

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `@anthropic-ai/sdk` | npm | (verify) | (verify) | github.com/anthropics/anthropic-sdk-typescript (per claude-api skill) | (run gate) | Approved-pending-gate — official SDK per claude-api skill, but confirm exact name+version via `npm view` |
| `ajv` | npm | (verify) | (verify) | github.com/ajv-validator/ajv | (run gate) | Candidate — only if planner picks ajv over Zod |
| `zod` | npm | (verify) | (verify) | github.com/colinhacks/zod | (run gate) | Candidate — SDK-native path (`@anthropic-ai/sdk/helpers/zod`) |

**Packages removed due to [SLOP] verdict:** none (gate not yet run — planner runs it).
**Packages flagged as suspicious [SUS]:** none yet — planner inserts `checkpoint:human-verify` before each install per 216-01 precedent.

*Precedent: 216-01-PLAN.md gated the `parse5`/`cheerio` install behind a legitimacy checkpoint. Mirror that exactly for `@anthropic-ai/sdk` + the validator.*

## Architecture Patterns

### System Architecture Diagram

```
                         OPERATOR (off-CI, has ANTHROPIC_API_KEY)
                                        │
                                        ▼
                         scripts/ci/admin-panel.sh  ── ANTHROPIC_API_KEY unset? ──► exit 0 (skip+warn)
                                        │                                            [JUDGE-CI-01 no-op]
                 resolve bundles by app_git_sha = git rev-parse HEAD
                 (warn/skip if bundles stale vs HEAD; default pilots; --all fans out)
                                        │
                                        ▼
                            scripts/panel/judge.mjs
              ┌─────────────────────────┼──────────────────────────┐
              │ per (surface × cell):   │                          │
              │  1. render_sha256 lookup in admin-panel-verdicts.json (committed)     │
              │     └─ hit + provenance match ──► CARRY FORWARD, callCount += 0  ◄── D-09 skip
              │     └─ miss OR provenance drift ──► need LLM                          │
              │  2. build inputs:                                                     │
              │       excerpt.mjs(dom.html) [anchor-preserving canonicalization]      │
              │       + facts.json (read-only) + screenshot.png (base64)             │
              │  3. k=3 independent messages.create calls (NO temperature):          │
              │       model=claude-opus-4-8, output_config.format schema,            │
              │       cache_control system rubric, base64 image block, no prefill    │
              │  4. per-cell: 4 lenses × 3 questions = 12-cell forced-floor grid     │
              │  5. admit finding iff finding_id ∈ ≥2/3 samples (quorum on KEY)      │
              │       finding_id = sha256(surface \0 "lens:question" \0 anchor)      │
              │       severity = worst-verdict; description = first winning sample    │
              └─────────────────────────┬──────────────────────────┘
                                        │
              writes (gitignored, beside findings.json):  panel-findings.json  +  admin-panel-report.md
              writes (committed forward-only):            admin-panel-verdicts.json
                     (NEVER writes findings.json; NEVER writes open_findings)
                                        │
   ┌────────────────────────────────────┴─── DETERMINISTIC DERIVATIVES (the only things that gate) ───┐
   │                                                                                                   │
   ▼                                                                                                   ▼
scripts/ci/fix-queue-build.mjs  ──► guides/reference/fix-queue.json (committed, sorted)         panel-forced-floor-check.mjs
  open = built(findings.json) − settled(settled-findings.tsv)                                    (12-cell grid, NONE tokens,
  SOLE WRITER of open_findings in admin-render-sha.json                                           anchors via isStructuralAnchor)
  systemic collapse: anchor across ≥2 surfaces → high-priority parent
                                        │
                                        ▼
                    scripts/ci/admin-autofix-loop.sh  (OFF merge path; operator/nightly)
                    per auto_eligible finding, highest-priority-first:
                      fix-apply.mjs (heex attr / inline style; token via onScale nearest; copy via copy-rules.json)
                      → git add -A && git commit  (atomic, one fix/commit)
                      → re-run admin-eval-harness.sh
                      → RAILS: (1) quality-findings-monotonic.sh count↑ vs pre-loop sha
                               (2) award-guard.mjs min(axes) floor breach vs pre-loop ledger snapshot
                               (3) any gate flips / cited anchor stops resolving
                      → ANY rail trips ──► git revert --no-edit HEAD (NEW commit; never reset/force-push)
                                          + settled-findings.tsv (waived, autofix-217) + poison-set (gitignored)
```

### Recommended Project Structure (new files this phase)
```
scripts/panel/                       # NEW — advisory, off-CI (JUDGE-CI-01 filesystem split)
├── judge.mjs                        # entrypoint: locate bundles, call Anthropic, write outputs
├── lenses.mjs                       # 4 lens definitions + prompt assembly
├── panel-schema.mjs                 # output JSON schema + shared finding_id helper
├── excerpt.mjs                      # deterministic anchor-preserving DOM canonicalization (+ .test)
scripts/ci/                          # deterministic — gates + orchestrators
├── admin-panel.sh                   # operator invocation (clone admin-eval-harness.sh; API-key no-op)
├── panel-forced-floor-check.mjs     # forced-floor lint at rest (clone panel-schema-check.sh shape)
├── panel-verdicts-lint.sh           # anti-rot triad for admin-panel-verdicts.json (+ --prune)
├── fix-queue-build.mjs              # fix-queue.json builder + SOLE writer of open_findings
├── fix-queue-lint.sh                # recompute auto_eligible/priority, fail on drift
├── fix-apply.mjs                    # token/copy fix application (heex + example only)
├── admin-autofix-loop.sh            # auto-apply loop (bash; git revert rails)
├── admin-autofix-loop.test.sh       # SC-4 hermetic injected-regression test (clone monotonic.test.sh)
guides/reference/
├── admin-graphic-design-lens.md     # NEW sibling lens (D-16; brand-v2 grounded)
├── admin-panel-verdicts.json        # NEW committed content-hash skip cache (D-09)
├── fix-queue.json                   # NEW committed derived open-set queue (D-12)
test/example/lib/example_web/live/admin/design_gallery_live.ex
└── board-autofix-seed               # NEW live fixture board for the SC-4 live companion (D-15)
test/example/priv/playwright/package.json   # + @anthropic-ai/sdk, ajv/zod devDeps (D-01)
```

### Pattern 1: createRequire-from-Playwright dependency resolution (D-01)
**What:** Resolve Node deps installed in the Playwright subproject from a `.mjs` guard living at repo `scripts/`.
**When to use:** Any panel `.mjs` file needing `@anthropic-ai/sdk`, `cheerio`, `ajv`/`zod`.
**Example (VERIFIED verbatim):**
```javascript
// Source: scripts/ci/evidence-anchor-check.mjs L42-46 [VERIFIED]
const __filename = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), '..', '..');
const PW = path.join(ROOT, 'test', 'example', 'priv', 'playwright');
const _require = createRequire(path.join(PW, 'package.json'));
const { load: cheerioLoad } = _require('cheerio');
// panel: const Anthropic = _require('@anthropic-ai/sdk');
```

### Pattern 2: finding_id byte-identity (D-07) — THE 216 SEAM
**What:** Panel `finding_id` MUST be byte-identical to the 216 probe hash so panel findings, `settled-findings.tsv` waivers, and the fix queue share ONE key space.
**Example (VERIFIED — 216 emitter):**
```javascript
// Source: test/example/priv/playwright/tests/admin-eval.spec.ts L85-102 [VERIFIED]
const finding_id = createHash('sha256')
  .update(surface).update('\0')
  .update(probeClass).update('\0')   // <-- 216 uses f.probe_class here
  .update(anchor).digest('hex');
return { ...f, class: probeClass, surface, finding_id };
```
**217 panel MUST feed `class = "<lens>:<question>"` into the SAME hash layout.** The schema-doc's own recommended path #1 is `class = lens + ":" + question` `[VERIFIED: admin-eval-schema.md L47-53]`. See Pitfall 2 — the hash reads `f.probe_class`, so the panel enrichment path must set the `probe_class`-slot value to the `lens:question` string (or the shared `panel-schema.mjs` `finding_id` helper hashes the `lens:question` string directly). Whichever, the three `\0`-delimited components must be exactly `surface`, `lens:question`, `anchor`.

### Pattern 3: min(axes) award floor as an auto-revert rail (D-14 rail 2)
**What:** An already-elevated surface must not silently drop; a bare count guard misses this (Betterer-style baseline).
**Example (VERIFIED):**
```javascript
// Source: scripts/ci/award-guard.mjs L70-78, L135-137 [VERIFIED]
const BAND_ORD = { A0: 0, A1: 1, A2: 2, A3: 3 };
const AXES = ['token_fidelity', 'rhythm', 'a11y_polish', 'states'];
function minBand(axes) { let min = 3; for (const a of AXES) { const v = BAND_ORD[axes[a]]; if (v < min) min = v; } return Object.keys(BAND_ORD)[min]; }
// rail 2: compare min(axes) per surface vs a pre-loop admin-award-ledger.json snapshot; any decrease → revert
```

### Pattern 4: token-swap arithmetic reuses the live probe scale (D-13)
**What:** Off-scale numeric CSS → nearest on-scale `--sg-*` token, read from the LIVE scale in `facts.json`, never a forked constant table.
**Example (VERIFIED — the onScale/nearest logic to reuse):**
```typescript
// Source: test/example/priv/playwright/lib/eval/probes.ts L59-61, L89-97 [VERIFIED]
function onScale(valuePx, scalePx) { const EPSILON = 0.5; return scalePx.some((t) => Math.abs(valuePx - t) <= EPSILON); }
// facts.json carries measured_px[] + scale_px[] per off-token finding; fix-apply picks the nearest scale_px
// token within the tightened ±1.0px band; tie or >1.0px → downgrade to judgment (D-13).
```

### Pattern 5: hermetic mktemp self-test (D-15 SC-4 clone target)
**What:** A `.test.sh` that copies the REAL guard binary into a mktemp throwaway git repo, mutates a committed ledger, asserts exit code + stderr string, and cleans up on trap EXIT — leaving the real repo untouched.
**Example (VERIFIED — the exact idiom to clone):**
```bash
# Source: scripts/ci/quality-findings-monotonic.test.sh L51-66, L112-130 [VERIFIED]
TMPDIR_ROOT="$(mktemp -d)"; trap 'rm -rf "$TMPDIR_ROOT"' EXIT
REPO="$TMPDIR_ROOT/test-repo"; git -C "$REPO" init -q
cp "$REAL_GUARD" "$REPO/scripts/ci/quality-findings-monotonic.sh"
# mutate ledger, commit baseline, then: assert exit != 0 AND grep -q "open findings increased" stderr
```

### Anti-Patterns to Avoid
- **Merging panel findings into `findings.json`:** would inflate the deterministic `open_findings` that `quality-findings-monotonic.sh` gates on. Panel findings go in a PARALLEL `panel-findings.json` (D-05).
- **`git reset`/force-push for auto-revert:** the ruleset blocks force-push/reset/admin-merge; use `git revert --no-edit HEAD` (a NEW commit) (D-14).
- **`temperature` for k=3 diversity:** 400s on `claude-opus-4-8` (D-08). Diversity is free and undialable across independent requests.
- **Auto-applying CSS-token fixes:** trips the 3-lockstep `sigra_admin.css` copies + `golden_diff_test` + drift guard; SCOPED OUT (D-13).
- **Putting the panel or loop in `scripts/ci/` as a wired CI step:** the whole JUDGE-CI-01 invariant. Panel lives in `scripts/panel/`; the loop is operator/nightly only.
- **Duplicating `open_findings`:** it lives ONLY in `admin-render-sha.json`, written ONLY by `fix-queue-build.mjs` (D-12 / one-authoritative-source).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser-free anchor resolution | A regex DOM matcher | `evidence-anchor-check.mjs` cheerio `$()` + `isStructuralAnchor` | Already handles selector-syntax validation + prose rejection + injection safety `[VERIFIED]` |
| finding_id hashing | A new hash formula | The 216 `sha256(surface \0 class \0 anchor)` layout | Byte-identity is the seam; a new formula breaks `settled-findings-lint.sh` + the fix queue key space |
| Token nearest-scale math | A hardcoded `--sg-*` value table | The probe `onScale`/nearest logic reading `facts.json` `scale_px` | The live scale can change; a forked table silently rots (216 D-12) |
| Award-band floor comparison | A new band comparator | `award-guard.mjs` `minBand` + `BAND_ORD` | Already recomputes `min(axes)`, never trusts the typed band |
| Hermetic guard self-test scaffold | A bespoke test harness | The `quality-findings-monotonic.test.sh` mktemp+trap idiom | Proven browser-free, real-binary, real-repo-untouched pattern |
| Structured-output response validation | Manual JSON shape checks | ajv, or Zod via `@anthropic-ai/sdk/helpers/zod` + `client.messages.parse()` | SDK-native path auto-strips unsupported schema constraints; manual checks miss edge cases |
| Content-hash skip / carry-forward | A timestamp or mtime cache | `render_sha256` from `admin-render-sha.json` | The single authoritative content key; mtime is non-deterministic |

**Key insight:** The 216 substrate already solved every deterministic sub-problem this phase touches. 217's net-new code is the LLM call shape + the k=3 quorum + the fix-application arithmetic + the loop orchestration. Everything else is reuse-verbatim or clone-in-shape.

## Runtime State Inventory

> This phase is greenfield-additive tooling, not a rename/refactor. This section is included only because D-12 mutates a shared ledger's write-path.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data (committed ledgers) | `admin-render-sha.json` `open_findings` is currently written by the harness/spec, read by `quality-findings-monotonic.sh` `[VERIFIED]` | D-12 code edit: move the WRITER to `fix-queue-build.mjs` (sole writer). The values already exist and are read correctly — this is a write-path relocation, not a data migration. Sequence it so no window exists where `open_findings` is unwritten. |
| Live service config | None — no external service holds panel/queue state (all committed JSON or gitignored bundles) | None |
| OS-registered state | None — no Task Scheduler/pm2/launchd/systemd registration for the panel or loop | None ("None — verified: harness is invoked by hand / nightly workflow only, no OS registration") |
| Secrets/env vars | `ANTHROPIC_API_KEY` — env-only, never in prompts/messages (D-03); read by `admin-panel.sh` for the no-op degrade (D-02) | New env var; document in the runbook. NOT a SOPS/committed secret. Never logged. |
| Build artifacts | The new `@anthropic-ai/sdk` + validator devDeps land in the EXISTING Playwright `package.json` lockfile | Run `npm install` in `test/example/priv/playwright`; no new lockfile (D-01). Confirm the install doesn't perturb `golden_diff_test` (it's outside `priv/templates/`, so it should not). |

**Nothing found in category:** Live service config, OS-registered state — verified by grep + the harness's hand/nightly invocation model.

## Common Pitfalls

### Pitfall 1: `isStructuralAnchor` is NOT exported from `evidence-anchor-check.mjs`
**What goes wrong:** D-06 and D-10 say to "reuse the shared `isStructuralAnchor`," but the function is a **local (non-exported) declaration** in `evidence-anchor-check.mjs` (L92-117). A naive `import { isStructuralAnchor }` will fail.
**Why it happens:** 216 wrote it as a file-private helper; there was no cross-file consumer until 217.
**How to avoid:** The planner must add a task to EXTRACT `isStructuralAnchor` (and likely the `GEOMETRY_ONLY_CLASSES` set and the `$(anchor).length` resolution check) into a shared module — the natural home is `scripts/ci/lib/` alongside the existing `scripts/ci/lib/eval-probe-ids.mjs` (which `award-guard.mjs` already imports via `import { resolveEvidenceRef } from './lib/eval-probe-ids.mjs'` `[VERIFIED: award-guard.mjs L32]`). Then re-import it in both `evidence-anchor-check.mjs` and the new `panel-forced-floor-check.mjs`. This refactor must keep `evidence-anchor-check.mjs`'s behavior byte-identical (it's in `fast_checks` — regressing it breaks the gate).
**Warning signs:** `SyntaxError: ... does not provide an export named 'isStructuralAnchor'` at panel-forced-floor-check load time.

### Pitfall 2: the `finding_id` hash reads `f.probe_class`, not `f.class`
**What goes wrong:** D-07 wants `class = "<lens>:<question>"`, but the verified 216 emitter hashes `probeClass = f.probe_class` and only sets `class` as an ADDITIVE ALIAS afterward `[VERIFIED: admin-eval.spec.ts L87-98]`. If the panel enrichment sets `class` but leaves `probe_class` empty/different, the SHA diverges from the intended key and the seam breaks silently.
**Why it happens:** The 216 record shape carries BOTH `probe_class` (original) and `class` (alias); the hash uses the former.
**How to avoid:** Author the shared `panel-schema.mjs` `finding_id` helper to hash the three explicit components (`surface`, `lens:question`, `anchor`) directly — do NOT route panel findings through the 216 `enrichFindingsForBundle` (which is probe-specific). Add a `.test` that asserts a known `(surface, "graphic_design:salience", anchor)` triple produces the SAME 64-hex digest whether computed by the panel helper or by the 216 formula. This byte-identity assertion is the D-07 seam guard.
**Warning signs:** `settled-findings-lint.sh` (which recomputes finding_id from `surface\0class\0anchor` — 7 cols, verified) rejects a waiver row the panel wrote, OR a carried-forward finding gets a new finding_id and the diff-scope re-invokes the LLM needlessly.

### Pitfall 3: `open_findings` sole-writer refactor has an ordering hazard
**What goes wrong:** D-12 makes `fix-queue-build.mjs` the sole writer of `open_findings`. Today the harness/spec writes it. If the writer is removed from the harness BEFORE `fix-queue-build.mjs` is wired into `admin-eval-harness.sh`, there's a window where `admin-render-sha.json` has stale/absent counts and `quality-findings-monotonic.sh` (in `fast_checks`) diffs garbage.
**Why it happens:** Two producers of the same field during a migration.
**How to avoid:** Sequence the plan so `fix-queue-build.mjs` is authored AND chained into `admin-eval-harness.sh` (which already runs the derivative guards `[VERIFIED: admin-eval-harness.sh]`) in the SAME wave that removes the old writer. Add a `fix-queue-lint.sh` check that `open_findings` equals `built − settled` so drift is caught. Because `admin-eval-harness.sh` runs in the non-required `continue-on-error` render job (NOT `fast_checks`) `[VERIFIED: ci.yml L2012-2019]`, a mid-migration render-job failure won't block merges — but a stale committed `open_findings` WOULD fail `fast_checks`. Commit the ledger only after `fix-queue-build.mjs` produces it.
**Warning signs:** `quality-findings-monotonic.sh` fails on a PR that changed no admin source (stale open_findings), or `open_findings` missing from a cell.

### Pitfall 4: proving the loop NEVER touches CI (JUDGE-CI-01)
**What goes wrong:** The auto-fix loop re-runs `admin-eval-harness.sh` (D-14) — and `admin-eval-harness.sh` itself DOES run in CI (the non-required render job) `[VERIFIED: ci.yml L2019]`. It's easy to accidentally wire `admin-autofix-loop.sh` or `admin-panel.sh` into a job, or to let a `scripts/ci/*` glob sweep them.
**Why it happens:** The loop and panel live under `scripts/ci/` (bash orchestrators, per house idiom) even though the JUDGE-CI-01 intent is off-merge-path. The `scripts/panel/` split protects the `.mjs` judge, but `admin-panel.sh` and `admin-autofix-loop.sh` sit in `scripts/ci/`.
**How to avoid:** Add an explicit negative-assertion guard/test: grep `.github/workflows/ci.yml` and assert NO job `run:` line invokes `admin-panel.sh` or `admin-autofix-loop.sh`. The `.test.sh` self-tests DO attach to the `fast_checks` self-test list (verified pattern: each guard's `.test.sh` is a named step in `fast_checks` `[VERIFIED: ci.yml L112-140]`), but the loop/panel binaries themselves must NOT. The Hammer no-op (`exit 0` on missing `ANTHROPIC_API_KEY`, D-02) is the belt; this negative-assertion is the suspenders.
**Warning signs:** `admin-panel.sh` or `admin-autofix-loop.sh` appears as a `run:` step in any workflow; a required check consumes panel output.

### Pitfall 5: SC-5's "committed-HEAD" trap for the live companion (from 216-09)
**What goes wrong:** The D-15 live fixture-board companion (`board-autofix-seed`) is proven by a real OFF-CI harness run. Per the 216-09 lesson (Phase 216 memory), a render-then-commit harness green run captured at a PRE-COMMIT sha is INVALID — the stale-render-guard rejects a bundle whose `app_git_sha ≠ HEAD`.
**Why it happens:** The auto-fix loop commits between fixes; a bundle captured before the commit has a stale sha.
**How to avoid:** The live companion must capture on a CLEAN tree at the final committed HEAD. Structure the SC-4 proof as: hermetic `.test.sh` proves the WIRING (rails fire, revert commit exists, ledger restored) at any sha; the live companion proves REALITY with a capture at the final committed HEAD on a clean tree. Do not conflate them.
**Warning signs:** `stale-render-guard.sh` rejects the companion bundle (bundle_sha ≠ HEAD).

### Pitfall 6: `claude-opus-4-8` model-contract 400s (D-08, confirmed against claude-api skill)
**What goes wrong:** Passing `temperature`/`top_p`/`top_k` returns 400; passing an assistant-turn prefill returns 400; passing `thinking: {type:"enabled", budget_tokens:N}` returns 400.
**How to avoid (VERIFIED against claude-api skill):** Use `output_config: { format: { type: "json_schema", schema: {...} } }` (NOT the deprecated `output_format`); adaptive thinking is the default (omit `thinking` or set `{type:"adaptive"}`); feed the screenshot as `{ type: "image", source: { type: "base64", media_type: "image/png", data: <b64> } }`; put the rubric in a `system` block with `cache_control: {type:"ephemeral"}`. The schema must use `additionalProperties:false` on every object and MUST NOT use `minimum`/`maximum`/`minLength`/`maxLength`/`multipleOf` or recursion (the SDK TS helpers strip these client-side, but authoring them invites drift). `[VERIFIED: bundled claude-api skill]`
**Warning signs:** HTTP 400 `invalid_request_error` naming a sampling parameter; empty/garbled structured output because a constraint was silently stripped.

## Code Examples

### The Anthropic call shape (D-03) — VERIFIED against claude-api skill
```javascript
// Source: bundled claude-api skill → typescript/claude-api/README.md (adapted to .mjs + createRequire) [CITED]
const Anthropic = _require('@anthropic-ai/sdk');
const client = new Anthropic(); // reads ANTHROPIC_API_KEY from env — never in prompts (D-03)

// one call per (surface × cell), carrying all 4 lenses; k=3 = call this 3× independently (D-04/D-08)
const response = await client.messages.create({
  model: 'claude-opus-4-8',                    // pinned (D-03)
  max_tokens: 16000,
  // NO temperature / top_p / top_k — 400 on 4.8 (D-08)
  // adaptive thinking is the default — omit `thinking`
  system: [{ type: 'text', text: RUBRIC_TEXT, cache_control: { type: 'ephemeral' } }], // cached rubric (D-03)
  output_config: {
    format: {
      type: 'json_schema',
      schema: PANEL_SCHEMA,   // enum verdicts, additionalProperties:false, NO min/max/minLength/etc. (D-03)
    },
  },
  messages: [{
    role: 'user',
    content: [
      { type: 'image', source: { type: 'base64', media_type: 'image/png', data: screenshotB64 } }, // → graphic-design lens (D-04/D-17)
      { type: 'text', text: excerptDom + '\n\n' + factsJson },  // → 3 persona lenses (D-04)
    ],
  }],
  // NO assistant prefill (400 on 4.8) — structured output replaces it (D-03)
});
// first content block is text with valid JSON (output_config.format guarantee); validate with ajv/Zod
```

### settled-findings.tsv waiver sink (D-10/D-14) — VERIFIED CLI
```bash
# Source: scripts/ci/settled-findings-lint.sh L19-20, L82 [VERIFIED] — 7 tab-separated columns
# finding_id  surface  class  anchor  disposition  waived_by  note
bash scripts/ci/settled-findings-lint.sh --add \
  --surface "$SURFACE" --class "graphic_design:salience" --anchor "$ANCHOR" \
  --disposition waived --waived-by autofix-217 --note "reverted: regressed award floor"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `temperature: 0.7` to "keep the diversity knob" (discuss-phase premise) | k=3 independent requests, NO sampling params — 400 on `claude-opus-4-8` | Opus 4.7/4.8 removed `temperature`/`top_p`/`top_k` | D-08 correction; diversity is free + undialable |
| `output_format` parameter | `output_config: { format: { type: "json_schema", schema } }` | API-wide deprecation | Use the nested form; the flat one is deprecated |
| Assistant-turn prefill to force JSON shape | Structured outputs (`output_config.format`) | 4.6+ family (400 on prefill) | Prefill is a 400 on 4.8 |
| Fixed `budget_tokens` thinking | Adaptive thinking (default) | 4.7/4.8 (400 on `budget_tokens`) | Omit `thinking` or use `{type:"adaptive"}` |
| Markdown persona panel (`panel-schema-check.sh`, retired) validating frozen v1.42 files | JSON `panel-findings.json` + `panel-forced-floor-check.mjs` reading JSON | Phase 214 retired the .sh; 217 replaces with .mjs | Moots the column-4-integer markdown hazard |

**Deprecated/outdated:**
- `panel-schema-check.sh` — RETIRED Phase 214 (validates frozen v1.42 milestone markdown; NOT wired, will NOT be wired) `[VERIFIED: panel-schema-check.sh L1-15]`. Clone its SHAPE (frontmatter/floor validation structure), not its target.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `@anthropic-ai/sdk` is the exact package to install (name + registry existence) | Standard Stack | LOW — confirmed as the official TS SDK by the claude-api skill, but MUST run the legitimacy gate + `npm view` before install (slopsquat vector) |
| A2 | `ajv` OR `zod` is the validator; planner picks | Standard Stack | LOW — both are ubiquitous; Zod is SDK-native (`@anthropic-ai/sdk/helpers/zod`). Gate both. |
| A3 | The exact current `@anthropic-ai/sdk` version | Standard Stack | LOW — pin via `npm view` at install time; SDK is fast-moving |
| A4 | `scripts/ci/lib/` is the right home for the extracted `isStructuralAnchor` | Pitfall 1 | LOW — `scripts/ci/lib/eval-probe-ids.mjs` already exists and is imported by `award-guard.mjs` `[VERIFIED]`; mirror it |

**If this table looks short:** it is — nearly every claim in this research was VERIFIED against the live codebase or the claude-api skill. The only genuine assumptions are the two devDep package names (both must pass the legitimacy gate) and the SDK version (pin at install).

## Open Questions (RESOLVED)

1. **`fix-apply.mjs` heex-attribute edit surface — which `.heex` files, and how narrowly scoped?**
   - **RESOLVED: the baseline-PNG-drift risk is now a hard loop rail — Plan 06 (`217-06`) adds rail 4 (`scripts/ci/snapshot-canary-guard.sh --base <pre-loop-sha>`) that reverts any auto-fix that drifts a committed baseline PNG under the snapshot allowlist, on the same `git revert` footing as the other three rails; it closes the hole where the harness (which the loop re-runs) does NOT invoke `snapshot-canary-guard.sh` (a `fast_checks` step), so a `.heex`/inline-style fix could otherwise pass the loop yet fail `fast_checks` on its PR.**
   - What we know: D-13 confines auto-apply to admin LiveView `.heex` attributes/inline-`style=` + the example only; CSS is out.
   - What's unclear: the exact set of admin LiveView `.heex` files and whether a token swap in a `.heex` inline style can ever perturb a committed baseline PNG (triggering `snapshot-canary-guard`).
   - Recommendation: the planner should enumerate the auto-apply-eligible `.heex` targets and add a rail check that no committed baseline PNG drifts unexpectedly (the loop already re-runs the harness; confirm the snapshot lane is either included or explicitly out-of-loop). — Done: rail 4 in `217-06`.

2. **Consolidated vs two-file for `fix-queue.json` + `admin-panel-verdicts.json`** (Claude's Discretion, D-254/255).
   - **RESOLVED: keep them as two separate files (default recorded in the plans) — different keys (`finding_id` vs `render_sha256`), different lifecycles, different lints; no consolidation.**
   - Recommendation: keep them separate — different keys (`finding_id` vs `render_sha256`), different lifecycles (queue is open-set derived; verdicts is content-hash cache), different lints. Consolidation buys legibility but couples two anti-rot triads.

3. **`--max-fixes` default and staleness-horizon N** (Claude's Discretion, D-256).
   - **RESOLVED: defaults recorded in the plans — `--max-fixes` small (default e.g. 5) for a bounded, reviewable first run; staleness-horizon N = 3 renders before a pure-taste carried-forward finding is re-verified. Both are knobs, not load-bearing.**
   - Recommendation: `--max-fixes` small (e.g. 5–10) for a bounded, reviewable first run; staleness-horizon N = re-verify a pure-taste finding after ~3 renders. Both are knobs, not load-bearing; defer to the planner.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `ANTHROPIC_API_KEY` | The judge (LLM calls) | ✗ (operator-supplied, off-CI) | — | Hammer no-op: `admin-panel.sh` `exit 0` skip-with-warning (D-02) — this IS the JUDGE-CI-01 guarantee |
| `@anthropic-ai/sdk` | `judge.mjs` | ✗ (new devDep) | (pin via `npm view`) | none — install after legitimacy gate |
| ajv / zod | response validation | ✗ (new devDep) | (pin via `npm view`) | none — install after legitimacy gate |
| Node (built-ins) | all guards | ✓ | repo Node | — |
| Playwright + example server (port 4011) | live SC-5 companion capture | ✓ (216 substrate) | existing | — |
| cheerio / parse5 (Playwright subproject) | excerpt + anchor checks | ✓ | installed | — |

**Missing dependencies with no fallback:** the two new devDeps (blocking the judge, but NOT blocking any deterministic gate — the panel is advisory).
**Missing dependencies with fallback:** `ANTHROPIC_API_KEY` — the no-op degrade is a designed fallback, not a failure.

## Validation Architecture

> **REQUIRED (Nyquist Dimension 8).** `workflow.nyquist_validation` is not disabled — this section maps each of the 5 Success Criteria (ROADMAP Phase 217) to a concrete, deterministic, off-CI-safe mechanism. The through-line: **every SC is provable by a committed-ledger diff or a hermetic `.test.sh` EXCEPT the two that need a live off-CI run** (SC-2's "zero LLM calls" and the SC-4 live companion) — those follow 216-09 SC-5 discipline (hermetic test proves wiring; live run proves reality).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash `*.test.sh` self-tests (mktemp-hermetic) + Node `*.test.mjs` self-tests + Playwright TS `.test.ts` — the existing 216 tri-modal harness |
| Config file | none for the self-tests (each `.test.sh`/`.test.mjs` is standalone); Playwright config in `test/example/priv/playwright/` |
| Quick run command | `bash scripts/ci/<guard>.test.sh` / `node scripts/ci/<guard>.test.mjs` (each < a few seconds, browser-free) |
| Full suite command | the `fast_checks` job's self-test steps (verified: each guard's self-test is a named `fast_checks` step `[VERIFIED: ci.yml L112-140]`) |

### Phase Requirements → Test Map (5 Success Criteria)
| SC | Behavior | Test Type | Automated Command | Committed-ledger provable? | File Exists? |
|----|----------|-----------|-------------------|---------------------------|-------------|
| **SC-1** | 4-lens panel emits machine-parseable findings; every lens×question holds a cited anchor OR literal `NONE — searched for: <what>` (forced floor on clean surfaces) | at-rest lint over `panel-findings.json` | `node scripts/ci/panel-forced-floor-check.mjs` (asserts 12-cell grid, rejects empty/vague NONE, validates anchors via shared `isStructuralAnchor`) | YES — the committed `admin-panel-verdicts.json` grid + the forced-floor lint prove the shape without any LLM call | ❌ Wave 0 (`panel-forced-floor-check.mjs` + its `.test`; clone `panel-schema-check.sh` shape) |
| **SC-2** | k=3 ≥2/3 quorum; unchanged surfaces skipped via content-hash → **zero new LLM calls + zero finding churn** on unmodified code | (a) hermetic call-counter test (b) committed-verdicts diff | (a) `node scripts/panel/judge.test.mjs` asserting `callCount === 0` on a render_sha256 cache hit with an injected SDK test-double; (b) `git diff admin-panel-verdicts.json` empty on unchanged tree | PARTIAL — the quorum logic + carry-forward are provable by a committed `admin-panel-verdicts.json` diff (sample_key_sets audit); "zero LLM calls" needs the **call-counter test** (hermetic, no real API) per D-09; a real live run needs `ANTHROPIC_API_KEY` (off-CI, one-time) | ❌ Wave 0 (call-counter `.test`; SDK test-double) |
| **SC-3** | all findings dedup into a single fix queue keyed by `finding_id`; cross-surface recurring anchors collapse into high-priority systemic parents at the top | committed-ledger diff + lint | `node scripts/ci/fix-queue-build.mjs && bash scripts/ci/fix-queue-lint.sh` (recomputes `auto_eligible`/`priority`/`systemic_group`, fails on drift; asserts `open = built − settled`) | YES — `fix-queue.json` is committed + derived; the lint recomputes every derived field and the systemic collapse from `findings.json` + `settled-findings.tsv` deterministically | ❌ Wave 0 (`fix-queue-build.mjs` + `fix-queue-lint.sh` + `.test`) |
| **SC-4** | injected deliberately-clunky change (off-token spacing/ember misuse/misalignment) → auto-revert FIRES + `quality-findings-monotonic.sh` exits non-zero (rails actually catch it) | hermetic mktemp injected-regression test + live companion | (a) `bash scripts/ci/admin-autofix-loop.test.sh` (clone `quality-findings-monotonic.test.sh`: mktemp repo, seed count-delta, assert `git log` shows `Revert "autofix...`, reflog clean, ledger restored, finding in `settled-findings.tsv`, AND `quality-findings-monotonic.sh` exits non-zero on the pre-revert commit); (b) `board-autofix-seed` live board run through the real harness OFF-CI once | PARTIAL — the hermetic `.test.sh` proves the WIRING deterministically (committed-ledger + git-log assertions); the live companion proves REALITY and needs a capture on a CLEAN tree at final committed HEAD (216-09 SC-5 discipline; Pitfall 5) | ❌ Wave 0 (`admin-autofix-loop.test.sh` + `board-autofix-seed` fixture) |
| **SC-5** | panel NOT in `fast_checks`; NOT in any merge-blocking gate; only deterministic derivatives gate (JUDGE-CI-01) | negative-assertion CI-wiring test | grep-assert that no workflow `run:` line invokes `admin-panel.sh`/`admin-autofix-loop.sh`; assert the 5 required checks (ci.yml) exclude the panel; assert `admin-panel.sh` `exit 0`s on missing `ANTHROPIC_API_KEY` | YES — fully static: the filesystem split (`scripts/panel/`), the Hammer no-op, and a grep over `ci.yml` prove it with zero LLM involvement | ❌ Wave 0 (a `.test.sh` grepping `.github/workflows/*.yml`) |

### Sampling Rate
- **Per task commit:** the relevant `<guard>.test.sh`/`.test.mjs` (browser-free, seconds).
- **Per wave merge:** the full `fast_checks` self-test list (all guard self-tests) + `fix-queue-lint.sh` + `panel-forced-floor-check.mjs` + `panel-verdicts-lint.sh`.
- **Phase gate:** full `fast_checks` green + the SC-2 call-counter test green + the SC-4 hermetic test green + ONE off-CI live run (SC-2 zero-calls reality + SC-4 `board-autofix-seed` companion) captured on a clean tree at final committed HEAD.

### Which SCs are committed-ledger-provable vs need a live off-CI run
- **Fully committed-ledger / hermetic (no `ANTHROPIC_API_KEY`):** SC-1, SC-3, SC-5, and the WIRING half of SC-2 and SC-4.
- **Need a live off-CI run (216-09 SC-5 discipline):** SC-2's "unchanged surface → zero LLM calls" reality (the call-counter test proves the code path with a test-double; only a real run with an API key proves the cache actually skips against the live model) and SC-4's `board-autofix-seed` live companion (hermetic test proves rails fire; live run proves an end-to-end injected regression is caught + reverted at final committed HEAD).

### Wave 0 Gaps
- [ ] `scripts/ci/panel-forced-floor-check.mjs` (+ `.test`) — covers SC-1 (clone `panel-schema-check.sh` shape, read JSON)
- [ ] Extract `scripts/ci/lib/anchor.mjs` (or similar) from `evidence-anchor-check.mjs` exposing `isStructuralAnchor` + resolution helper — unblocks SC-1's shared-anchor reuse (Pitfall 1); keep `evidence-anchor-check.mjs` byte-behavior identical
- [ ] `scripts/panel/panel-schema.mjs` finding_id helper + `.test` asserting byte-identity with the 216 formula for `(surface, "lens:question", anchor)` — SC-3 seam guard (Pitfall 2)
- [ ] `scripts/panel/judge.test.mjs` call-counter test (SDK test-double, `callCount === 0` on cache hit) — SC-2 zero-calls wiring
- [ ] `scripts/ci/fix-queue-build.mjs` + `scripts/ci/fix-queue-lint.sh` (+ `.test`) — SC-3; also the `open_findings` sole-writer refactor (Pitfall 3 ordering)
- [ ] `scripts/ci/admin-autofix-loop.test.sh` — SC-4 hermetic (clone `quality-findings-monotonic.test.sh`)
- [ ] `board-autofix-seed` board in `design_gallery_live.ex` — SC-4 live companion fixture
- [ ] A `.test.sh` grepping `.github/workflows/*.yml` asserting no `admin-panel.sh`/`admin-autofix-loop.sh` `run:` step + `admin-panel.sh` no-op — SC-5
- [ ] Framework install: `npm install --save-dev @anthropic-ai/sdk ajv|zod` in the Playwright subproject (AFTER legitimacy gate)

*(No new global test framework needed — the existing tri-modal 216 harness covers all phase requirements.)*

## Security Domain

> `security_enforcement` is not disabled. This phase adds an LLM call path + an auto-commit loop over untrusted-ish rendered evidence — the ASVS surface is real.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface (dev tooling) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | LLM structured-output validated with ajv/Zod; every anchor validated by `isStructuralAnchor` + run through cheerio `$()` ONLY (never eval/shell — the existing T-216-04-INJECT invariant `[VERIFIED: evidence-anchor-check.mjs L19-22, L221]`); `findings.json`/`panel-findings.json` JSON-parsed, never eval'd |
| V6 Cryptography | yes | `node:crypto` SHA-256 for finding_id — never hand-rolled; already the 216 standard |
| V7 Secrets | yes | `ANTHROPIC_API_KEY` env-only, NEVER in prompts/messages/logs/committed files (D-03); the no-op degrade must not echo the key |

### Known Threat Patterns for {LLM-panel + auto-commit loop}
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prompt-injection via rendered DOM/copy tricking the judge into fabricating an anchor | Tampering | Judge output is ADVISORY only; every cited anchor is re-validated against the real DOM via `evidence-anchor-check` before it can enter the fix queue or a finding_id (D-08 pre-hash validation) — a hallucinated/injected anchor is dropped, not voted on |
| Auto-fix loop applying an unsafe/unbounded edit | Tampering/DoS | Only `copy`+`token` classes auto-apply (D-13); CSS + component out; `--max-fixes N` bounds a run; `git revert` (never force-push) per the ruleset; poison-set prevents retry loops (Renovate lesson) |
| LLM findings inflating the merge-gating count | Elevation of Privilege (advisory→gate) | Panel findings in a PARALLEL `panel-findings.json`, NEVER `findings.json`; `open_findings` written ONLY by `fix-queue-build.mjs` (D-05/D-12) |
| API key leakage into a committed ledger/report | Information Disclosure | Key env-only; `admin-panel-verdicts.json` stores `provenance {model, k, quorum, rubric_version, prompt_sha}` — a prompt_sha, NEVER the prompt or key (D-09) |
| Shell/command injection via anchor or finding text | Tampering | Anchors go through cheerio `$()` only; `settled-findings-lint.sh --add` takes structured flags, not interpolated shell (verified CLI) |
| Auto-commit forging history / bypassing the ruleset | Repudiation | `git revert --no-edit HEAD` = a new commit, reflog-clean (D-15 asserts `git log` shows `Revert "autofix...` + clean reflog); no admin-merge/force-push |

## Sources

### Primary (HIGH confidence — verified in this session)
- `scripts/ci/evidence-anchor-check.mjs` — createRequire-cheerio, `isStructuralAnchor` (non-exported), `$(anchor).length`, GEOMETRY_ONLY_CLASSES, injection invariant
- `scripts/ci/award-guard.mjs` — `minBand`/`BAND_ORD`/AXES, `git show base:` diff, `import from './lib/eval-probe-ids.mjs'`
- `scripts/ci/quality-findings-monotonic.test.sh` — mktemp+trap hermetic self-test, `--base`, stderr-string assertion
- `scripts/ci/panel-schema-check.sh` — RETIRED marker, markdown forced-floor validation shape, column-4 integer prohibition
- `scripts/ci/settled-findings-lint.sh` — 7-col TSV, `--add --surface --class --anchor --disposition --waived-by --note`, finding_id recompute
- `scripts/ci/admin-eval-harness.sh` — bash orchestrator chaining derivative guards; off-`fast_checks`
- `test/example/priv/playwright/tests/admin-eval.spec.ts` — `enrichFindingsForBundle` finding_id `sha256(surface \0 probe_class \0 anchor)`, `class` alias, writeBundleLocal
- `test/example/priv/playwright/lib/eval/probes.ts` — `onScale` nearest-scale, `measured_px`/`scale_px`, probe classes
- `guides/reference/admin-eval-schema.md` — finding_id byte spec + the UNRESOLVED SEAM section (D-07 path #1) + one-authoritative-source rule
- `guides/reference/admin-persona-jtbd-rubric.md` — 3 persona lenses, forced-floor, `keep|tighten|kill`, `NONE — searched for:`, worst-verdict, `clean`
- `guides/reference/admin-render-sha.json` — `render_sha256` + `open_findings` per cell; harness-written today
- `guides/reference/admin-eval-runbook.md` — the "Phase 217 will add the LLM-panel step (off-CI)" note
- `guides/reference/settled-findings.tsv` — 7-col header
- `brandbook/brand-book.md` + `brandbook/tokens.css` — ember `#c2410c` light / `#fdba74` dark, Space Grotesk, Core Rails (brand v2)
- `.github/workflows/ci.yml` — `fast_checks` self-test list (L112-140), harness in non-required `continue-on-error` render job (L2012-2019), 5 required checks
- **bundled claude-api skill** — `claude-opus-4-8` 400s on temperature/top_p/top_k; `output_config.format` structured outputs + schema-constraint limits; base64 image blocks; no assistant prefill; adaptive thinking default; `cache_control` system prompt; `@anthropic-ai/sdk` (TS) + `@anthropic-ai/sdk/helpers/zod`

### Secondary (MEDIUM confidence)
- `.planning/phases/216-harness-foundation-award-gradient/216-CONTEXT.md` (substrate; not re-read line-by-line this session — referenced via CONTEXT.md canonical refs)
- MEMORY.md 216-09 SC-5 lesson (committed-HEAD render trap) — Pitfall 5

### Tertiary (LOW confidence — ASSUMED, gate before use)
- `@anthropic-ai/sdk` + `ajv`/`zod` exact package names/versions on npm — run the legitimacy gate + `npm view` before install

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — SDK is confirmed by the claude-api skill as the official TS SDK, but exact npm name/version unverified this session (gate + `npm view` required)
- Architecture / idiom reuse: HIGH — every named idiom verified at its cited path with real excerpts
- Model contract (D-08): HIGH — verified against the bundled claude-api skill (the authoritative model contract)
- Pitfalls/seams: HIGH — the four landmines were found by reading the actual code, not inferred
- Validation architecture: HIGH — mapped to concrete verified guard idioms + the 216-09 SC-5 discipline

**Research date:** 2026-07-04
**Valid until:** 2026-08-03 for the reuse idioms/seams (stable committed code); ~7 days for the `@anthropic-ai/sdk` version (fast-moving — pin at install).
