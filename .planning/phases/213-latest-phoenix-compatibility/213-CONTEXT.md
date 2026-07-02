# Phase 213: Latest-Phoenix Compatibility - Context

**Gathered:** 2026-07-02 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make an adopter's generated host compile clean under `--warnings-as-errors` against the
current `phx.new` (≥1.8.8), reconcile the install golden fixture with 1.8.8 output, and move
CI off the frozen `phx_new 1.8.7` archive. Scope is compatibility/CI plumbing only — no new
auth features, no admin UI changes, no template redesign. Requirements COMPAT-01/02/03.
</domain>

<decisions>
## Implementation Decisions

### A. Button-fix approach — verify, do not re-architect
- **D-01:** No generated-template button re-engineering is planned. Research proved the stock
  `phx.new` `CoreComponents.button/1` is **byte-identical across 1.8.5 / 1.8.7 / 1.8.8**, and
  `type` is a built-in LiveView global (present since LV 1.0.0) — so `<.button type=…>` never
  errored against a stock button. The current Sigra templates already contain **zero**
  `<.button type=…>` callsites (explicit-type buttons use plain `<button type=…>`). The seed's
  `type="submit"` callsite references are stale.
- **D-02:** COMPAT-01 is treated as **verification-first**: the ground-truth gate is a fresh
  `phx.new` (≥1.8.8) + `mix sigra.install` + `mix compile --warnings-as-errors` run via
  `scripts/ci/install-smoke.sh`. If it compiles clean, COMPAT-01 is satisfied with no code change.
- **D-03:** Contingency only — if a real `undefined attribute` error *does* surface, the root
  cause is Sigra-side (a narrowed `:global` in Sigra's own vendored/generated component), and the
  fix is a Sigra-owned button declared in the existing `core/sigra_auth_components.ex` wrapper
  (which already imports into the auth templates). **Do not** patch the host's `core_components.ex`
  — that violates the "own your code / don't patch host files" philosophy. This contingency is not
  expected to trigger.

### B. Golden-fixture reconciliation
- **D-04:** Reconcile by running `MIX_ENV=test mix sigra.fixture.rebless_golden` under a phx.new
  ≥1.8.8 archive and committing the resulting `test/fixtures/install_golden/` delta. No hand-editing
  of fixture bytes.
- **D-05:** The expected, acceptable delta is confined to `config/config.exs`: the new
  `config :phoenix_live_view, root_tag_attribute: "phx-r"` block, the esbuild version bump
  (`4.1.12` → `4.3.0`), and the added esbuild `NODE_PATH` env. If the delta extends beyond
  `config/config.exs` (e.g. touches `core_components.ex`), stop and review — that would signal a
  real host-side drift and re-open Area A.
- **D-06:** Add `mix sigra.fixture.rebless_golden --check` (already exits 2 on drift, see
  `rebless_golden.ex:120-145`) as a dedicated CI drift-detector job, so a future phx.new config
  addition surfaces as an actionable signal rather than an opaque `golden_diff_test` byte failure.

### C. CI pin policy — bump to concrete 1.8.8, do not fully unpin
- **D-07:** Replace `mix archive.install --force hex phx_new 1.8.7` with a concrete
  `phx_new 1.8.8` pin (NOT a fully-floating/unpinned install). Rationale: the entire SEED-004
  incident was caused by an *unpinned* phx.new silently upgrading 1.8.7→1.8.8 and breaking the
  golden fixture; a concrete pin keeps the golden fixture byte-deterministic. The `--check`
  drift-detector (D-06) provides the "tracks current Phoenix" signal by flagging when a newer
  phx.new appears — reconciling COMPAT-03's intent without re-exposing the silent-upgrade failure.
- **D-08:** Update all **11 pin sites**: 9 in `.github/workflows/ci.yml`, 1 in
  `release-please.yml`, 1 in `hex-publish.yml`. Invert/rewrite the CLAUDE.md dev-prereq note
  (currently at CLAUDE.md:210-222) so it instructs installing 1.8.8 locally and drops the
  "don't rebless to fix 1.8.8 drift" warning.
- **D-09:** **Ordering is load-bearing:** rebless the golden fixture (Area B) FIRST, then flip the
  pins (D-07/D-08) atomically. Unpinning/bumping before the rebless turns all golden/install jobs
  red on the config.exs byte-diff.

### D. Test / verification strategy — zero human UAT
- **D-10:** Three existing automated gates, all run against the ≥1.8.8 archive:
  (1) `test/sigra/install/golden_diff_test.exs` — fixture byte-parity;
  (2) `scripts/ci/install-smoke.sh` — the COMPAT-01 `--warnings-as-errors` compile gate;
  (3) `scripts/ci/admin-acceptance-smoke.sh` — generated-host boot + Playwright.
- **D-11:** Assert the resolved phx.new archive version in each smoke script's preamble, so a
  cached 1.8.7 archive on a runner cannot produce a false green that masks the compat gap.

### Claude's Discretion
- Exact wording of the rewritten CLAUDE.md dev-prereq note.
- Whether the `--check` drift-detector is its own CI job or folded into an existing golden lane
  (planner's call based on CI structure).
- Whether to split into one plan or two (rebless+fixture vs pin-flip+docs).

### Folded Todos
None. The Phase-213-adjacent todo matches (Playwright per-shard DB, phase-209/200 review
deferrals, Hex version-ranking, app.css corruption) all belong to **Phase 214 (Debt & Robustness
Clear)**, not this compatibility phase — left for 214.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/seeds/SEED-004-phx-new-button-forward-compat.md` — original diagnosis (note: its
  button-breakage premise is now known to be stale; the config.exs drift + pin removal are the
  real work).
- `lib/mix/tasks/sigra.fixture.rebless_golden.ex` — the golden-fixture regenerator (`--check` mode
  at lines 120-145).
- `test/sigra/install/golden_diff_test.exs` — the byte-diff parity test (`:golden` tagged).
- `test/support/install_fixture.ex` — `setup_tmp_app/0` + `normalize_content_for_golden/2`
  (lines ~385-423).
- `scripts/ci/install-smoke.sh` — COMPAT-01 compile gate (`--warnings-as-errors` at ~line 64).
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host acceptance smoke (COMPAT-03).
- `.github/workflows/ci.yml` (9 pin sites), `.github/workflows/release-please.yml` (1),
  `.github/workflows/hex-publish.yml` (1) — the phx_new archive-install steps.
- `CLAUDE.md:210-222` — the dev-prereq note to rewrite.
- `priv/templates/sigra.install/core/sigra_auth_components.ex` — the existing Sigra-owned
  component wrapper (contingency home for a `sigra_button/1` if D-03 ever triggers).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mix sigra.fixture.rebless_golden` already scaffolds a fresh tmp app, re-normalizes, replaces
  the fixture tree, prints a git-backed delta report, and has a `--check` drift mode — the entire
  Area-B mechanism already exists; the phase runs it, it does not build it.
- `core/sigra_auth_components.ex` already exists and is imported into auth templates
  (`core/login_html.ex:16` etc.), with an `attr :rest, :global` slot — ready to host a
  `sigra_button/1` if ever needed.
- `install-smoke.sh` + `admin-acceptance-smoke.sh` already scaffold via `mix phx.new` and inherit
  the CI-installed archive, so they auto-exercise whatever version the pin resolves to.

### Established Patterns
- Installer templates in `priv/templates/sigra.install/` are canonical; `test/example/` is a
  hand-maintained mirror that drifts behind — verify both when reasoning about generated output
  (installer-template-drift is a known recurring bite).
- Golden fixtures are byte-exact; the workflow is "rebless via the mix task, review the delta,
  commit," never hand-edit fixture bytes.
- Explicit-`type` buttons in templates already use plain lowercase `<button type=…>`; component
  `<.button>` callsites carry only styling/`phx-*`/`data-*`/`name`/`value`/`disabled` attrs.

### Integration Points
- The pin flip (D-07/D-08) touches 3 workflow files + CLAUDE.md and MUST follow the fixture
  rebless (D-09) or every golden/install job goes red.
- The `--check` drift-detector (D-06) is the CI hook that gives the "tracks current Phoenix"
  behavior COMPAT-03 asks for, without a floating archive.
</code_context>

<specifics>
## Specific Ideas

- Confirmed exact 1.8.8 config.exs addition (verbatim block to expect in the reblessed fixture):
  ```elixir
  # Configure LiveView
  config :phoenix_live_view,
    # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
    root_tag_attribute: "phx-r"
  ```
  Plus esbuild `4.1.12` → `4.3.0` and an added `NODE_PATH` env in the esbuild config block.
- Pin target is the concrete string `phx_new 1.8.8` (current latest at time of discussion).
</specifics>

<deferred>
## Deferred Ideas

- Fully-floating/unpinned phx.new archive — rejected (D-07) because it re-exposes the SEED-004
  silent-upgrade failure mode; revisit only if a maintenance policy demands always-latest.
- Sigra-owned `sigra_button/1` component — held in reserve as the D-03 contingency; only build it
  if `install-smoke.sh` actually reports a button compile error under ≥1.8.8.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db` — CI perf, out of scope (Out-of-Scope list).
- `2026-07-01-phase209-code-review-deferred` — Phase 214 (DEBT-02).
- `2026-06-25-phase200-code-review-deferred` — Phase 214 (DEBT-03).
- `2026-06-21-app-css-comment-corruption-cleanup` — Phase 214 (DEBT-05).
- `2026-06-20-runtime-auth-prefix-override`, `2026-06-20-mix-sigra-migrate-schema-helper`,
  `2026-06-22-white-label-auth-email-theming` — v2 FEAT-0x, future feature milestone.
</deferred>
