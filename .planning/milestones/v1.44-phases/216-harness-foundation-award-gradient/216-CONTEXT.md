# Phase 216: Harness Foundation + Award Gradient - Context

**Gathered:** 2026-07-03 (assumptions mode + deep research)
**Status:** Ready for planning

<domain>
## Phase Boundary

**In scope (from ROADMAP.md Phase 216 / REQUIREMENTS HARNESS-01..03, RATCHET-01..02):**
A single near-command renders every admin surface into tamper-proof evidence bundles; deterministic
visual probes run over rendered DOM/computed-style and flag defects automatically; the quality ledger
gains a finer-grained award sub-score above the Tier-2 ceiling with verify-then-climb; a
findings-count-monotonic guard + settled-findings suppression enforce forward-only. **Proven end-to-end
on TWO pilot surfaces only** — the broad wave over all 8 surfaces is Phase 218.

**Out of scope (defer):**
- The 4-lens **LLM panel, consensus, auto-fix** — Phase 217 (only the deterministic substrate + the
  `finding_id` key contract land here).
- Broad elevation across all 8 surfaces + L1/L2 fractal — Phase 218.
- Baseline recapture / canary reset — Phase 219.

**Milestone invariant (holds across every decision below):** the merge-blocking forward-only signal
stays **100% deterministic** (monotonic guards, snapshot-canary, axe, token/contrast gates). The LLM
panel is an issue-finder/judge-of-taste ONLY — never a CI gate, never flips a ledger cell. The whole
design defeats **cite-and-flip** (evaluate RENDERED output, never code) and **LLM-nondeterminism**
(judge off the merge path).
</domain>

<decisions>
## Implementation Decisions

### Harness runtime & home (HARNESS-01)
- **D-01:** Build the harness as a **new Playwright/TypeScript project** (`admin-eval`, targeting the
  existing `/admin/_design` gallery) with a **thin bash orchestrator** under `scripts/ci/`
  (`admin-eval-harness.sh` or `admin-harness.sh`), cloned in structure from `snapshot-recapture-gate.sh`.
  The render+probe+hash logic lives in a TS spec beside `admin-design.spec.ts`; the deterministic guards
  are bash/node under `scripts/ci/` beside `quality-ledger-monotonic.sh`.
- **D-02:** **Reject a `mix` task** and **reject a standalone Node CLI.** A `mix` task's only real value
  is Ecto SQL-Sandbox reuse (the `phoenix_test_playwright` idiom), which is moot — the `/admin/_design`
  gallery is a static dev-only board with populated/zero/loading/error states baked in, no per-test DB
  fixtures. Axe / `getComputedStyle` / geometry only exist in a real browser (the BEAM has none), so
  Playwright is unavoidable regardless; adding a mix or node wrapper is a second orchestration brain with
  no payoff. One bash entrypoint → one Playwright project. (Cite "considered & rejected: mix task — no
  Sandbox dependency" in the phase doc.)
- **D-03:** Inherit `playwright.config.ts` determinism defaults (`animations:'disabled'`, `caret:'hide'`,
  `scale:'css'`, existing longpoll-aware timeouts, `pathTemplate`) — **add a project, do not fork the
  config.** Reuse `waitForLiveViewReady` (font-gate + `.phx-connected`) before any capture.

### Evidence bundle format & location (HARNESS-01)
- **D-04:** **Gitignore the full evidence bundles** (post-hydration DOM, computed-style facts, geometry
  facts, raw axe JSON, PNG) as ephemeral build artifacts under
  `test/example/priv/playwright/eval/<app_git_sha>/<surface>/<cell>/` (top-level keyed on app git SHA so
  bundles from different commits never collide). Upload as CI artifacts like `playwright-report/`. Extend
  `.gitignore` (which already ignores `test-results/` + `playwright-report/`).
- **D-05:** **Commit only the small derived signal**: a canonical `render_sha256`-per-(surface×cell)
  ledger + the curated findings/settled-findings/award ledger. A SHA change is a reviewable one-line text
  diff that merges cleanly — this is the forward-only artifact, same role `quality-ledger-monotonic.sh`
  already guards. PNGs stay out of git; if committed visual baselines are ever wanted, route them through
  the **existing** `admin-design.spec.ts-snapshots/` lane, not a second image store. (Every mature tool —
  Chromatic/Percy/reg-suit commit nothing; BackstopJS/loki suffer committed-blob churn → git-lfs — confirms
  this.)
- **D-06:** `render_sha256` is hashed over a **canonicalized DOM allowlist**, never raw `outerHTML`.
  Pipeline: capture after `.phx-connected`; parse (LazyHTML/lexbor or parse5/rehype); **strip volatile**
  (`<meta name=csrf-token>`, all `data-phx-*`/`phx-*`, `nonce`, `integrity`, `id^=phx-`, `_csrf_token`
  values, asset `?vsn=`/digest fingerprints — all random per request); **allowlist-keep** (tag in tree
  order, whitespace-normalized text, curated semantic attrs: `href` digest-stripped, `type`, `name`,
  `role`, `aria-label`, `alt`, `data-testid`); **canonicalize** (sort attrs, sort class tokens, drop
  whitespace-only nodes); serialize → sha256. **Allowlist, not denylist** (a denylist rots on every
  LiveView release). Consider Playwright **ARIA-snapshots** as the hash basis (a pre-built semantic
  allowlist). Round/bucket geometry facts to tolerances or CI-pin — never hash raw sub-pixel floats.

### Stale-render + evidence-integrity guards (HARNESS-02)
- **D-07:** **Git plumbing, never mtime.** `actions/checkout` stamps every file with run-time mtime
  (actions/checkout#468) → mtime false-passes 100% in CI. Stale-render guard (`scripts/ci/`, bash):
  hard-fail if any `bundle.app_git_sha != $(git rev-parse HEAD)`; additionally fail if
  `git diff --name-only <bundle_sha> HEAD -- <admin source globs>` is non-empty ("admin source newer than
  bundle"). Anchor globs to the same admin paths the installer-detect step uses (`lib/sigra/**/admin/**`,
  `sigra_admin.css`, admin LiveViews); unit-test the glob in a `.test.sh`. Error loudly
  (`git cat-file -e <sha>`) if the bundle sha is unreachable rather than skip.
- **D-08:** **Absence of bundles = hard FAIL, not skip.** (Contrast the monotonic guard's skip-on-empty-
  *base*, which is correct there because a decrease is impossible with no baseline.) HARNESS-02 forbids
  trusting absent/untrustworthy renders. The captured sha lives inside the current run's bundle, so there
  is **no first-phase bootstrap problem** — the guard is self-contained against current HEAD.
- **D-09:** Evidence-integrity / anchor-presence check is **node + cheerio** over the captured
  `outerHTML` string (`scripts/ci/evidence-anchor-check.mjs`), cheap and browser-free. For every finding,
  assert its cited DOM anchor is present (`cheerio.load(html); $(anchor).length > 0`). Anchor identity
  MUST be a **structural selector / `data-*` hook, never prose/text** (survives copy edits). Load in HTML
  mode (not `xmlMode`). This makes cite-and-flip impossible by construction. cheerio (not jsdom): the
  string is already hydrated, no JS execution needed. Geometry-dependent facts (misalignment, below-fold,
  focus-ring) **cannot** be recomputed here — jsdom/cheerio have no layout — they are produced in-browser
  at capture (D-11).

### CI base-ref correctness fix (in-scope foundation)
- **D-10:** **Fix the shared `id: base` step in `ci.yml` to emit the merge-base**, not the base-branch
  tip. Today it resolves `ref=origin/${base_ref}` (tip, `--depth=1`) while the installer-detect step uses
  three-dot `origin/main...HEAD` (merge-base) — an existing inconsistency. Tip-diffing false-fails a
  down-ratchet whenever main moves ahead of the fork. Fix: `MB=$(git merge-base origin/${base_ref} HEAD)`
  (needs history, not `--depth=1`). One-line semantics change that simultaneously corrects the new
  findings-count guard, the existing tier guard, and `snapshot-canary-guard.sh`. Belongs in a "harness
  foundation" phase.

### Deterministic visual probe engine (HARNESS-03)
- **D-11:** Probes run **in the live Playwright `page` at capture time** (`page.evaluate`), results
  written into `bundle.findings`. Geometry/box facts (`getBoundingClientRect`, viewport, focus-ring) are
  **only** measurable in the browser and are serialized as pre-computed facts; post-hoc consumers read
  facts, never recompute geometry.
- **D-12:** Define "off-token"/"off-scale" by **reading the `--sg-*` scale live from `:root`**
  (`getComputedStyle(document.documentElement).getPropertyValue('--sg-space-4')` …), never a duplicated
  JS constant table (proven drift risk — the example↔source CSS-split/JS-bundle incidents). Footguns to
  bake in: resolve root font-size and **normalize rem→px with ±0.5px epsilon**; read **longhands**
  (`paddingTop/Right/Bottom/Left`, four radius corners), never shorthand; `clamp()`/`color-mix()`/`oklab`
  resolve to concrete values under `getComputedStyle` — read the resolved value, don't parse the
  expression; never use Playwright `toHaveCSS` for custom props (#12629) — always `evaluate` +
  `getComputedStyle`.
- **D-13:** **Focus-ring probe (#7) diffs computed `box-shadow`, NOT `outline`.** Decisive: this system
  authors focus as `outline:none; box-shadow: var(--sg-focus-ring)` (`sigra_admin.css:449`) — an
  outline-width check would false-positive on every `.sg-btn`/chip/metric-link. Call `.focus()` and diff
  the unfocused→focused computed `box-shadow` (and outline); PASS if either changes. `--sg-focus-ring`
  (3px) already clears WCAG 2.4.13, so a presence check suffices for the gate; leave the 3:1 contrast
  delta to warn/LLM.
- **D-14:** **Reuse, don't reinvent:** axe-core's `target-size` rule (enable via WCAG-2.2 ruleset — off by
  default) as the primary engine for probe #6 (inherit its spacing-exception math); the existing
  card-in-card check in `admin-design.spec.ts:349-361` verbatim for probe #8; the existing
  `data-sg-<probe>-audit-only` / `data-sg-card-nesting-audit-only` suppression-attribute convention for
  every probe's escape hatch (don't invent a new mechanism).
- **D-15:** **Gate-vs-warn split** (flake containment — any probe whose signal moves with font metrics /
  subpixel rounding / data volume / theme rgba rounding must not hard-gate, or it becomes the next
  "known pre-existing failure"):
  - **HARD GATE (deterministic, low-flake):** #1 off-token spacing, #4 ember-reserved-for, #5 off-scale
    radius + control-height, #6 target-size @24×24, #7 missing focus-ring, #8 card-in-card nesting.
  - **WARN-ONLY (flaky or judgment-laden):** #2 1–6px misalignment, #3 size/weight budget (≤5 sizes /
    ≤3 weights per surface), #5 shadow-composite, #6 the 44×44 advisory tier, #9 below-fold / non-obvious
    primary action (deterministic geometry part only; salience judgment routes to the Phase-217 panel).
  - Geometry probes **hard-gate only in the `-chromium` DPR1 project**; `-mobile`/`-dark` runs of the same
    probes emit warnings. Fold line uses `documentElement.clientHeight` (excludes scrollbar).
- **D-16:** The three "documented-as-manual" scorecard proxies (motion, whitespace-rhythm, target-size —
  `admin-fractal-scorecard.md:160-174`) are **promoted to rendered probes** by this phase (their prose
  `reviewed —` assertions are replaced by measured findings), satisfying HARNESS-03's promotion clause.

### Award sub-score gradient (RATCHET-01)
- **D-17:** The award sub-score is an **ordinal band A0→A3 above Tier-2** (Tier-2 = entry gate to A0),
  **not** a 0–100 score (Lighthouse's own 99→100 diminishing-returns problem; un-earnable/gameable at the
  top). Ladder stays monotone end-to-end: `Tier 0→1→2 → A0→A1→A2→A3`. Band semantics are additive
  (cannot hold A2 without A1): A0 Nominated (Tier-2 + every applicable probe has a *rendered* evidence
  key), A1 Shortlisted (+ the 3 manual proxies converted to rendered probes), A2 Commended (+ adversarial
  states rendered & axe-clean, content-equivalence proven), A3 Award-grade (+ persona-JTBD panel `clean`
  + cross-viewport/theme render parity). **A3 = the point where both instruments (fractal scorecard +
  persona-JTBD) agree** — no new quality theory invented.
- **D-18:** Decompose the band into a **fixed 4-axis vector** (`token_fidelity` / `rhythm` /
  `a11y_polish` / `states`) — sub-scores tell the operator *what to fix next*, a bare scalar doesn't.
  **Roll-up = `min()` floor rule, NOT weighted average.** `min()` means the band equals the weakest axis
  (can't "buy" a band by maxing one cheap axis) — this mirrors the persona rubric's existing worst-verdict
  floor rule. The vector is diagnostic/visible; `band = min(axes)` is derived, never hand-typed.
- **D-19:** Store the award data in a **new sibling `guides/reference/admin-award-ledger.json`, NOT a
  markdown column.** The markdown tier column-4 `awk -F'|'` parse is already so fragile the persona rubric
  needed a "D-07 bare-integer prohibition" contract; a 5th award column multiplies that. **Keep the
  markdown tier column-4 grammar frozen and untouched** (append at most one sentence to a cell's evidence
  prose cross-referencing the JSON). A JSON guard can enforce what awk cannot (see D-20).
- **D-20:** A new **award guard** (node, with its own `.test.sh`-equivalent) enforces verify-then-climb
  anti-gaming: fail CI if (a) an axis band rose but `verified_at_sha` did not change (climb without a
  fresh render), (b) `award_band != min(axes)`, (c) any raised axis has `rendered:false` or an
  `evidence_ref` that doesn't resolve to a known probe id / test id / conformance-script selector, or
  (d) any axis band decreased vs merge-base. Prose "reviewed —" can no longer raise a band — only a
  resolvable probe id can. This is the structural cure for the manual era's optimistically-flipped cells.

### Findings-count-monotonic guard + settled-findings (RATCHET-02)
- **D-21:** A **separate** `scripts/ci/quality-findings-monotonic.sh`, structurally cloned from
  `quality-ledger-monotonic.sh` (same `git show BASE:file`, same associative-array diff, same `.test.sh`)
  but with the comparison **inverted**: fail when a cell's OPEN-finding count *increases* vs **merge-base**
  (D-10). One guard = one ratchet direction (tiers/award ratchet UP, finding-counts ratchet DOWN — don't
  cram opposite comparators into one awk parse). Mandatory `.test.sh`: count 3→4 FAIL, no-change PASS,
  4→3 PASS (down-ratchet), decorated-cell-invisible documented (the existing Test-D positional-parse
  lesson). `Open` count = total findings minus settled, computed by the harness from one source (never
  hand-maintained → no drift).
- **D-22:** Settled-findings suppression is a **committed, sorted, one-entry-per-line
  `guides/reference/settled-findings.tsv`**, keyed `finding_id = sha256(surface + "\0" + class + "\0"
  + anchor)`. **This key MUST match Phase 217's AUTOFIX-01 fix-queue `finding_id`** — plan both together.
  Columns: `finding_id  surface  class  anchor  disposition(waived|resolved)  waived_by  note`. Structural
  anchor (survives copy edits — the Betterer merge-conflict lesson: never hash line numbers/prose). Add a
  `settled-findings-lint.sh` that fails if unsorted/deduped, and a regen helper (`--add … --disposition`)
  so humans never hand-edit ordering. A settled entry whose anchor no longer appears in any current bundle
  is flagged stale (the `@ts-expect-error`-unnecessary anti-rot pattern; non-blocking prune). Modeled on
  ESLint bulk-suppressions (count-based → near-zero merge conflicts) + SonarQube "new-code" reference-
  branch grandfathering.

### Two pilot surfaces (RATCHET-01 verify-then-climb, end-to-end proof)
- **D-23:** Pilots = **`users-index-live`** + **`user-show-live`** (both L3). Together they span all nine
  probe classes: users-index owns table↔mobile-card content-equivalence + card-density + zero/loading/
  error (richest re-verifiable claim: `assertUserResultEquivalence`, frozen 5-col contract, near-threshold
  `applied_chip` target-size); user-show is the **only** Tier-2 cell that owns a modal/focus-trap (overlay-
  axe + APG focus-trap/restore). Alternatives rejected: `audit-index-live` duplicates the table path and
  owns no modal; `index-live`/`organization-live` own no results table + no modal (would leave two high-
  value probe classes unpiloted).
- **D-24:** The user-show pilot's **first job is to re-verify modal ownership** — the design contract says
  the confirm overlay *moved to `UserSessionsLive`*, so the ledger's cited `admin-modal-interaction.spec.ts`
  APG claim may be stale. This is a **feature** (proves the harness catches a stale prior claim), not a
  blocker.
- **D-25:** **Scope the pilots to A2**, not A3, unless the persona-JTBD panel
  (`v1.42-PERSONA-JTBD-PANEL.md`) is re-run at current HEAD — A3 requires panel `clean` by construction
  (D-17), and that panel is a Phase-209 artifact that isn't re-run here.

### Claude's Discretion
- Exact file/script names (`admin-eval-harness.sh` vs `admin-harness.sh`, `eval/` vs `artifacts/admin-
  harness/`), the on-disk cell-directory naming (`<theme>-<viewport>-<state>`), and whether the award
  guard is `.mjs` vs `.sh`+`jq` — left to the planner, provided the substance of D-01..D-25 holds.
- Whether to consolidate the render_sha256 ledger + open-finding counts into the same committed JSON as
  the award ledger, or keep them as separate small committed files — planner's call for legibility, as
  long as each guard reads one authoritative source and merge-base (D-10) is used.

### Folded Todos
- **UI-01 / UI-02 are NOT folded here** — the ROADMAP folds demo-DX nits (UI-01) and Tasklane rebrand
  residuals (UI-02) into **Phase 218**, not 216. Reviewed todos below.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 216 details + Success Criteria (the fixed boundary)
- `.planning/REQUIREMENTS.md` — HARNESS-01/02/03, RATCHET-01/02 + the milestone invariant
- `guides/reference/admin-quality-ledger.md` — the ledger cell inventory, tier column, evidence format,
  parse rules (lines 14–31), Terminal Ratification proof method (lines 104–125)
- `guides/reference/admin-fractal-scorecard.md` — scorecard dimensions + the 3 documented-as-manual
  proxies (lines 160–174) that HARNESS-03/D-16 promote
- `guides/reference/admin-persona-jtbd-rubric.md` — the persona/JTBD lenses, worst-verdict floor rule,
  D-07 column-4 integer prohibition (grounds D-18/D-19)
- `guides/reference/admin-design-contract.md` + `guides/reference/admin-ui-principles.md` — archetype
  contracts (List/Detail/Audit), design pillars, ember reservation
- `scripts/ci/quality-ledger-monotonic.sh` + `.test.sh` — the guard idiom to clone for D-21 (and the
  fragile awk parse that grounds D-19)
- `scripts/ci/snapshot-recapture-gate.sh`, `scripts/ci/snapshot-canary-guard.sh` — the bash-orchestrator-
  over-Playwright pattern (D-01) + the `--base` ref consumers (D-10)
- `.github/workflows/ci.yml` — the shared `id: base` step (~L66, needs the merge-base fix D-10), the
  `fast_checks` deterministic lane (~L58–116) where new guards attach, the 5 required checks
- `test/example/priv/playwright/playwright.config.ts` — add an `admin-eval` project; inherit determinism
  config (D-03)
- `test/example/priv/playwright/tests/admin-design.spec.ts` — sibling spec; reusable card-in-card check
  (349–361), `waitForLiveViewReady` font-gate, `data-sg-*-audit-only` suppression precedent
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — the `/admin/_design` gallery that
  already renders every board × light/dark/mobile × populated/zero/loading/error
- `test/example/priv/static/assets/sigra_admin.css` — the real `--sg-*` scale + the `box-shadow` focus
  ring at ~line 449 (grounds D-12/D-13); `brandbook/tokens.css` + `brandbook/brand-book.md` (ember
  reservation for D-14, brand motifs)
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`,
  `prompts/elixir-opensource-libs-best-practices-deep-research.md` — house CI/DX idiom

**External precedent surfaced in research (for the planner/researcher, not repo files):** betterer,
ESLint bulk-suppressions, SonarQube new-code reference-branch, type-coverage `--at-least`, Playwright
test-snapshots + ARIA-snapshots, Storybook test-runner, reg-suit/Chromatic/Percy/BackstopJS/loki artifact
models, axe-core `target-size` (WCAG-2.2), WCAG 2.5.8 / 2.4.13, Awwwards weighted sub-scores, Lighthouse
0–100 bands, CMMI/DORA/Nielsen ordinal maturity. `actions/checkout#468` (mtime clobber).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`/admin/_design` gallery** (`design_gallery_live.ex`, ~1407 lines) already enumerates every component
  board (`board-stat`…`board-audit_row`), the 11 MG group boards, 4 cfg composites, AND populated/zero/
  loading/error states via `data-testid="mg-N-{populated,zero,loading,error}"`. **The render matrix
  already exists — it just isn't captured as a bundle.**
- **`quality-ledger-monotonic.sh` + `.test.sh`** — the exact guard idiom (git-base-ref diff, awk parse,
  associative-array compare, skip-on-empty-base, hermetic self-test) to clone for the findings guard.
- **`snapshot-recapture-gate.sh`** — the thin bash orchestrator over Playwright projects to clone for the
  harness entrypoint.
- **`admin-design.spec.ts`** — card-in-card check (349–361, lift verbatim), `waitForLiveViewReady`
  font-gate, `data-sg-card-nesting-audit-only` suppression convention, existing `getComputedStyle` usage.
- **`@axe-core/playwright`** already in `test/example/priv/playwright/package.json`.
- **`admin-modal-interaction.spec.ts`** — the modal axe-while-open + 7-APG focus-trap/restore gates cited
  by the user-show pilot cell.

### Established Patterns
- Bash orchestrator over Playwright + single-purpose bash guards per CI step (`scripts/ci/*.sh`), each
  with a `.test.sh`; `git show ${BASE}:file` base-ref diffing; forward-only monotonic ledgers.
- Build-free `--sg-*` token + BEM design system (example is `--no-tailwind`); admin LiveViews are
  library-owned, the example app is the generated host used for browser testing.
- CI-native (ubuntu) rendering for anything pixel/geometry-bearing — never darwin-local recapture.

### Integration Points
- New guards attach to the `fast_checks` deterministic lane in `ci.yml` (never a Playwright/nightly lane
  and never the LLM panel) — preserving the JUDGE-CI-01 invariant.
- The `finding_id` key (D-22) is the contract seam with Phase 217 (AUTOFIX-01 fix queue) — must be
  identical.
- `render_sha256` ledger + settled-findings + award ledger are the committed forward-only signal;
  everything else (bundles, PNGs) is gitignored CI-artifact.
</code_context>

<specifics>
## Specific Ideas

- **Reconciled research divergence (operator-locked "as-is"):** the two research streams split on award
  representation. **Locked toward `admin-award-ledger.json` (D-19)** over a markdown column, because it
  keeps the fragile awk column-4 frozen AND is the only representation that lets the guard enforce
  verify-then-climb (band==min(axes), evidence_ref resolves, verified_at_sha freshness — D-20). The
  markdown-column alternative was explicitly considered and rejected.
- **The CI base-ref merge-base fix (D-10)** was surfaced by research as a latent bug and folded into this
  phase deliberately (operator-approved), because it's foundational to the new down-ratchet guard.
- **Ember accent reserved for the A3/"Award-grade" marker** in any operator-facing readout — on-brand
  (ember = ownership-boundary/selected-state per brand book), motivating, without decorating the ledger.
</specifics>

<deferred>
## Deferred Ideas

- **LLM 4-lens panel, k=3 consensus, auto-fix + auto-revert** → Phase 217 (only the `finding_id` key
  contract + the deterministic substrate land here).
- **Broad elevation across all 8 surfaces + L1/L2 fractal** → Phase 218.
- **A3 award band for the pilots** → deferred unless/until the persona-JTBD panel is re-run at HEAD
  (D-25); pilots cap at A2.
- **Baseline recapture / allowlist reset / canary reconciliation** → Phase 219.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db` (score 0.9, area ci) — tracked as SEED-005
  (CI-PERF); a performance-infra item, not this quality-harness foundation. Not folded.
- `2026-06-19-uat-demo-dx-polish-nits` (UI-01) — folded into **Phase 218** by the ROADMAP, not 216.
- `2026-06-22-vaultr-authed-rebrand-residuals` (UI-02) — folded into **Phase 218** by the ROADMAP, not
  216.
- `2026-06-20-mix-sigra-migrate-schema-helper`, `2026-06-20-runtime-auth-prefix-override`,
  `2026-06-22-white-label-auth-email-theming` — v2 FEAT-01/02/03, out of milestone scope.
- `2026-07-02-app-css-corruption-guard-blind-spot` — general robustness, not this phase.
- `2026-07-03-hex-retire-stray-1-20-0` — Jon-manual release chore, out of roadmap scope.
</deferred>
</content>
</invoke>
