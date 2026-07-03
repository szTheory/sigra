# Phase 213: Latest-Phoenix Compatibility - Research

**Researched:** 2026-07-02
**Domain:** Elixir/Phoenix generator forward-compat, install golden-fixture reconciliation, CI archive-pin policy
**Confidence:** HIGH (all load-bearing claims verified against the live codebase + empirical `phx.new` 1.8.7-vs-1.8.8 generation this session)

## Summary

This phase is compatibility/CI plumbing only. Three moves: (1) rebless the install golden fixture against `phx.new` ≥1.8.8, (2) flip every `phx_new 1.8.7` archive pin to `1.8.8`, (3) add a `rebless_golden --check` CI drift-detector so a future phx.new config addition surfaces as an actionable signal instead of an opaque byte-diff failure. There is **no auth/UI/template work** — the button-breakage premise in SEED-004 is stale (verified: zero `<.button type=…>` callsites in templates, and `type` is a built-in LiveView global).

The single most important correction to the CONTEXT.md: **the actual reblessed golden delta is a single ~4-line block in `config/config.exs`** — the new `config :phoenix_live_view, root_tag_attribute: "phx-r"` block. D-05's mention of an esbuild/tailwind version bump and a NODE_PATH env line is a **false alarm**: the golden fixture is generated with `mix phx.new --no-assets` (verified at `test/support/install_fixture.ex:15,53`), which strips the esbuild/tailwind config blocks entirely. Those blocks are *not in the fixture*, so their 1.8.8 changes cannot appear in the delta. The `root_tag_attribute` block is LiveView-core and present regardless of `--no-assets`, so it *is* the delta.

Second correction: the "11 pin sites" is accurate for the archive-install commands (9 in `ci.yml` + 1 in `release-please.yml` + 1 in `hex-publish.yml`), but there are **three additional coupled touch-sites the CONTEXT.md did not enumerate**, and one of them is a *hard test assertion that will turn red* when the pin flips. The planner MUST include all of them (see "Complete Touch-Site Inventory").

**Primary recommendation:** Two-plan split honoring D-09 ordering. Plan 1 (rebless-first): run `MIX_ENV=test mix sigra.fixture.rebless_golden` under the 1.8.8 archive, commit the `config/config.exs` `root_tag_attribute` delta, confirm `golden_diff_test` green. Plan 2 (atomic pin-flip + docs + test): flip all 11 archive pins to `1.8.8`, rewrite the 3 doc touch-sites, update the phase-198 DX-contract test's `1.8.7` assertion, add the `--check` drift-detector CI job, and add the D-11 resolved-version assertion to the two smoke scripts.

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** No generated-template button re-engineering. Stock `CoreComponents.button/1` is byte-identical across 1.8.5/1.8.7/1.8.8; `type` is a built-in LiveView global since LV 1.0.0. Sigra templates already contain **zero** `<.button type=…>` callsites. The seed's `type="submit"` references are stale. **[VERIFIED: codebase grep — zero `<.button type=` callsites in `priv/templates/`]**
- **D-02:** COMPAT-01 is verification-first: ground-truth gate is a fresh `phx.new` (≥1.8.8) + `mix sigra.install` + `mix compile --warnings-as-errors` via `scripts/ci/install-smoke.sh`. Compiles clean ⇒ COMPAT-01 satisfied with no code change.
- **D-03:** Contingency only — if a real `undefined attribute` error surfaces, root cause is Sigra-side (a narrowed `:global` in a Sigra vendored/generated component); fix is a Sigra-owned button in `core/sigra_auth_components.ex`. **Do not** patch the host's `core_components.ex`. Not expected to trigger.
- **D-04:** Reconcile the fixture by running `MIX_ENV=test mix sigra.fixture.rebless_golden` under a phx.new ≥1.8.8 archive and committing the `test/fixtures/install_golden/` delta. No hand-editing of fixture bytes.
- **D-05:** Expected delta confined to `config/config.exs`. *(Research refinement: the ONLY delta under `--no-assets` is the `root_tag_attribute` block; the esbuild/tailwind version + NODE_PATH parts of D-05 do not apply because `--no-assets` strips those blocks from the fixture. If the delta extends beyond `config/config.exs`, stop and review.)*
- **D-06:** Add `mix sigra.fixture.rebless_golden --check` (already exits 2 on drift, `rebless_golden.ex:120-145` — **[VERIFIED]**) as a dedicated CI drift-detector.
- **D-07:** Replace `phx_new 1.8.7` with a concrete `phx_new 1.8.8` pin (NOT unpinned). Rationale: unpinned phx.new caused SEED-004. The `--check` detector provides the "tracks current Phoenix" signal.
- **D-08:** Update all 11 pin sites: 9 in `ci.yml`, 1 in `release-please.yml`, 1 in `hex-publish.yml`. Rewrite the CLAUDE.md dev-prereq note (CLAUDE.md:210-222). **[VERIFIED: exact count and line anchors — see inventory below]**
- **D-09:** **Ordering is load-bearing:** rebless the fixture FIRST, then flip the pins atomically. Flipping before rebless turns all golden/install jobs red on the config.exs byte-diff.
- **D-10:** Three existing automated gates run against the ≥1.8.8 archive: (1) `golden_diff_test.exs`, (2) `install-smoke.sh` (the `--warnings-as-errors` gate), (3) `admin-acceptance-smoke.sh`.
- **D-11:** Assert the resolved phx.new archive version in each smoke script's preamble so a cached 1.8.7 archive cannot produce a false green. **[VERIFIED: neither smoke script currently asserts the version — this is net-new]**

### Claude's Discretion
- Exact wording of the rewritten CLAUDE.md dev-prereq note.
- Whether the `--check` drift-detector is its own CI job or folded into an existing golden lane.
- Whether to split into one plan or two (rebless+fixture vs pin-flip+docs).

### Deferred Ideas (OUT OF SCOPE)
- Fully-floating/unpinned phx.new archive — rejected (D-07); re-exposes SEED-004 silent-upgrade.
- Sigra-owned `sigra_button/1` — held as D-03 contingency; build only if `install-smoke.sh` reports a button compile error under ≥1.8.8.
- **All Phase-214 debt** (Playwright per-shard DB, phase-209/200 review deferrals, Hex version-ranking, app.css corruption) — not this phase.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMPAT-01 | Host from current `phx.new` (≥1.8.8) + `mix sigra.install` compiles clean under `--warnings-as-errors` | Verification-first (D-02). Gate = `scripts/ci/install-smoke.sh` (runs `mix compile --warnings-as-errors` at line 64). No code change expected; zero `<.button type=` callsites confirms no button-attr break. |
| COMPAT-02 | Install golden fixture + `golden_diff_test` reconciled with ≥1.8.8 output (`config.exs` `root_tag_attribute` byte-diff absorbed) | Rebless via existing `mix sigra.fixture.rebless_golden` (no build needed). Verified exact delta = single `phoenix_live_view` block. Gate = `test/sigra/install/golden_diff_test.exs`. |
| COMPAT-03 | `phx_new 1.8.7` pin removed from CI + CLAUDE.md; generated-host acceptance smoke green against current `phx.new` | Flip 11 archive pins + 3 coupled doc/test sites to `1.8.8`. `--check` drift-detector (D-06) gives the "tracks current Phoenix" signal. Gate = `scripts/ci/admin-acceptance-smoke.sh`. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Golden fixture regeneration | Build/Test tooling (`lib/mix/tasks/sigra.fixture.rebless_golden.ex`) | — | Fixture is a byte-exact snapshot regenerated by an existing mix task; the phase runs it, does not build it. |
| Byte-parity gate | Test suite (`golden_diff_test.exs`, `:golden` tag) | — | Fails loudly with a Myers diff on first divergent file. |
| Compile-clean gate (COMPAT-01) | CI shell script (`install-smoke.sh`) | — | Scaffolds real `mix phx.new` + `mix sigra.install` + `--warnings-as-errors`; the ground-truth adopter simulation. |
| Generated-host boot gate (COMPAT-03) | CI shell script (`admin-acceptance-smoke.sh`) | — | Boots the generated host + Playwright; proves runtime parity. |
| Archive-pin policy | CI workflow YAML (`ci.yml`, `release-please.yml`, `hex-publish.yml`) | Docs (CLAUDE.md, CONTRIBUTING.md, local-development.md) + DX-contract test | Pin is a build-input; docs and the phase-198 test are contract mirrors of it. |
| Drift detection | CI job (net-new, wraps `rebless_golden --check`) | — | Turns a future silent phx.new config addition into an actionable red signal, not an opaque golden failure. |

## Standard Stack

No new packages. This phase changes CI inputs, one fixture file, docs, and one test assertion. It uses tooling that already exists in-tree.

| Tool | Version | Purpose | Status |
|------|---------|---------|--------|
| `phx_new` (Hex archive) | `1.8.8` (pin target) | Phoenix app generator used by golden fixture + smoke scripts | **[VERIFIED: `mix archive` shows `phx_new-1.8.8` installed locally; `phx_new 1.8.8` is the current pin target per D-07]** |
| `mix sigra.fixture.rebless_golden` | in-tree | Regenerates `test/fixtures/install_golden/`; `--check` mode exits 2 on drift | **[VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `--check` at lines 120-145]** |
| `golden_diff_test.exs` | in-tree (`:golden` tag) | Byte-parity gate | **[VERIFIED: `test/sigra/install/golden_diff_test.exs`]** |

**No `## Package Legitimacy Audit` section** — this phase installs no external packages. The only "package" is the `phx_new` Hex archive, already vetted and in use.

## Complete Touch-Site Inventory

> This is the enumerated, line-anchored map the planner needs. Counts verified this session.

### The 11 archive-install pin sites (D-08) — flip `1.8.7` → `1.8.8`

All are the identical line `run: mix archive.install --force hex phx_new 1.8.7`.

| # | File | Line | Enclosing CI job |
|---|------|------|------------------|
| 1 | `.github/workflows/ci.yml` | 171 | `install_golden_contract` |
| 2 | `.github/workflows/ci.yml` | 233 | `library_tests_shard` |
| 3 | `.github/workflows/ci.yml` | 346 | `library_tests_dep_off` |
| 4 | `.github/workflows/ci.yml` | 497 | `install_smoke` |
| 5 | `.github/workflows/ci.yml` | 558 | `upgrade_smoke` |
| 6 | `.github/workflows/ci.yml` | 610 | `passkeys_manual_fallback_smoke` |
| 7 | `.github/workflows/ci.yml` | 666 | `install_matrix` |
| 8 | `.github/workflows/ci.yml` | 791 | `passkeys_opt_out_smoke` |
| 9 | `.github/workflows/ci.yml` | 1247 | `generated_admin_playwright_smoke` |
| 10 | `.github/workflows/release-please.yml` | 214 | (release-please gate) |
| 11 | `.github/workflows/hex-publish.yml` | 114 | (hex-publish gate) |

**[VERIFIED: `grep -n "phx_new" .github/workflows/*.yml` — exactly these 11 archive-install lines; line numbers may shift ±few if edits reflow, so match on the literal string, not the line number.]**

### Three additional coupled touch-sites NOT in CONTEXT.md's "11" — MUST also be handled

| File | Line(s) | Current content | Action | Why it matters |
|------|---------|-----------------|--------|----------------|
| `CLAUDE.md` | 210-222 | Dev-prereq note: "require the **phx_new 1.8.7** archive … Do **not** regenerate the fixture to 'fix' this — install 1.8.7 instead." | **Rewrite** (D-08): instruct installing **1.8.8**; drop the "don't rebless" warning (the whole premise is inverted once the fixture is reblessed). | Stale instruction actively tells contributors to keep 1.8.7. |
| `CONTRIBUTING.md` | 33-39, 62 | "**phx_new 1.8.7 archive**… install the pinned version… install 1.8.7 to fix." | **Rewrite** to `1.8.8`. | Contract doc; also the target of the phase-198 test below. |
| `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` | 72-80 | `assert contributing =~ "1.8.7", "CONTRIBUTING.md must mention the phx_new 1.8.7 prerequisite"` | **Update assertion to `"1.8.8"`** (title string on line 72 too). | **This test WILL turn red the moment CONTRIBUTING.md drops "1.8.7".** It is a hard byte-assertion. Must be updated in the SAME plan/commit as the CONTRIBUTING.md rewrite or the pin-flip plan goes red. **[VERIFIED: `phase_198_contributor_dx_contract_test.exs:78`]** |

### Two low-priority informational references (verify, likely just prose to refresh)

| File | Line(s) | Note |
|------|---------|------|
| `guides/recipes/local-development.md` | 30 | "the pinned `phx_new` archive — `mix archive.install --force hex phx_new 1.8.7`" — refresh to 1.8.8. |
| `mix.exs` | 141-142 | Comment mentioning "phx_new 1.8.7 archive installed locally" — refresh to 1.8.8. **[VERIFIED: `grep -n phx_new mix.exs`]** |

**[ASSUMED]** The `guides/recipes/local-development.md` and `mix.exs` refs are prose-only (no test asserts them); refreshing them is a cleanliness win, not a gate. Planner should include them to avoid leaving stale 1.8.7 breadcrumbs but they will not turn CI red if missed.

## The Exact Golden Delta (empirically verified this session)

Generated `mix phx.new … --no-assets --no-install --database postgres` under both `phx_new 1.8.7` and `phx_new 1.8.8`, identical flags. The **only** `config/config.exs` difference is a new block inserted between the endpoint config and the mailer config:

```diff
   pubsub_server: App.PubSub,
   live_view: [signing_salt: "<LIVE_VIEW_SALT>"]

+# Configure LiveView
+config :phoenix_live_view,
+  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
+  root_tag_attribute: "phx-r"
+
 # Configure the mailer
```

**[VERIFIED: empirical dual generation 2026-07-02 — `diff` of 1.8.7 vs 1.8.8 `--no-assets` output shows exactly this one added block and nothing else.]**

Why esbuild/tailwind changes do NOT appear (correcting D-05):
- Stock `phx.new` 1.8.8 (WITH assets) also bumps `config :tailwind, version: "4.1.12"` → `"4.3.0"` and adds a `NODE_PATH` env to the **tailwind** block (D-05 mislabeled this as "esbuild 4.1.12→4.3.0"; esbuild stays `0.25.4` in both). **[VERIFIED]**
- BUT the golden fixture is generated with **`mix phx.new --no-assets`** (`test/support/install_fixture.ex:15,53`), which omits the entire `config :esbuild` and `config :tailwind` blocks. The current committed fixture (`test/fixtures/install_golden/tree/config/config.exs`) has neither block — **[VERIFIED: grep found zero esbuild/tailwind/NODE_PATH lines in the fixture tree]**. Therefore those blocks cannot contribute to the delta.
- The `root_tag_attribute` block belongs to `phoenix_live_view` core, is unrelated to assets, and appears even under `--no-assets` — **[VERIFIED: `--no-assets` 1.8.8 generation still contains the block]**.

**Gate for the planner:** after rebless, the ONLY changed fixture file should be `test/fixtures/install_golden/tree/config/config.exs` (plus possibly `STDOUT.txt` if install output text shifted — spot-check). If the delta touches `core_components.ex`, any `.heex`, or adds esbuild/tailwind blocks, **stop and review** — that signals a flag drift or a real host-side change and re-opens Area A (D-05 guard).

## Architecture Patterns

### System Data Flow

```
                    ┌─────────────────────────────────────────────┐
  phx_new 1.8.8 ───▶│ mix phx.new --no-assets  (InstallFixture)    │
  archive (pin)     └─────────────────────┬───────────────────────┘
                                          │ fresh host app
                                          ▼
                    ┌─────────────────────────────────────────────┐
                    │ mix sigra.install  (injector: insert before  │
                    │ import_config — preserves stock blocks)      │
                    └─────────────────────┬───────────────────────┘
                                          │ normalized tree + STDOUT
                          ┌───────────────┴───────────────┐
                          ▼                               ▼
         ┌────────────────────────────┐   ┌──────────────────────────────┐
         │ rebless_golden (writes      │   │ golden_diff_test (:golden)    │
         │ test/fixtures/install_golden│──▶│ byte-parity assert            │
         │  — Plan 1)                  │   │ (Plan 1 gate)                 │
         └────────────────────────────┘   └──────────────────────────────┘
                          │
                          │ --check mode (exits 2 on drift)
                          ▼
         ┌────────────────────────────┐
         │ NEW CI drift-detector job   │  ◀── D-06 (Plan 2)
         │ (tmp dir, never writes repo)│
         └────────────────────────────┘

  Parallel COMPAT-01/03 gates (full assets, compile+boot only, no byte-diff):
    install-smoke.sh ──▶ mix compile --warnings-as-errors   (COMPAT-01)
    admin-acceptance-smoke.sh ──▶ boot generated host + Playwright  (COMPAT-03)
    Both inherit whatever archive the CI pin resolves to; add D-11 version-assert preamble.
```

### Pattern 1: Rebless-then-flip ordering (D-09, load-bearing)
**What:** Regenerate + commit the golden fixture under 1.8.8 BEFORE flipping any CI pin.
**Why:** Every golden/install CI job diffs generated output against the committed fixture. If a pin resolves to 1.8.8 while the fixture is still the 1.8.7 snapshot, the `root_tag_attribute` block appears in generated output but not the fixture → byte-diff → red across `install_golden_contract` and every install job. Reblessing first makes the fixture already contain the block, so the flip is a no-op for byte-parity.
**Sequence:**
1. Ensure local archive is `phx_new 1.8.8` (`mix archive.install --force hex phx_new 1.8.8`).
2. `MIX_ENV=test mix sigra.fixture.rebless_golden` → review delta (expect only the config.exs block).
3. `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs` → green.
4. Commit the fixture. (End of Plan 1.)
5. Flip 11 pins + 3 coupled doc/test sites + add `--check` job + D-11 asserts atomically. (Plan 2.)

### Pattern 2: Concrete pin, not floating (D-07)
**What:** Pin `phx_new 1.8.8`, not an unpinned `mix archive.install hex phx_new`.
**Why:** SEED-004 root cause was an unpinned archive silently upgrading 1.8.7→1.8.8 and breaking byte-parity. A concrete pin keeps the fixture deterministic; the `--check` drift-detector provides the "tracks current Phoenix" signal without re-exposing the silent-upgrade failure.

### Anti-Patterns to Avoid
- **Hand-editing fixture bytes.** Always rebless via the mix task, review `git diff test/fixtures/install_golden/`, then commit (established pattern; `golden_diff_test` is byte-exact).
- **Patching the host's `core_components.ex`** (violates "own your code"; D-03 contingency lives in `core/sigra_auth_components.ex` only, and is not expected to trigger).
- **Flipping pins before reblessing** (D-09 violation → red CI).
- **Rewriting CONTRIBUTING.md's "1.8.7" without updating the phase-198 test** → the test asserts the literal string and goes red.
- **Fully unpinning phx.new** (D-07 rejected).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Regenerate the golden fixture | A bespoke iex runbook / manual copy | `mix sigra.fixture.rebless_golden` | Already scaffolds a tmp app, normalizes, replaces the tree, and prints a git-backed delta report. **[VERIFIED]** |
| Detect future phx.new config drift | A custom diff script in CI | `mix sigra.fixture.rebless_golden --check` (exits 2) | Already implemented; writes to tmp, never touches the repo, exits 2 on drift. **[VERIFIED: `rebless_golden.ex:120-145`]** |
| Prove COMPAT-01 compile-clean | A new minimal repro harness | `scripts/ci/install-smoke.sh` | Already runs `mix phx.new` + `sigra.install` + `mix compile --warnings-as-errors` (line 64) + the oauth generator contract. **[VERIFIED]** |
| Prove generated-host boot parity | A new e2e scaffold | `scripts/ci/admin-acceptance-smoke.sh` | Already scaffolds phx.new + sigra.install + boot + Playwright. **[VERIFIED]** |

**Key insight:** Every mechanism this phase needs already exists. The phase *invokes and re-points* existing tooling; it does not build new tooling except the thin `--check` CI job wrapper (D-06) and a version-assert preamble (D-11).

## Runtime State Inventory

> This is a CI-config + fixture + docs change, not a data/service rename. Categories checked explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no databases, collections, or datastores reference "1.8.7" as a key. Verified: only file-level string references exist. | None |
| Live service config | GitHub Actions workflow YAML is the only "service config," and it lives in git (the 11 pin sites). No UI/DB-resident config (no Datadog/Tailscale/etc. references this pin). | Edit the 3 workflow files |
| OS-registered state | None — no Task Scheduler / launchd / systemd / pm2 registration embeds the archive version. The archive is installed fresh per CI run via `mix archive.install`. **Caveat:** a *cached* 1.8.7 archive on a self-hosted/reused runner could mask the flip — this is exactly what D-11's version-assert defends against. | Add D-11 version-assert to smoke scripts |
| Secrets/env vars | None — no secret or env var names reference the phx.new version. | None |
| Build artifacts | The developer's **local `~/.mix/archives/phx_new-1.8.x`** is machine-state, not repo state. Locally the archive is already `1.8.8` (so `golden_diff_test` currently FAILS locally against the still-1.8.7 fixture — the live SEED-004 symptom). The committed fixture itself is the only repo build-artifact that carries the old-version shape. | Rebless the fixture (Plan 1); note the local-archive step in CLAUDE.md |

## Common Pitfalls

### Pitfall 1: Flipping pins before reblessing (D-09)
**What goes wrong:** `install_golden_contract` + all install jobs go red on the config.exs byte-diff.
**Why:** Generated output gains `root_tag_attribute`; the committed fixture lacks it.
**How to avoid:** Strict ordering — rebless + commit fixture first (Plan 1), flip pins second (Plan 2).
**Warning signs:** A red `install_golden_contract` job whose diff shows `+ config :phoenix_live_view` — that's the ordering violation, not a real drift.

### Pitfall 2: The phase-198 DX-contract test regression
**What goes wrong:** After rewriting CONTRIBUTING.md to say "1.8.8", `phase_198_contributor_dx_contract_test.exs:78` (`assert contributing =~ "1.8.7"`) flunks.
**Why:** It's a literal-string byte assertion.
**How to avoid:** Update the assertion and the test title (lines 72, 78) to `"1.8.8"` in the same commit as the CONTRIBUTING.md rewrite.
**Warning signs:** Red `library_tests_shard` / fast planning lane with "CONTRIBUTING.md must mention the phx_new 1.8.7 prerequisite".

### Pitfall 3: Assuming the delta includes esbuild/tailwind (D-05 over-scope)
**What goes wrong:** Planner adds tasks to reconcile esbuild/tailwind version bumps that never appear, or panics when they're absent from the delta.
**Why:** The fixture uses `--no-assets`; those blocks are stripped. Only `root_tag_attribute` changes.
**How to avoid:** Expect a single-block, single-file (`config/config.exs`) delta. Treat anything larger as a stop-and-review signal (which is the correct D-05 guard behavior).
**Warning signs:** A rebless delta touching `assets/`, esbuild/tailwind config, or `core_components.ex`.

### Pitfall 4: A cached 1.8.7 archive producing a false green (D-11)
**What goes wrong:** A reused/self-hosted runner (or a Dependabot-suppressed cache) keeps a stale 1.8.7 archive; smoke scripts pass against 1.8.7 output, masking the compat gap.
**Why:** `install-smoke.sh` and `admin-acceptance-smoke.sh` inherit whatever archive is present and do not assert its version. **[VERIFIED: neither script asserts a version]**
**How to avoid:** Add a preamble to both scripts asserting the resolved `mix phx.new --version` (or the archive listed by `mix archive`) equals the expected `1.8.8`, failing fast otherwise.
**Warning signs:** A green smoke job whose generated app lacks the `root_tag_attribute` block.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Freeze at `phx_new 1.8.7`, block reblessing | Rebless to `1.8.8`, concrete pin + `--check` drift-detector | This phase | Adopters on latest `phx.new` unblocked; CI surfaces future phx.new config additions actionably. |
| `<.button type=…>` assumed to break on 1.8.8 (SEED-004 premise) | Known non-issue: `type` is a built-in LV global; templates use plain `<button type=…>` for explicit types | Established pre-phase (D-01) | No template/button work; scope shrinks to config + CI. |
| esbuild/tailwind assumed part of the delta (D-05) | Only `root_tag_attribute` (fixture is `--no-assets`) | This research | Delta is a single ~4-line block; smaller/cleaner than anticipated. |

**Deprecated/outdated:**
- The CLAUDE.md:210-222 and CONTRIBUTING.md:33-39 "install 1.8.7 / do not rebless" instructions — inverted by this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `guides/recipes/local-development.md:30` and `mix.exs:141-142` are prose-only refs with no test asserting them | Complete Touch-Site Inventory | Low — if a test does assert them, it surfaces as a red lane and the planner adds the update; no silent failure. |
| A2 | Reblessing under 1.8.8 changes only `config/config.exs` (and possibly `STDOUT.txt` text) — no other fixture files | The Exact Golden Delta | Medium — mitigated by the D-05 stop-and-review guard and by running the rebless in Plan 1 before any pin flip; a larger delta is caught at rebless time, not in prod. |
| A3 | `1.8.8` is the correct pin target (current latest at planning time) | Standard Stack / D-07 | Low — if a newer patch (e.g. 1.8.9) exists at execution time, the planner should pin to the then-current concrete version and rebless against it; the `--check` job will flag any subsequent drift. Confirm current latest with `mix hex.info phx_new` at execution time. |

**Note on A3:** The local archive is confirmed `1.8.8` and CONTEXT.md's specifics fix `1.8.8` as the target, but the planner should re-confirm `1.8.8` is still current-latest (`mix hex.info phx_new`) when executing, and if a newer patch shipped, pin to *that* concrete version and rebless against it (the process is identical).

## Open Questions

1. **Should the `--check` drift-detector be `continue-on-error` (advisory) or a hard gate?**
   - What we know: D-06 wants it as a signal that "tracks current Phoenix" without re-exposing silent upgrade. `--check` runs against the *current* pinned archive, so with a concrete pin it will normally pass; it only trips if the committed fixture drifts from what the pinned archive generates.
   - What's unclear: whether it should also run against *latest* phx.new (advisory) to proactively flag "a newer phx.new would change the fixture."
   - Recommendation: Make the pinned-archive `--check` a **hard gate** (fast, deterministic — catches an un-reblessed fixture). Optionally add a *second, advisory* (`continue-on-error: true`) job that installs latest phx.new and runs `--check` to surface "newer Phoenix would drift" as a non-blocking notice. Planner's call per D-06 discretion; a single hard-gate job satisfies the requirement.

2. **One plan or two?**
   - Recommendation: **Two plans** for clean D-09 ordering and reviewable commits — Plan 1 = rebless + fixture commit + golden_diff_test green; Plan 2 = atomic pin-flip (11) + doc rewrites (3) + phase-198 test assertion + `--check` CI job + D-11 smoke asserts. This makes the load-bearing ordering explicit in the plan graph (Plan 2 depends on Plan 1).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `phx_new` Hex archive | Rebless + smoke scripts | ✓ (local) | `1.8.8` | — |
| Elixir | All mix tasks | ✓ | 1.19.5 | — |
| Erlang/OTP | Runtime | ✓ | 28 (erts-16.3) | — |
| Live PostgreSQL | `golden_diff_test` install run + smoke scripts | Assumed per CLAUDE.md dev-prereq (`scripts/db/up.sh`) | — | Dockerized ephemeral PG (`scripts/db/up.sh`) |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** PostgreSQL for the install run — covered by `scripts/db/up.sh` (ephemeral dynamic-port PG) per CLAUDE.md.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5) + shell CI smoke scripts + GitHub Actions |
| Config file | `mix.exs` (`aliases/0` `ci:`), `.github/workflows/ci.yml` |
| Quick run command | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs` |
| Full suite command | `mix ci` (the local PR-gate mirror) + `scripts/ci/install-smoke.sh` + `scripts/ci/admin-acceptance-smoke.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMPAT-01 | Generated host compiles clean under `--warnings-as-errors` on ≥1.8.8 | integration/smoke | `GITHUB_WORKSPACE=$(pwd) scripts/ci/install-smoke.sh` (compile gate at line 64) | ✅ |
| COMPAT-02 | Golden fixture byte-parity with ≥1.8.8 output | integration | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs` | ✅ (fixture reblessed in Plan 1) |
| COMPAT-02 | Fixture stays in sync (drift-detector) | drift-check | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` (exits 2 on drift) | ✅ task; ❌ CI job (Wave 0 — new job, D-06) |
| COMPAT-03 | No `1.8.7` pin remains; generated-host boots green on current phx.new | integration/smoke | `scripts/ci/admin-acceptance-smoke.sh` + `grep -r "1.8.7" .github/ CLAUDE.md CONTRIBUTING.md` returns nothing | ✅ |
| COMPAT-03 | Contributor DX contract reflects 1.8.8 | unit | `MIX_ENV=test mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs` (after assertion update) | ✅ (assertion updated in Plan 2) |
| COMPAT-01/03 | Cached 1.8.7 archive cannot false-green | smoke preamble | version-assert in `install-smoke.sh` + `admin-acceptance-smoke.sh` | ❌ Wave 0 (add per D-11) |

### Sampling Rate
- **Per task commit:** `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs` (Plan 1); `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs` (Plan 2 test-assertion task).
- **Per wave merge:** `mix ci` locally; the two smoke scripts if PG available.
- **Phase gate:** Full CI green on the branch (all 9 ci.yml jobs + release-please + hex-publish resolve `1.8.8`), plus the new `--check` drift-detector green.

### Wave 0 Gaps
- [ ] New CI job wrapping `mix sigra.fixture.rebless_golden --check` (D-06) — add to `ci.yml` (own job or folded into `install_golden_contract`; discretion).
- [ ] Version-assert preamble in `scripts/ci/install-smoke.sh` and `scripts/ci/admin-acceptance-smoke.sh` (D-11) — assert resolved phx.new == `1.8.8`, fail fast otherwise.
- [ ] `phase_198_contributor_dx_contract_test.exs` assertion update (`1.8.7` → `1.8.8`) — must land with the CONTRIBUTING.md rewrite.

*(No net-new product test files needed; the existing gates cover all three requirements once reblessed + repointed.)*

## Security Domain

> `security_enforcement` is absent from `.planning/config.json` (treat as enabled), but this phase touches no authentication, session, crypto, or input-validation surface — it changes CI inputs, one config-fixture, docs, and one test assertion.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |
| V14 Configuration | **yes (supply-chain hygiene)** | Concrete, pinned `phx_new 1.8.8` (not floating) — mitigates the SEED-004 silent-upgrade class; `--check` drift-detector adds change-visibility. |

### Known Threat Patterns for this change
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Silent generator-version upgrade changing generated bytes undetected | Tampering / supply-chain | Concrete version pin (D-07) + `--check` drift-detector (D-06) + smoke version-assert (D-11). |
| Cached/stale toolchain producing a false-green gate | Repudiation (of a real gap) | D-11 resolved-version assertion in smoke preambles. |

No new attack surface introduced. The net security posture *improves* (explicit pin + drift visibility).

## Sources

### Primary (HIGH confidence)
- Live codebase (this session): `lib/mix/tasks/sigra.fixture.rebless_golden.ex` (`--check` at 120-145), `test/sigra/install/golden_diff_test.exs`, `test/support/install_fixture.ex` (`--no-assets` at 15,53; baseline-diff at 360-368), `lib/sigra/install/injector.ex` (insert-before-`import_config` at 50-63), `test/fixtures/install_golden/tree/config/config.exs`, `test/sigra/planning/phase_198_contributor_dx_contract_test.exs:72-80`, `scripts/ci/install-smoke.sh`, `scripts/ci/admin-acceptance-smoke.sh`.
- Empirical dual generation (this session): `mix phx.new --no-assets --no-install --database postgres` under `phx_new 1.8.7` vs `1.8.8`, `diff` confirming the single `root_tag_attribute` block delta; full-assets 1.8.8 confirming the (irrelevant) tailwind `4.1.12→4.3.0` + NODE_PATH change.
- `grep -n "phx_new" .github/workflows/*.yml` — the 11 pin sites + job mapping.
- `.planning/phases/213-latest-phoenix-compatibility/213-CONTEXT.md` (assumptions-mode decisions D-01..D-11).
- `.planning/REQUIREMENTS.md` (COMPAT-01/02/03), `CLAUDE.md:210-222` (dev-prereq note + confirming the `root_tag_attribute` delta).

### Secondary (MEDIUM confidence)
- `.planning/config.json` (workflow flags: `nyquist_validation: true`, `security_enforcement` absent ⇒ enabled).

### Tertiary (LOW confidence)
- None load-bearing. (A3 pin-currency should be re-confirmed at execution time via `mix hex.info phx_new`.)

## Metadata

**Confidence breakdown:**
- Touch-site inventory: HIGH — every pin site and coupled doc/test site grepped and line-anchored this session; the phase-198 test coupling verified directly.
- Golden delta: HIGH — empirically generated under both archive versions with identical flags; single-block delta reproduced.
- D-05 correction (no esbuild/tailwind in delta): HIGH — verified `--no-assets` strips those blocks and the fixture contains none.
- Tooling reuse (rebless/`--check`/smoke): HIGH — all read directly from source.
- Pin-target currency: MEDIUM — `1.8.8` confirmed locally + in CONTEXT.md; re-confirm current-latest at execution (A3).

**Research date:** 2026-07-02
**Valid until:** 2026-08-01 (stable; the only volatile input is the current-latest `phx_new` patch version — re-check at execution).
