# Phase 192: Ratification & Baseline Lock - Context

**Gathered:** 2026-06-18 (assumptions mode + deep multi-subagent prior-art research)
**Status:** Ready for planning

<domain>
## Phase Boundary

The **GATE** phase — the TERMINAL idempotency gate of the v1.39 DS-COHERENCE fractal
program (L0 tokens → L1 components → L2 groups → L3 pages → L4 flows → COPY →
**ratification & baseline lock**). This phase **proves the milestone holds forward-only**;
it is NOT a redesign, re-audit, or feature build. Scope is the existing admin design-system
quality harness — Playwright baselines (`admin-checkpoints` + `admin-design` lanes × 3
projects), the byte-golden component suite, the two snapshot allowlists, both canaries, the
quality ledger, the monotonic guard, and the generated-host parity smoke.

Delivers three requirements:
- **GATE-01** — all baselines (admin checkpoints + gallery boards) are verified idempotent via
  the recapture harness; both allowlists are at steady-state empty; both canaries are green.
  **Reinterpreted (D-04):** "deliberately recapture all baselines" → "deliberately **re-render
  and prove zero-drift idempotency** + canary/allowlist invariants" (a force-recapture is
  self-contradictory for an idempotent system — see decisions).
- **GATE-02** — generated-host parity is proven (`RUN_PARITY=1`, **proof-by-CI** pinned to the
  head SHA), full-surface axe is clean (**widened to WCAG 2.1/2.2 AA**), and the byte-golden
  component suite is green.
- **GATE-03** — the final quality ledger records the achieved tier per item (**locked at the
  already-achieved Tier 1 — no Tier-2 promotion**), and the monotonic guard is green versus
  `origin/main` (forward-only proven so a re-run starts from "current = ratified").

Success (ROADMAP): all baselines ratified + both canaries green; allowlists empty;
generated-host parity proven; final ledger records achieved tier per item; monotonic guard
green vs origin/main.

**OUT of scope:** any net-new admin surface, component, token, or copy change; Tier-2
"award-grade" promotion of any ledger cell (a future, separately-earned milestone);
byte-level rasterization parity (Docker/font pinning — a real infra project, backlogged);
fixing the 3 known pre-existing v1.39 failures (they are carved out, not remediated here).
</domain>

<decisions>
## Implementation Decisions

### A. Ledger tier policy — LOCK at Tier 1, never promote to Tier 2 (GATE-03)
- **D-01:** Phase 192 **locks every ledger cell at the tier each phase already achieved (all
  ~35 cells at Tier 1 / "Ratified")** and does NOT promote any item to Tier 2 / "Award-grade."
  The terminal gate *proves forward-only*, it does not declare new quality. Rationale: GATE-03's
  own wording is "records the **achieved** tier" + "re-run starts from **current = ratified**"
  (`REQUIREMENTS.md:84`, `ROADMAP.md` Phase 192 success). The monotonic guard
  (`scripts/ci/quality-ledger-monotonic.sh`) protects whatever tier is written **forever**
  (it forbids decreases). Tier 2 is defined **subjectively** (`admin-quality-ledger.md:12` —
  "emilkowal.ski-level micro-interaction quality… delightful in detail"); encoding a subjective
  verdict in a monotonic CI ratchet is the single documented anti-pattern across every
  comparable system (Codecov, ESLint suppressions, betterer, RuboCop TODO, Figma strict-migration
  all ratchet **objective, deterministic quantities** — never aesthetic judgment). A premature
  "2" with no test behind it is an irreversible false-confidence claim. Idiomatic Elixir agrees:
  the ecosystem has **no** subjective-quality ratchets — only objective binary gates
  (`format`/`credo --strict`/`dialyzer`/`test`), per
  `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`.
- **D-02:** Tier 2 remains available as a **future, separately-earned** milestone. The correct
  way to earn it later is to **decompose "award-grade" into objective proxies and ratchet those**
  (transition-token coverage, reduced-motion coverage, focus-visible presence, contrast ratios,
  CLS/Lighthouse thresholds) + the existing visual-regression snapshots, while the taste verdict
  stays a human review (Danger/reviewdog model) — **never a build-failing monotonic integer**.
  Record this as the deferred path; do not act on it now.

### B. Baseline lock — compare-mode zero-drift, NOT force-recapture (GATE-01)
- **D-03:** The terminal lock runs the admin baselines in **plain compare mode (no
  `--update-snapshots`)** and treats "**re-render changes nothing**" as the idempotency success
  signal. Do **not** use `--require-all`; do **not** commit any new PNG bytes; do **not** invoke
  `scripts/ci/snapshot-recapture-gate.sh` for the lock (it is a *change*-tool — it requires
  intended slugs and runs `--require-all`, which is self-contradictory for an unchanged system:
  an idempotent re-render produces no delta, so "every declared slug must change" fails by
  construction — the exact paradox the research dissolved). This matches the mature
  ApprovalTests/Chromatic/jest-`--ci` pattern: never force-rewrite goldens at a lock gate.
- **D-04:** Reinterpret GATE-01 (confirmed with maintainer). "Deliberately recapture ALL
  baselines + reset allowlists to empty" → "**deliberately re-render and prove zero-drift
  idempotency + canary/allowlist invariants**." The allowlists are **already** at steady-state
  empty (comments only) — that empty state is what we *lock and prove*, not a step to perform.
  **Update the GATE-01 phrasing in `REQUIREMENTS.md`** to match this idempotency intent so the
  requirement is no longer literally contradictory.
- **D-05:** The concrete GATE-01 proof is a five-clause invariant assertion, each independently
  re-runnable:
  1. **No regression** — all 6 admin screenshot projects
     (`admin-checkpoints-{chromium,mobile,dark}` + `admin-design-{chromium,mobile,dark}`) pass
     in plain compare mode against committed baselines under CI tolerances.
  2. **Zero drift committed** — `git status --porcelain` over both `*-snapshots/` dirs shows
     **no modified/untracked PNGs** (compare mode never writes baselines).
  3. **Canaries live + byte-green** — `impersonation-banner` (checkpoints) and `board-notice`
     (design) unchanged at the byte level, and **neither canary slug appears in either
     allowlist** (verified by grep).
  4. **Allowlists at steady state** — both `snapshot-allowlist` and `snapshot-allowlist-design`
     are comments-only; `snapshot-canary-guard.sh --base origin/main` (NO `--require-all`, NO
     slug args) reports `PASS (0 changed slug(s))` for each lane.
  5. **Byte-goldens locked** — `mix test test/sigra/admin/components_test.exs` green (the one
     truly byte-exact, idempotent layer — text, no rasterization).
- **D-06 (caveat, recorded not acted on):** "Lock" currently means "within CI tolerance"
  (`admin-checkpoints.spec.ts:143-147` — `maxDiffPixels: 200_000`, `maxDiffPixelRatio: 0.22`),
  NOT byte-reproducible, because baselines are authored on macOS and compared on Linux CI with
  **no font/raster pinning**. Closing that honestly requires **Docker/font rasterization parity**
  (capture+compare in the pinned `mcr.microsoft.com/playwright` image with pinned fonts), after
  which tolerances can be tightened. This is a real infra project → **v1.40 backlog**, not
  terminal-gate work. The plan must NOT attempt it; the verification narrative must state the
  proof is within-tolerance idempotency + invariant integrity, not byte-reproducibility.

### C. Full-surface axe — widen to WCAG 2.1/2.2 AA (GATE-02)
- **D-07:** Widen the axe tag set in **both** `assertNoAxeViolations` helpers
  (`admin-checkpoints.spec.ts:120-122` full-page, `admin-design.spec.ts:53` element-scoped) from
  `['wcag2a','wcag2aa']` to **`['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']`**. This adds
  exactly **5 rules** (`target-size` 2.5.8, `autocomplete-valid` 1.3.5,
  `label-content-name-mismatch` 2.5.3, `avoid-inline-spacing` 1.4.12, `css-orientation-lock`
  1.3.4) at **zero new infra** (axe-core 4.11.3 already supports them), making "full-surface axe
  is clean" literally defensible against the modern legal floor (WCAG 2.2 AA — EN 301 549,
  GOV.UK/DWP gate there).
- **D-08:** If `target-size` (or any new rule) fires on **intentionally dense** admin controls
  the design contract accepts, suppress **only that single rule** with a documented
  `.disableRules(['target-size'])` + an inline comment citing the contract — do **NOT** drop the
  2.2 tag wholesale, and do NOT silently absorb it. Any other new finding is a real bug to fix in
  this phase (the gate doing its job).
- **D-09:** Do **NOT** gate on the `best-practice` tag (≈30 page-structure rules dominated by
  landmark/`region`/heading-order — the exact false-positive class for component-isolation
  boards; not WCAG-required; no serious design system gates on it). Keep the existing `region`
  exclusion (it's `best-practice`-only and standard for component isolation — Storybook disables
  it by default). Do **NOT** add whole-page axe on live admin routes beyond the 7 curated
  checkpoints (broad-crawl scope creep the `admin-ui-principles.md:56` testing standard warns
  against). Hover/focus-visible/reduced-motion stay in the interaction + screenshot lanes (not
  axe-testable) — already covered, not a gap.

### D. Generated-host parity — proof-by-CI pinned to head SHA (GATE-02)
- **D-10:** GATE-02 parity is proven by **citing the green `admin-acceptance` CI run for the
  current commit** — `gh run list --workflow ci.yml --branch <branch> --commit $(git rev-parse
  HEAD) --json name,conclusion --jq '.[]|select(.name=="admin-acceptance").conclusion'` must read
  `success`. Local proof = the **fast text layer only** (`mix test --only golden` /
  `golden_diff_test.exs`) + `bash -n scripts/ci/admin-acceptance-smoke.sh`. Do **NOT** require a
  full local `RUN_PARITY=1` scaffold-boot (20-min phx.new + Postgres + Playwright). Rationale:
  every mature generator (phx.gen.auth, igniter, Rails, CRA, cookiecutter) gates fast text-goldens
  locally and slow scaffold-boot in CI; Sigra's own history (`reference_example_js_bundle_drift`,
  `reference_installer_template_drift`) shows **CI is the env that catches generated-host drift**,
  not the laptop. A full local run is a *fallback only* if the CI lane is red/skipped.

### E. Known pre-existing failures — executable quarantine, not silent exclude (GATE-02/03)
- **D-11:** The **3 known pre-existing v1.39 failures** (carved out as NON-regressions per
  `191-VERIFICATION.md:108-111` and memory `reference_v139_known_pretest_failures`) get an
  **executable quarantine**, not prose:
  1. `test/sigra/install/golden_diff_test.exs` — installer/template golden-tree diff
  2. `test/sigra/install/vault_promotion_test.exs` — installer/template lane
  3. `admin-design.spec.ts` MG-5/6 content-equivalence — data-dependent pagination (needs 25+
     audit events; from Phase 188)
  Pattern: tag the ExUnit two with a greppable
  `@moduletag known_failure: "<reason>; reproduces on origin/main; tracked: <todo path>"`; mark
  the Playwright MG-5/6 case with `test.fail(reason)` (the JS strict-xfail analog). The terminal
  gate runs the suite **`--exclude known_failure` (blocking, must be green)** AND runs the tagged
  tests in a **separate non-blocking but REPORTED quarantine lane** (`mix test --only
  known_failure || echo "KNOWN-FAILURE LANE…"`) — the Google/Spotify "report-don't-block" model.
- **D-12:** Add a **self-healing contract test** (model on
  `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs`) asserting **exactly these 3
  known failures exist and each is still red** — if any starts *passing*, the gate goes red and
  forces removing the tag (the strict-xfail / RSpec-`pending` property that prevents quarantine
  rot into permanent meaningless green). **Create the 2 missing tracking todos** for the installer
  failures (the MG-5/6 todo already exists:
  `.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md`).
  The quarantine must not silently outlive the milestone — `gsd-complete-milestone` should refuse
  to archive v1.39 while any `known_failure` todo is unresolved + unexpired (record as intent).

### F. Monotonic guard base ref — fetch then `--base origin/main` (GATE-03)
- **D-13:** GATE-03 "forward-only vs origin/main" is proven by
  **`git fetch origin main && bash scripts/ci/quality-ledger-monotonic.sh --base origin/main`**.
  The script defaults to `--base HEAD` (self-referential — wrong for a merge decision); the
  fetch is **mandatory** (otherwise `git show origin/main:<ledger>` reads a stale/missing ref —
  this exact stale-base mistake previously mislabeled branch regressions as "pre-existing", per
  memory `reference_preexisting_mix_test_failures`). The same fetch-then-`--base origin/main`
  discipline applies to the snapshot canary guard when run locally. CI already does this correctly
  (`ci.yml` — `git fetch origin "$base_ref"` then `--base origin/$base_ref`).

### Claude's Discretion
- Whether to add a thin convenience wrapper (e.g. `scripts/ci/terminal-gate.sh`) that does
  fetch + monotonic guard + compare-mode lanes + golden text test + CI-SHA parity citation in one
  re-runnable command (a DX nicety the research suggested) — planner's call; keep it optional and
  non-duplicative of existing scripts.
- Exact wording of the GATE-01 edit in REQUIREMENTS.md (D-04), as long as it removes the
  internal contradiction and preserves the idempotency intent.

### Folded Todos
None folded as new scope. The MG-5/6 todo and the 2 to-be-created installer todos are *referenced*
by the quarantine (D-11/D-12), not folded as feature work.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

Harness scripts (the gate machinery — read before touching):
- `scripts/ci/snapshot-recapture-gate.sh` — change-tool; requires intended slugs + `--require-all`; **NOT used for the lock** (D-03)
- `scripts/ci/snapshot-canary-guard.sh` — `--require-all` semantics, canary-must-never-be-allowlisted, plain-mode "0 changed" pass
- `scripts/ci/quality-ledger-monotonic.sh` — decrease-only guard; default `--base HEAD` must be overridden to `origin/main` (D-13)
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host parity smoke (PORT 4017, scaffolds phx.new + sigra.install + Postgres); proof-by-CI (D-10)

Ledger + contract + principles:
- `guides/reference/admin-quality-ledger.md` — all ~35 cells at Tier 1; Tier 2 subjective (line 12); parsing rules
- `guides/reference/admin-ui-principles.md` — a11y/testing-standard direction (line 32 status-not-by-color, 42-43 light/dark/system, 48 reduced-motion, 56 "curated evidence, axe-paired-with-snapshot")
- `guides/reference/admin-design-contract.md` — design-system contract

Test surfaces:
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (axe tags 120-122; CI tolerances 138-147)
- `test/example/priv/playwright/tests/admin-design.spec.ts` (element-scoped axe 53; MG-5/6 known failure; reduced-motion 535-577; focus 594-625)
- `test/example/priv/playwright/playwright.config.ts` — 6 admin projects; dark = `colorScheme:'dark'`; no font/raster pinning (D-06)
- `test/example/priv/playwright/snapshot-allowlist`, `…/snapshot-allowlist-design` — both steady-state empty; canary-never-listed
- `test/sigra/admin/components_test.exs` — byte-exact component goldens (the one idempotent layer)
- `test/sigra/install/golden_diff_test.exs`, `test/sigra/install/vault_promotion_test.exs` — known failures #1/#2 (D-11)
- `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` — model for the self-healing known-failure contract test (D-12)

Planning context:
- `.planning/ROADMAP.md` — Phase 192 goal + success criteria; v1.39 idempotency model
- `.planning/REQUIREMENTS.md` — GATE-01..03 (line 82-84); GATE-01 to be re-worded per D-04
- `.planning/phases/191-microcopy-ia-sweep/191-VERIFICATION.md:108-111` — documented known-failure carve-out + recapture precedent
- `.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` — existing MG-5/6 tracking todo
- `.github/workflows/ci.yml` — `admin-acceptance` job + correct `git fetch origin` / `origin/$base_ref` pattern
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — idiomatic objective binary gates; "coverage as signal not primary gate"
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
The **entire** gate is pre-built (phases 184-191): `snapshot-recapture-gate.sh` +
`snapshot-canary-guard.sh` + `quality-ledger-monotonic.sh` + `admin-acceptance-smoke.sh`, the
6-project Playwright config, the byte-golden `components_test.exs`, the quality ledger, both
allowlists (already empty), both canaries (`impersonation-banner`, `board-notice`), and the
`phase_51_install_golden_ci_contract_test.exs` contract-test pattern. Phase 192 *operates* this
harness — it builds almost no new code (the only edits are: the axe tag widening D-07, the
known_failure tags + self-healing contract test D-11/D-12, the GATE-01 REQUIREMENTS reword D-04,
and the ledger's final terminal-ratification note).

### Established Patterns
- **Forward-only ratchet** = objective deterministic quantity only (Tier 1 is test-backed; Tier 2
  is subjective → never ratcheted). Mirrors Codecov-patch / ESLint-suppressions discipline.
- **Goldens are never force-rewritten at a lock** (jest `--ci` / ApprovalTests / Chromatic) —
  compare-mode zero-drift is the proof.
- **Component-scoped vs page-scoped axe** split (GOV.UK / Storybook) — element-scoped on boards,
  full-page on the 7 checkpoints; `region` excluded for isolation.
- **Report-don't-block quarantine** for known failures (pytest strict-xfail / Google-Spotify
  quarantine lane) + self-healing count assertion to prevent rot.
- **Generated-host proof split** — fast text-goldens local, slow scaffold-boot in CI
  (phx.gen.auth / igniter / Rails).

### Integration Points
- Both snapshot lanes + canary guard + monotonic guard + admin-acceptance job already wired into
  `.github/workflows/ci.yml` with the correct `origin/$base_ref` base. Phase 192's local
  invocations must replicate the `git fetch origin main && --base origin/main` discipline.
- The axe widening (D-07) touches the two shared `assertNoAxeViolations` helpers — a single edit
  point each, applied across all 3 projects automatically.
- The known_failure tag (D-11) is greppable and excludable suite-wide via `--exclude/--only`.
</code_context>

<specifics>
## Specific Ideas

- Axe tag set, verbatim: `['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']` (D-07).
- Monotonic invocation, verbatim: `git fetch origin main && bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` (D-13).
- Parity proof, verbatim: `gh run list --workflow ci.yml --branch <branch> --commit $(git rev-parse HEAD) --json name,conclusion --jq '.[]|select(.name=="admin-acceptance").conclusion'` → `success` (D-10).
- Mature-pattern anchors the maintainer cited as the bar: ApprovalTests/Chromatic/jest-`--ci`
  (goldens), Codecov-patch/ESLint-suppressions (ratchet), GOV.UK/Storybook (axe), pytest
  strict-xfail / Google-Spotify quarantine (known failures).
</specifics>

<deferred>
## Deferred Ideas

- **Tier-2 "award-grade" promotion** — a future, separately-earned milestone; earn it by
  ratcheting **objective polish proxies** (transition-token coverage, reduced-motion coverage,
  focus-visible presence, contrast ratios, CLS/Lighthouse) + human taste review, never a
  subjective monotonic integer (D-02).
- **Byte-level rasterization parity** — capture+compare admin baselines in the pinned
  `mcr.microsoft.com/playwright` Docker image with pinned fonts, then tighten the 0.22 CI
  tolerance so "lock" means byte-reproducible, not within-22%-tolerance. Real infra project →
  v1.40 backlog (D-06).
- **`scripts/ci/terminal-gate.sh` one-command wrapper** — optional DX nicety (fetch + guard +
  compare lanes + golden + CI-SHA parity citation); planner's discretion, must not duplicate
  existing scripts.
- **`gsd-complete-milestone` quarantine guard** — refuse to archive v1.39 while any
  `known_failure` tracking todo is unresolved + unexpired (D-12 intent).

### Reviewed Todos (not folded)
- `2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` — referenced by the
  MG-5/6 quarantine (D-11), not folded as feature work; stays a deferred data-dependent fix.

[2 new installer-failure tracking todos to be CREATED during execution per D-12 — golden_diff
and vault_promotion — not pre-existing.]
</deferred>
