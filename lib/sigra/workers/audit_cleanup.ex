defmodule Sigra.Workers.AuditCleanup do
  @moduledoc """
  Optional Oban worker that deletes audit rows older than the configured
  retention window (D-10 retention cleanup for AUDIT-03).

  ## Decisions

  - **D-09 default is forever** — when `retention_days` is `nil`, the worker
    is a no-op. Host apps must explicitly opt in to automatic deletion of
    forensic history.
  - **D-10 inline fallback** — host apps without Oban call
    `Sigra.Audit.cleanup/1` directly from their own scheduler. A startup
    warning in `Sigra.Application` advises this when `retention_days` is set
    but Oban is absent.
  - **Phase 1 D-36 fail-open** — `max_attempts: 1` ensures cleanup failures
    surface immediately in the Oban dashboard rather than retrying silently.

  Matches `Sigra.Workers.TokenCleanup` structure (same queue, same
  `max_attempts`).

  ## Threat mitigations

  - **T-9-04 (Repudiation):** `nil` default preserves forensic trail. Failures
    surface via `max_attempts: 1` rather than silent retries.
  - **T-9-08 (Tampering):** `String.to_existing_atom/1` rejects atoms that are
    not already loaded, preventing atom-table exhaustion and limiting module
    selection to host-loaded schemas/repos.
  """

  alias Sigra.OptionalDeps
  @oban_available Code.ensure_loaded?(Oban.Worker)

  if @oban_available do
    use Oban.Worker,
      queue: :sigra_lifecycle,
      max_attempts: 1

    alias Oban.{Job, Worker}

    def new(args, opts) when is_map(args) and is_list(opts) do
      OptionalDeps.ensure_available!(:lifecycle_jobs, lifecycle_job_context(opts))
      Job.new(args, Worker.merge_opts(__opts__(), Keyword.drop(opts, [:dependency_loaded?])))
    end

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      repo = String.to_existing_atom(args["repo"])
      audit_schema = String.to_existing_atom(args["audit_schema"])
      retention_days = args["retention_days"]

      Sigra.Audit.do_cleanup(repo, audit_schema, retention_days)
      {:ok, :cleaned}
    end
  else
    def __opts__, do: [queue: :sigra_lifecycle, max_attempts: 1, worker: inspect(__MODULE__)]

    def new(args, opts \\ []) when is_map(args) and is_list(opts) do
      OptionalDeps.ensure_available!(:lifecycle_jobs, lifecycle_job_context(opts))
    end
  end

  @doc """
  Direct callable for the inline fallback path.

  Host apps without Oban can call `Sigra.Audit.cleanup/1` (which delegates
  here) from their own scheduler — a periodic GenServer, a cron hit to a
  background task, etc.
  """
  @spec cleanup(module(), module(), pos_integer() | nil) :: :ok
  def cleanup(repo, audit_schema, retention_days) do
    Sigra.Audit.do_cleanup(repo, audit_schema, retention_days)
  end

  defp lifecycle_job_context(opts) do
    [lifecycle_jobs?: true, dependency_loaded?: Keyword.get(opts, :dependency_loaded?, &dependency_loaded?/1)]
  end

  defp dependency_loaded?(spec) do
    Enum.any?(spec.dependency_modules, &Code.ensure_loaded?/1)
  end
end
