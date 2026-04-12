---
phase: 11
plan: 04
subsystem: installer-generator
tags:
  - generator
  - features
  - core-extraction
  - wave-3
requires:
  - lib/sigra/install/feature.ex (Wave 1 — 5-callback behaviour)
  - lib/sigra/install/injection.ex (Wave 1 — %Injection{} struct)
  - lib/sigra/install/injector.ex (Wave 1 — apply/2 + apply_anchor/3)
  - lib/sigra/install/report.ex (Wave 1 — 4-column accumulator)
  - priv/templates/sigra.install/core/ (Wave 2 — 45 relocated templates)
provides:
  - lib/sigra/install/features/core.ex (full Feature implementation)
  - test/sigra/install/features/core_test.exs (behaviour contract tests)
  - test/sigra/install/features/core_post_instructions_test.exs (Oban/Swoosh fixture tests)
affects:
  - lib/mix/tasks/sigra.install.ex (INTENTIONALLY UNCHANGED — Wave 4 flips the walker)
tech-stack:
  added: []
  patterns:
    - behaviour-impl-with-impl-annotations
    - data-only-callbacks-describe-not-execute
    - ansi-iodata-stripped-in-tests-via-io-ansi-format
key-files:
  created:
    - lib/sigra/install/features/core.ex
    - test/sigra/install/features/core_test.exs
    - test/sigra/install/features/core_post_instructions_test.exs
  modified: []
decisions:
  - Features.Core is a SINGLE public module (not split into Core.Files / Core.Injections / ...). Current LOC (~695) is readable; splitting would bury the isolation boundary under cross-file navigation.
  - Isolation invariant is enforced by a moduledoc-stripping test so the documentation can describe the boundary without false-positiving its own prose.
  - post_instructions/2 helpers (oban_instructions, swoosh_instructions) read the host-app filesystem directly — they are NOT routed through %Injection{} because they are detection-and-report, not marker-based code injection. This matches CONTEXT.md RESEARCH Q2 resolution (a).
  - Swoosh mutation to config/dev.exs is preserved verbatim as a real file-write side effect inside post_instructions/2. This is the ONLY side effect in a callback that is otherwise pure; removing it would break the byte-identity contract with the v1.0 monolith.
  - Injection marker uniqueness is per-(target,marker) pair, not global. Router/config/test.exs all share the "# Sigra authentication" marker because idempotency is checked against a single file at a time — matches the monolith's existing Injector behavior.
  - ANSI color atoms (:yellow, :green, :reset) in post_instructions output are valid chardata for Mix.shell().info/1 but not for IO.iodata_to_binary/1; the tests strip them via IO.ANSI.format(false).
metrics:
  duration: ~35 minutes
  tasks_completed: 2
  files_created: 3
  files_modified: 0
  core_ex_loc: 695
  callbacks_implemented: 5
  injection_records_default_opts: 4
  injection_records_full_flags: 7
  migration_slots: 3
  unit_tests_added: 42
  fixture_tests_added: 14
---

# Phase 11 Plan 04: Features.Core Extraction Summary

Wave 3 of Phase 11's generator-feature-system refactor. Extract every
v1.0-specific installer concern from the 785-line `Mix.Tasks.Sigra.Install`
monolith into a new `Sigra.Install.Features.Core` module implementing the
5-callback `Sigra.Install.Feature` behaviour. **Pure addition** — the
monolith is unchanged in this wave; Wave 4 flips the walker.

## Outcomes

**1. `lib/sigra/install/features/core.ex` (695 LOC) — the full Feature implementation.**

All 5 callbacks are populated, each annotated with `@impl true`:

- `enabled?/1` — always `true` (Phase 11 Success Criterion #4).
- `files/1` — returns `{:eex, source, target}` tuples with `core/` prefix.
  - 25 base files (always)
  - 9 live-mode UI files OR 3 controller-mode UI files
  - 2 api files (`--api` / implied by `--jwt`)
  - 1 jwt file (`--jwt`)
  - Totals: 34 default, 28 `--no-live`, 37 `--live --api --jwt`
- `migrations/1` — 3 slots in canonical order: `:primary`, `:api_token`, `:audit_events`.
- `injections/1` — 4 base `%Injection{}` records (router, config.exs, test.exs, conn_case.ex), +2 on `--api`, +1 more on `--jwt`. Every injection is a structured `%Sigra.Install.Injection{}`; Features.Core never calls `Injector` directly.
- `post_instructions/2` — base instructions (ported from `print_instructions/1`) + Oban-detection block + Swoosh-detection block (ported from `inject_oban_queue/1` and `inject_swoosh_config/2`).

**2. Isolation invariant (Pitfall X-1) mechanically enforced.**

Zero references to `Features.Organizations`, `Features.Passkeys`, or `Features.Admin` in the module source (moduledoc-stripped grep). The moduledoc itself describes the isolation boundary — the test strips `@moduledoc """..."""` before grepping to avoid false-positiving its own documentation.

**3. 56 tests added across 2 files — all green.**

- `test/sigra/install/features/core_test.exs` (42 tests, async): behaviour contract, enabled?/1, migrations/1, files/1 (default + `--no-live` + `--api` + `--jwt` + target paths + deduplication), isolation invariant, template coverage (full-combos vs on-disk minus orphans), injections/1 (shape, uniqueness, anchors, targets, router content, config content, --api/--jwt).
- `test/sigra/install/features/core_post_instructions_test.exs` (14 tests, async: false): Oban detection (5 branches), Swoosh detection (4 branches), base instruction content (5 tests covering live/no-live/--api/--jwt). Fixture-mode via `File.cd!` into a per-test temp dir — mandatory because `post_instructions/2` reads and (in the Swoosh case) writes host-app config files.

**4. Monolith `lib/mix/tasks/sigra.install.ex` UNCHANGED.**

`git diff 2983e3765a677caf46c1866fc27bfab8c14cbbf5 -- lib/mix/tasks/sigra.install.ex` reports zero lines. The golden-diff regression test (`test/sigra/install/golden_diff_test.exs`) continues to exit 0 — the end-to-end install output is still produced exclusively by the monolith, preserving byte-identity.

**5. Orphan templates discovered.**

Three templates exist under `priv/templates/sigra.install/core/` but are NEVER rendered by the v1.0 monolith:

- `auth_api_token.ex`
- `auth_hooks.ex`
- `api_token_created_email.ex`

The monolith references `auth_api_token.ex` only in a post-install instructions line ("Add the functions from auth_api_token.ex to your Auth context"), and `auth_hooks.ex` only inside `Sigra.Install.Injector.lifecycle_template_files/0` (which is itself never called from the current install path). `api_token_created_email.ex` has no references anywhere in the install path.

These are pre-existing dead code from earlier phases. Features.Core intentionally does NOT reference them — doing so would generate new files the monolith never generates, breaking byte-identity. They are captured by the `files/1 + migrations/1 reference exactly the templates the v1.0 monolith generates` test which uses an explicit `orphans` exclusion list. Any future phase that wants to render these templates must:

1. Add them to Features.Core's appropriate file group,
2. Regenerate the golden-diff fixture, and
3. Remove them from the `orphans` list in `core_test.exs`.

## Injection coverage

| # | Target | Marker | Anchor | Gate |
|---|--------|--------|--------|------|
| 1 | `lib/my_app_web/router.ex` | `# Sigra authentication` | `:before_last_end` | always |
| 2 | `config/config.exs` | `# Sigra authentication` | `:before_last_end` | always |
| 3 | `config/test.exs` | `# Sigra authentication` | `:before_last_end` | always |
| 4 | `test/support/conn_case.ex` | `MyAppWeb.ConnCaseHelpers` | `:before_last_end` | always |
| 5 | `lib/my_app_web/router.ex` | `# Sigra API` | `:before_last_end` | `--api` / `--jwt` |
| 6 | `config/config.exs` | `api_token:` | `:before_last_end` | `--api` / `--jwt` |
| 7 | `lib/my_app_web/router.ex` | `# Sigra JWT` | `:before_last_end` | `--jwt` only |

All 3 anchors used (`:before_last_end`) are already supported by `Injector.apply_anchor/3` from Wave 1. **No new anchors added to Injector in this plan.**

The router is the only target with multiple distinct markers — that's intentional and matches how the monolith lays them out (each is a separate `inject_file` call in `inject_into_files/2`).

## Template categorization

All 42 non-orphan templates (45 total minus 3 orphans) are routed through Features.Core exactly once:

- **25 base files** (always rendered): user.ex, user_token.ex, scope.ex, auth.ex, user_auth.ex, error_handler.ex, session_controller.ex, auth_fixtures.ex, conn_case_helpers.ex, emails.ex, auth_mailer.ex, confirmation_{controller,html}.ex, reset_password_{controller,html}.ex, user_session.ex, sudo_{controller,html}.ex, user_mfa_credential.ex, user_backup_code.ex, mfa_challenge_{controller,html}.ex, audit_event.ex, encrypted.ex, mailer.ex
- **9 live UI files** (`--live`): login_html.ex, registration_live.ex, confirmation_live.ex, reset_password_live.ex, session_live.ex, mfa_challenge_live.ex, mfa_settings_live.ex, settings_live.ex, reactivation_live.ex
- **3 controller-mode UI files** (`--no-live`): login_html.ex, registration_html.ex, mfa_settings_html.ex
- **2 api files** (`--api` / `--jwt`): user_api_token.ex, api_token_controller.ex
- **1 jwt file** (`--jwt`): token_controller.ex
- **3 migration slots**: migration.exs, api_token_migration.exs, create_audit_events.exs

`login_html.ex` is in BOTH `--live` and `--no-live` ui_files groups — preserving Phase 10.1.1 B9/D-12's structural fix where the login page is always a plain controller.

## Self-Check: PASSED

- [x] `lib/sigra/install/features/core.ex` exists with `@behaviour Sigra.Install.Feature` — FOUND
- [x] 5 `@impl true` callbacks — FOUND (grep count: 5)
- [x] 8 `%Injection{` struct literals — FOUND (grep count: 8; 4 base + 2 api + 1 jwt branch + 1 via conn_case direct literal ≥ 3 requirement)
- [x] Isolation: `grep -E 'Features\.(Organizations|Passkeys|Admin)' lib/sigra/install/features/core.ex` → only moduledoc prose (test strips before grep)
- [x] Monolith unchanged: `git diff 2983e37 -- lib/mix/tasks/sigra.install.ex | wc -l` → 0
- [x] `mix test test/sigra/install/features/` → 56 tests, 0 failures
- [x] `mix test test/sigra/install/golden_diff_test.exs` → 2 tests, 0 failures
- [x] `mix test test/sigra/install/` → 322 tests, 0 failures
- [x] `mix compile --warnings-as-errors` → clean
- [x] `mix format --check-formatted` on new files → clean
- [x] Task 1 commit: `545eb62 feat(11-04): implement Features.Core behaviour with files/migrations/enabled?`
- [x] Task 2 commit: `b8dd53e test(11-04): add Features.Core injection + Oban/Swoosh fixture tests`

## Commits

| Commit | Message |
|--------|---------|
| `112f10c` | test(11-04): add failing Features.Core behaviour contract tests |
| `545eb62` | feat(11-04): implement Features.Core behaviour with files/migrations/enabled? |
| `b8dd53e` | test(11-04): add Features.Core injection + Oban/Swoosh fixture tests |

## What Wave 4 Will Do

With Features.Core feature-complete, Wave 4 will:

1. Delete or gut `generate/4` / `inject_into_files/2` / `print_instructions/1` / `inject_oban_queue/1` / `inject_swoosh_config/2` in the monolith.
2. Rewrite `Mix.Tasks.Sigra.Install` into a ~150 LOC generic walker over `[Features.Core]`, threading a `Sigra.Install.Report` and `Sigra.Install.MigrationTimestamps.allocate/2` output through each feature's callbacks.
3. Replace the raw `Mix.shell().info/1` calls with `Report.record_*/2` accumulation, rendering via `Report.render_summary/1` at the end.
4. Regenerate and commit a fresh `test/fixtures/install_golden/` snapshot if any whitespace-level drift occurs; the goal remains zero diff.

The load-bearing promise this wave makes is: **adding Features.Organizations in Phase 18 requires zero edits to `lib/mix/tasks/sigra.install.ex`** — only a new entry in the feature list and a new module under `lib/sigra/install/features/`.
