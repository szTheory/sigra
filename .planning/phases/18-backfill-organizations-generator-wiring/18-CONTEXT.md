---
phase: 18-backfill-organizations-generator-wiring
captured: 2026-04-14
requirements: [ORG-02, ORG-UPGRADE-01, ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03]
depends_on: [17]
locked_decisions: 8
---

# Phase 18: Backfill + `--organizations` Generator Wiring — Context

**Phase Goal:** Developer upgrading a v1.0 app to v1.1 can run the upgrade with or without backfill and reach a working app on the other side, with a boot-tested upgrade fixture proving it; `--no-organizations` produces a zero-org install that compiles clean.

**Requirements covered:** ORG-02, ORG-UPGRADE-01, ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03 (org-axis slice).

**Context derived from:**
- ROADMAP.md Phase 18 entry (goal + success criteria + pitfalls addressed)
- Prior locked decisions from Phase 11 (feature manifest), Phase 12 (`add_active_organization_id_to_user_sessions` migration template), Phase 14 (`select_active_organization/3` login orchestrator, zero-org landing), Phase 16 D-08 (NO auto-personal-org on registration — Jetstream #117 regression lock), Phase 16 D-01 (upgrade must reuse the Phase 12 migration template verbatim)
- 3 parallel research agents (personal-workspace modeling, Ecto data-migration patterns, generator conditional-wiring patterns)
- Codebase scout: `lib/mix/tasks/sigra.install.ex`, `lib/sigra/install/feature.ex`, `lib/sigra/install/features/organizations.ex`, `lib/sigra/test/install_fixture.ex`, `deps/phoenix/lib/mix/tasks/phx.gen.auth.ex`, `deps/phoenix/priv/templates/phx.gen.auth/auth.ex`

## Pre-Answered by Prior Phases (NOT re-discussed)

- **No auto-personal-org creation on registration** (Phase 16 D-08). Backfill is strictly opt-in. New signups land in the zero-org hero/create flow. This phase does not re-open the Jetstream #117 question.
- **Zero-org post-login path is safe** (Phase 14 + 16). `Sigra.Organizations.select_active_organization/3` returns `{:none, :zero_orgs}`; `Sigra.Plug.LoadActiveOrganization` handles it; generated router redirects to `/organizations`. ORG-UPGRADE-02 is nearly free — Phase 18 only needs to prove it under the upgrade path with a regression test, not design it.
- **Upgrade must reuse the `add_active_organization_id_to_user_sessions.exs` migration template verbatim** (Phase 16 D-01). One canonical definition of "the active_organization_id migration" across fresh-install and upgrade codepaths.
- **Feature manifest system is live** (Phase 11). `Sigra.Install.Feature` behaviour with `enabled?/1`, `files/1`, `injections/1`, `migrations/1`, `post_instructions/2`. `Sigra.Install.Features.Organizations.enabled?/1` already reads `Keyword.get(opts, :organizations, true)`. The gate exists; the flag plumbing is missing.
- **Library is org-aware** (v1.1 philosophy, captured in memory 2026-04-11). `lib/sigra/organizations.ex` and all library modules stay compiled regardless of host flags. Only **generated** code varies on `--no-organizations`. No compile-time library forks.

## Implementation Decisions

### Personal Org Identity & Naming

- **D-01: Personal orgs are a first-class row flag on `organizations`, not a conventional inference.**

  ```elixir
  alter table(:organizations) do
    add :personal, :boolean, null: false, default: false
  end
  create unique_index(:organizations, [:owner_user_id],
           where: "personal = true",
           name: :organizations_personal_owner_uidx)
  ```

  The `personal: boolean` column is added in a schema migration that lands **before** the data migration. Default is `false` (existing team orgs stay team orgs). Backfill inserts rows with `personal: true`. The partial unique index structurally guarantees "at most one personal org per user" and doubles as the insert-safety backstop for D-03's idempotency strategy.

  **Why:** Laravel Jetstream uses `personal_team` boolean on its `teams` table — direct prior art, same shape. Notion and Linear both model personal vs team workspaces as first-class distinctions at the schema level (Notion pricing explicitly gates features on personal-vs-team). The column becomes the anchor for future UI decisions (switcher hide-when-alone, billing tier defaults, "upgrade personal to team" flows) without requiring a schema rewrite later. It also lets analytics/audit queries distinguish "personal workspace events" from "team workspace events" without fragile inference. Alternatives considered and rejected: (a) no column, inferred from membership count — breaks once the personal workspace gets a second member; (c) partial unique index on `owner_user_id` alone without a column — invisible to new contributors, fragile under schema introspection.

  **Semantics:** `personal = true` means **"origin"**, not "current state". The flag is sticky — if a user invites others into their personal workspace, the row stays `personal: true`. UI gates that want "only solo workspaces" should check `personal = true AND membership_count == 1`.

- **D-04: Personal org name = `"{display_name || email_local_part}'s Workspace"`, slug = `"user-#{id}"` (immutable).**

  Name is the human-facing string the user sees on first login after upgrade. Fallback chain: `user.display_name` → local-part of `user.email` (before `@`) → literal `"Personal"` (degenerate case — user has neither). The possessive `"'s Workspace"` form is directly supported by Linear's and Notion's onboarding literature (Intercom/Linear blog posts 2022–2023 on first-impression workspace naming) — it signals ownership immediately versus generic `"Workspace 1"` or raw email.

  Slug is `"user-#{user.id}"` — opaque, immutable, collision-free by construction, PII-safe. **Renaming the workspace never changes the slug**, so users can freely edit the name without breaking `/:slug/...` URLs (Rails `friendly_id` gem's `slug_history` hack-tax is avoided entirely). **Email is never in URLs** — avoids OWASP ASVS v4 §8.3.1 referer/analytics/server-log leaks flagged in Supabase's backfill discussions.

  **Alternatives rejected:** `slug = parameterize(email_local)` leaks PII; `slug = parameterize(name)` couples URL stability to name-change frequency; `name = "Personal"` for everyone is impersonal and signals nothing in the switcher.

### Backfill Execution & Idempotency

- **D-02: Backfill uses the Dashbit "data migrations" pattern, invoked via `mix sigra.upgrade --backfill-personal-orgs`.**

  Implementation shape:
  1. The upgrade task generates a data migration file into the **host app's** `priv/repo/data_migrations/YYYYMMDDHHMMSS_backfill_personal_orgs.exs`. This directory is separate from `priv/repo/migrations/` so schema and data migrations never coexist in the same lock.
  2. The generated file is 5-10 lines — it subclasses `Ecto.Migration` with `@disable_ddl_transaction true` and `@disable_migration_lock true`, then calls `Sigra.Upgrade.Backfill.run_personal_orgs(repo, opts)`. **All batching, logging, and SQL logic lives in the versioned library**, not generated code — so fixes propagate via `mix deps.update` without requiring host-app regeneration.
  3. `mix sigra.upgrade --backfill-personal-orgs` invokes `Ecto.Migrator.with_repo/2` + `Ecto.Migrator.run(repo, "priv/repo/data_migrations", :up, all: true)`. Ecto's `schema_migrations`-style bookkeeping, advisory lock, ordering, and "run-once" guarantees all apply automatically — a re-run of the upgrade command is a no-op after successful completion because Ecto tracks it.

  **Why Dashbit's pattern and not the alternatives:** José's explicit post ["Automatic and manual Ecto migrations"](https://dashbit.co/blog/automatic-and-manual-ecto-migrations) prescribes separating data migrations from schema migrations, because long-running data migrations inside schema migrations "slow down new deployments", tightly couple schema-time code to run-time code, and can't be batched. The `--migrations-path` flag on `mix ecto.migrate` has supported this pattern since Ecto 3.4. Prior art: `ecto_immigrant`, Tyler Young's Elixir backfill microframework (tylerayoung.com/2023/08/13/migrations/), and Oban Pro's own versioned migration approach all converge on this shape.

  **Rejected alternatives:** (A) Pure schema migration — Dashbit anti-pattern, can't be batched, blocks deploys. (B) Raw mix task with manual `Repo.transaction` batches — throws away Ecto's free bookkeeping, reinvents version tracking. (C) Oban job — violates Sigra's "Oban is optional" rule, overkill for one-shot upgrades (Oban's own docs position it for ongoing async work).

  **Concurrent-safety flags:** `@disable_ddl_transaction true` and `@disable_migration_lock true` are mandatory. Without them a multi-hour backfill holds `pg_advisory_lock` and blocks every subsequent migration and deploy. Reference: [fly-apps/safe-ecto-migrations](https://github.com/fly-apps/safe-ecto-migrations).

  **Adapter branching:** `ON CONFLICT DO NOTHING` / `INSERT IGNORE` / `INSERT OR IGNORE` is handled by Ecto's `on_conflict: :nothing` at the query level — zero hand-written SQL branching. Ecto emits the correct DDL per adapter automatically.

- **D-03: Idempotency is guaranteed by a `NOT EXISTS` keyset-paginated selector plus `ON CONFLICT DO NOTHING` on the partial unique index.**

  Batch selector (exact shape):
  ```elixir
  from u in users_schema,
    where: u.id > ^last_cursor,
    where: not exists(
      from o in orgs_schema,
        where: o.owner_user_id == parent_as(:u).id and o.personal == true
    ),
    order_by: u.id,
    limit: ^batch_size,
    as: :u
  ```
  Batch default: `1_000` rows. Configurable via upgrade task option.

  Insert uses `Repo.insert_all/3` with `on_conflict: :nothing, conflict_target: {:unsafe_fragment, "(owner_user_id) WHERE personal = true"}`. This gives **two independent idempotency guarantees**:
  1. **Selector-level**: a re-run naturally narrows to the residual set via the `NOT EXISTS` clause, so resume-after-crash is free and no user is ever counted twice across batches.
  2. **Insert-level**: the partial unique index (D-01) catches any race condition between a concurrent user signup and an in-flight backfill batch. `on_conflict: :nothing` collapses the duplicate silently.

  **Keyset, not OFFSET:** `u.id > ^last_cursor` is a keyset cursor. Postgres `OFFSET` is O(n) and scales catastrophically on the `users` table when the backfill has already processed most rows — standard Postgres pagination wisdom.

  **Why not alternatives:** "User has any membership → skip" (a) misses team-joined users who still need a personal org — fails the spec intent. "User has any owner membership → skip" (c) over-broadly skips users who own team orgs but have no personal. Sidecar `upgrade_state` tracking table (d) is over-engineered and duplicates what Ecto's `schema_migrations` already tracks at the migration-version level; Shopify's `maintenance_tasks` learned (railsatscale.com 2023-01-04) that idempotency must live in `#process`, not sidecar state. The `NOT EXISTS` + partial unique index combo is the Ecto-idiomatic equivalent of Rails' `find_or_create_by` + unique-index pattern.

### Generator Opt-Out & Library/Generated Bifurcation

- **D-05: `--no-organizations` opt-out uses three mechanisms from `mix phx.gen.auth`'s playbook — inline EEx conditionals for small gated blocks, file-manifest omission for whole files, injections for host-owned files. No duplicate template variants.**

  This is **exactly** how `mix phx.gen.auth` handles its `live?`, `binary_id`, and scope-config flags. Verified against `deps/phoenix/priv/templates/phx.gen.auth/auth.ex` (inline `<%= if live? do %>` conditionals at ~10 sites), `deps/phoenix/priv/templates/phx.gen.auth/migration.ex` (conditionals down to sub-expression level), and `deps/phoenix/lib/mix/tasks/phx.gen.auth.ex:478` `files_to_be_generated/1` (file omission via keyword lookup). Zero duplicate `_with_X / _without_X` template files exist in phx.gen.auth's 35-template tree — the Phoenix team explicitly chose inline conditionals over duplication because duplicating N lines so M can differ is a maintenance disaster (every bug fix has to land in two places, silent drift at review time).

  **Three mechanisms, each in its lane:**

  1. **Inline EEx conditionals in templates** — for small (~5-20 line) gated blocks within otherwise-shared files. The canonical Sigra case is the generated `MyApp.Accounts.Auth` context's `create_session/3` function: wrap the `Sigra.Organizations.select_active_organization/3` call in `<%= if @organizations? do %>…<% end %>`. Pass `organizations?: Sigra.Install.Features.Organizations.enabled?(opts)` through the binding. **Constraint:** keep conditionals shallow — ≤20 lines, ≤2 nesting levels. Deeper than that, extract into a helper template partial or split the file.

  2. **Whole-file omission via feature manifest** — `Sigra.Install.Features.Organizations.files/1` already knows which org files to emit. When `enabled?/1` returns `false`, `files/1` returns `[]` and `migrations/1` returns `[]`. Schemas (`Organization`, `OrganizationMembership`, `OrganizationInvitation`), migrations, LiveViews (`OrganizationsLive.*`, `OrganizationSwitcherLive`, `OrganizationMembersLive`, `InvitationAcceptLive` from Phase 17), and routes are never emitted.

  3. **Existing `Sigra.Install.Injection` mechanism** for host-owned files that already exist and can't be clobbered — router, `config/config.exs`, `lib/my_app_web/components/layouts/app.html.heex`, `test/support/conn_case.ex`, `AGENTS.md`. Injections **must fail loudly on missing markers** — silent no-op on a missing marker is the worst failure mode (phx.gen.auth's `Mix.Phoenix.Injector` raises; Sigra's `Sigra.Install.Injection` must match this behavior).

  **Library stays always-compiled.** `lib/sigra/organizations.ex`, `lib/sigra/organizations/invitations.ex`, `lib/sigra/plug/load_active_organization.ex`, etc. are always compiled on the host regardless of `--no-organizations`. BEAM lazy-loads modules — dead code costs effectively nothing. Prior art: `bcrypt_elixir` and `argon2_elixir` both ship in Phoenix regardless of `--hashing-lib` choice. Do NOT add compile-time library forks, optional-dep gating, or `Code.ensure_loaded?/1` checks inside library modules — the research agent and the saved project philosophy are both emphatic on this point.

  **Flag wiring (only missing piece):** `sigra.install.ex` `@switches` needs `organizations: :boolean` added, and `build_binding/4` needs to forward `organizations?: Keyword.get(opts, :organizations, true)` into the template binding. The Organizations feature module's `enabled?/1` already reads the flag correctly — no changes needed there.

### Upgrade Test Fixture

- **D-06: `test/upgrade_test.exs` uses semantic equivalence — `mix sigra.install --no-organizations` IS the v1.0 state by definition, once D-05 lands.**

  Test flow:
  1. `Sigra.Test.InstallFixture.build_app/1` (the existing Phase 11/17 helper) spins up a throwaway Phoenix app in `System.tmp_dir!/1` via `mix phx.new`.
  2. Run `mix sigra.install --no-organizations --yes` in the tmp app. This produces v1.0-shape code (no org schemas, no org migrations, no org LVs, no org routes).
  3. Seed N test users via a helper (`UserFixtures.create_users(n: 5)` or similar).
  4. Run `mix ecto.migrate` against the tmp app's repo.
  5. Run `mix sigra.upgrade --yes` (no backfill flag) → assert login still works for all seeded users, all users land on `/organizations` create/accept page, no 500s.
  6. Run `mix sigra.upgrade --backfill-personal-orgs --yes` → assert every user now has a personal org (matching D-01/D-03/D-04 shape), `SELECT COUNT(*) FROM organizations WHERE personal = true` equals seeded user count, re-running the backfill command is a no-op.

  **Why semantic equivalence and not snapshots:**
  - Snapshot freeze (option A) guarantees drift — every unrelated template change breaks the snapshot; you stop running it, stop trusting it.
  - Git-ref checkout (option C) is brittle across rebases, forces CI to do a second clone.
  - Hex tarball (option D) is impossible pre-release and wasteful post-release.
  - Semantic equivalence works because `--no-organizations` **is** the definition of "v1.0-shape" going forward — the install generator is your single source of truth for what v1.0 looked like, so v1.0 is reproducible by construction.

  **Prior art:** Ecto's integration suite regenerates from current code. Oban generates current-version migrations into a test repo and exercises upgrade paths via `Oban.Migration.up(version: N)` — see [Oban v2.6 upgrade docs](https://hexdocs.pm/oban/v2-6.html). Neither freezes snapshots. Pow historically did not test migration upgrade paths across major versions and ossified on Phoenix <1.8 — this is a cautionary tale, not a model to copy.

  **Cross-link to D-07:** the same fixture pattern (`mix sigra.install ${flag_combo} --yes` in a tmp app) powers both the upgrade regression test AND the CI matrix. One fixture helper, two callers.

### CI Matrix Scope

- **D-07: Phase 18 adds an `install_matrix` CI job with the org-axis only (`["", "--no-organizations"]`); the matrix structure is extensible so Phase 19-22 can append passkey axis entries without restructuring.**

  `.github/workflows/ci.yml` gains a new job:
  ```yaml
  install_matrix:
    strategy:
      matrix:
        flags:
          - ""
          - "--no-organizations"
    steps:
      # setup OTP/Elixir/Postgres
      - run: mix phx.new tmp_app --no-assets --no-mailer
      - run: cd tmp_app && mix sigra.install ${{ matrix.flags }} --yes
      - run: cd tmp_app && mix deps.get && mix compile --warnings-as-errors
      - run: cd tmp_app && mix ecto.create && mix ecto.migrate
      - run: cd tmp_app && mix test
  ```

  **Matrix shape is a list-of-flag-strings**, NOT a 2D product of booleans. Phase 19-22 appends `"--no-passkeys"`, `"--no-organizations --no-passkeys"` to the same list without restructuring the job. Low-ceremony extensibility.

  **Why just the org axis for Phase 18:** The roadmap entry explicitly scopes GEN-03 coverage to the "org-axis slice" for this phase. Passkeys don't exist yet (Phase 19-22). Attempting to structure the matrix for future axes now would be speculative and add churn when Phase 19 actually lands.

  **Zero-org job catches the invariant** that matters most for D-05: any `Sigra.Organizations` reference that slipped into non-gated generated code will cause compilation or test failure in the `--no-organizations` matrix leg. This is the structural regression lock for ORG-02.

### Upgrade Task UX

- **D-08: `mix sigra.upgrade` ships with `--yes`, `--dry-run`, `--allow-dirty`, `--backfill-personal-orgs`, `--from VERSION`, interactive confirmation on clean runs, dirty-git-tree refusal by default, version detection (refuse downgrades, allow re-runs), three-section stdout summary, and per-batch telemetry events.**

  ```
  mix sigra.upgrade [--yes] [--dry-run] [--allow-dirty]
                    [--backfill-personal-orgs] [--from VERSION]
  ```

  **Flag semantics:**
  - `--yes` short-circuits all interactive prompts. Matches the existing `mix sigra.install --yes` precedent and fixes phx.gen.auth's documented papercut where CI runs must hack `MIX_SHELL=quiet`. **Required** for CI use.
  - `--dry-run` prints the full file-change plan (files to create, files to modify via injection, migrations to generate, optional backfill user count) without writing anything. Cheap to implement — the feature manifest already computes file lists, and the backfill user count comes from running D-03's `NOT EXISTS` selector with `COUNT(*)` instead of `LIMIT`. High trust signal for an upgrade command that touches migrations.
  - `--allow-dirty` escape hatch for the default dirty-git-tree check. Rails-5.1 convention. Default is to refuse running on a dirty working tree (makes the upgrade diff reviewable), but monorepo/worktree users (e.g., your own `.planning/` churn) need the escape hatch.
  - `--backfill-personal-orgs` opt-in flag for the D-02 data migration. Matches roadmap-mandated naming.
  - `--from VERSION` optional explicit source version (normally auto-detected from a version sentinel — see below). Lets users override when auto-detection fails or during partial rollbacks.

  **Interactive confirmation:** on a clean run without `--yes`, after computing the plan, print it and call `Mix.shell().yes?/1`. On dissent, `System.halt(0)` for clean CI exit codes (match phx.gen.auth's pattern — `Mix.shell().yes?(...) || System.halt()`).

  **Version detection:** record the Sigra schema version as `:sigra_schema_version` in `config/config.exs` (injection inserted on install / upgraded on each upgrade). Refuse on downgrade (target version < recorded version — fail loudly). **Allow re-runs** — idempotent upgrades are a feature, not a bug. Prior art: Ash does this, Ecto `schema_migrations` does this.

  **Success output: three sections printed to stdout** — no sidecar summary files (phx/ecto/tailwind all avoid this antipattern):
  ```
  Applied:
    ✓ Created 3 files
    ✓ Applied 2 injections
    ✓ Generated 1 migration

  Pending:
    → Run: mix ecto.migrate
    → Optional: mix sigra.upgrade --backfill-personal-orgs

  Next steps:
    📖 See: https://hexdocs.pm/sigra/upgrade-v1.1.html
  ```
  Per-section counts make progress legible without log parsing.

  **Telemetry:** emit `[:sigra, :upgrade, :backfill, :batch]` per backfill batch with `%{batch_index: i, batch_size: n, total_processed: t}` measurements. Host apps observe progress through their existing telemetry stack — fits the Phoenix 1.8+ observability idiom.

  **Option validation:** use `NimbleOptions` for the option schema. Gives `--help` output for free, matches the `CLAUDE.md` stack choice, and surfaces bad flag combinations at CLI parse time instead of mid-run.

- **CD-01: Planner's discretion — exact wording of `post_instructions` and `--help` text.** The `post_instructions` hook (already part of the Phase 11 feature behaviour) gets to decide the exact wording of the "next steps" section in the success output, including the docs URL. The `NimbleOptions` schema also gets to author its own `--help` prose. These are DX copywriting decisions, not architectural ones.

- **CD-02: Planner's discretion — batch size default and its tuning knob.** D-03 specifies `1_000` as a default but the planner can land on a different default if research into backfill memory pressure / checkpoint overhead suggests otherwise. Expose it as an `Sigra.Upgrade.Backfill.run_personal_orgs/2` option, NOT as a CLI flag (keeps the task surface area small).

- **CD-03: Planner's discretion — file location for the version sentinel.** D-08 suggests `config/config.exs` via injection. Alternative: `priv/sigra/.version` as a dedicated file. Either works; the planner picks based on what's cleanest given the existing injection infrastructure from Phase 11.

## Coherence check

- D-01 (personal column) ↔ D-03 (idempotency): the partial unique index is BOTH a schema invariant AND an insert-safety backstop. Single design artifact, dual purpose.
- D-02 (Dashbit data migrations) ↔ D-06 (semantic-equivalence fixture): the upgrade test exercises the real `Ecto.Migrator` path, not a simulation.
- D-02 ↔ D-08 (`--dry-run`): dry-run for the backfill just swaps D-03's `LIMIT` selector for `COUNT(*)`. Zero extra infrastructure.
- D-05 (EEx + manifest) ↔ D-07 (CI matrix): the `--no-organizations` matrix leg validates D-05's bifurcation on every PR. If a `Sigra.Organizations` call slips into ungated generated code, the matrix breaks.
- D-04 (opaque slug) ↔ future phases: stable slug URLs mean Phase 20 (passkeys) can use `/org/:slug/passkeys` paths without slug-change churn.
- Entire stack ↔ **no library forking** — `lib/sigra/*` is always compiled; only generated code varies on flags. Matches saved philosophy "library-first for orgs: lib owns logic + thin generated wrapper".

## Deferred Ideas (NOT in Phase 18 scope)

- **Auto-personal-org on signup as a generator flag** (e.g., `mix sigra.install --auto-personal-org`) — new capability, not in ROADMAP scope. Note for future roadmap backlog. Phase 16 D-08 explicitly decided against this for the happy path.
- **"Convert personal org to team org" UX flow** — Notion has this, Linear has this. Out of scope for Phase 18. Add to roadmap backlog as a post-v1.1 DX enhancement.
- **Passkey axis in CI matrix** — Phase 19-22 concern. D-07 structure is extensible; nothing to do now.
- **Backfill progress UI beyond telemetry** (live CLI progress bar, structured log stream) — `IO.ANSI` fancy output could be a polish phase. Telemetry events (D-08) unblock host apps that want to build their own dashboards now.
- **Multi-repo support in the upgrade task** — Sigra assumes a single primary Ecto repo. Host apps with multiple repos will need manual steps. Add to backlog.
- **`mix sigra.downgrade`** — refuse to build. Downgrades are handled by restoring from backup or rolling migrations manually; a programmatic downgrade path is out of scope for an auth library and would be a security footgun.
- **Upgrade telemetry dashboards / LiveDashboard integration** — out of scope for the library, belongs in a future docs phase.

## Canonical refs

- `.planning/ROADMAP.md` lines 183-193 — Phase 18 roadmap entry with goal, depends, requirements, success criteria
- `.planning/REQUIREMENTS.md` — ORG-02 (line 19), ORG-UPGRADE-01/02/03 (lines 50-52), GEN-03 (line 115), and phase traceability matrix lines 175-243
- `.planning/phases/11-generator-feature-system/11-CONTEXT.md` — feature manifest contract (Sigra.Install.Feature behaviour)
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` — `add_active_organization_id_to_user_sessions.exs` migration template (reused by this phase's upgrade path)
- `.planning/phases/16-org-liveviews-switcher/16-CONTEXT.md` — D-08 (NO auto-personal-org on signup), D-01 (Phase 18 reuses the Phase 12 migration template verbatim), zero-org post-login landing design
- `lib/mix/tasks/sigra.install.ex` — `@switches` list (line 37-44) needs `organizations: :boolean` added; `build_binding/4` needs `organizations?` forwarded
- `lib/sigra/install/feature.ex` — `Sigra.Install.Feature` behaviour callbacks
- `lib/sigra/install/features/organizations.ex:37` — `enabled?/1` already reads `Keyword.get(opts, :organizations, true)`
- `lib/sigra/test/install_fixture.ex` — `Sigra.Test.InstallFixture` helper (reused by upgrade test fixture)
- `lib/sigra/organizations.ex` — library-side `select_active_organization/3` and friends (always compiled)
- `deps/phoenix/lib/mix/tasks/phx.gen.auth.ex:478` — `files_to_be_generated/1` file-omission pattern (D-05 prior art)
- `deps/phoenix/priv/templates/phx.gen.auth/auth.ex:165` — inline `<%= if live? do %>` conditional (D-05 prior art)
- `deps/phoenix/lib/mix/phoenix.ex:340` — `prompt_for_conflicts/1` reference for D-08 interactive confirmation
- https://dashbit.co/blog/automatic-and-manual-ecto-migrations — D-02 canonical source
- https://github.com/fly-apps/safe-ecto-migrations — D-02 concurrent-safety flags reference
- https://tylerayoung.com/2023/08/13/migrations/ — Elixir backfill microframework prior art
- https://github.com/samsamai/ecto_immigrant — separate-data-migrations-directory prior art
- https://hexdocs.pm/oban/v2-6.html — Oban self-testing upgrade pattern (D-06 prior art)
- https://jetstream.laravel.com/features/teams.html — `personal_team` boolean precedent (D-01)
- https://railsatscale.com/2023-01-04-how-we-scaled-maintenance-tasks-to-shopify-s-core-monolith/ — idempotency-in-process lesson (D-03)
