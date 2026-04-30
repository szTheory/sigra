# Phase 94: postgres-only-declaration-hard-01 - Research

**Researched:** 2026-04-30  
**Domain:** Elixir/Phoenix generator hardening for Postgres-only installer support [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/REQUIREMENTS.md]  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-94-01 — Strict Postgres allowlist at pre-flight.** `mix sigra.install` must allow only `Ecto.Adapters.Postgres`. Any detected `Ecto.Adapters.MyXQL`, `Ecto.Adapters.SQLite3`, unknown adapter, or undetectable adapter is refused. The current unknown-to-Postgres fallback is the core footgun this phase removes. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-02 — Refuse before any writes or adapter-shaped binding work.** Adapter validation happens before `Runner.run/3` and before any file emission. Prefer validating before `build_binding/4` as well so no template/binding path pretends other adapters still matter. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-03 — Failure surface is `Mix.raise`, not warning + continue.** This is a generator task, not a best-effort migrator. Phoenix/Mix idiom is fail fast for unsupported project state. User-facing behavior is a hard stop with exit status 1. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-04 — Error copy is one calm paragraph.** The refusal message names the adapter when known, says "PostgreSQL only" in the first sentence, says the task cannot continue, and points to the Installation guide prerequisites. Do not use a defensive warning wall or a long remediation checklist. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-05 — Installation guide is the canonical refusal target.** The refusal message should point to `guides/introduction/installation.md` (HexDocs Installation page / prerequisites anchor when published), not generator-options or getting-started. Support boundary and prerequisites belong in installation docs. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-06 — Collapse to single Postgres-only templates.** `priv/templates/sigra.install/core/migration.exs`, `priv/templates/sigra.install/core/api_token_migration.exs`, and `priv/templates/sigra.install/organizations/migration.exs` should contain one real Postgres path each. No residual `if adapter == :postgres` wrappers after the MySQL/SQLite bodies are removed. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-07 — Do not introduce partial/template indirection just to preserve optionality.** Single-file migration readability is more valuable than DRY here. Split into helper partials only if there is a future duplication problem independent of adapter support. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-08 — Rewrite or remove fallback comments.** Keep comments that explain current Postgres design choices. Delete comments whose only purpose was to justify MySQL/SQLite fallbacks, composite-index substitutes, or partial-index limitations on unsupported adapters. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-09 — Reconcile all remaining installer-surface adapter branches under `priv/templates/sigra.install`.** The phase should not stop at the first three files if adjacent install-surface templates/tests still encode MySQL/SQLite behavior. Current known nearby drift: passkeys migration/template tests still assert adapter-matrix behavior and should be brought into the same honesty pass if they remain in the installer contract. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-10 — Delete adapter-matrix template tests; replace them with Postgres contract tests.** Tests that assert MySQL/SQLite branch shapes, duplicate branch counts, or fallback-specific comments should be removed rather than preserved behind renamed expectations. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-11 — Keep exactly one installer-boundary regression for non-Postgres refusal.** The key remaining non-Postgres contract is that `mix sigra.install` rejects MyXQL, SQLite3, and unknown/undetectable adapters before writing files, while Postgres proceeds. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-12 — Golden diff, idempotency, and install-smoke stay Postgres-backed.** Those are the real maintainer contract. The phase should reduce test surface, not replace it with looser coverage. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-13 — Prefer behavioral assertions over branch-count archaeology.** Tests should assert "Postgres migration shape is correct" and "unsupported adapters are refused," not "all three adapter sections still exist." [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-14 — Say "PostgreSQL only" early and plainly across the public entry points.** README, Installation, Getting Started, and First Hour should state PostgreSQL as the only supported adapter in the first screenful where relevant. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-15 — `mix.exs` description should mention PostgreSQL directly.** Hex package metadata is part of the trust surface. Leaving the package description generic while docs are explicit is still a support-boundary leak. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-16 — CHANGELOG framing: "clarified support boundary" first, "removed placeholder MySQL/SQLite branches" second.** This should read as honest narrowing/cleanup, not apology theater and not a defensive confession. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-17 — Tone should be calm, firm, and user-friendly.** State the limit, state the reason in one sentence, give the next step. Avoid "misleading claims" rhetoric in public copy even if that is the internal motivation. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- **D-94-18 — Downstream GSD preference: bias toward coherent recommendations and escalate only on genuinely high-impact choices.** For planning and discussion in this project, the default should be "the agent recommends and locks a coherent set of defaults" unless the gray area materially changes compatibility, security posture, legal/compliance posture, pricing/commercial positioning, or another decision the user is likely to care about deeply. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]

### Claude's Discretion

- Exact refusal-message wording, as long as it stays a single paragraph and points to Installation prerequisites [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- Whether the installer uses a small private helper returning `{:ok, :postgres} | {:error, reason}` internally before the public `Mix.raise` [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- Exact README / Installation / Getting Started / First Hour wording, provided all are aligned on "PostgreSQL only" [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- Exact test file names for the new installer-boundary regression [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- Whether nearby passkeys adapter drift is fixed inside this phase or explicitly called out and closed as part of the same grep-zero target [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)

- If Sigra ever wants non-Postgres support again, prefer an explicit adapter package or separately scoped reintroduction phase over reopening dormant branches in core templates. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- CI lint or grep contract that fails when installer-surface files reintroduce MySQL/SQLite conditionals after HARD-01. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- Broader repo-wide audit of historical changelog/doc references to non-Postgres behavior outside the installer surface if any remain after the scoped cleanup. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HARD-01 | `mix sigra.install` refuses to run against a non-Postgres adapter with a clear error; all unimplemented MySQL / SQLite migration branches are removed; PROJECT.md / README / mix.exs / getting-started honestly state PostgreSQL as the only supported adapter. [VERIFIED: .planning/REQUIREMENTS.md] | Sections `Architecture Patterns`, `Don't Hand-Roll`, `Common Pitfalls`, `Validation Architecture`, and `Security Domain` prescribe the installer chokepoint, template cleanup boundary, doc/metadata touch points, and regression coverage needed to satisfy HARD-01. [VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: .planning/ROADMAP.md] |
</phase_requirements>

## Summary

The current installer does not enforce the support boundary that the phase requires. `Mix.Tasks.Sigra.Install.run/1` validates the three positional args, then calls `build_binding/4`, and `build_binding/4` calls `detect_adapter/1`; `detect_adapter/1` maps `Ecto.Adapters.Postgres` to `:postgres`, `Ecto.Adapters.MyXQL` to `:mysql`, `Ecto.Adapters.SQLite3` to `:sqlite`, and silently falls back to `:postgres` for both unknown adapters and unloaded repos. [VERIFIED: lib/mix/tasks/sigra.install.ex] That means today an unsupported or undetectable host can still proceed into template rendering and file emission, which directly contradicts HARD-01 and D-94-01/D-94-02. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]

The template and test surface is still adapter-matrix shaped. Core auth, API token, organizations, passkeys, audit-events migration, and user API token schema templates all contain adapter conditionals or Postgres/non-Postgres forks; corresponding tests assert MySQL/SQLite-specific output and even count duplicate sections in raw templates. [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: priv/templates/sigra.install/core/api_token_migration.exs][VERIFIED: priv/templates/sigra.install/organizations/migration.exs][VERIFIED: priv/templates/sigra.install/passkeys/create_user_passkeys.exs][VERIFIED: priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs][VERIFIED: priv/templates/sigra.install/core/user_api_token.ex][VERIFIED: test/mix/tasks/sigra.install_test.exs][VERIFIED: test/sigra/install/api_token_generator_test.exs][VERIFIED: test/sigra/templates/session_templates_test.exs][VERIFIED: test/sigra/passkeys/migration_test.exs] The doc and metadata surface also drifts: README still says other adapters are handled in generated migrations, Installation still says PostgreSQL is only the “primary supported” adapter, and `mix.exs` package description does not mention PostgreSQL at all. [VERIFIED: README.md][VERIFIED: guides/introduction/installation.md][VERIFIED: mix.exs]

**Primary recommendation:** Put all support-boundary enforcement in `Mix.Tasks.Sigra.Install`, collapse every installer-surface adapter branch to a single Postgres path, and replace adapter-matrix tests with one refusal regression plus Postgres-only contract assertions. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: priv/templates/sigra.install][VERIFIED: test/support/install_fixture.ex][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Installer adapter detection and refusal | API / Backend | Database / Storage | The logic lives in the Mix task and inspects the host repo adapter before generator execution; the DB tier matters only as the declared adapter being interrogated. [VERIFIED: lib/mix/tasks/sigra.install.ex] |
| Migration template support boundary | Database / Storage | API / Backend | The main behavior difference is in generated Ecto migrations and schema fields that rely on Postgres-only constructs such as `citext`, array columns, `fragment("now()")`, and partial indexes. [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: priv/templates/sigra.install/core/api_token_migration.exs][VERIFIED: priv/templates/sigra.install/organizations/migration.exs][CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] |
| Installer smoke, golden diff, and idempotency verification | API / Backend | Database / Storage | The fixture harness drives `mix sigra.install` end to end in a generated Phoenix app; Postgres is the environment prerequisite for the real host path and existing CI/local test contract. [VERIFIED: test/support/install_fixture.ex][VERIFIED: test/sigra/install/golden_diff_test.exs][VERIFIED: test/sigra/install/idempotency_test.exs][VERIFIED: CLAUDE.md] |
| Public support-boundary messaging | CDN / Static | API / Backend | README, guides, changelog, and Hex metadata are static trust surfaces, but their truth must match the installer behavior implemented in the Mix task. [VERIFIED: README.md][VERIFIED: guides/introduction/installation.md][VERIFIED: guides/introduction/getting-started.md][VERIFIED: CHANGELOG.md][VERIFIED: mix.exs] |

## Project Constraints (from CLAUDE.md)

- Phoenix `1.8+` and Ecto `3.x` are the blessed framework path. [VERIFIED: CLAUDE.md]
- PostgreSQL is the primary database and Sigra relies on `citext` and `JSONB` in its project-level framing. [VERIFIED: CLAUDE.md]
- Security-sensitive code should follow OWASP-oriented defaults. [VERIFIED: CLAUDE.md]
- Dependencies should stay minimal; small stable code may be copied instead of adding new deps. [VERIFIED: CLAUDE.md]
- Tests should be comprehensive, AAA-style, flat, and self-contained. [VERIFIED: CLAUDE.md]
- Local and CI `mix test` both require a live Postgres at `localhost:5432` using `postgres/postgres`; no tag exclusion is configured in `test/test_helper.exs`. [VERIFIED: CLAUDE.md][VERIFIED: test/test_helper.exs]
- No project-local skills were found under `.claude/skills/` or `.agents/skills/` in this workspace. [VERIFIED: project skills discovery command output]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | Declared `~> 1.8`; current stable `1.8.5` published 2026-03-05. [VERIFIED: mix.exs][VERIFIED: https://hex.pm/api/packages/phoenix] | Host-app baseline for `Mix.Phoenix.base/0`, `web_module/1`, and `otp_app/0` used by the installer. [VERIFIED: lib/mix/tasks/sigra.install.ex] | This phase should keep the existing Phoenix-aware generator flow instead of inventing a framework-agnostic installer path. [VERIFIED: lib/mix/tasks/sigra.install.ex] |
| Ecto | Declared `~> 3.12`; current stable `3.13.5` published 2025-11-09. [VERIFIED: mix.exs][VERIFIED: https://hex.pm/api/packages/ecto] | Repo adapter discovery uses Ecto adapter modules and generated host code targets Ecto schemas/migrations. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: priv/templates/sigra.install] | The support boundary is defined in terms of concrete `Ecto.Adapters.*` modules, so the phase should stay on the existing Ecto adapter contract. [VERIFIED: lib/mix/tasks/sigra.install.ex] |
| Ecto SQL | Declared `~> 3.12`; current stable `3.13.5` published 2026-03-03. [VERIFIED: mix.exs][VERIFIED: https://hex.pm/api/packages/ecto_sql] | Generated migrations depend on `Ecto.Migration` features such as `execute/1`, `unique_index/3`, and `where:` predicates. [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: priv/templates/sigra.install/organizations/migration.exs][CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] | HARD-01 is mostly migration-surface cleanup, so `Ecto.Migration` is the core abstraction the planner should target. [VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: priv/templates/sigra.install] |
| Postgrex | Declared `~> 0.17` for test-only use in this repo; current stable `0.22.0` published 2026-01-10. [VERIFIED: mix.exs][VERIFIED: https://hex.pm/api/packages/postgrex] | Live Postgres-backed tests and generated host installs depend on a real Postgres adapter path. [VERIFIED: mix.exs][VERIFIED: CLAUDE.md][VERIFIED: test/support/install_fixture.ex] | The repo’s local/CI test contract and the phase goal both center on Postgres as the only supported adapter. [VERIFIED: CLAUDE.md][VERIFIED: .planning/REQUIREMENTS.md] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| NimbleOptions | Declared `~> 1.1`; current stable `1.1.1` published 2024-05-25. [VERIFIED: mix.exs][VERIFIED: https://hex.pm/api/packages/nimble_options] | Existing Sigra public configuration surfaces already standardize on structured option validation. [VERIFIED: mix.exs][VERIFIED: CLAUDE.md] | Do not add new option parsing complexity for HARD-01 unless a helper actually needs a typed internal return contract. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |
| Mix | Installed `1.19.5` locally; `Mix.raise/1` and `Mix.raise/2` are documented APIs. [VERIFIED: local command `mix --version`][CITED: https://hexdocs.pm/mix/Mix.html] | The installer already uses `Mix.raise` for invalid invocation and should use the same hard-stop behavior for unsupported adapters. [VERIFIED: lib/mix/tasks/sigra.install.ex] | Use for the refusal surface instead of warnings, telemetry-only notices, or custom exit plumbing. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |
| InstallFixture harness | Repo-local helper, no external version. [VERIFIED: test/support/install_fixture.ex] | End-to-end temp-app scaffolding for install-smoke, idempotency, and golden diff. [VERIFIED: test/support/install_fixture.ex][VERIFIED: test/sigra/install/golden_diff_test.exs][VERIFIED: test/sigra/install/idempotency_test.exs] | Use when the planner needs true “no files written before refusal” evidence or a Postgres acceptance path. [VERIFIED: .planning/ROADMAP.md][VERIFIED: test/support/install_fixture.ex] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Strict adapter allowlist in `Mix.Tasks.Sigra.Install` [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | Keep silent `:postgres` fallback for unknown or unloaded repos [VERIFIED: lib/mix/tasks/sigra.install.ex] | Rejected because the fallback is the current footgun and allows unsupported hosts to proceed into file generation. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |
| Single Postgres-only templates [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | Preserve adapter branches behind partials or helpers [VERIFIED: priv/templates/sigra.install] | Rejected because it keeps dead optionality and leaves the maintainer surface larger than the real support boundary. [VERIFIED: priv/templates/sigra.install][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |
| Behavioral contract tests [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | Continue branch-count assertions and MySQL/SQLite render tests [VERIFIED: test/sigra/install/api_token_generator_test.exs][VERIFIED: test/sigra/templates/session_templates_test.exs][VERIFIED: test/sigra/passkeys/migration_test.exs] | Rejected because the old tests verify dead branches instead of the supported installer contract. [VERIFIED: test/sigra/install/api_token_generator_test.exs][VERIFIED: test/sigra/templates/session_templates_test.exs][VERIFIED: test/sigra/passkeys/migration_test.exs][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |

**Installation:** No new library dependencies are required for HARD-01; the phase should reuse the existing Mix/Phoenix/Ecto/Postgres stack already declared in `mix.exs`. [VERIFIED: mix.exs]

```bash
mix deps.get
```

## Architecture Patterns

### System Architecture Diagram

Current and recommended data flow through the installer chokepoint. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: test/support/install_fixture.ex]

```text
Developer runs `mix sigra.install`
        |
        v
OptionParser + positional arg validation
        |
        v
Repo resolution (`ecto_repos` or fallback repo module)
        |
        v
Adapter detection
        |
        +--> adapter == `Ecto.Adapters.Postgres`
        |         |
        |         v
        |   build binding -> Runner.run/3 -> EEx templates -> files + injections
        |
        +--> adapter == MyXQL / SQLite3 / unknown / undetectable
                  |
                  v
             `Mix.raise` before binding and before any file writes
```

### Recommended Project Structure

The relevant implementation surface is already concentrated in these paths. [VERIFIED: codebase grep]

```text
lib/mix/tasks/sigra.install.ex                 # pre-flight repo lookup, adapter detection, refusal
priv/templates/sigra.install/core/             # core auth/API migration and schema templates
priv/templates/sigra.install/organizations/    # org migration template
priv/templates/sigra.install/passkeys/         # adjacent installer-surface adapter drift
test/mix/tasks/                                # task-level render and argument tests
test/sigra/install/                            # installer contract, golden diff, idempotency, feature tests
test/support/install_fixture.ex                # temp-app harness for file-write / smoke assertions
README.md + guides/introduction/* + mix.exs    # public support-boundary trust surface
```

### Pattern 1: Validate Adapter Before Binding

**What:** Move adapter validation ahead of `build_binding/4` and `Runner.run/3`, returning a small internal result and raising exactly once at the public boundary. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md][VERIFIED: lib/mix/tasks/sigra.install.ex]  
**When to use:** On every `mix sigra.install` invocation after positional arg validation and before any binding or file-emission work. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]

**Example:**
```elixir
# Source: lib/mix/tasks/sigra.install.ex + https://hexdocs.pm/mix/Mix.html
case detect_supported_adapter(repo_module) do
  {:ok, :postgres} ->
    binding = build_binding(context_name, schema_name, table_name, opts)
    {:ok, _report} = Runner.run(@features, binding, opts)

  {:error, adapter_name} ->
    Mix.raise(
      "Sigra supports PostgreSQL only. Detected #{adapter_name}. " <>
        "mix sigra.install cannot continue. See guides/introduction/installation.md."
    )
end
```

### Pattern 2: Keep One Real Migration Path

**What:** Use a single Postgres migration body with Postgres-native types and predicates instead of preserving dormant MySQL/SQLite branches. [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: priv/templates/sigra.install/core/api_token_migration.exs][VERIFIED: priv/templates/sigra.install/organizations/migration.exs]  
**When to use:** For every installer-owned migration template that currently forks on `adapter`. [VERIFIED: codebase grep]

**Example:**
```elixir
# Source: priv/templates/sigra.install/core/migration.exs + https://hexdocs.pm/ecto_sql/Ecto.Migration.html
def up do
  execute "CREATE EXTENSION IF NOT EXISTS citext"

  create table(:users) do
    add :email, :citext, null: false
    add :deleted_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  create unique_index(:users, [:email],
    where: "deleted_at IS NULL",
    name: :users_email_active_index
  )
end
```

### Pattern 3: Use Integration Harnesses Only for Boundary Proofs

**What:** Keep golden diff, idempotency, and install smoke on the supported Postgres path; add exactly one unsupported-adapter regression at the installer boundary. [VERIFIED: test/support/install_fixture.ex][VERIFIED: test/sigra/install/golden_diff_test.exs][VERIFIED: test/sigra/install/idempotency_test.exs][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]  
**When to use:** When a test needs to prove no files were written or that a fresh Phoenix app still installs cleanly. [VERIFIED: test/support/install_fixture.ex]

**Example:**
```elixir
# Source: test/support/install_fixture.ex
{out, status} =
  System.cmd("mix", ["sigra.install", "Accounts", "User", "users", "--yes"],
    cd: app_dir,
    stderr_to_stdout: true,
    env: [{"MIX_ENV", "dev"}]
  )
```

### Anti-Patterns to Avoid

- **Silent unknown-adapter fallback:** The current `detect_adapter/1` fallback to `:postgres` for `_` and unloaded repos is the exact behavior HARD-01 must delete. [VERIFIED: lib/mix/tasks/sigra.install.ex]
- **Half-cleaned installer surface:** Cleaning only three migration files while leaving passkeys, `alter_audit_events_add_org_columns.exs`, or `user_api_token.ex` adapter forks behind will keep docs and tests dishonest. [VERIFIED: priv/templates/sigra.install/passkeys/create_user_passkeys.exs][VERIFIED: priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs][VERIFIED: priv/templates/sigra.install/core/user_api_token.ex]
- **Branch-count tests:** `session_templates_test.exs` currently proves three sections exist by counting `create table(:user_sessions)` occurrences; that is exactly the wrong contract after HARD-01. [VERIFIED: test/sigra/templates/session_templates_test.exs]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Unsupported-adapter error handling | Custom logger/warning flow or manual exit plumbing [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | `Mix.raise` at the task boundary [VERIFIED: lib/mix/tasks/sigra.install.ex][CITED: https://hexdocs.pm/mix/Mix.html] | The installer already uses `Mix.raise`, and the project decision explicitly wants one hard-stop surface. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |
| Postgres DDL emulation for unsupported adapters | New adapter abstraction or fallback DDL shims [VERIFIED: priv/templates/sigra.install][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | Native Postgres-only Ecto migrations [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: priv/templates/sigra.install/core/api_token_migration.exs][VERIFIED: priv/templates/sigra.install/organizations/migration.exs] | The project already relies on Postgres-native capabilities such as `citext`, array columns, and partial indexes. [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: priv/templates/sigra.install/core/api_token_migration.exs][VERIFIED: priv/templates/sigra.install/organizations/migration.exs] |
| Fresh integration rig for refusal/no-write proof | New temp-app scaffolding helpers [VERIFIED: test/support/install_fixture.ex] | `Sigra.Test.InstallFixture` plus a focused refusal test [VERIFIED: test/support/install_fixture.ex][VERIFIED: .planning/ROADMAP.md] | The harness already knows how to create a Phoenix app, patch the path dependency, compile it, and run the installer. [VERIFIED: test/support/install_fixture.ex] |

**Key insight:** HARD-01 is a truth-surface cleanup phase, not a compatibility phase, so the planner should delete optionality rather than encapsulate it. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md][VERIFIED: .planning/REQUIREMENTS.md]

## Common Pitfalls

### Pitfall 1: Refusing Too Late

**What goes wrong:** The task still reaches `build_binding/4` or `Runner.run/3` before discovering the host is unsupported. [VERIFIED: lib/mix/tasks/sigra.install.ex]  
**Why it happens:** Adapter detection currently lives inside `build_binding/4`, and unknown or unloaded repos silently fall back to `:postgres`. [VERIFIED: lib/mix/tasks/sigra.install.ex]  
**How to avoid:** Resolve the repo module, validate the adapter, and raise before binding construction. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]  
**Warning signs:** A non-Postgres refusal test needs to inspect generated files or migration output instead of failing before any writes. [VERIFIED: .planning/ROADMAP.md]

### Pitfall 2: Leaving Adjacent Adapter Drift Behind

**What goes wrong:** Core migrations get cleaned up, but neighboring installer templates or schema files still mention non-Postgres behavior. [VERIFIED: codebase grep]  
**Why it happens:** Adapter branches exist outside the three headline migration files, including passkeys, audit-events, and `user_api_token.ex`. [VERIFIED: priv/templates/sigra.install/passkeys/create_user_passkeys.exs][VERIFIED: priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs][VERIFIED: priv/templates/sigra.install/core/user_api_token.ex]  
**How to avoid:** Use a grep-zero sweep across `priv/templates/sigra.install`, `lib/mix/tasks/sigra.install.ex`, and the relevant tests before closing the phase. [VERIFIED: .planning/ROADMAP.md][VERIFIED: codebase grep]  
**Warning signs:** `rg "adapter == :mysql|adapter == :sqlite|:mysql|:sqlite"` still returns hits in installer-owned paths after the main edits. [VERIFIED: codebase grep]

### Pitfall 3: Updating Templates Without Updating Trust Surfaces

**What goes wrong:** The code becomes Postgres-only but README, Installation, Hex metadata, or CHANGELOG still imply a wider support matrix. [VERIFIED: README.md][VERIFIED: guides/introduction/installation.md][VERIFIED: mix.exs][VERIFIED: CHANGELOG.md]  
**Why it happens:** The current support boundary is described in multiple public entry points, and they already disagree. [VERIFIED: README.md][VERIFIED: guides/introduction/installation.md][VERIFIED: guides/introduction/getting-started.md][VERIFIED: mix.exs]  
**How to avoid:** Treat README, Installation, Getting Started, First Hour, `mix.exs`, and `[Unreleased]` CHANGELOG as one change set. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]  
**Warning signs:** The package description stays generic while guides say “PostgreSQL only,” or vice versa. [VERIFIED: mix.exs][VERIFIED: guides/introduction/installation.md]

### Pitfall 4: Assuming the Existing Test Slice Is Clean

**What goes wrong:** The planner assumes all nearby tests are green and builds verification on top of them. [VERIFIED: local command `mix test …`]  
**Why it happens:** A phase-relevant slice currently has one pre-existing failure in `Sigra.Install.Features.OrganizationsTest`, where `migrations/1` returns three slots but the test still expects two. [VERIFIED: local command `MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs test/sigra/passkeys/migration_test.exs test/sigra/install/api_token_generator_test.exs test/sigra/templates/session_templates_test.exs test/sigra/install/features/organizations_test.exs`]  
**How to avoid:** Either fold that stale expectation into the phase’s test realignment or choose a narrower quick-run command that excludes unrelated drift. [VERIFIED: local command `mix test …`][VERIFIED: test/sigra/install/features/organizations_test.exs]  
**Warning signs:** Quick-run verification fails before reaching any HARD-01 assertion. [VERIFIED: local command `mix test …`]

## Code Examples

Verified patterns from official sources and the codebase:

### Pre-flight Refusal in a Mix Task

```elixir
# Source: lib/mix/tasks/sigra.install.ex + https://hexdocs.pm/mix/Mix.html
case parsed do
  [context_name, schema_name, table_name] ->
    validate_args!(context_name, schema_name, table_name)
    validate_supported_adapter!(get_repo_module(Mix.Phoenix.otp_app()))
    binding = build_binding(context_name, schema_name, opts[:table] || table_name, opts)
    {:ok, _report} = Runner.run(@features, binding, opts)

  _ ->
    Mix.raise("Expected exactly 3 arguments: context_name schema_name table_name")
end
```

### Postgres-native Partial Index

```elixir
# Source: priv/templates/sigra.install/organizations/migration.exs + https://hexdocs.pm/ecto_sql/Ecto.Migration.html
create unique_index(:organization_invitations, [:organization_id, :email],
  where: "accepted_at IS NULL AND revoked_at IS NULL",
  name: :organization_invitations_pending_index
)
```

### Temp-app Installer Harness

```elixir
# Source: test/support/install_fixture.ex
{:ok, %{app_dir: app_dir}} = Sigra.Test.InstallFixture.setup_tmp_app_without_install()
{out, status} =
  System.cmd("mix", ["sigra.install", "Accounts", "User", "users", "--yes"],
    cd: app_dir,
    stderr_to_stdout: true,
    env: [{"MIX_ENV", "dev"}]
  )
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Placeholder multi-adapter generator branches in core templates [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: priv/templates/sigra.install/core/api_token_migration.exs][VERIFIED: priv/templates/sigra.install/organizations/migration.exs] | Explicit Postgres-only installer and templates [VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | Planned for Phase 94 on 2026-04-30. [VERIFIED: .planning/ROADMAP.md][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | Shrinks maintenance surface and aligns docs, metadata, and executable behavior. [VERIFIED: .planning/REQUIREMENTS.md] |
| Raw-template branch-count assertions [VERIFIED: test/sigra/templates/session_templates_test.exs] | Behavioral contract tests on supported Postgres output and unsupported-adapter refusal [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | Planned for Phase 94 on 2026-04-30. [VERIFIED: .planning/ROADMAP.md] | Tests become smaller and better aligned with the real maintainer contract. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |

**Deprecated/outdated:**

- Silent unknown-to-Postgres fallback in `detect_adapter/1` is outdated for HARD-01 because it keeps unsupported hosts on the happy path. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/REQUIREMENTS.md]
- “Primary supported adapter” wording is outdated in Installation once the installer refuses non-Postgres hosts. [VERIFIED: guides/introduction/installation.md][VERIFIED: .planning/REQUIREMENTS.md]

## Assumptions Log

All claims in this research were verified or cited in this session. No user confirmation is required for factual accuracy before planning. [VERIFIED: source audit]

## Open Questions

1. **Should the phase clean adjacent passkeys/audit/API-token adapter drift or defer it?**
   - What we know: Adapter-conditioned installer files still exist in passkeys, `alter_audit_events_add_org_columns.exs`, and `user_api_token.ex`; the discuss-phase context explicitly warns not to stop at the first three files if adjacent installer drift remains. [VERIFIED: priv/templates/sigra.install/passkeys/create_user_passkeys.exs][VERIFIED: priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs][VERIFIED: priv/templates/sigra.install/core/user_api_token.ex][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
   - What's unclear: Whether the planner wants those adjacent files as required scope or as stretch cleanup under the same grep-zero gate. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
   - Recommendation: Treat them as in-scope because they are installer-surface honesty leaks, and the grep-zero success criterion already points in that direction. [VERIFIED: .planning/ROADMAP.md][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]

2. **Where should the refusal regression live?**
   - What we know: The context allows exact file-name discretion, and the repo already has both task-level tests and temp-app harness integration tests. [VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md][VERIFIED: test/mix/tasks/sigra.install_test.exs][VERIFIED: test/support/install_fixture.ex]
   - What's unclear: Whether the cleanest proof is a task-level adapter stub test, a temp-app no-write test, or one of each. [VERIFIED: test/mix/tasks/sigra.install_test.exs][VERIFIED: test/support/install_fixture.ex]
   - Recommendation: Keep one task-level refusal regression for fast feedback and only use the temp-app harness if the planner needs explicit “no files written” proof. [VERIFIED: test/mix/tasks/sigra.install_test.exs][VERIFIED: test/support/install_fixture.ex][VERIFIED: .planning/ROADMAP.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Mix task edits and test execution | ✓ [VERIFIED: local command `elixir --version`] | `1.19.5` [VERIFIED: local command `elixir --version`] | — |
| Mix | Installer and tests | ✓ [VERIFIED: local command `mix --version`] | `1.19.5` [VERIFIED: local command `mix --version`] | — |
| PostgreSQL server on localhost | Full test suite and real host install validation | ✓ [VERIFIED: local command `pg_isready`] | accepting connections on `:5432` [VERIFIED: local command `pg_isready`] | Docker container if local service is absent. [VERIFIED: CLAUDE.md] |
| `psql` | Manual DB inspection / troubleshooting | ✓ [VERIFIED: local command `psql --version`] | `14.17` [VERIFIED: local command `psql --version`] | — |
| Docker | Disposable Postgres for local verification | ✓ [VERIFIED: local command `docker --version`] | `29.4.0` [VERIFIED: local command `docker --version`] | Existing local Postgres service. [VERIFIED: local command `pg_isready`] |

**Missing dependencies with no fallback:** None. [VERIFIED: local environment probes]

**Missing dependencies with fallback:**
- None in this workspace. [VERIFIED: local environment probes]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir `1.19.5`. [VERIFIED: test/test_helper.exs][VERIFIED: local command `elixir --version`] |
| Config file | `test/test_helper.exs`. [VERIFIED: test/test_helper.exs] |
| Quick run command | `MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs test/sigra/passkeys/migration_test.exs test/sigra/install/api_token_generator_test.exs test/sigra/templates/session_templates_test.exs` [VERIFIED: repo test layout] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HARD-01 | Refuse MyXQL, SQLite3, unknown, and undetectable adapters before writes; allow Postgres. [VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: .planning/ROADMAP.md] | unit or focused integration | `MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs` or new `test/sigra/install/postgres_only_test.exs` [VERIFIED: test/mix/tasks/sigra.install_test.exs][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] | ❌ new refusal regression needed |
| HARD-01 | Postgres-only migration and schema templates no longer contain adapter branches. [VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: .planning/ROADMAP.md] | unit | `MIX_ENV=test mix test test/sigra/passkeys/migration_test.exs test/sigra/install/api_token_generator_test.exs test/sigra/templates/session_templates_test.exs test/sigra/install/features/organizations_test.exs` [VERIFIED: repo test layout] | ✅ existing files need rewrite |
| HARD-01 | Installer still works on supported Postgres path. [VERIFIED: .planning/ROADMAP.md] | integration | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` and CI `mix ci.install_golden` [VERIFIED: test/sigra/install/golden_diff_test.exs][VERIFIED: test/sigra/install/idempotency_test.exs][VERIFIED: mix.exs] | ✅ |
| HARD-01 | README / guides / metadata / changelog stay aligned. [VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: .planning/ROADMAP.md] | grep/manual doc contract | `rg -n "PostgreSQL only|primary supported adapter|other adapters" README.md guides/introduction mix.exs CHANGELOG.md .planning/PROJECT.md` [VERIFIED: current grep results] | ✅ files exist; assertions need update |

### Sampling Rate

- **Per task commit:** `MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs test/sigra/passkeys/migration_test.exs test/sigra/install/api_token_generator_test.exs test/sigra/templates/session_templates_test.exs` [VERIFIED: repo test layout]
- **Per wave merge:** `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` [VERIFIED: test/sigra/install/golden_diff_test.exs][VERIFIED: test/sigra/install/idempotency_test.exs]
- **Phase gate:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md]

### Wave 0 Gaps

- [ ] `test/sigra/install/postgres_only_test.exs` or equivalent — installer refusal contract for MyXQL, SQLite3, unknown, undetectable, and Postgres acceptance. [VERIFIED: .planning/ROADMAP.md][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md]
- [ ] Rewrite `test/sigra/passkeys/migration_test.exs`, `test/sigra/install/api_token_generator_test.exs`, `test/sigra/templates/session_templates_test.exs`, and the adapter-related assertions in `test/mix/tasks/sigra.install_test.exs` to remove MySQL/SQLite expectations. [VERIFIED: test/sigra/passkeys/migration_test.exs][VERIFIED: test/sigra/install/api_token_generator_test.exs][VERIFIED: test/sigra/templates/session_templates_test.exs][VERIFIED: test/mix/tasks/sigra.install_test.exs]
- [ ] Decide whether to fix the pre-existing stale expectation in `test/sigra/install/features/organizations_test.exs` as part of this phase’s test realignment or exclude it from the quick run. [VERIFIED: local command `mix test …`][VERIFIED: test/sigra/install/features/organizations_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: phase scope] | This phase does not change runtime auth flows. [VERIFIED: .planning/REQUIREMENTS.md] |
| V3 Session Management | no [VERIFIED: phase scope] | Session behavior is unaffected; only generator support claims are being narrowed. [VERIFIED: .planning/REQUIREMENTS.md] |
| V4 Access Control | no [VERIFIED: phase scope] | No runtime authorization change is in scope. [VERIFIED: .planning/REQUIREMENTS.md] |
| V5 Input Validation | yes [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/REQUIREMENTS.md] | Validate args and adapter allowlist before file writes using explicit checks plus `Mix.raise`. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |
| V6 Cryptography | yes [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: .planning/PROJECT.md] | Keep Postgres-only migration constructs that underpin auth data integrity, including `citext`-based email columns and Postgres-specific indexes already assumed by Sigra’s documented path. [VERIFIED: priv/templates/sigra.install/core/migration.exs][VERIFIED: README.md][VERIFIED: CLAUDE.md] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unsupported adapter proceeds and generates broken host code | Tampering / DoS | Hard-stop in `mix sigra.install` before binding or file writes. [VERIFIED: lib/mix/tasks/sigra.install.ex][VERIFIED: .planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md] |
| Public docs promise broader support than executable code | Spoofing | Keep README, Installation, Getting Started, First Hour, `mix.exs`, and CHANGELOG aligned in one phase. [VERIFIED: README.md][VERIFIED: guides/introduction/installation.md][VERIFIED: guides/introduction/getting-started.md][VERIFIED: mix.exs][VERIFIED: CHANGELOG.md] |
| Dead fallback branches mask regressions | Repudiation | Delete MySQL/SQLite branches and replace branch-count tests with supported-contract assertions. [VERIFIED: priv/templates/sigra.install][VERIFIED: test/sigra/install/api_token_generator_test.exs][VERIFIED: test/sigra/templates/session_templates_test.exs][VERIFIED: test/sigra/passkeys/migration_test.exs] |

## Sources

### Primary (HIGH confidence)

- `lib/mix/tasks/sigra.install.ex` - current installer flow, `detect_adapter/1`, and existing `Mix.raise` usage. [VERIFIED: codebase grep]
- `priv/templates/sigra.install/core/migration.exs` - Postgres-specific `citext` and partial-index template path plus current MySQL/SQLite branches. [VERIFIED: codebase grep]
- `priv/templates/sigra.install/core/api_token_migration.exs` - Postgres array scopes versus MySQL/SQLite string scopes. [VERIFIED: codebase grep]
- `priv/templates/sigra.install/organizations/migration.exs` - Postgres partial-index path and current non-Postgres fallback branch. [VERIFIED: codebase grep]
- `priv/templates/sigra.install/passkeys/create_user_passkeys.exs` - adjacent installer-surface adapter branch on `:aaguid`. [VERIFIED: codebase grep]
- `priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` - adjacent Postgres/non-Postgres migration divergence. [VERIFIED: codebase grep]
- `priv/templates/sigra.install/core/user_api_token.ex` - adjacent Postgres/non-Postgres schema divergence. [VERIFIED: codebase grep]
- `test/support/install_fixture.ex` - temp-app install harness. [VERIFIED: codebase grep]
- `test/sigra/install/golden_diff_test.exs` and `test/sigra/install/idempotency_test.exs` - supported-path integration contract. [VERIFIED: codebase grep]
- `test/mix/tasks/sigra.install_test.exs`, `test/sigra/install/api_token_generator_test.exs`, `test/sigra/templates/session_templates_test.exs`, `test/sigra/passkeys/migration_test.exs` - current adapter-matrix test surface. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/phases/94-postgres-only-declaration-hard-01/94-CONTEXT.md` - requirement, success criteria, milestone framing, and user decisions. [VERIFIED: planning docs]
- `README.md`, `guides/introduction/installation.md`, `guides/introduction/getting-started.md`, `CHANGELOG.md`, `mix.exs`, `CLAUDE.md` - current trust-surface wording and project constraints. [VERIFIED: codebase grep]
- https://hexdocs.pm/ecto_sql/Ecto.Migration.html - official Ecto migration API for `unique_index/3` and migration constructs. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html]
- https://hexdocs.pm/mix/Mix.html - official Mix docs for `Mix.raise/1` and `Mix.raise/2`. [CITED: https://hexdocs.pm/mix/Mix.html]
- https://hex.pm/api/packages/phoenix - current Phoenix stable version and publish date. [VERIFIED: npm-like registry equivalent, Hex API]
- https://hex.pm/api/packages/ecto - current Ecto stable version and publish date. [VERIFIED: npm-like registry equivalent, Hex API]
- https://hex.pm/api/packages/ecto_sql - current Ecto SQL stable version and publish date. [VERIFIED: npm-like registry equivalent, Hex API]
- https://hex.pm/api/packages/postgrex - current Postgrex stable version and publish date. [VERIFIED: npm-like registry equivalent, Hex API]
- https://hex.pm/api/packages/nimble_options - current NimbleOptions stable version and publish date. [VERIFIED: npm-like registry equivalent, Hex API]

### Secondary (MEDIUM confidence)

- None. All non-codebase claims used official docs or registry APIs. [VERIFIED: source audit]

### Tertiary (LOW confidence)

- None. [VERIFIED: source audit]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - versions were verified against `mix.exs` and live Hex package APIs. [VERIFIED: mix.exs][VERIFIED: Hex package APIs]
- Architecture: HIGH - the installer chokepoint, template branches, and verification harnesses were inspected directly in the codebase. [VERIFIED: codebase grep]
- Pitfalls: HIGH - each pitfall maps to concrete current code, tests, docs, or a reproduced local test failure. [VERIFIED: codebase grep][VERIFIED: local command `mix test …`]

**Research date:** 2026-04-30  
**Valid until:** 2026-05-30 for codebase findings; re-check Hex versions sooner if the phase slips past that date. [VERIFIED: research date][VERIFIED: task output-format policy]
