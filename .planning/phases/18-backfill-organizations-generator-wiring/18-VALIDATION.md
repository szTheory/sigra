---
phase: 18-backfill-organizations-generator-wiring
captured: 2026-04-14
requirements: [ORG-02, ORG-UPGRADE-01, ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03]
framework: ExUnit (Elixir 1.18 built-in)
config_files:
  - test/test_helper.exs
  - config/test.exs
quick_run: "mix test <file>:<line>"
full_suite: "mix test --include integration"
---

# Phase 18 — Validation Architecture

Canonical source for the test framework, per-workstream verification commands, and sampling rate for Phase 18. This file was extracted from `18-RESEARCH.md` lines 510–581 during the revision pass (BLOCKER 4 — nyquist_validation_gate).

**No Wave 0 placeholders.** Every test file listed below is either (a) already present in the repo or (b) created by a named task in one of the three Phase 18 plans. Executors MUST NOT leave any `MISSING — Wave 0 must create …` sentinel in place.

## Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.18 built-in) |
| Config file | `test/test_helper.exs` + `config/test.exs` |
| Quick run command | `mix test <file>:<line>` |
| Full suite command | `mix test --include integration` |
| Upgrade-specific command | `mix test test/upgrade_test.exs --include integration` |
| Fast-loop exclusion | `mix test --exclude integration` |

## Workstream 1 — Plan 18-01: Foundation Schema + Generator Flag

Requirements locked: **ORG-02**.

| Req ID | Behavior | Test Type | Automated Command | Created By |
|--------|----------|-----------|-------------------|------------|
| ORG-02 | `--no-organizations` emits zero `organizations/*` files | unit (Runner) | `mix test test/sigra/install/runner_test.exs -x` | Plan 18-01 Task 3 acceptance criteria |
| ORG-02 | `Features.Organizations.enabled?(organizations: false)` returns `false` | unit (feature) | `mix test test/sigra/install/features/organizations_test.exs -x` | Pre-existing (Phase 11) |
| ORG-02 | `build_binding/4` forwards `:organizations?` into template binding | unit (binding) | `mix test test/mix/tasks/sigra.install_test.exs -x` | Plan 18-01 Task 3 |
| ORG-02 | Fresh install bakes `owner_user_id` + `personal` + partial unique index into `create_organizations.exs` | unit (golden diff) | `mix test test/sigra/install/golden_diff_test.exs` | Plan 18-01 Task 1 (golden regenerate) |
| ORG-02 | `Sigra.Organizations.create_organization/3` writes `owner_user_id` via `put_change/3`, never via `cast/3` | unit (AAA) | `mix test test/sigra/organizations_test.exs -x` | Plan 18-01 Task 4 |

## Workstream 2 — Plan 18-02: Upgrade Task + Backfill Library

Requirements locked: **ORG-UPGRADE-01**.

| Req ID | Behavior | Test Type | Automated Command | Created By |
|--------|----------|-----------|-------------------|------------|
| ORG-UPGRADE-01 | `Sigra.Upgrade.Backfill.run_personal_orgs/2` inserts 1 personal org per user | unit | `mix test test/sigra/upgrade/backfill_test.exs -x` | Plan 18-02 Task 1 |
| ORG-UPGRADE-01 | Re-running backfill is a no-op (count unchanged) | unit (idempotency) | same file | Plan 18-02 Task 1 |
| ORG-UPGRADE-01 | Keyset cursor resume across batches (no duplicate user selection) | unit (resume) | same file | Plan 18-02 Task 1 |
| ORG-UPGRADE-01 | `[:sigra, :upgrade, :backfill, :batch]` telemetry emitted per batch | unit (telemetry.attach) | same file | Plan 18-02 Task 1 |
| ORG-UPGRADE-01 | NimbleOptions rejects missing required opts | unit | same file | Plan 18-02 Task 1 |
| ORG-UPGRADE-01 | Slug format is `"user-#{id}"` (opaque, no email PII) | unit | same file | Plan 18-02 Task 1 |
| ORG-UPGRADE-01 | `mix sigra.upgrade --dry-run` prints plan without writing files | unit (task) | `mix test test/mix/tasks/sigra.upgrade_test.exs -x` | Plan 18-02 Task 4 (alongside Task 3 task regression harness) |
| ORG-UPGRADE-01 | `mix sigra.upgrade` refuses dirty git tree without `--allow-dirty` | unit | same file | Plan 18-02 Task 3 |
| ORG-UPGRADE-01 | `mix sigra.upgrade` refuses downgrade (target < source) | unit | same file | Plan 18-02 Task 3 |
| ORG-UPGRADE-01 | Version sentinel injection into `config/config.exs` is idempotent | unit (injector) | `mix test test/sigra/install/injector_test.exs -x` | Plan 18-02 Task 3 acceptance (BLOCKER 3 Q5 regression) |
| ORG-UPGRADE-01 | `migrations_to_emit/1` returns `[]` when `priv/repo/migrations/` has no `create_organizations` file | unit | `mix test test/sigra/upgrade_test.exs -x` | Plan 18-02 Task 3 (BLOCKER 1 regression) |
| ORG-UPGRADE-01 | `detect_versions/1` defaults source to `"1.0.0"` when `:schema_version` config key is absent | unit | same file | Plan 18-02 Task 3 (INFO 8 regression) |
| ORG-UPGRADE-01 | Generated ALTER migration module name is `MyApp.Repo.Migrations.AddOwnerUserIdToOrganizations` with no stray quotes | unit | same file | Plan 18-02 Task 3 (WARNING 7 regression) |

## Workstream 3 — Plan 18-03: Upgrade Test Fixture + CI Matrix

Requirements locked: **ORG-UPGRADE-02**, **ORG-UPGRADE-03**, **GEN-03**.

| Req ID | Behavior | Test Type | Automated Command | Created By |
|--------|----------|-----------|-------------------|------------|
| ORG-UPGRADE-03 | `InstallFixture.setup_tmp_app_without_install/1` helper exists (additive, preserves byte-identity of `setup_tmp_app/1`) | unit | `mix test test/sigra/install/golden_diff_test.exs` (byte-identity regression) | Plan 18-03 Task 1 (WARNING 5) |
| ORG-UPGRADE-03 | `InstallFixture.run_sigra_install/2`, `run_sigra_upgrade/2`, `run_mix/3` helpers exist and capture stdout | unit | `mix test test/support/install_fixture.ex` (doctest) | Plan 18-03 Task 1 |
| ORG-UPGRADE-03 | `test/upgrade_test.exs` boots `--no-organizations` v1.0 install + runs upgrade without crash, emits ZERO ALTER migrations, app bootable | integration | `mix test test/upgrade_test.exs --include integration` | Plan 18-03 Task 2 (BLOCKER 1 zero-org describe block) |
| ORG-UPGRADE-02 | `test/upgrade_test.exs` boots default install + upgrade + HTTP login via curl → 302 redirect to `/organizations`, no 5xx in any response | integration (HTTP) | same file | Plan 18-03 Task 2 (BLOCKER 2 org-enabled describe block) |
| ORG-UPGRADE-01 | `test/upgrade_test.exs` runs `mix sigra.upgrade --backfill-personal-orgs`, asserts `personal_count == seeded_count`, re-run is a no-op | integration | same file | Plan 18-03 Task 2 backfill-on describe block |
| GEN-03 | CI `install_matrix` job runs `mix sigra.install ${{ matrix.flags }}` for `""` and `"--no-organizations"`; both legs compile, migrate, and test clean | CI workflow | `.github/workflows/ci.yml` (PR run) | Plan 18-03 Task 3 |
| GEN-03 | Matrix shape is list-of-flag-strings (D-07), extensible for Phase 19+ passkey axis | CI workflow | YAML lint on ci.yml | Plan 18-03 Task 3 |

## Sampling Rate

| Trigger | Command | Target |
|---------|---------|--------|
| Per task commit (fast loop) | `mix test --exclude integration` | <30s |
| Per wave merge | `mix test --include integration` | 2–5 min |
| Phase gate | Full suite green + `install_matrix` CI passes both legs + `/gsd-verify-work` sign-off | — |

## No Wave 0 Placeholders

All test files referenced above are either pre-existing or created by explicit tasks in Plans 18-01, 18-02, 18-03. Executors MUST NOT emit any `<automated>MISSING — Wave 0 must create …</automated>` sentinels in task `<verify>` blocks. Any missing fixture must be created by the task that needs it, within the same commit.

## Notes

- **Adapter matrix is out of scope for Phase 18.** Postgres is the primary target; MySQL/SQLite coverage is via `golden_diff_test.exs` template rendering, NOT live backfill execution. Live adapter-matrix backfill is deferred to a future phase.
- **HTTP login assertion (ORG-UPGRADE-02)** uses `mix phx.server` + `curl` as the preferred path. An in-process `Plug.Test.conn/3` fallback is acceptable if the background-server approach proves unreliable in CI. Either path MUST assert: login 2xx/3xx, redirect chain terminates at `/organizations`, no 5xx anywhere.
- **Crash-scan discipline:** every `upgrade_out` and `migrate_out` from `run_sigra_upgrade/2` / `run_mix/2` MUST be asserted free of `** (` (the Elixir raised-exception prefix). Plan 18-03 Task 2 acceptance criteria enforce this.
