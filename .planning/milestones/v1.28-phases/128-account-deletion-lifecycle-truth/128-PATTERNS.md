# Phase 128: Account Deletion Lifecycle Truth - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 10
**Analogs found:** 10 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/account/deletion.ex` | service | CRUD + event-driven enqueue | `lib/sigra/account/deletion.ex` | exact |
| `lib/sigra/account.ex` | service/facade | request-response + transactional CRUD | `lib/sigra/account.ex` | exact |
| `lib/sigra/auth.ex` | service/facade | request-response context propagation | `lib/sigra/auth.ex` | exact |
| `lib/sigra/workers/account_deletion.ex` | worker | event-driven + batch | `lib/sigra/workers/account_deletion.ex` | exact |
| `lib/sigra/workers.ex` | utility/behaviour | transform + validation | `lib/sigra/workers.ex` | exact |
| `test/sigra/account/deletion_test.exs` | test | CRUD + event-driven enqueue proof | `test/sigra/account/deletion_test.exs` | exact |
| `test/sigra/workers/account_deletion_test.exs` | test | event-driven worker proof | `test/sigra/workers/account_deletion_test.exs` | exact |
| `test/sigra/account_audit_atomicity_test.exs` | test | transactional CRUD rollback proof | `test/sigra/account_audit_atomicity_test.exs` | role-match |
| `priv/templates/sigra.install/core/auth.ex` | generated template/provider | request-response context propagation | `priv/templates/sigra.install/core/auth.ex` | role-match |
| `test/support/mock_repo_behaviour.ex` / `test/test_helper.exs` | test support/config | validation + test double I/O | `test/support/mock_repo_behaviour.ex` / `test/test_helper.exs` | exact |

## Pattern Assignments

### `lib/sigra/account/deletion.ex` (service, CRUD + event-driven enqueue)

**Analog:** `lib/sigra/account/deletion.ex`

**Imports/aliases pattern** (lines 20-22):
```elixir
alias Ecto.Multi
alias Sigra.{Hooks, Telemetry}
require Logger
```

**Public lifecycle guard pattern** (lines 48-78, 110-128):
```elixir
def schedule(repo, user, opts) do
  if user.deleted_at != nil do
    {:error, :already_scheduled}
  else
    do_schedule(repo, user, opts)
  end
end

def cancel(repo, user, opts) do
  if not scheduled?(user) do
    {:error, :not_scheduled}
  else
    do_cancel(repo, user, opts)
  end
end

def execute(repo, user, opts) do
  if not scheduled?(user) do
    {:error, :not_scheduled}
  else
    do_execute(repo, user, opts)
  end
end

def scheduled?(user) do
  not is_nil(user.deleted_at) and not is_nil(user.scheduled_deletion_at)
end
```

**Status truth pattern** (lines 140-151):
```elixir
cond do
  not is_nil(user.deleted_at) and not is_nil(user.scheduled_deletion_at) ->
    days = DateTime.diff(user.scheduled_deletion_at, DateTime.utc_now(), :day)
    {:scheduled, max(days, 0)}

  not is_nil(user.deleted_at) ->
    :deleted

  true ->
    :not_scheduled
end
```

**Schedule transaction + enqueue-after-commit pattern** (lines 174-218):
```elixir
user_changeset =
  changeset_fn.(user, %{
    deleted_at: now,
    scheduled_deletion_at: scheduled_deletion_at,
    original_email: user.email,
    pending_email: nil
  })

multi =
  Multi.new()
  |> Multi.update(:user, user_changeset)
  |> Multi.delete_all(:tokens, token_query_fn.(user, :all))
  |> Hooks.maybe_run_hook(:delete, %{user: user, strategy: get_strategy(config)}, config)

case repo.transaction(multi) do
  {:ok, %{user: updated_user}} ->
    revoke_sessions(user, opts)
    maybe_enqueue_deletion_job(repo, updated_user, scheduled_deletion_at, opts)
    {:ok, updated_user, scheduled_deletion_at}

  {:error, :user, changeset, _} ->
    {:error, changeset}
end
```

**Soft-delete finalization pattern** (lines 266-278):
```elixir
user_changeset =
  changeset_fn.(user, %{
    original_email: nil,
    pending_email: nil,
    scheduled_deletion_at: nil
  })

Multi.new()
|> Multi.update(:user, user_changeset)
```

**Optional Oban degradation and logging pattern** (lines 306-329):
```elixir
with true <- Code.ensure_loaded?(Oban),
     true <- Code.ensure_loaded?(Sigra.Workers.AccountDeletion),
     {:ok, args} <- deletion_job_args(repo, user, opts),
     {:ok, changeset} <- build_deletion_job_changeset(args, scheduled_at),
     {:ok, _job} <- repo.insert(changeset) do
  :ok
else
  false ->
    :ok

  {:error, :missing_job_context} ->
    :ok

  {:error, reason} ->
    Logger.warning("Sigra account deletion job was not enqueued: #{inspect(reason)}")
    :ok
end
```

**Worker args + changeset pattern** (lines 331-368):
```elixir
args = %{
  "organization_id" => scope_organization_id(scope),
  "actor_id" => scope_actor_id(scope, user),
  "user_id" => user.id,
  "strategy" => get_strategy(Keyword.get(opts, :config, [])) |> Atom.to_string(),
  "repo" => Atom.to_string(repo),
  "user_schema" => Atom.to_string(user_schema),
  "scope_module" => stringify_module(Keyword.get(opts, :scope_module)),
  "organization_schema" => stringify_module(Keyword.get(opts, :organization_schema)),
  "audit_schema" => stringify_module(Keyword.get(opts, :audit_schema)),
  "user_token_schema" => stringify_module(Keyword.get(opts, :user_token_schema)),
  "session_store" => stringify_module(Keyword.get(opts, :session_store))
}

Sigra.Workers.new(
  Sigra.Workers.AccountDeletion,
  args,
  scheduled_at: scheduled_at,
  replace: [scheduled: [:scheduled_at, :args]]
)
```

### `lib/sigra/account.ex` (service/facade, request-response + transactional CRUD)

**Analog:** `lib/sigra/account.ex`

**Audit co-fate schedule wrapper pattern** (lines 380-417):
```elixir
multi =
  Multi.new()
  |> Multi.run(:domain, fn r, _ ->
    case Deletion.schedule(r, user, opts) do
      {:ok, u, scheduled_at} -> {:ok, %{user: u, scheduled_at: scheduled_at}}
      err -> err
    end
  end)
  |> Sigra.Audit.log_multi_safe(
    "account.deletion_schedule",
    Keyword.merge(audit_repo_opts(repo, opts), Keyword.merge(scope_kw, actor_id: user.id, target_id: user.id, metadata: %{}))
  )

case finish_audit_multi(repo, multi) do
  {:ok, %{domain: %{user: u, scheduled_at: at}}} -> {:ok, u, at}
  {:error, :domain, reason, _} -> {:error, reason}
  {:error, failed, reason, _} -> unexpected_account_multi!(failed, reason)
end
```

**Cancel wrapper pattern** (lines 422-454):
```elixir
multi =
  Multi.new()
  |> Multi.run(:domain, fn r, _ -> Deletion.cancel(r, user, opts) end)
  |> Sigra.Audit.log_multi_safe("account.deletion_cancel", audit_opts)

case finish_audit_multi(repo, multi) do
  {:ok, %{domain: u}} -> {:ok, u}
  {:error, :domain, reason, _} -> {:error, reason}
  {:error, failed, reason, _} -> unexpected_account_multi!(failed, reason)
end
```

**Execute wrapper and audit metadata pattern** (lines 459-520):
```elixir
multi =
  Multi.new()
  |> Multi.run(:deletion, fn r, _ ->
    case Deletion.execute(r, user, opts) do
      {:ok, strategy} -> {:ok, %{strategy: strategy, user_id: user_id}}
      err -> err
    end
  end)
  |> Sigra.Audit.log_multi_safe("account.deletion_execute", audit_opts)
  |> Sigra.Audit.log_multi_safe("account.deletion_executed", audit_opts)

case repo.transaction(multi) do
  {:ok, %{deletion: %{strategy: strategy}} = changes} ->
    Sigra.Audit.emit_telemetry_from_changes(changes, [:audit_deletion_execute, :audit_deletion_executed])
    {:ok, strategy}

  {:error, :deletion, reason, _} ->
    {:error, reason}
end
```

**Delegated truth pattern** (lines 524-530):
```elixir
defdelegate deletion_scheduled?(user), to: Deletion, as: :scheduled?
defdelegate deletion_status(user), to: Deletion, as: :status
```

### `lib/sigra/auth.ex` (service/facade, request-response context propagation)

**Analog:** `lib/sigra/auth.ex`

**Generated-host-facing schedule context pattern** (lines 2414-2432):
```elixir
def schedule_deletion(config, user, opts \\ []) do
  repo = config.repo

  merged_opts =
    Keyword.merge(
      [
        config: config,
        repo: repo,
        user_schema: config.user_schema,
        scope_module: Map.get(config, :scope_module),
        audit_schema: get_in(config, [:audit, :audit_schema]),
        session_store: get_session_store(config),
        session_schema: get_in(config, [:session, :session_schema]),
        user_token_schema: Keyword.fetch!(opts, :user_token_schema)
      ],
      opts
    )

  Sigra.Account.schedule_deletion(repo, user, merged_opts)
end
```

**Cancel/execute propagation pattern** (lines 2444-2480):
```elixir
merged_opts =
  Keyword.merge(
    [
      repo: config.repo,
      user_schema: config.user_schema,
      scope_module: Map.get(config, :scope_module),
      audit_schema: get_in(config, [:audit, :audit_schema])
    ],
    opts
  )

Sigra.Account.cancel_deletion(config.repo, user, merged_opts)
Sigra.Account.execute_deletion(config.repo, user, merged_opts)
```

Planner note: if `LIFE-01` fails through the public API, repair this context propagation first. The enqueue helper already requires `:user_schema`; optional worker args should be passed here only when available from `Sigra.Config` or generated opts.

### `lib/sigra/workers/account_deletion.ex` (worker, event-driven + batch)

**Analog:** `lib/sigra/workers/account_deletion.ex`

**Conditional compile + Oban worker config pattern** (lines 1-55):
```elixir
if Code.ensure_loaded?(Oban.Worker) do
  defmodule Sigra.Workers.AccountDeletion do
    use Oban.Worker,
      queue: :sigra_lifecycle,
      max_attempts: 3,
      unique: [period: 300, keys: [:user_id]]

    @behaviour Sigra.Workers

    alias Sigra.{Account, Account.Deletion}
```

**Required-arg validation and safe module resolution pattern** (lines 57-109):
```elixir
def perform(%Oban.Job{args: args}) do
  _organization_id_key = Sigra.Workers.fetch_arg!(args, "organization_id")
  _actor_id_key = Sigra.Workers.fetch_arg!(args, "actor_id")
  _audit_schema_key = Sigra.Workers.fetch_arg!(args, "audit_schema")
  _scope_module_key = Sigra.Workers.fetch_arg!(args, "scope_module")
  _organization_schema_key = Sigra.Workers.fetch_arg!(args, "organization_schema")
  _repo_key = Sigra.Workers.fetch_arg!(args, "repo")
  _user_schema_key = Sigra.Workers.fetch_arg!(args, "user_schema")
  _user_id_key = Sigra.Workers.fetch_arg!(args, "user_id")

  repo = Module.safe_concat([args["repo"]])
  user_schema = Module.safe_concat([args["user_schema"]])
  user = repo.get(user_schema, user_id)
  scope = case scope_module do
    nil -> nil
    mod -> Sigra.Scope.build(mod, user, active_organization: active_org)
  end

  perform(scope, args)
end
```

**Stale-job no-op and execute delegation pattern** (lines 129-164):
```elixir
user_id = Map.fetch!(args, "user_id")
strategy = String.to_existing_atom(Map.fetch!(args, "strategy"))

case repo.get(user_schema, user_id) do
  nil ->
    {:ok, :user_not_found}

  user ->
    if Deletion.scheduled?(user) do
      exec_opts = [
        config: %{deletion: %{strategy: strategy}},
        changeset_fn: &default_changeset_fn/2,
        token_query_fn: &default_token_query_fn/2,
        audit_schema: audit_schema,
        scope_module: scope_module
      ]

      case Account.execute_deletion(repo, user, exec_opts) do
        {:ok, _strategy} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, :not_scheduled}
    end
end
```

**Optional module arg propagation pattern** (lines 146-171):
```elixir
exec_opts =
  exec_opts
  |> maybe_add_opt(:user_token_schema, args["user_token_schema"])
  |> maybe_add_opt(:session_store, args["session_store"])
  |> maybe_add_opt(:identity_schema, args["identity_schema"])
  |> maybe_add_opt(:api_token_schema, args["api_token_schema"])
  |> maybe_add_opt(:mfa_credential_schema, args["mfa_credential_schema"])
  |> maybe_add_opt(:backup_code_schema, args["backup_code_schema"])

defp maybe_add_opt(opts, key, module_string) when is_binary(module_string) do
  Keyword.put(opts, key, Module.safe_concat([module_string]))
end
```

### `lib/sigra/workers.ex` (utility/behaviour, transform + validation)

**Analog:** `lib/sigra/workers.ex`

**Behaviour and return contract pattern** (lines 37-38):
```elixir
@callback perform(scope :: term() | nil, args :: map()) ::
            :ok | {:ok, term()} | {:error, term()} | {:snooze, pos_integer()}
```

**Required string-key validation pattern** (lines 40-67):
```elixir
@required_keys ["organization_id", "actor_id"]

def new(worker, args, opts \\ []) when is_atom(worker) and is_map(args) do
  missing = Enum.reject(@required_keys, &Map.has_key?(args, &1))

  if missing != [] do
    raise ArgumentError,
          "Sigra.Workers.new/3: missing required args #{inspect(missing)}. " <>
            "Every Sigra-aware worker must receive #{inspect(@required_keys)} " <>
            "(nil values are permitted, absent keys are not)."
  end

  apply(worker, :new, [args, opts])
end
```

**Runtime belt-and-suspenders validation pattern** (lines 69-77):
```elixir
def fetch_arg!(args, key) when is_map(args) and is_binary(key) do
  Map.fetch!(args, key)
end
```

### `test/sigra/account/deletion_test.exs` (test, CRUD + event-driven enqueue proof)

**Analog:** `test/sigra/account/deletion_test.exs`

**Imports/setup pattern** (lines 1-10):
```elixir
defmodule Sigra.Account.DeletionTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Account.Deletion
  alias Ecto.Multi

  setup :verify_on_exit!
```

**User fixture + base opts pattern** (lines 13-45):
```elixir
defp build_user(attrs \\ %{}) do
  defaults = %{
    id: 1,
    email: "user@example.com",
    hashed_password: "hashed_pw",
    pending_email: nil,
    deleted_at: nil,
    scheduled_deletion_at: nil,
    original_email: nil
  }

  struct(Sigra.TestUser, Map.merge(defaults, attrs))
end

defp base_opts(overrides \\ []) do
  Keyword.merge(
    [
      changeset_fn: fn user, attrs ->
        known = ~w(deleted_at scheduled_deletion_at original_email pending_email email hashed_password)a
        filtered = Map.take(attrs, known)
        Ecto.Changeset.change(user, filtered)
      end,
      session_store: Sigra.MockSessionStore,
      token_query_fn: fn _user, _contexts ->
        import Ecto.Query
        from(t in Sigra.TestUserToken, where: false)
      end,
      config: [deletion: [strategy: :soft_delete, grace_period_days: 14, cooldown_hours: 24]]
    ],
    overrides
  )
end
```

**Schedule success transaction assertion pattern** (lines 51-83):
```elixir
Sigra.MockRepo
|> expect(:transaction, fn multi ->
  assert %Multi{} = multi
  now = DateTime.utc_now() |> DateTime.truncate(:second)
  scheduled = DateTime.add(now, 14 * 86400, :second) |> DateTime.truncate(:second)

  {:ok, %{user: %{user | deleted_at: now, scheduled_deletion_at: scheduled, original_email: user.email, pending_email: nil}}}
end)

Sigra.MockSessionStore
|> expect(:delete_all_for_user, fn _user_id, _opts -> {1, nil} end)

assert {:ok, updated_user, scheduled_at} = Deletion.schedule(Sigra.MockRepo, user, base_opts())
```

**Cancel and finalized rejection pattern** (lines 122-136):
```elixir
test "returns {:error, :not_scheduled} when not scheduled" do
  user = build_user()
  result = Deletion.cancel(Sigra.MockRepo, user, base_opts())
  assert result == {:error, :not_scheduled}
end

test "returns {:error, :not_scheduled} when user is already finalized" do
  user = build_user(%{deleted_at: ~U[2026-01-01 00:00:00Z]})
  result = Deletion.cancel(Sigra.MockRepo, user, base_opts())
  assert result == {:error, :not_scheduled}
end
```

**Soft-delete execute proof pattern** (lines 142-168):
```elixir
Sigra.MockRepo
|> expect(:transaction, fn multi ->
  assert %Multi{} = multi

  {:ok,
   %{
     user: %{
       user
       | original_email: nil,
         pending_email: nil,
         scheduled_deletion_at: nil
     }
   }}
end)

opts = base_opts(config: [deletion: [strategy: :soft_delete]])
assert {:ok, :soft_delete} = Deletion.execute(Sigra.MockRepo, user, opts)
```

**Active-scheduled predicate proof pattern** (lines 226-247):
```elixir
assert Deletion.scheduled?(%{user | deleted_at: ~U[2026-01-01 00:00:00Z], scheduled_deletion_at: ~U[2026-01-15 00:00:00Z]}) == true
assert Deletion.scheduled?(build_user()) == false
assert Deletion.scheduled?(build_user(%{deleted_at: ~U[2026-01-01 00:00:00Z]})) == false
```

Planner note: add a new `schedule/3` test beside lines 51-83 with `base_opts(user_schema: Sigra.TestUser, scope_module: ..., audit_schema: ..., user_token_schema: ..., session_store: ...)` and `expect(:insert, fn changeset -> ... end)` to pin the Oban job shape.

### `test/sigra/workers/account_deletion_test.exs` (test, event-driven worker proof)

**Analog:** `test/sigra/workers/account_deletion_test.exs`

**Base args pattern** (lines 9-22):
```elixir
defp base_args(overrides \\ %{}) do
  %{
    "user_id" => 1,
    "strategy" => "soft_delete",
    "repo" => "Sigra.Workers.AccountDeletionTest.TestRepo",
    "user_schema" => "Sigra.Workers.AccountDeletionTest.TestUserSchema",
    "scope_module" => "Sigra.Workers.AccountDeletionTest.TestScope",
    "organization_schema" => nil,
    "audit_schema" => "Sigra.Workers.AccountDeletionTest.TestAuditSchema",
    "organization_id" => nil,
    "actor_id" => nil
  }
  |> Map.merge(overrides)
end
```

**Module config proof pattern** (lines 52-81):
```elixir
test "uses Oban.Worker" do
  Code.ensure_loaded!(AccountDeletion)
  assert function_exported?(AccountDeletion, :perform, 1)
end

test "configures :sigra_lifecycle queue" do
  source = File.read!("lib/sigra/workers/account_deletion.ex")
  assert source =~ "queue: :sigra_lifecycle"
end
```

**Stale job no-op test pattern** (lines 99-114):
```elixir
defmodule TestRepoNotScheduled do
  def get(_schema, _id) do
    %{id: 1, deleted_at: nil, scheduled_deletion_at: nil}
  end

  def insert(changeset), do: {:ok, changeset}
end

args = base_args(%{"repo" => "Sigra.Workers.AccountDeletionTest.TestRepoNotScheduled"})
assert {:ok, :not_scheduled} = AccountDeletion.perform(%Oban.Job{args: args})
```

**Security invariant tests pattern** (lines 122-154):
```elixir
test "uses Module.safe_concat for repo resolution (T-8-10 mitigation)" do
  source = File.read!("lib/sigra/workers/account_deletion.ex")
  assert source =~ "Module.safe_concat"
end

test "uses String.to_existing_atom for strategy resolution (T-8-10 mitigation)" do
  source = File.read!("lib/sigra/workers/account_deletion.ex")
  assert source =~ "String.to_existing_atom"
end

test "raises KeyError when audit_schema arg is absent (worker-specific belt+suspenders)" do
  args = base_args() |> Map.delete("audit_schema")

  assert_raise KeyError, fn ->
    AccountDeletion.perform(%Oban.Job{args: args})
  end
end
```

### `test/sigra/account_audit_atomicity_test.exs` (test, transactional rollback proof)

**Analog:** `test/sigra/account_audit_atomicity_test.exs`

**Audit co-fate regression pattern** (lines 433-469):
```elixir
test "rolls back anonymize when account.deletion_execute audit is rejected", %{repo: repo} do
  {:ok, user} =
    repo.insert(
      AccountUser.changeset(%AccountUser{id: id}, %{
        email: "victim@example.com",
        hashed_password: "hash",
        deleted_at: deleted_at,
        scheduled_deletion_at: scheduled_at,
        original_email: "victim@example.com"
      })
    )

  Ecto.Adapters.SQL.query!(
    repo,
    "ALTER TABLE audit_events ADD CONSTRAINT account_audit_del_guard CHECK (action <> 'account.deletion_execute')",
    []
  )

  assert_raise Ecto.ConstraintError, fn ->
    Account.execute_deletion(repo, user, opts)
  end

  reloaded = repo.get!(AccountUser, id)
  assert reloaded.email == "victim@example.com"
  assert count(repo, "audit_events") == 0
end
```

Use this pattern only if lifecycle changes touch `Sigra.Account` audit wrappers. Do not broaden this phase into audit refactoring.

### `priv/templates/sigra.install/core/auth.ex` (generated template/provider, request-response context propagation)

**Analog:** `priv/templates/sigra.install/core/auth.ex`

**Thin generated wrapper pattern** (lines 1034-1045):
```elixir
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

**Cancel wrapper pattern** (lines 1052-1055):
```elixir
def cancel_deletion(user, opts \\ []) do
  Sigra.Auth.cancel_deletion(sigra_config(), user,
    Keyword.merge([changeset_fn: &<%= schema_alias %>.deletion_changeset/2], opts)
  )
end
```

Planner note: Phase 129 owns broad template/docs parity. Touch this template in Phase 128 only if public schedule enqueue cannot be proven without adding narrow context propagation.

### `test/support/mock_repo_behaviour.ex` / `test/test_helper.exs` (test support/config, validation + test double I/O)

**Analog:** `test/support/mock_repo_behaviour.ex`, `test/test_helper.exs`

**Mock repo insert support pattern** (`test/support/mock_repo_behaviour.ex` lines 5-15):
```elixir
@callback get_by(module(), keyword()) :: struct() | nil
@callback get!(module(), term()) :: struct()
@callback insert(Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
@callback get(module(), term()) :: struct() | nil
@callback transaction(Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), term(), map()}
```

**Mox setup pattern** (`test/test_helper.exs` lines 6-12):
```elixir
ExUnit.start()

Mox.defmock(Sigra.MockRepo, for: Sigra.MockRepo.Behaviour)
Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)
```

Use existing `Sigra.MockRepo.expect(:insert, ...)` for enqueue assertions; no new test-double infrastructure should be needed.

## Shared Patterns

### Active Scheduled Truth
**Source:** `lib/sigra/account/deletion.ex` lines 126-128 and 140-151  
**Apply to:** cancel, execute, worker execution, status/export truth, tests
```elixir
def scheduled?(user) do
  not is_nil(user.deleted_at) and not is_nil(user.scheduled_deletion_at)
end
```

### Soft-Delete Finalization Truth
**Source:** `lib/sigra/account/deletion.ex` lines 266-278  
**Apply to:** `Deletion.execute/3`, worker execution proof, docs/template copy that references finalization
```elixir
changeset_fn.(user, %{
  original_email: nil,
  pending_email: nil,
  scheduled_deletion_at: nil
})
```

### Optional Infrastructure Degradation
**Source:** `lib/sigra/account/deletion.ex` lines 306-329  
**Apply to:** enqueue path and tests for missing `:user_schema` / absent Oban
```elixir
{:error, :missing_job_context} ->
  :ok

{:error, reason} ->
  Logger.warning("Sigra account deletion job was not enqueued: #{inspect(reason)}")
  :ok
```

### Worker Arg Validation
**Source:** `lib/sigra/workers.ex` lines 40-67 and `lib/sigra/workers/account_deletion.ex` lines 66-73  
**Apply to:** any new/updated account deletion job args
```elixir
@required_keys ["organization_id", "actor_id"]
missing = Enum.reject(@required_keys, &Map.has_key?(args, &1))

_repo_key = Sigra.Workers.fetch_arg!(args, "repo")
_user_schema_key = Sigra.Workers.fetch_arg!(args, "user_schema")
_user_id_key = Sigra.Workers.fetch_arg!(args, "user_id")
```

### Phase 127 Export Alignment
**Source:** `lib/sigra/data_export.ex` lines 89-97 and 303-318  
**Apply to:** any lifecycle truth assertions that mention exported/account status
```elixir
account: %{
  deleted_at: Map.get(user, :deleted_at),
  scheduled_deletion_at: Map.get(user, :scheduled_deletion_at),
  lifecycle_status: lifecycle_status(user)
}

case Deletion.status(user) do
  {:scheduled, days_remaining} -> %{state: :scheduled, days_remaining: days_remaining}
  :deleted -> %{state: :deleted}
  :not_scheduled -> %{state: :not_scheduled}
end
```

### Test Style
**Source:** `test/sigra/account/deletion_test.exs` lines 50-96 and 141-221  
**Apply to:** new lifecycle proofs
```elixir
describe "schedule/3" do
  test "..." do
    user = build_user()

    Sigra.MockRepo
    |> expect(:transaction, fn multi ->
      assert %Multi{} = multi
      {:ok, %{user: updated_user}}
    end)

    assert {:ok, updated_user, scheduled_at} = Deletion.schedule(Sigra.MockRepo, user, base_opts())
  end
end
```

## No Analog Found

No Phase 128 file lacks a close analog. The implementation should copy existing lifecycle, worker, and Mox patterns rather than introducing new architecture.

Out-of-scope/deferred surfaces for Phase 129 unless a narrow propagation fix is required:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `guides/flows/account-lifecycle.md` | docs | documentation | Broad operator-facing docs parity is deferred to Phase 129. |
| `guides/recipes/testing.md` | docs | documentation | Testing helper/docs truth alignment is deferred to Phase 129. |
| `test/example/lib/example/accounts.ex` | generated/example wrapper | request-response | Example app parity is deferred to Phase 129. |
| `test/example/lib/example_web/live/reactivation_live.ex` | component/live view | event-driven UI | Example UI copy parity is deferred to Phase 129. |

## Metadata

**Analog search scope:** `lib/sigra`, `test/sigra`, `test/support`, `priv/templates/sigra.install/core`  
**Files scanned:** 200+ repo files via `rg --files`; strong analog search stopped after exact lifecycle/worker/test matches.  
**Project guidance read:** `CLAUDE.md`; no project-local skill directories were present.  
**Pattern extraction date:** 2026-05-27
