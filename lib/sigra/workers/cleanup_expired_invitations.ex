if Code.ensure_loaded?(Oban.Worker) do
  defmodule Sigra.Workers.CleanupExpiredInvitations do
    @moduledoc """
    Optional Oban worker that hard-deletes expired, unaccepted invitation
    rows past the configured retention window (D-11).

    ## Invariants

    - **Only deletes `accepted_at IS NULL` rows.** Accepted invitations are
      preserved indefinitely by this worker — they are forensic history.
      Host apps with stricter retention policies should configure
      `Sigra.Audit` retention, not this worker.
    - **Retention window** is `expires_at < now() - retention_days * 86400 s`.
      Default 30 days past expiry (see `@org_config_schema
      :invitation_cleanup_retention_days`).
    - **Tenant-aware** via `@behaviour Sigra.Workers`: the reconstructed
      `%Scope{}` carries `organization_id` from args so any per-batch
      audit event (optional) is tagged with tenant context. Q3 RESOLVED
      in 17-RESEARCH.md — this earns the behaviour overhead because the
      rows being deleted carry `organization_id`.
    - **Inline fallback** via direct-callable `cleanup/3` for hosts
      without Oban (mirrors `Sigra.Workers.AuditCleanup.cleanup/3`
      precedent).

    ## Scheduling

    Host apps opt in by adding this worker to their Oban cron config:

        config :my_app, Oban,
          plugins: [
            {Oban.Plugins.Cron,
             crontab: [
               {"0 3 * * *", Sigra.Workers.CleanupExpiredInvitations,
                 args: %{
                   "organization_id" => nil,
                   "actor_id" => nil,
                   "repo" => "MyApp.Repo",
                   "invitation_schema" => "MyApp.Organizations.OrganizationInvitation",
                   "scope_module" => "MyApp.Accounts.Scope",
                   "organization_schema" => "MyApp.Organizations.Organization",
                   "retention_days" => 30
                 }}
             ]}
          ]

    Sigra does NOT auto-register this cron — host apps opt in by design.
    """

    use Oban.Worker,
      queue: :sigra_lifecycle,
      max_attempts: 1

    @behaviour Sigra.Workers

    alias Oban.{Job, Worker}
    alias Sigra.OptionalDeps

    import Ecto.Query

    # Phase 95 — lifecycle_jobs optional-dep boundary.
    @impl Oban.Worker
    def new(args, opts) when is_map(args) and is_list(opts) do
      OptionalDeps.ensure_available!(:lifecycle_jobs, lifecycle_job_context(opts))
      Job.new(args, Worker.merge_opts(__opts__(), Keyword.drop(opts, [:dependency_loaded?])))
    end

    defp lifecycle_job_context(opts) do
      [
        lifecycle_jobs?: true,
        dependency_loaded?: Keyword.get(opts, :dependency_loaded?, &dependency_loaded?/1)
      ]
    end

    defp dependency_loaded?(spec) do
      Enum.any?(spec.dependency_modules, &Code.ensure_loaded?/1)
    end

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      # Step 1: validate required keys up front (belt + suspenders over
      # Sigra.Workers.new/3 — D-20).
      _ = Sigra.Workers.fetch_arg!(args, "organization_id")
      _ = Sigra.Workers.fetch_arg!(args, "actor_id")
      _ = Sigra.Workers.fetch_arg!(args, "repo")
      _ = Sigra.Workers.fetch_arg!(args, "invitation_schema")
      _ = Sigra.Workers.fetch_arg!(args, "scope_module")
      _ = Sigra.Workers.fetch_arg!(args, "retention_days")

      # Step 2: resolve stringified modules.
      repo = Module.safe_concat([args["repo"]])
      scope_module = Module.safe_concat([args["scope_module"]])

      organization_schema =
        case args["organization_schema"] do
          nil -> nil
          mod when is_binary(mod) -> Module.safe_concat([mod])
        end

      # Step 3: reconstruct audit-only scope (tenant-aware).
      organization_id = args["organization_id"]

      active_org =
        case {organization_schema, organization_id} do
          {nil, _} -> nil
          {_, nil} -> nil
          {mod, id} -> repo.get(mod, id)
        end

      scope = Sigra.Scope.build(scope_module, nil, active_organization: active_org)

      perform(scope, args)
    end

    @impl Sigra.Workers
    def perform(_scope, args) do
      repo = Module.safe_concat([Map.fetch!(args, "repo")])
      invitation_schema = Module.safe_concat([Map.fetch!(args, "invitation_schema")])
      retention_days = Map.fetch!(args, "retention_days")

      {count, _} = do_cleanup(repo, invitation_schema, retention_days)
      {:ok, %{deleted: count}}
    end

    @doc """
    Direct callable for the inline fallback path.

    Host apps without Oban can call this from their own scheduler
    (periodic GenServer, cron hit, test setup, etc.). Matches the
    precedent set by `Sigra.Workers.AuditCleanup.cleanup/3`.

    Deletes invitations where `expires_at < now() - retention_days days`
    AND `accepted_at IS NULL`. Returns `{count_deleted, nil}`.
    """
    @spec cleanup(module(), module(), pos_integer()) :: {non_neg_integer(), nil}
    def cleanup(repo, invitation_schema, retention_days) do
      do_cleanup(repo, invitation_schema, retention_days)
    end

    defp do_cleanup(repo, invitation_schema, retention_days) do
      cutoff =
        DateTime.utc_now()
        |> DateTime.add(-retention_days * 86_400, :second)
        |> DateTime.truncate(:second)

      from(i in invitation_schema,
        where: is_nil(i.accepted_at) and i.expires_at < ^cutoff
      )
      |> repo.delete_all()
    end
  end
else
  defmodule Sigra.Workers.CleanupExpiredInvitations do
    @moduledoc """
    Stub fallback for hosts that compile Sigra without Oban (Phase 95
    `:lifecycle_jobs` optional-dep boundary). See
    `Sigra.Workers.AccountDeletion` for the rationale on the dual-defmodule
    shape.
    """

    alias Sigra.OptionalDeps

    @doc false
    def new(args, opts \\ []) when is_map(args) and is_list(opts) do
      OptionalDeps.ensure_available!(:lifecycle_jobs, lifecycle_job_context(opts))
      raise "unreachable"
    end

    defp lifecycle_job_context(opts) do
      [
        lifecycle_jobs?: true,
        dependency_loaded?: Keyword.get(opts, :dependency_loaded?, fn _spec -> false end)
      ]
    end
  end
end
