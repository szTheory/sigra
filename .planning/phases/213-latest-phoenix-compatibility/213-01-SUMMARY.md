---
phase: 213-latest-phoenix-compatibility
plan: "01"
subsystem: install-golden-fixture
tags: [compat, golden-fixture, phx-new-1.8.8, install-smoke]
dependency_graph:
  requires: []
  provides: [golden-fixture-reblessed-1.8.8, compat-01-verified, compat-02-verified]
  affects: [test/fixtures/install_golden/]
tech_stack:
  added: []
  patterns: [rebless-via-mix-task, verification-first]
key_files:
  created: []
  modified:
    - test/fixtures/install_golden/tree/config/config.exs
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/application.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/layouts.ex
decisions:
  - "phx.new 1.8.8 is the pin target (confirmed current latest via mix hex.info phx_new)"
  - "Delta confined to fixture only — no Sigra source code changes needed for COMPAT-01 or COMPAT-02"
  - "Three fixture files modified: config/config.exs (root_tag_attribute block), application.ex + layouts.ex (hexdocs.pm URL format change hexdocs.pm → subdomain-based)"
  - "HexDocs URL format changes in application.ex and layouts.ex are Phoenix-generated boilerplate changes, not template drift — do not trigger D-05 stop-and-review guard"
metrics:
  duration: "~4 minutes"
  completed: "2026-07-02"
  tasks_completed: 2
  tasks_total: 2
status: complete
---

# Phase 213 Plan 01: Rebless Golden Fixture under phx.new 1.8.8 Summary

Reblessed the install golden fixture under `phx_new 1.8.8` and proved COMPAT-01 (fresh generated host compiles clean under `--warnings-as-errors`) with zero source code changes.

## One-Liner

Reblessed `test/fixtures/install_golden/` against `phx_new 1.8.8` via `mix sigra.fixture.rebless_golden`, absorbing the `root_tag_attribute: "phx-r"` LiveView block in `config.exs` and two HexDocs URL format changes, with `golden_diff_test` (2/2) and `install-smoke.sh` both exiting clean.

## Tasks Completed

| # | Task | Status | Commit | Files |
|---|------|--------|--------|-------|
| 1 | Rebless install golden fixture under phx.new >= 1.8.8 | Done | d5797e91 | 3 fixture files |
| 2 | Prove COMPAT-01 — fresh generated host compiles clean under --warnings-as-errors | Done (verification-only, no commit) | — | 0 files changed |

## phx.new Version Used

**`1.8.8`** — confirmed as pin target via `mix hex.info phx_new` (latest as of 2026-07-02) and confirmed installed via `mix phx.new --version` (prints `Phoenix installer v1.8.8`).

## Reblessed File List

All three files modified by `MIX_ENV=test mix sigra.fixture.rebless_golden`:

| File | Change Type | Description |
|------|------------|-------------|
| `test/fixtures/install_golden/tree/config/config.exs` | Block added | New `config :phoenix_live_view, root_tag_attribute: "phx-r"` block inserted between endpoint config and mailer config |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/application.ex` | URL update | `hexdocs.pm/elixir/Application.html` → `elixir.hexdocs.pm/Application.html` and `hexdocs.pm/elixir/Supervisor.html` → `elixir.hexdocs.pm/Supervisor.html` |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/layouts.ex` | URL update | `hexdocs.pm/phoenix/scopes.html` → `phoenix.hexdocs.pm/scopes.html`, `hexdocs.pm/phoenix/overview.html` → `phoenix.hexdocs.pm/overview.html` |

`STDOUT.txt` did NOT change (install output text is unchanged between 1.8.7 and 1.8.8).

## D-05 Stop-and-Review Guard Assessment

**Guard NOT triggered.** The delta assessment:

- `core_components.ex` — NOT modified
- Any `.heex` file — NOT modified
- `assets/` directory — NOT modified
- `config :esbuild` blocks — NOT added (fixture uses `--no-assets`, which strips esbuild/tailwind blocks)
- `config :tailwind` blocks — NOT added
- `NODE_PATH` env — NOT added

The two additional modified files (`application.ex`, `layouts.ex`) contain only HexDocs.pm URL format changes — Phoenix (not Sigra) updated its boilerplate to use subdomain-based HexDocs URLs (e.g. `hexdocs.pm/elixir/...` → `elixir.hexdocs.pm/...`). These are trivial Phoenix-generated boilerplate changes that do NOT signal host-side template drift or button/component changes. The guard applies to structural template/component drift; URL format changes in comments/links are outside its scope.

## COMPAT-02 Verification (Golden Diff Test)

```
MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs
2 tests, 0 failures
```

Passes with zero byte-diffs against `phx_new 1.8.8` archive.

## COMPAT-01 Verification (Install Smoke)

```
GITHUB_WORKSPACE=$(pwd) scripts/ci/install-smoke.sh
==> install-smoke: done; tmp_app generated + sigra-installed + compiled clean
```

Exit 0. Key steps passed:
- `mix phx.new ... --database postgres` scaffolded under `phx_new 1.8.8`
- `mix sigra.install --yes Accounts User users` installed cleanly
- `mix compile --warnings-as-errors` — NO `undefined attribute "type"` warning, NO other 1.8.8 compile break
- DB created + migrated
- `mix sigra.gen.oauth --providers google,github` + `mix compile --warnings-as-errors` — clean
- OAuth generator contract: all >=11 generated paths + migration + router inject verified

COMPAT-01 is satisfied with **zero code changes** (D-02 verified).

## The Exact Golden Delta

```diff
   pubsub_server: SigraInstallGoldenTmp.PubSub,
   live_view: [signing_salt: "<LIVE_VIEW_SALT>"]

+# Configure LiveView
+config :phoenix_live_view,
+  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
+  root_tag_attribute: "phx-r"
+
 # Configure the mailer
```

This is the single block added to `config.exs` — matches the empirically-verified delta from RESEARCH.md exactly.

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| d5797e91 | feat(213-01) | Rebless install golden fixture under phx.new 1.8.8 |

Task 2 (COMPAT-01 verification) required no file changes — no commit needed.

## Deviations from Plan

### Additional Fixture Files Beyond config.exs

**Finding:** Rebless modified 3 files (`config/config.exs`, `application.ex`, `layouts.ex`) rather than the expected 1 file (`config/config.exs`).

**Root cause:** Phoenix 1.8.8 updated its HexDocs.pm URL format in generated boilerplate. `hexdocs.pm/elixir/...` and `hexdocs.pm/phoenix/...` URLs became `elixir.hexdocs.pm/...` and `phoenix.hexdocs.pm/...`. These changes appear in `application.ex` (2 comment URLs) and `layouts.ex` (1 doc attr URL + 1 href URL).

**Assessment:** Does NOT trigger D-05 stop-and-review guard. The guard targets: `core_components.ex`, `.heex` files, `assets/`, esbuild/tailwind/NODE_PATH config blocks. HexDocs URL format changes in generated boilerplate comments and links are structurally distinct — they carry no Sigra template drift signal.

**Action:** Committed all 3 files as part of the rebless. Fixture now matches 1.8.8 output byte-for-byte across all 3 changed files. `golden_diff_test` passes 2/2.

**Classification:** [Rule 1 - Expected Variation] Anticipated by the plan's COMPAT-02 requirement (fixture byte-parity with 1.8.8 output). The rebless task is specifically designed to capture all 1.8.8 changes and commit them.

## Known Stubs

None — this plan only reblesses the install golden fixture (test artifact). No UI stubs, placeholder data, or wired-but-empty components.

## Threat Flags

None. The `config :phoenix_live_view, root_tag_attribute: "phx-r"` block is a Phoenix-generated LiveView configuration line — no new Sigra network endpoints, auth paths, file access patterns, or schema changes were introduced.

## Self-Check: PASSED

- [x] `test/fixtures/install_golden/tree/config/config.exs` exists and contains `root_tag_attribute: "phx-r"`
- [x] Commit `d5797e91` exists in git log
- [x] `golden_diff_test.exs` passes: 2 tests, 0 failures
- [x] `install-smoke.sh` exits 0: "done; tmp_app generated + sigra-installed + compiled clean"
- [x] D-05 guard assessed: NOT triggered (no core_components.ex, no .heex, no assets/, no esbuild/tailwind blocks)
- [x] COMPAT-01 satisfied: zero code changes, clean compile under `--warnings-as-errors`
- [x] COMPAT-02 satisfied: fixture byte-parity with phx_new 1.8.8 confirmed by golden_diff_test
- [x] phx.new version used: `1.8.8` (current latest, confirmed via `mix hex.info phx_new`)
- [x] D-09 ordering preserved: fixture reblessed and committed BEFORE any CI pin flip (Plan 02 handles pins)
