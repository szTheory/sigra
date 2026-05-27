# Phase 128: Account Deletion Lifecycle Truth - Research

**Researched:** 2026-05-27 [VERIFIED: system date]
**Domain:** Elixir account lifecycle semantics, Ecto transactional updates, optional Oban worker enqueueing [VERIFIED: `.planning/ROADMAP.md`, `lib/sigra/account/deletion.ex`, `lib/sigra/workers/account_deletion.ex`]
**Confidence:** HIGH [VERIFIED: repo code, phase context, Hex package metadata, official HexDocs]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Enqueue Ownership
- **D-01:** Keep scheduled deletion job creation in the library-owned `Sigra.Account.Deletion.schedule/3` path.
- **D-02:** When `Oban`, `Sigra.Workers.AccountDeletion`, and generated-host job context such as `:user_schema` are available, scheduling must enqueue `Sigra.Workers.AccountDeletion` for the computed `scheduled_deletion_at`.
- **D-03:** Missing job context or missing Oban support should safely degrade without failing the schedule operation, but the degradation must remain explicit enough for tests and operator documentation to stay truthful.

### Active-Scheduled Predicate
- **D-04:** An actively scheduled deletion means both `deleted_at` and `scheduled_deletion_at` are present.
- **D-05:** Cancel and execute must return `{:error, :not_scheduled}` for users with no deletion markers and for finalized soft-deleted users where `deleted_at` is set but `scheduled_deletion_at` is nil.
- **D-06:** Worker execution should use the same active-scheduled predicate, so stale jobs created before cancellation become no-ops instead of re-finalizing or reactivating the wrong state.

### Soft-Delete Finalization Truth
- **D-07:** Soft-delete execution preserves the user row and `deleted_at`.
- **D-08:** Soft-delete execution must clear `scheduled_deletion_at`, `pending_email`, and `original_email` so finalized rows are no longer interpreted as pending deletion and do not retain email-change staging fields.
- **D-09:** Operator-facing surfaces must not claim the user row was hard-deleted or permanently removed when the configured strategy is `:soft_delete`.

### Contract Boundary
- **D-10:** Repair lifecycle semantics in the existing `Sigra.Account`, `Sigra.Account.Deletion`, `Sigra.Auth`, and `Sigra.Workers.AccountDeletion` path rather than moving behavior into generated host code.
- **D-11:** Generated templates and example app wrappers should remain thin providers of repo, schema, scope, audit, token, and session context for the library contract.
- **D-12:** Keep lifecycle truth aligned with Phase 127 export semantics and `Sigra.Account.Deletion.status/1`; do not infer host-domain retention or generic compliance behavior.

### the agent's Discretion
- Exact helper names and test organization for enqueue proof.
- Whether to prove enqueue behavior through fake repo insertion, Oban changeset assertions, or a focused integration test, as long as `scheduled_at`, worker module, and args are pinned.
- Exact warning/log message wording for no-op job degradation, if implementation needs to surface it.

### Folded Todos
None.

### Claude's Discretion
Exact helper names and test organization for enqueue proof.
Whether to prove enqueue behavior through fake repo insertion, Oban changeset assertions, or a focused integration test, as long as `scheduled_at`, worker module, and args are pinned.
Exact warning/log message wording for no-op job degradation, if implementation needs to surface it.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

Generated-host, example-app, install-golden, and public docs parity are Phase 129 unless Phase 128 implementation needs a narrow template/context propagation fix to prove `LIFE-01`.

### Reviewed Todos (not folded)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LIFE-01 | User deletion scheduling enqueues `Sigra.Workers.AccountDeletion` for the scheduled time when Oban and generated-host context are available, while safely degrading when job context is absent. [VERIFIED: `.planning/REQUIREMENTS.md`] | `Sigra.Account.Deletion.schedule/3` already calls `maybe_enqueue_deletion_job/4`; planner should add/repair proof around `repo.insert(changeset)` and `deletion_job_args/3`. [VERIFIED: `lib/sigra/account/deletion.ex`] |
| LIFE-02 | User deletion cancel and execute paths only apply to actively scheduled deletions; already-finalized users return `{:error, :not_scheduled}`. [VERIFIED: `.planning/REQUIREMENTS.md`] | `Deletion.scheduled?/1` already defines active schedule as both timestamps present; tests already cover finalized rejection and should be preserved or extended through `Sigra.Account`/worker paths. [VERIFIED: `lib/sigra/account/deletion.ex`, `test/sigra/account/deletion_test.exs`] |
| LIFE-03 | Soft-delete finalization clears scheduled deletion state and pending/original email fields without claiming the user row was hard-deleted. [VERIFIED: `.planning/REQUIREMENTS.md`] | `build_execute_multi(:soft_delete, ...)` updates `scheduled_deletion_at`, `pending_email`, and `original_email` to nil and does not delete the user row; docs/testing helpers may need narrow truth alignment later. [VERIFIED: `lib/sigra/account/deletion.ex`, `guides/flows/account-lifecycle.md`, `lib/sigra/testing.ex`] |
</phase_requirements>

## Summary

Phase 128 should be planned as a narrow lifecycle-contract repair inside the existing library path, not a generated-host rewrite. The locked scope says scheduling, cancellation, execution, and worker no-op semantics belong in `Sigra.Account.Deletion`, surfaced through `Sigra.Account`, `Sigra.Auth`, and `Sigra.Workers.AccountDeletion`. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`, `lib/sigra/account.ex`, `lib/sigra/auth.ex`, `lib/sigra/workers/account_deletion.ex`]

The current code already has the right active-scheduled predicate and soft-delete field clearing in the core module, but the planner must prove those semantics through the correct public and worker paths. [VERIFIED: `lib/sigra/account/deletion.ex`, `test/sigra/account/deletion_test.exs`, `test/sigra/workers/account_deletion_test.exs`] The highest-risk gap is enqueue truth: `schedule/3` builds an Oban job changeset and calls `repo.insert/1` only after the deletion transaction commits, but existing tests do not pin the generated job shape. [VERIFIED: `lib/sigra/account/deletion.ex`, local `MIX_ENV=test mix run` inspection]

**Primary recommendation:** Add focused tests first around `Sigra.Account.Deletion.schedule/3` with full generated-host context, asserting the inserted Oban changeset pins `worker`, `queue`, `scheduled_at`, `replace`, and args, then make only the smallest code/context propagation edits needed to satisfy `LIFE-01..03`. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`, local `MIX_ENV=test mix run` inspection]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Schedule deletion lifecycle state | API / Backend library | Database / Storage | `Sigra.Account.Deletion.schedule/3` owns setting `deleted_at`, `scheduled_deletion_at`, `original_email`, clearing `pending_email`, deleting tokens, and calling enqueue logic. [VERIFIED: `lib/sigra/account/deletion.ex`] |
| Enqueue account-deletion worker | API / Backend library | Background job system | `maybe_enqueue_deletion_job/4` builds `Sigra.Workers.AccountDeletion` through `Sigra.Workers.new/3` and inserts the changeset through the repo when Oban and `:user_schema` exist. [VERIFIED: `lib/sigra/account/deletion.ex`, `lib/sigra/workers.ex`] |
| Cancel deletion | API / Backend library | Database / Storage | `Deletion.cancel/3` gates on `scheduled?/1` and updates the user lifecycle fields through an Ecto.Multi. [VERIFIED: `lib/sigra/account/deletion.ex`] |
| Execute deletion | API / Backend library | Database / Storage | `Deletion.execute/3` gates on `scheduled?/1`, selects strategy from config, and builds strategy-specific Ecto.Multi operations. [VERIFIED: `lib/sigra/account/deletion.ex`] |
| Stale worker no-op | Background job worker | API / Backend library | `Sigra.Workers.AccountDeletion.perform/2` reloads the user and returns `{:ok, :not_scheduled}` when `Deletion.scheduled?/1` is false. [VERIFIED: `lib/sigra/workers/account_deletion.ex`] |
| Lifecycle export/status truth | API / Backend library | Phase 127 export surface | `Sigra.Account.Deletion.status/1` is the shared interpretation used by Phase 127 export work and must remain aligned with finalized soft-delete semantics. [VERIFIED: `.planning/phases/127-versioned-auth-data-export/127-RESEARCH.md`, `lib/sigra/account/deletion.ex`] |

## Project Constraints (from CLAUDE.md)

- Target Phoenix 1.8+ and Ecto 3.x as the blessed path; Plug compatibility is secondary where DX is not compromised. [VERIFIED: `CLAUDE.md`]
- PostgreSQL is the primary database target; account lifecycle proof can rely on Ecto/Postgres behavior already present in tests. [VERIFIED: `CLAUDE.md`, `test/test_helper.exs`]
- Security-sensitive code belongs in the library, while generated schemas/context wrappers remain host-owned and thin. [VERIFIED: `CLAUDE.md`, `128-CONTEXT.md`]
- Keep dependencies minimal; do not introduce a new dependency for this phase. [VERIFIED: `CLAUDE.md`, `mix.exs`]
- Tests should cover happy path, main error cases, and boundary conditions in flat, self-contained AAA style. [VERIFIED: `CLAUDE.md`, `test/sigra/account/deletion_test.exs`]
- `mix test` requires a live Postgres at `localhost:5432` with `postgres`/`postgres`; this machine currently has PostgreSQL accepting connections at that host/port. [VERIFIED: `CLAUDE.md`, `test/test_helper.exs`, `pg_isready`]
- GSD workflow guidance says direct repo edits should happen through a GSD workflow; this research artifact is itself part of the GSD phase workflow. [VERIFIED: `CLAUDE.md`, user objective]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 on OTP 28 locally; project minimum `~> 1.18` | Runtime and build/test runner | Existing project is an Elixir library and local environment matches modern BEAM tooling. [VERIFIED: `elixir --version`, `mix.exs`] |
| Ecto | Locked 3.13.5; latest Hex 3.14.0 | Changesets and transactional lifecycle updates | Existing lifecycle code uses `Ecto.Multi`, changesets, and repo transactions; official docs define Multi as grouping repo operations in one transaction. [VERIFIED: `mix deps`, `mix hex.info ecto`, cited HexDocs `https://hexdocs.pm/ecto/Ecto.Multi.html`] |
| Oban | Locked 2.21.1; latest Hex 2.22.1 | Optional delayed account-deletion worker | Existing worker uses `use Oban.Worker`; official docs support `queue`, `max_attempts`, `unique`, `replace`, and runtime `new/2` options. [VERIFIED: `mix deps`, `mix hex.info oban`, cited HexDocs `https://hexdocs.pm/oban/Oban.Worker.html`] |
| Mox | Locked 1.2.0 | Mock repo/session store proof | Existing tests define `Sigra.MockRepo` and `Sigra.MockSessionStore` with Mox, including `insert/1` and `transaction/1` callbacks needed for enqueue proof. [VERIFIED: `mix hex.info mox`, `test/test_helper.exs`, `test/support/mock_repo_behaviour.ex`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix | Locked 1.8.5; latest Hex 1.8.7 | Generated-host target framework | No direct Phase 128 code should require Phoenix changes, but generated-host context is the source of repo/schema/scope inputs. [VERIFIED: `mix deps`, `mix hex.info phoenix`, `priv/templates/sigra.install/core/auth.ex`] |
| Postgrex/Postgres | `postgrex ~> 0.17` in test; local `psql` 14.17 | Integration tests using `Sigra.Test.PostgresRepo` | Use only if planner chooses a database-backed integration proof; unit tests can prove enqueue changeset with Mox faster. [VERIFIED: `mix.exs`, `psql --version`, `test/sigra/account_audit_atomicity_test.exs`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Mox fake repo enqueue proof | Full Oban integration test with a real `oban_jobs` table | Full integration proves insert persistence but adds setup cost; Mox can pin the exact changeset shape within the existing unit-test pattern. [VERIFIED: `test/sigra/account/deletion_test.exs`, `test/support/mock_repo_behaviour.ex`, local changeset inspection] |
| Library-owned enqueue in `Deletion.schedule/3` | Generated host manually enqueues `Sigra.Workers.AccountDeletion` | Rejected by locked D-01/D-10; generated hosts should pass context, not own lifecycle semantics. [VERIFIED: `128-CONTEXT.md`] |
| Custom scheduler/state machine | Oban worker changeset through existing `Sigra.Workers.AccountDeletion.new/2` | Existing Oban worker already has queue, unique key, retry, and stale-job no-op behavior; custom scheduling would duplicate background job semantics. [VERIFIED: `lib/sigra/workers/account_deletion.ex`, cited HexDocs `https://hexdocs.pm/oban/Oban.Worker.html`] |

**Installation:**
```bash
# No new packages are recommended for Phase 128.
mix deps.get
```

**Version verification:** `mix hex.info oban`, `mix hex.info ecto`, `mix hex.info phoenix`, and `mix hex.info mox` were run on 2026-05-27. [VERIFIED: command output]

## Architecture Patterns

### System Architecture Diagram

```text
User/operator action
  -> Generated host wrapper passes config + repo + schemas + scope
  -> Sigra.Auth.schedule_deletion/3
  -> Sigra.Account.schedule_deletion/3
  -> Sigra.Account.Deletion.schedule/3
       -> active-state guard: deleted_at nil?
       -> Ecto.Multi updates user lifecycle fields and deletes tokens
       -> repo.transaction(multi)
       -> after commit: revoke sessions
       -> if Oban + worker + user_schema context exist:
            Sigra.Workers.AccountDeletion.new(args, scheduled_at: scheduled_deletion_at)
            -> repo.insert(job_changeset)
          else:
            safe no-op degradation

Cancel path
  -> Sigra.Account.Deletion.cancel/3
  -> scheduled?(user)?
       true: clear deleted_at/scheduled_deletion_at/original_email
       false: {:error, :not_scheduled}

Worker execute path
  -> Oban calls Sigra.Workers.AccountDeletion.perform/1
  -> reload user from repo/schema args
  -> scheduled?(user)?
       false: {:ok, :not_scheduled}
       true: Sigra.Account.execute_deletion/3
         -> Sigra.Account.Deletion.execute/3
         -> strategy branch:
              :soft_delete clears scheduled_deletion_at/pending_email/original_email
              :hard_delete deletes Sigra tokens and user row
              :anonymize clears selected Sigra-owned PII and scheduled state
```

### Recommended Project Structure

```text
lib/sigra/
├── account/deletion.ex             # Primary schedule/cancel/execute/enqueue contract
├── account.ex                      # Public account lifecycle wrapper + audit co-fate
├── auth.ex                         # Config-aware generated-host-facing entrypoint
├── workers/account_deletion.ex     # Oban worker execution and stale-job no-op
└── workers.ex                      # Sigra-aware worker arg validation

test/sigra/
├── account/deletion_test.exs       # Unit proof for lifecycle state and enqueue changeset
├── workers/account_deletion_test.exs # Worker no-op and arg contract proof
└── account_audit_atomicity_test.exs  # Audit co-fate regression protection
```

### Pattern 1: Single Active-Scheduled Predicate

**What:** Treat a deletion as actively scheduled only when both `deleted_at` and `scheduled_deletion_at` are present. [VERIFIED: `lib/sigra/account/deletion.ex`]

**When to use:** Use this predicate in cancel, execute, worker execution, and status interpretation; do not duplicate conditionals in generated host code. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`, `lib/sigra/workers/account_deletion.ex`]

**Example:**
```elixir
# Source: lib/sigra/account/deletion.ex
def scheduled?(user) do
  not is_nil(user.deleted_at) and not is_nil(user.scheduled_deletion_at)
end
```

### Pattern 2: Enqueue After Domain Transaction Commit

**What:** `Deletion.schedule/3` commits lifecycle field updates and token deletion first, then revokes sessions and tries to enqueue the worker. [VERIFIED: `lib/sigra/account/deletion.ex`]

**When to use:** Keep worker enqueue outside the `Ecto.Multi` used for domain lifecycle updates because locked D-03 requires safe degradation without failing the schedule operation. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`]

**Example:**
```elixir
# Source: lib/sigra/account/deletion.ex
case repo.transaction(multi) do
  {:ok, %{user: updated_user}} ->
    revoke_sessions(user, opts)
    maybe_enqueue_deletion_job(repo, updated_user, scheduled_deletion_at, opts)
    {:ok, updated_user, scheduled_deletion_at}
end
```

### Pattern 3: Pin Oban Changeset Shape in Unit Tests

**What:** Assert `repo.insert/1` receives a valid `Oban.Job` changeset with the expected worker, queue, args, scheduled time, and replacement rule. [VERIFIED: local `MIX_ENV=test mix run` inspection, `lib/sigra/account/deletion.ex`]

**When to use:** Use for `LIFE-01` because it avoids a full Oban supervision/table setup while proving exactly what the library enqueues. [VERIFIED: `test/sigra/account/deletion_test.exs`, `test/support/mock_repo_behaviour.ex`]

**Example:**
```elixir
# Source: local test inspection of Sigra.Workers.AccountDeletion.new/2
Sigra.MockRepo
|> expect(:insert, fn changeset ->
  assert changeset.valid?
  assert Ecto.Changeset.get_field(changeset, :worker) == "Sigra.Workers.AccountDeletion"
  assert Ecto.Changeset.get_field(changeset, :queue) == "sigra_lifecycle"
  assert Ecto.Changeset.get_field(changeset, :scheduled_at) == scheduled_at
  assert Ecto.Changeset.get_field(changeset, :replace) == [scheduled: [:scheduled_at, :args]]
  assert Ecto.Changeset.get_field(changeset, :args)["user_schema"] == "Sigra.TestUser"
  {:ok, %Oban.Job{}}
end)
```

### Anti-Patterns to Avoid

- **Moving enqueue to generated host code:** This violates D-01/D-10 and would create lifecycle drift between apps. [VERIFIED: `128-CONTEXT.md`]
- **Checking only `deleted_at` for cancel/execute:** Finalized soft-deleted users have `deleted_at` set but are not active scheduled deletions. [VERIFIED: `lib/sigra/account/deletion.ex`, `test/sigra/account/deletion_test.exs`]
- **Claiming soft-delete removed the row:** Soft-delete finalization preserves the user row and should clear scheduled/staging fields without over-claiming permanent removal. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`, `guides/flows/account-lifecycle.md`]
- **Using `String.to_atom/1` for worker strategy:** Existing worker uses `String.to_existing_atom/1`; keep that atom-safety mitigation. [VERIFIED: `lib/sigra/workers/account_deletion.ex`, `test/sigra/workers/account_deletion_test.exs`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Delayed deletion execution | Custom timer, cron table, or ad hoc process | `Sigra.Workers.AccountDeletion` with Oban changeset | Oban already supports worker callbacks, retry results, queue names, uniqueness, scheduled jobs, and replacement rules. [VERIFIED: `lib/sigra/workers/account_deletion.ex`, cited HexDocs `https://hexdocs.pm/oban/Oban.Worker.html`] |
| Multi-step lifecycle persistence | Independent repo calls without transaction grouping | `Ecto.Multi` | Ecto.Multi groups operations that should run in one transaction and exposes named success/failure results. [CITED: `https://hexdocs.pm/ecto/Ecto.Multi.html`] |
| Active scheduled state | Local boolean flags or generated-host copies | `Sigra.Account.Deletion.scheduled?/1` | The predicate is already the shared library source of truth for cancel, execute, worker, and status semantics. [VERIFIED: `lib/sigra/account/deletion.ex`, `lib/sigra/workers/account_deletion.ex`] |
| Worker arg validation | Hand-built map validation per call site | `Sigra.Workers.new/3` and worker `fetch_arg!/2` | Existing behavior enforces required string keys and nil-vs-absent semantics consistently. [VERIFIED: `lib/sigra/workers.ex`, `lib/sigra/workers/account_deletion.ex`] |

**Key insight:** Phase 128 is a truth and proof phase over existing lifecycle seams; custom abstractions would increase drift from Phase 127 export status and generated-host wrappers. [VERIFIED: `.planning/phases/127-versioned-auth-data-export/127-RESEARCH.md`, `128-CONTEXT.md`]

## Common Pitfalls

### Pitfall 1: Finalized Soft-Delete Looks Like Scheduled Deletion

**What goes wrong:** Code treats `deleted_at != nil` as actively scheduled and allows cancel or execute after finalization. [VERIFIED: `128-CONTEXT.md`, `test/sigra/account/deletion_test.exs`]
**Why it happens:** Scheduling sets `deleted_at` immediately, while final soft-delete preserves `deleted_at` but clears `scheduled_deletion_at`. [VERIFIED: `lib/sigra/account/deletion.ex`]
**How to avoid:** Use `Deletion.scheduled?/1` everywhere. [VERIFIED: `lib/sigra/account/deletion.ex`, `lib/sigra/workers/account_deletion.ex`]
**Warning signs:** New checks like `if user.deleted_at` in cancellation, execution, worker, export, or templates. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`]

### Pitfall 2: Silent Enqueue Non-Proof

**What goes wrong:** Schedule tests assert field changes but never prove a worker job was built or inserted. [VERIFIED: `test/sigra/account/deletion_test.exs`, `lib/sigra/account/deletion.ex`]
**Why it happens:** `maybe_enqueue_deletion_job/4` intentionally degrades to `:ok` when context is missing, so schedule return values do not prove enqueue. [VERIFIED: `lib/sigra/account/deletion.ex`, `128-CONTEXT.md`]
**How to avoid:** Add a full-context test with `user_schema`, `scope`, `scope_module`, `organization_schema`, `audit_schema`, token/session schemas, and an `expect(:insert, ...)` assertion. [VERIFIED: `lib/sigra/account/deletion.ex`, `test/support/mock_repo_behaviour.ex`]
**Warning signs:** Tests pass with no `Sigra.MockRepo.expect(:insert, ...)` or no `Oban.Job` changeset field assertions. [VERIFIED: `test/sigra/account/deletion_test.exs`]

### Pitfall 3: Nested Transactions Around Audit Wrapper

**What goes wrong:** `Sigra.Account.schedule_deletion/3` wraps `Deletion.schedule/3` in a `Multi.run`, while `Deletion.schedule/3` itself calls `repo.transaction/1`. [VERIFIED: `lib/sigra/account.ex`, `lib/sigra/account/deletion.ex`]
**Why it happens:** Existing audit co-fate wrappers compose domain operations with audit rows. [VERIFIED: `lib/sigra/account.ex`, `test/sigra/account_audit_atomicity_test.exs`]
**How to avoid:** Keep the phase narrowly focused unless tests expose a real regression; Ecto docs warn nested transaction management can become complex and recommend composing operations in one transaction when possible. [CITED: `https://hexdocs.pm/ecto/Ecto.Repo.html`]
**Warning signs:** Enqueueing before the durable user update or coupling optional Oban insert failure to the main deletion schedule transaction. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`]

### Pitfall 4: Missing Generated-Host Context

**What goes wrong:** Oban and worker modules are loaded, but `deletion_job_args/3` returns `{:error, :missing_job_context}` because `:user_schema` is absent. [VERIFIED: `lib/sigra/account/deletion.ex`]
**Why it happens:** The worker needs repo and schema module names serialized into args so it can reload the user later. [VERIFIED: `lib/sigra/workers/account_deletion.ex`]
**How to avoid:** Ensure `Sigra.Auth.schedule_deletion/3` and generated wrappers pass `config.user_schema` plus optional schemas/context needed by the worker. [VERIFIED: `lib/sigra/auth.ex`, `priv/templates/sigra.install/core/auth.ex`]
**Warning signs:** Tests only call `Deletion.schedule/3` with `base_opts()` that lacks `:user_schema`. [VERIFIED: `test/sigra/account/deletion_test.exs`]

## Code Examples

Verified patterns from official and repo sources:

### Oban Worker Configuration

```elixir
# Source: lib/sigra/workers/account_deletion.ex; Oban.Worker docs https://hexdocs.pm/oban/Oban.Worker.html
use Oban.Worker,
  queue: :sigra_lifecycle,
  max_attempts: 3,
  unique: [period: 300, keys: [:user_id]]
```

### Worker No-Op on Stale Jobs

```elixir
# Source: lib/sigra/workers/account_deletion.ex
if Deletion.scheduled?(user) do
  Account.execute_deletion(repo, user, exec_opts)
else
  {:ok, :not_scheduled}
end
```

### Soft-Delete Finalization

```elixir
# Source: lib/sigra/account/deletion.ex
changeset_fn.(user, %{
  original_email: nil,
  pending_email: nil,
  scheduled_deletion_at: nil
})
```

### Generated Host Wrapper Pattern

```elixir
# Source: priv/templates/sigra.install/core/auth.ex
def schedule_deletion(user, opts \\ []) do
  Sigra.Auth.schedule_deletion(sigra_config(), user,
    Keyword.merge(
      [
        changeset_fn: &User.deletion_changeset/2,
        user_token_schema: UserToken,
        session_store: Sigra.SessionStores.Ecto
      ],
      opts
    )
  )
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Treat any `deleted_at` as scheduled | Use `deleted_at && scheduled_deletion_at` for active scheduled state | Existing code before Phase 128 research; locked by D-04 | Cancel/execute reject finalized soft-deleted rows. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`] |
| Overstate soft-delete as permanent row removal | Describe soft-delete as lifecycle finalization preserving the row | Locked by D-07/D-09 | Operator-facing surfaces must distinguish soft, hard, and anonymize strategies. [VERIFIED: `128-CONTEXT.md`, `guides/flows/account-lifecycle.md`] |
| Trust schedule return value as enqueue proof | Assert `Oban.Job` changeset fields at `repo.insert/1` | Phase 128 planning target | Planner should add a targeted test before relying on docs truth. [VERIFIED: `test/sigra/account/deletion_test.exs`, local changeset inspection] |

**Deprecated/outdated:**
- `Repo.transaction/2` is deprecated in latest Ecto docs in favor of `Repo.transact/2`, but this phase should not refactor all transaction calls unless needed for the lifecycle fix. [CITED: `https://hexdocs.pm/ecto/Ecto.Repo.html`, VERIFIED: `lib/sigra/account/deletion.ex`]
- `Sigra.Testing.assert_account_deleted/3` currently treats absent row or anonymized email as deletion success and does not model finalized soft-delete truth; broad testing-helper/docs parity is Phase 129 unless Phase 128 needs a narrow proof fix. [VERIFIED: `lib/sigra/testing.ex`, `128-CONTEXT.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No new dependency is needed for Phase 128. [ASSUMED] | Standard Stack | If wrong, planner may omit a dependency or setup task, but current code already has Ecto, Oban, and Mox surfaces for the requested behavior. |

## Open Questions (RESOLVED)

1. **RESOLVED: Missing job context should remain a safe no-op; non-missing enqueue errors should log.**
   - What we know: Locked D-03 requires safe degradation and says it must remain explicit enough for tests and docs. [VERIFIED: `128-CONTEXT.md`]
   - What's unclear: Current code returns `:ok` silently for `{:error, :missing_job_context}`. [VERIFIED: `lib/sigra/account/deletion.ex`]
   - Resolution: Phase 128 plans require test proof for both full-context enqueue and missing-context no-op. The missing `:user_schema` branch resolves to `{:error, :missing_job_context}` and degrades to `:ok` without logging; unexpected enqueue errors and rescue paths log warnings. [RESOLVED: `128-01-PLAN.md`, D-03]

2. **RESOLVED: Phase 128 should not perform broad generated-template parity work.**
   - What we know: Phase 129 owns broad generated-host/docs parity. [VERIFIED: `.planning/ROADMAP.md`, `128-CONTEXT.md`]
   - What's unclear: A narrow template/context propagation fix is allowed if needed to prove `LIFE-01`. [VERIFIED: `128-CONTEXT.md`]
   - Resolution: Phase 128 plans keep generated templates, example app files, install-golden fixtures, and public docs out of scope unless a focused compile failure directly requires a narrow change. The planned implementation path repairs library behavior and `Sigra.Auth.schedule_deletion/3` context propagation only. [RESOLVED: `128-01-PLAN.md`, D-10, D-11]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Running tests and Mix tasks | yes | 1.19.5 on OTP 28 | None needed. [VERIFIED: `elixir --version`] |
| Mix | Running targeted test commands | yes | 1.19.5 | None needed. [VERIFIED: `mix --version`] |
| PostgreSQL server | Full `mix test` and integration tests | yes | `localhost:5432` accepting connections | Unit tests can run without new DB setup, but full suite needs the server. [VERIFIED: `pg_isready`, `CLAUDE.md`] |
| psql CLI | Manual DB inspection if needed | yes | 14.17 | Use Ecto queries/tests if CLI unavailable. [VERIFIED: `psql --version`] |
| Docker | Starting disposable Postgres if local DB stops | yes | 29.5.2 | Existing local Postgres is available. [VERIFIED: `docker --version`, `pg_isready`] |
| Network/Hex | Version metadata verification | yes | Hex queries succeeded | Use locked `mix.lock` if offline. [VERIFIED: `mix hex.info oban`, `mix hex.info ecto`, `mix hex.info phoenix`, `mix hex.info mox`] |

**Missing dependencies with no fallback:**
- None found for Phase 128 research/planning. [VERIFIED: environment probes]

**Missing dependencies with fallback:**
- None found. [VERIFIED: environment probes]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Mox; project test helper starts ExUnit and defines Mox mocks. [VERIFIED: `test/test_helper.exs`] |
| Config file | `mix.exs` plus `test/test_helper.exs`. [VERIFIED: `mix.exs`, `test/test_helper.exs`] |
| Quick run command | `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs` [VERIFIED: files exist] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: `CLAUDE.md`, `test/test_helper.exs`] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| LIFE-01 | Scheduling enqueues `Sigra.Workers.AccountDeletion` when Oban and host context are available, and degrades when context is absent. [VERIFIED: `.planning/REQUIREMENTS.md`] | unit with Mox repo insert assertion | `mix test test/sigra/account/deletion_test.exs --trace` | yes, needs new/expanded tests. [VERIFIED: `test/sigra/account/deletion_test.exs`] |
| LIFE-02 | Cancel/execute reject non-active and finalized users with `{:error, :not_scheduled}`. [VERIFIED: `.planning/REQUIREMENTS.md`] | unit + worker unit | `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --trace` | yes. [VERIFIED: `test/sigra/account/deletion_test.exs`, `test/sigra/workers/account_deletion_test.exs`] |
| LIFE-03 | Soft-delete finalization clears `scheduled_deletion_at`, `pending_email`, and `original_email` while preserving row/deleted marker truth. [VERIFIED: `.planning/REQUIREMENTS.md`] | unit with changeset/result assertions | `mix test test/sigra/account/deletion_test.exs --trace` | yes, existing test should be strengthened to assert final updated fields. [VERIFIED: `test/sigra/account/deletion_test.exs`] |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs` [VERIFIED: files exist]
- **Per wave merge:** `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs test/sigra/account_audit_atomicity_test.exs test/sigra/data_export_test.exs` [VERIFIED: files exist]
- **Phase gate:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` before `/gsd-verify-work`. [VERIFIED: `CLAUDE.md`, `test/test_helper.exs`]

### Wave 0 Gaps

- [ ] Add a full-context enqueue assertion to `test/sigra/account/deletion_test.exs` that pins `worker`, `queue`, `scheduled_at`, `replace`, and args. [VERIFIED: `test/sigra/account/deletion_test.exs`, local changeset inspection]
- [ ] Add or strengthen a missing-context degradation assertion so `Deletion.schedule/3` succeeds without `:user_schema` and does not call `repo.insert/1`. [VERIFIED: `lib/sigra/account/deletion.ex`, `test/sigra/account/deletion_test.exs`]
- [ ] Strengthen soft-delete execution assertions to inspect the returned updated user or `Ecto.Multi.to_list/1` changeset fields for cleared staging fields. [VERIFIED: `test/sigra/account/deletion_test.exs`, cited HexDocs `https://hexdocs.pm/ecto/Ecto.Multi.html`]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Scheduled deletion revokes tokens/sessions immediately; finalization must not reactivate stale users. [VERIFIED: `lib/sigra/account/deletion.ex`, `guides/flows/account-lifecycle.md`] |
| V3 Session Management | yes | `schedule/3` deletes tokens and calls configured session store `delete_all_for_user/2`. [VERIFIED: `lib/sigra/account/deletion.ex`] |
| V4 Access Control | limited | Worker reconstructed scope is audit-only and must not be used for authorization decisions. [VERIFIED: `lib/sigra/workers.ex`] |
| V5 Input Validation | yes | Worker args use required-key checks, `Module.safe_concat/1`, and `String.to_existing_atom/1`. [VERIFIED: `lib/sigra/workers.ex`, `lib/sigra/workers/account_deletion.ex`] |
| V6 Cryptography | no direct change | This phase does not modify password/token cryptography. [VERIFIED: `.planning/ROADMAP.md`, `lib/sigra/account/deletion.ex`] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale scheduled job executes after cancellation | Tampering / Repudiation | Reload user and gate execution through `Deletion.scheduled?/1`; return `{:ok, :not_scheduled}` when no longer active. [VERIFIED: `lib/sigra/workers/account_deletion.ex`] |
| Lifecycle misrepresentation in exports/docs | Repudiation | Use `Sigra.Account.Deletion.status/1` and avoid hard-delete claims for soft-delete strategy. [VERIFIED: `.planning/phases/127-versioned-auth-data-export/127-RESEARCH.md`, `128-CONTEXT.md`] |
| Atom exhaustion from job args | Denial of Service | Keep `String.to_existing_atom/1` for strategy and do not switch to `String.to_atom/1`. [VERIFIED: `lib/sigra/workers/account_deletion.ex`] |
| Missing worker context silently prevents finalization | Repudiation / Availability | Test explicit degradation and document that Oban + generated-host context are required for automatic finalization. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/128-account-deletion-lifecycle-truth/128-CONTEXT.md` - locked implementation decisions, phase boundary, canonical refs. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - `LIFE-01`, `LIFE-02`, `LIFE-03`. [VERIFIED: file read]
- `.planning/ROADMAP.md` - Phase 128 success criteria and Phase 129 boundary. [VERIFIED: file read]
- `.planning/STATE.md` - current milestone and Phase 128 planning state. [VERIFIED: file read]
- `CLAUDE.md` - project constraints and test prerequisites. [VERIFIED: file read]
- `lib/sigra/account/deletion.ex` - schedule, cancel, execute, status, enqueue helper. [VERIFIED: file read]
- `lib/sigra/account.ex` - public lifecycle/audit wrapper. [VERIFIED: file read]
- `lib/sigra/auth.ex` - config-aware generated-host-facing lifecycle entrypoints. [VERIFIED: file read]
- `lib/sigra/workers/account_deletion.ex` and `lib/sigra/workers.ex` - worker contract, args, no-op semantics. [VERIFIED: file read]
- `test/sigra/account/deletion_test.exs`, `test/sigra/workers/account_deletion_test.exs`, `test/sigra/account_audit_atomicity_test.exs` - current proof surfaces. [VERIFIED: file read]
- `https://hexdocs.pm/oban/Oban.Worker.html` - worker options, return semantics, `perform/1`. [CITED: official HexDocs]
- `https://hexdocs.pm/ecto/Ecto.Multi.html` - Multi transaction grouping and introspection. [CITED: official HexDocs]
- `https://hexdocs.pm/ecto/Ecto.Repo.html` - transaction/transact and nested transaction cautions. [CITED: official HexDocs]

### Secondary (MEDIUM confidence)

- `mix hex.info oban`, `mix hex.info ecto`, `mix hex.info phoenix`, `mix hex.info mox` - package version metadata and recent releases from Hex. [VERIFIED: Hex CLI]
- Local `MIX_ENV=test mix run` inspection of `Sigra.Workers.AccountDeletion.new/2` - confirms Oban changeset fields for this repo. [VERIFIED: command output]

### Tertiary (LOW confidence)

- None. [VERIFIED: all research claims either repo-verified, Hex-verified, or official-doc cited except A1 which is explicitly assumed]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - package versions were checked against `mix.lock`/`mix deps` and Hex metadata; no new stack is proposed. [VERIFIED: `mix deps`, `mix hex.info ...`]
- Architecture: HIGH - architecture follows locked phase decisions and existing code paths. [VERIFIED: `128-CONTEXT.md`, `lib/sigra/account/deletion.ex`]
- Pitfalls: HIGH - pitfalls are derived from existing tests/code and official Ecto/Oban docs. [VERIFIED: repo files, cited HexDocs]

**Research date:** 2026-05-27 [VERIFIED: system date]
**Valid until:** 2026-06-03 for package-version currency; lifecycle architecture remains valid while Phase 128 scope and existing modules remain unchanged. [ASSUMED]
