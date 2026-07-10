# Phase 217: Adversarial Panel + Auto-Fix Safety Rails - Context

**Gathered:** 2026-07-04 (assumptions mode + deep 4-cluster subagent research + claude-api skill verification)
**Status:** Ready for planning

<domain>
## Phase Boundary

**In scope (from ROADMAP.md Phase 217 / REQUIREMENTS PANEL-01/02, AUTOFIX-01/02):**
Layer an **OFF-CI, operator-triggered 4-lens LLM panel** (3 persona/JTBD lenses verbatim from
`admin-persona-jtbd-rubric.md` + 1 new graphic-design lens) on top of Phase 216's deterministic
substrate. The panel judges RENDERED evidence bundles under a forced-finding floor with k=3 consensus,
deduplicates findings into a stable committed fix queue keyed by the 216 `finding_id`, and auto-applies
only provably-safe fix classes (**copy + token-swap only** — operator decision) as atomic commits with
per-fix `git revert` auto-revert on regression. Proven by an injected-regression test that trips BOTH the
auto-revert AND the findings-count-monotonic guard.

**Out of scope (defer):**
- Broad elevation wave across all 8 surfaces + L1/L2 fractal, and folding UI-01/UI-02 → **Phase 218**.
- Baseline recapture / canary reconciliation → **Phase 219**.
- Terminal ratification → **Phase 220**.
- **CSS-token auto-apply** (`sigra_admin.css` lives in 3 lockstep copies) → deferred past 217 (D-13).
- **component-swap auto-apply** — routed to the human queue (operator decision).

**Milestone invariant (JUDGE-CI-01 — holds across every decision below):** the panel and the auto-fix
loop are **never** in `fast_checks` and **never** in any merge-blocking CI gate. Only their DETERMINISTIC
derivatives gate merges — `quality-findings-monotonic.sh`, the probe findings, and the committed ledger
diffs (`admin-render-sha.json`, `admin-award-ledger.json`, `fix-queue.json`, `settled-findings.tsv`,
`admin-panel-verdicts.json`). The whole design defeats **cite-and-flip** (judge RENDERED output, cite a
structural anchor validated by `evidence-anchor-check.mjs`) and **LLM-nondeterminism** (k=3 consensus on a
deterministic key + content-hash skip; panel off the merge path; panel findings NEVER inflate the
deterministic `open_findings`).
</domain>

<decisions>
## Implementation Decisions

### A. Panel runtime, home & operator DX (PANEL-01)

- **D-01: Panel code home = `scripts/panel/` (plain `.mjs`, a SIBLING of — not inside — `scripts/ci/`).**
  Files: `judge.mjs` (entrypoint: locate bundles, call Anthropic, write outputs), `lenses.mjs` (the 4 lens
  definitions + prompt assembly), `panel-schema.mjs` (output JSON schema + shared `finding_id` helper),
  `excerpt.mjs` (deterministic DOM canonicalization for the input contract). Reuse the Playwright
  subproject's `node_modules` via `createRequire(path.join(PW,'package.json'))` — the SAME pattern
  `evidence-anchor-check.mjs` uses for cheerio. Add `@anthropic-ai/sdk` as a `devDependency` to
  `test/example/priv/playwright/package.json`. **No new `package.json`, no TS build step.** The
  `scripts/panel/` (advisory) vs `scripts/ci/` (deterministic merge gates) split encodes JUDGE-CI-01 in the
  filesystem — a `scripts/ci/*.mjs` glob can never sweep the judge into a CI lane. (Considered & rejected:
  `test/example/priv/playwright/lib/panel/*.ts` — drags the browser-free judge into the Playwright-run world,
  inviting a CI-lane wiring hazard; panel needs no browser.)

- **D-02: Operator invocation = a thin `scripts/ci/admin-panel.sh`** cloned structurally from
  `admin-eval-harness.sh`. It (a) resolves bundles by the locked `app_git_sha = git rev-parse HEAD` key,
  (b) **hard-degrades to `exit 0` (skip-with-warning) when `ANTHROPIC_API_KEY` is unset** — the Hammer
  no-op idiom, which structurally guarantees JUDGE-CI-01 (a missing key can only ever pass), (c) enforces a
  bundle-freshness precondition (warn/skip, not hard-fail, if bundles are stale vs HEAD — don't burn API
  tokens on a stale render), (d) defaults to the pilot surfaces and requires `--all` to fan out (Phase-218
  scope; print an estimated call count first), (e) **never writes any git-tracked ledger the deterministic
  guards read.** Rejected: a `mix` task (no Ecto/Sandbox payoff, D-02 of 216) and an `npm run` script
  (buries an off-CI tool inside the browser-test subproject).

- **D-03: LLM call shape = `@anthropic-ai/sdk` `messages.create`, model pinned `claude-opus-4-8`,**
  structured output via `output_config.format` JSON-schema (bands/verdicts as `enum` strings,
  `additionalProperties:false`, NO `minimum`/`maximum`/`minLength`/`maxLength`/`multipleOf`, no recursion —
  per the schema-constraint limits), rubric in a `cache_control`-ed `system` prompt, response validated with
  `ajv`/Zod. Adaptive thinking default; **no assistant prefill** (400s on 4.8). Image fed as a base64
  `image` content block. `ANTHROPIC_API_KEY` env-only (never in prompts/messages).

### B. Panel input/output contract & forced-floor validation (PANEL-01)

- **D-04: One Anthropic call per (surface × cell), carrying all 4 lenses.** Inputs per call: (1) a
  **deterministic, anchor-preserving DOM excerpt** produced by `excerpt.mjs` — reuse 216 D-06
  canonicalization (strip volatile `data-phx-*`/`nonce`/`id^=phx-`/csrf/`?vsn=`) BUT **retain the structural
  anchors** (`data-testid`, `data-sg-*`, `role`, `aria-label`, semantic classes) so any cited anchor
  round-trips through `evidence-anchor-check.mjs`; cap text-node length deterministically; (2) the full
  `facts.json`; (3) the committed `screenshot.png` (base64). The prompt routes the **image to the
  graphic-design lens** and **DOM/facts to the 3 persona lenses**. Per-cell (not per-lens, not one-giant-
  batch) is the granularity. `excerpt.mjs` is pure + covered by a `.test`.

- **D-05: Panel emits a PARALLEL `panel-findings.json` per cell, written beside `findings.json` in the
  gitignored bundle dir — NEVER merged into `findings.json`.** This is load-bearing: panel findings must not
  enter the deterministic `open_findings` count that `quality-findings-monotonic.sh` gates on. Shape mirrors
  the probe finding + adds `lens`, `question`, `verdict` (`keep|tighten|kill`), `none_searched_for`, and a
  `schema_version`. The human-readable `admin-panel-report.md` is **rendered from the JSON** by `judge.mjs`
  (one source of truth, two views) and is gitignored.

- **D-06: Forced-finding floor enforced TWICE.** (1) Structurally at generation: the `output_config.format`
  schema requires each (lens×question) cell to be EITHER a `verdict != keep` finding with a structural
  `anchor` + `refutation`, OR a `keep` with a non-empty `none_searched_for` (the literal
  `NONE — searched for: <what>`). (2) At rest: a new `scripts/ci/panel-forced-floor-check.mjs` cloned in
  shape from the retired `panel-schema-check.sh` (a `.mjs` guard reading JSON, so the markdown column-4
  hazard is moot) — asserts the 12-cell grid (4 lenses × 3 questions) is complete, rejects empty/vague NONE
  tokens, and validates every non-`keep` anchor via the shared `isStructuralAnchor` (reuse
  `evidence-anchor-check.mjs`) before it lands on disk.

### C. finding_id reconciliation, k=3 consensus & content-hash cache (PANEL-01/02)

- **D-07: `finding_id = sha256(surface + "\0" + class + "\0" + anchor)` — byte-identical to 216 — with
  `class = "<lens>:<question>"`** (e.g. `platform_admin:ia_muddy`, `graphic_design:salience`). This closes
  the `admin-eval-schema.md` "UNRESOLVED SEAM" via its own recommended path #1, so panel findings,
  `settled-findings.tsv` waivers, and the fix queue share ONE key space with zero re-tooling of
  `settled-findings-lint.sh`.

- **D-08 (CORRECTED — model contract): k=3 = three independent LLM samples per cell, NO `temperature`
  parameter.** `temperature`/`top_p`/`top_k` **400 on `claude-opus-4-8`** (verified against the `claude-api`
  skill — sampling params removed on Opus 4.7/4.8). The earlier "temperature 0.7" premise is void. Sample
  diversity comes from the model's inherent non-greedy sampling + adaptive thinking across independent
  requests — it is free and cannot be dialed. **Admit a finding iff its `finding_id` appears in ≥2 of 3
  samples** (quorum on the KEY, never on prose). Reconcile `severity` by **worst-verdict**
  (`kill > tighten > keep`) across the winning samples (mirrors the rubric's own worst-verdict floor +
  216 D-18 `min(axes)`); reconcile `description` by the **first winning sample** (deterministic, byte-stable).
  Pre-validate every proposed anchor against the DOM (closed allowlist of structural selectors already
  present) BEFORE hashing, so near-duplicate/hallucinated anchors are dropped, not voted on. Canonicalize
  anchor quote-style/whitespace before hashing. Filter `NONE` tokens out of finding_id space. k=3/≥2 is
  deliberately precision-favoring (correct for a non-blocking judge). **Pilot task: measure inter-sample
  finding_id-set variance; if samples are too agreeable, raise k or vary prompt/effort per sample — NEVER
  reach for temperature.**

- **D-09: Content-hash skip cache = a committed `guides/reference/admin-panel-verdicts.json`, keyed on
  `render_sha256`.** Per key: `admitted_findings[]` (each with finding_id, class, anchor, severity,
  description, quorum_count), `per_lens_disposition`, `surface_disposition`, `sample_key_sets` (the
  finding_id set each of the k samples emitted — for auditability/offline re-derivation of the vote), and
  `provenance {model, k, quorum, rubric_version, prompt_sha}`. It READS `render_sha256` from
  `admin-render-sha.json` (the single authoritative source) and **NEVER stores `open_findings`** (no
  duplication — the one-authoritative-source rule). Committed (not gitignored) because it is the small
  derived forward-only signal (216 D-05 category) and must be present at checkout for "unchanged surface →
  zero LLM calls" to be provable. **Cache-miss on `provenance` mismatch** (rubric/prompt drift) even when
  render_sha256 is unchanged, and on cross-surface render_sha256 collision (assert `cached.surface ==
  current.surface`). Anti-rot triad (mirrors 216 D-22): `panel-verdicts-lint.sh` (valid JSON, 64-hex keys,
  sorted, no dup, finding_id recomputes) + a non-blocking `--prune` for orphaned entries. Prove
  "unchanged → zero LLM calls" with a hermetic call-counter `.test` asserting `callCount === 0`.

- **D-10: Diff-scoped critique for changed surfaces (PANEL-02).** When a cell's `render_sha256` changed:
  (1) **carry forward** each prior admitted finding whose anchor still resolves (`evidence-anchor-check`)
  and whose probe (if class maps to one) still fires — same finding_id, no new LLM call; (2) mark
  **resolved** those whose anchor is gone or probe is now clean, and write a `resolved` row to
  `settled-findings.tsv` via the 216 D-22 regen helper (drives the down-ratchet); (3) invoke the LLM ONLY
  for the "new regressions" scope with an exclusion list of the carried-forward finding_ids. Diff is a
  set-difference on finding_ids computed BEFORE any LLM call (the SonarQube new-code pattern). Anchor-rename
  churn (one resolved + one new) is documented as honest, not a bug; add a staleness horizon so a
  pure-LLM taste finding carried across N renders is re-verified.

- **D-11: `--changed-only` is the default; cost + resumability.** Batch the 3 questions per lens into ONE
  structured call (~9N calls first run, not 27N). Re-runs on an unchanged tree cost ~0 (content-hash skip).
  Persist verdicts per-cell incrementally so a crashed run resumes automatically (a completed cell is a
  cache hit); fail **non-zero with a partial-completion report** on API error mid-run — never a false-green
  partial, never a `surface_disposition` for an unfinished cell.

### D. Fix queue, auto-fix safety rails & injected-regression test (AUTOFIX-01/02)

- **D-12: Fix queue = a committed, derived, sorted `guides/reference/fix-queue.json`,** built by a new
  `scripts/ci/fix-queue-build.mjs` from the `findings.json` bundles; the OPEN-set **sibling** of
  `settled-findings.tsv` (`open = built − settled`, finally making that schema-doc rule executable code).
  Per-finding fields: `finding_id`, `surface`, `class`, `anchor`, `lens`, `severity`, `fix_class`
  (`copy|token|component|judgment`), `auto_eligible` (DERIVED == `fix_class ∈ {copy,token}` — the guard
  recomputes, never trusts the typed bit), `systemic_group = sha256(class + "\0" + anchor)`, `priority`
  (DERIVED). **Systemic collapse:** group by `(class, anchor)`; any anchor recurring across ≥2 surfaces
  becomes a high-priority parent floated to the top. **`fix-queue-build.mjs` also becomes the sole writer
  of `open_findings` in `admin-render-sha.json`** (one builder, two outputs → kills the currently
  hand-maintained-count drift). Guard: `fix-queue-lint.sh` (recomputes `auto_eligible`/`priority`, fails on
  drift). Non-authoritative `fix-queue.md` operator view (systemic parents first, paginated). Class-chain-
  anchored findings are policy `judgment` (auto-editing `class=` would change the finding_id that identifies
  them). Rejected: gitignored queue (can't diff vs merge-base, loses the forward-only signal); markdown-only
  queue (fragile awk parse, D-19 lesson).

- **D-13: Safe-fix taxonomy — auto-apply = COPY-SWAP + TOKEN-SWAP ONLY (operator decision); LLM is strictly
  OUT of the apply path.**
  - `token` (auto): an off-scale numeric CSS value → its nearest on-scale `--sg-*` token, computed
    deterministically from `facts.json` `scale_px` + the finding's `measured_px` (reuse the probe's own
    `onScale`/nearest logic, D-12 of 216 — read the live scale, don't fork a constant table). Apply only
    when the nearest token is within a tightened ±1.0px band; ties or >1.0px → downgrade to `judgment`.
    Preserve `!important`.
  - `copy` (auto): a **text-node-only** edit from a fixed deterministic normalization ruleset
    (`copy-rules.json`: sentence-case labels, terminal-period consistency, house-style tokens). Any copy
    edit needing semantic judgment → `judgment`. Structural anchors mean a copy edit can't move a cited
    anchor.
  - `component` (human queue), `judgment` (human queue) — never auto.
  - **CSS-token auto-apply is SCOPED OUT of 217:** `sigra_admin.css` exists in 3 lockstep copies
    (`priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`,
    `test/fixtures/install_golden/tree/.../sigra_admin.css`); a token swap there is a multi-file atomic op
    that trips `golden_diff_test` + the example↔template drift guard. 217 auto-applies to admin LiveView
    `.heex` attributes/inline-`style=` and the example only. CSS-token fixes route to human until a later
    phase folds installer/golden regen into the loop.

- **D-14: Auto-apply loop = a bash `scripts/ci/admin-autofix-loop.sh`** (house idiom; Node at the leaves —
  `fix-queue-build.mjs`, `fix-apply.mjs`). Per `auto_eligible` finding, highest-priority-first:
  `fix-apply.mjs` → `git add -A && git commit` (atomic, one fix per commit) → re-run
  `admin-eval-harness.sh` (re-render + all guards). **Auto-revert via `git revert --no-edit HEAD` (a NEW
  commit — never `reset`/force-push, per the ruleset) if ANY of three rails trips:** (1)
  `quality-findings-monotonic.sh` shows a count increase vs the pre-loop sha, (2) a per-surface **award-band
  floor** breach — reuse `award-guard.mjs` `min(axes)` against a pre-loop `admin-award-ledger.json` snapshot
  (an already-elevated A2 surface must not drop; this is the Betterer-style baseline that a bare count guard
  misses), or (3) any deterministic gate flips / a cited anchor stops resolving. A reverted finding is
  written to `settled-findings.tsv` (`disposition=waived, waived_by=autofix-217`) and added to a persisted
  **poison-set** (`eval/autofix-state.json`, gitignored) so it is never retried (Renovate endless-loop
  lesson). `--max-fixes N` bounds a run; the loop is resumable + idempotent. The loop is an
  operator/nightly tool OFF the merge path; only its committed ledger diffs gate.

- **D-15: Injected-regression test (SC-4) = a hermetic `scripts/ci/admin-autofix-loop.test.sh`** cloned
  from `quality-findings-monotonic.test.sh` (mktemp throwaway git repo, real guard binaries, no touch to the
  real repo, browser-free). Seed a deliberately-clunky **count-delta** (off-token spacing / ember misuse /
  misalignment — because the monotonic guard reads the committed count, not the DOM) and assert BOTH rails
  fire: (a) a `git revert` commit exists (`git log` shows `Revert "autofix...`, reflog clean = no
  force-push), the ledger is restored, and the finding is in `settled-findings.tsv`; (b)
  `quality-findings-monotonic.sh` exits non-zero on the pre-revert commit — causally linked to the revert
  via a harness test-double, not independently green. PLUS a **live fixture-board companion**
  (`board-autofix-seed` in `design_gallery_live.ex`) run through the real harness OFF-CI once (216-09 SC-5
  discipline — the hermetic test proves the wiring, the live run proves reality). The `.test.sh` slots into
  the existing `*.test.sh` self-test list; the loop itself never enters `fast_checks`.

### E. The new graphic-design lens (PANEL-01)

- **D-16: New sibling `guides/reference/admin-graphic-design-lens.md`** (NOT appended to the persona rubric
  — keeps the frozen column-4-integer-prohibited persona markdown untouched; mirrors 216 D-19's sibling-file
  discipline; must itself obey the column-4 integer prohibition). Plugs into the same panel via
  `class = "graphic_design:<key>"`, same forced-floor + `keep|tighten|kill` + `NONE — searched for:` token.
  Three refutation questions, each targeting a PERCEPTUAL failure no probe can own, each deferring in-line to
  the probe/proxy that owns the measurable half:
  - **Q1 `salience`** — "does the eye land on the wrong thing first?" (perceived first-fixation dominance of
    the primary action; picks up probe #9's D-15-deferred salience judgment; probes already own the
    above-fold + target-size geometry).
  - **Q2 `emphasis_ember`** — "is emphasis (esp. ember) earning its meaning, or decorating?" (semantic
    ember-as-ownership-boundary vs probe #4's structural allowlist; also flags under-emphasis of
    meaning-bearing elements).
  - **Q3 `composition`** — "does grouping / type hierarchy / balance read coherently — in BOTH themes?"
    (gestalt grouping, perceived type-hierarchy descent, compositional balance, and light-vs-dark EMPHASIS
    parity; probes/D-16-proxies already own measured spacing/rhythm; axe owns contrast correctness).
  Widens the worst-verdict roll-up from 3→4 lenses; **A3 award = all 4 lenses `clean`** (extends 216 D-17).
  Explicitly NOT: misalignment (#2), radius/shadow/control-height (#5), focus-ring (#7), card-in-card (#8),
  motion (D-16 proxy), responsive reflow — those stay deterministic.

- **D-17: Lens inputs & the visual-finding↔structural-anchor reconciliation.** This is the ONLY lens that
  REQUIRES `screenshot.png` (Q3 needs the light AND dark PNGs of the cell); the canonicalized DOM is fed for
  ANCHORING only; `facts.json` is read-only ground truth the lens may cite but must NEVER recompute or
  contradict. **Two-field finding shape:** `observation` (the perceptual judgment, prose) + `anchor` (a
  structural selector from the existing `data-testid`/`sg-*` BEM vocabulary, validated by
  `evidence-anchor-check.mjs`) + `evidence_cell` (which PNG the judgment was made on). The judgment is about
  pixels; the citation is about structure — so cite-and-flip stays impossible AND vague vibes are rejected by
  the floor + anchor check. Rejected: bounding-box coordinate anchors (sub-pixel-volatile, unvalidatable by
  cheerio).

- **D-18: Brand coherence.** The lens is sensitive to 7 named Sigra pillars, each mapped to a question and a
  brand-book v2 / `admin-ui-principles` citation (hierarchy/salience→Q1; restraint/ember-as-boundary +
  brand-v2 ember `#c2410c` light / `#fdba74` dark + Space Grotesk / Core Rails→Q2; consistency &
  "same job → same component" + typographic coherence + dark/light emphasis parity + composition/balance→Q3).
  Every finding references a named pillar so the lens speaks Sigra's language, not generic AI design-critique.

### Claude's Discretion
- Exact leaf-script/field names (`fix-apply.mjs` internals, `copy-rules.json` shape, `admin-panel.sh` vs
  `admin-panel-harness.sh`, the on-disk `panel-findings.json` filename), and whether the report lives in the
  bundle dir vs a gitignored path under `guides/reference/` — planner's call, provided the substance of
  D-01..D-18 holds.
- Whether `fix-queue.json` and `admin-panel-verdicts.json` are two files or a consolidated committed JSON —
  planner's call for legibility, as long as each guard reads ONE authoritative source and `open_findings`
  lives ONLY in `admin-render-sha.json`.
- The precise `--max-fixes` default and the staleness-horizon N for carried-forward taste findings.

### Folded Todos
- None folded. The phase-matched todos (`playwright-parallelization-per-shard-db` SEED-005/CI-PERF;
  `uat-demo-dx-polish-nits` UI-01; other v2 FEAT items) belong to other phases/milestones — see Deferred.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 217 details + 5 Success Criteria (the fixed boundary)
- `.planning/REQUIREMENTS.md` — PANEL-01/02, AUTOFIX-01/02 + the milestone JUDGE-CI-01 invariant
- `.planning/phases/216-harness-foundation-award-gradient/216-CONTEXT.md` — the substrate this builds on;
  esp. D-05/D-06 (`render_sha256` canonical hash = the content-hash for PANEL-02), D-09
  (`evidence-anchor-check` structural-anchor rule), D-15 (gate-vs-warn + probe #9 salience → 217 panel),
  D-17/D-18 (award bands A0-A3, A3 = panel `clean`, `min(axes)`), D-19 (sibling-file-not-markdown-column),
  D-21 (monotonic down-ratchet guard), D-22 (`finding_id` key + settled-findings anti-rot triad)
- `guides/reference/admin-eval-schema.md` — the `finding_id` byte spec + the **"UNRESOLVED SEAM"** section
  (217 `lens+question` → `class` reconciliation, D-07) + the one-authoritative-source rule
- `guides/reference/admin-persona-jtbd-rubric.md` — the 3 persona lenses VERBATIM, the 3 refutation
  questions, the forced-finding-floor standing instruction, the worst-verdict floor, `keep|tighten|kill`,
  `clean` disposition (the authoring template for D-16)
- `guides/reference/admin-eval-runbook.md` — the harness runbook ("Phase 217 will add the LLM-panel step"
  off-CI) that `admin-panel.sh` extends
- `guides/reference/admin-render-sha.json` — `render_sha256` + `open_findings` per cell (read by D-09/D-12;
  `open_findings` writer becomes `fix-queue-build.mjs`)
- `guides/reference/admin-award-ledger.json` + `scripts/ci/award-guard.mjs` — award bands = the
  "already-elevated surface" floor for D-14 rail (2)
- `guides/reference/settled-findings.tsv` + `scripts/ci/settled-findings-lint.sh` — the 7-col suppression
  file the fix queue is sibling to; the waiver sink for D-10/D-14
- `scripts/ci/quality-findings-monotonic.sh` + `.test.sh` — the guard SC-4 must trip; the mktemp self-test
  idiom to clone for D-15
- `scripts/ci/admin-eval-harness.sh` — the bash orchestrator to clone for `admin-panel.sh` (D-02) and
  re-run inside the auto-fix loop (D-14)
- `scripts/ci/evidence-anchor-check.mjs` — the browser-free `createRequire`-cheerio guard idiom (D-01), the
  `isStructuralAnchor` to reuse (D-06), the anchor-resolution check for carry-forward/resolved (D-10)
- `scripts/ci/panel-schema-check.sh` — RETIRED prior forced-floor lint; the SHAPE to clone into
  `panel-forced-floor-check.mjs` (D-06)
- `test/example/priv/playwright/tests/admin-eval.spec.ts` — how `findings.json` + `finding_id` are produced
  (`enrichFindingsForBundle`); the 216-08 in-scope SEEDED-DEFECT pattern to reuse for D-15
- `test/example/priv/playwright/lib/eval/{bundle.ts,canonicalize.ts,probes.ts}` — bundle layout,
  `render_sha256` computation, the probe nearest-scale/`onScale` logic to reuse for D-13
- `test/example/priv/playwright/package.json` — where `@anthropic-ai/sdk` is added as a devDependency (D-01)
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — where the `board-autofix-seed` live
  fixture board lands (D-15)
- `test/example/priv/static/assets/sigra_admin.css` + `priv/templates/sigra.install/admin/sigra_admin.css`
  + `test/fixtures/install_golden/tree/**/sigra_admin.css` — the 3 lockstep CSS copies that scope CSS-token
  auto-apply OUT of 217 (D-13)
- `guides/reference/admin-graphic-design-lens.md` — NEW sibling authored by this phase (D-16); grounded in
  `guides/reference/admin-ui-principles.md`, `guides/reference/admin-design-contract.md`,
  `guides/reference/admin-fractal-scorecard.md`, and `brandbook/brand-book.md` + `brandbook/tokens.css`
  (brand v2 — ember `#c2410c`/`#fdba74`, Space Grotesk, Core Rails; IGNORE pre-v2 brand info)
- `.github/workflows/ci.yml` — `fast_checks` (the deterministic lane; new `.test.sh` self-tests attach; the
  panel + loop do NOT); the 5 required checks (JUDGE-CI-01)
- **claude-api skill** (bundled) — authoritative model contract: `claude-opus-4-8` 400s on
  `temperature`/`top_p`/`top_k`; `output_config.format` structured outputs (schema-constraint limits);
  base64 image input; no assistant prefill; adaptive thinking default

**External prior art surfaced (for researcher/planner, not repo files):** Anthropic structured outputs +
vision + `@anthropic-ai/sdk` `messages.create`; self-consistency / majority-vote (arXiv 2510.17472,
Wang et al. 2022; Zheng et al. 2023 LLM-as-judge — judges noisier on magnitude than existence); OpenRewrite
(semantics-preserving edit classes), ESLint `--fix` vs suggestions, Betterer (per-file baseline floor),
Renovate automerge (endless-loop lesson), SonarQube new-code reference-branch, codemod/jscodeshift safety;
Nielsen heuristics / Material design-review (adopt vocabulary, reject generic scope).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **The entire 216 substrate is on disk and green** — `scripts/ci/{admin-eval-harness.sh,
  quality-findings-monotonic.sh(+.test.sh), settled-findings-lint.sh, evidence-anchor-check.mjs,
  award-guard.mjs, stale-render-guard.sh}`; ledgers `admin-render-sha.json`, `admin-award-ledger.json`,
  `settled-findings.tsv`; TS `test/example/priv/playwright/{tests/admin-eval.spec.ts, lib/eval/*.ts}`.
  Real evidence bundles exist under `test/example/priv/playwright/eval/<app_git_sha>/…`.
- **`finding_id` is already implemented** at `sha256(surface \0 class \0 anchor)` in
  `enrichFindingsForBundle` and validated by `settled-findings-lint.sh`. 217 reuses it verbatim (D-07).
- **`evidence-anchor-check.mjs`** — the browser-free `createRequire`-from-Playwright cheerio pattern (D-01),
  `isStructuralAnchor` (D-06), and the `$(anchor).length` resolution check for carry-forward/resolved (D-10).
- **`panel-schema-check.sh` (RETIRED)** — the forced-floor lint shape to port to `.mjs` (D-06).
- **`quality-findings-monotonic.test.sh`** — the hermetic mktemp self-test idiom to clone for SC-4 (D-15).
- **216-08 seeded-defect pattern** in `admin-eval.spec.ts` — the injection idiom for the D-15 companion.
- **The probe nearest-scale/`onScale` logic in `probes.ts`** — reused verbatim for the token-swap
  arithmetic (D-13) so the fix reads the live `--sg-*` scale, never a forked constant table.

### Established Patterns
- Bash orchestrator over Playwright + single-purpose bash/node guards under `scripts/ci/`, each with a
  `.test`; `git show BASE:file` merge-base diffing; forward-only monotonic committed ledgers; the small
  derived signal is committed while heavy bundles are gitignored.
- `git revert` (new commit) auto-revert — the ruleset blocks force-push / `reset` / admin-merge (D-14).
- Build-free `--sg-*` token + BEM design system; admin LiveViews are library-owned; the example app is the
  generated host used for browser testing; this whole harness is repo-internal dev tooling, **NOT** shipped
  to host apps (it lives under `scripts/` + `test/example/`, outside `priv/templates/sigra.install/`).

### Integration Points
- **The `finding_id` key (D-07)** is the seam with 216 — must stay byte-identical.
- **`fix-queue-build.mjs` becomes the sole writer of `open_findings`** in `admin-render-sha.json` (D-12),
  killing the currently hand-maintained-count drift — one builder, one authoritative source.
- **New committed forward-only signals:** `fix-queue.json` + `admin-panel-verdicts.json` (join
  `admin-render-sha.json` / `admin-award-ledger.json` / `settled-findings.tsv`).
- **New `.test.sh`/`.test.mjs` self-tests attach to `fast_checks`'s existing self-test list**; the LLM
  panel (`admin-panel.sh`) and the auto-fix loop (`admin-autofix-loop.sh`) NEVER attach to any CI lane.
- **`@anthropic-ai/sdk` + a schema validator (`ajv`/Zod)** are the only new devDeps, added to the existing
  Playwright `package.json` — no new lockfile.
</code_context>

<specifics>
## Specific Ideas

- **Model-contract correction (load-bearing, verified against the `claude-api` skill):** `claude-opus-4-8`
  **400s on `temperature`/`top_p`/`top_k`.** The initial discuss-phase "temperature 0.7 to keep the knob"
  premise is void. k=3 sample diversity comes from the model's inherent non-greedy sampling + adaptive
  thinking across independent requests — free, undialable. Pin `claude-opus-4-8`; use `output_config.format`
  for schema-constrained JSON; feed the screenshot as a base64 image block; no assistant prefill. (D-08)
- **Operator-locked auto-fix scope:** auto-apply is **copy + token-swap only**; component-swap → human
  queue. Grounded in OpenRewrite "do-no-harm" + the research finding that component substitution can change
  layout/behavior (not byte-scoped/semantics-preserving). (D-13)
- **CSS auto-apply deferred by design:** the 3-lockstep-copy `sigra_admin.css` problem makes CSS-token
  fixes a fragile multi-file atomic op (golden + drift guards). 217 confines auto-apply to `.heex`
  attributes/inline-style + the example. (D-13)
- **The graphic-design lens must reference a named Sigra pillar per finding** — the single biggest lever
  against generic-AI design critique; adopt Nielsen/Material vocabulary but reject their generic scope.
</specifics>

<deferred>
## Deferred Ideas

- **CSS-token auto-apply** (fold installer/golden regen into the loop) → a later phase (D-13).
- **component-swap auto-apply** → not in scope; component-swap routes to the human queue.
- **Broad elevation across all 8 surfaces + L1/L2 fractal + UI-01/UI-02** → Phase 218.
- **Baseline recapture / canary reconciliation** → Phase 219.
- **A3 award for surfaces** → only earned once all 4 lenses (incl. the new graphic-design lens) read
  `clean`; the panel proposes, the deterministic ledger disposes.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db` (score 0.9, ci) — SEED-005 / CI-PERF perf-infra, not
  this quality-harness phase. Not folded.
- `2026-06-19-uat-demo-dx-polish-nits` (UI-01), `2026-06-22-vaultr-authed-rebrand-residuals` (UI-02) —
  folded into **Phase 218** by the ROADMAP, not 217.
- `2026-06-20-mix-sigra-migrate-schema-helper`, `2026-06-20-runtime-auth-prefix-override`,
  `2026-06-22-white-label-auth-email-theming` — v2 FEAT items, out of milestone scope.
</deferred>
</content>
