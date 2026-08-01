if Code.ensure_loaded?(Oban.Worker) do
  defmodule Sigra.Workers.AuditForward do
    @moduledoc """
    Optional Oban worker for async audit forwarder dispatch.

    Wrapped in `if Code.ensure_loaded?(Oban.Worker)` per D-18 — when Oban is
    absent from deps, this module does not exist and the `:async` dispatch path
    is a no-op (see `Sigra.Audit.Forwarders.dispatch_async/3`).

    ## Thin Job Args (D-13)

    Receives only three keys in job args — a thin reference, never a full payload
    (security: T-3-INFRA-01):

    - `"forwarder"` — forwarder module name string (e.g. `"Elixir.Sigra.Audit.Forwarders.Threadline"`)
    - `"audit_event_id"` — UUID of the audit event row to reload
    - `"occurred_at"` — ISO8601 timestamp for tracing (not used to load the row)

    The worker reloads the full audit row from the configured `repo` + `audit_schema`
    at perform time (D-13 — full payload from DB, not from job args).

    ## Cancel Taxonomy (D-16)

    - `{:cancel, :audit_event_not_found}` — row deleted between enqueue and perform
      (e.g. retention cleanup raced the job). Non-retryable.
    - `{:cancel, :unknown_forwarder}` — forwarder module no longer compiled/loaded.
      Non-retryable (configuration change removed the dep).
    - `{:cancel, :schema_mismatch}` — Threadline shipped a breaking schema change
      or actor configuration error. Non-retryable.
    - `{:error, reason}` — network / timeout / transient failure. Retryable with
      exponential backoff.

    ## Retry (D-14, D-15)

    `max_attempts: 5` — bumped from `EmailDelivery`'s `max_attempts: 3` because
    audit retries don't spam users. `backoff/1` curve mirrors `EmailDelivery`
    verbatim (D-15): exponential with jitter.

    ## Never Raises (D-17)

    `perform/1` NEVER raises. Non-`:ok` exits fire
    `[:sigra, :audit, :forward, :error]` telemetry. The originating audit/auth
    transaction already committed before this job was enqueued — failures here
    cannot roll it back (boundary doctrine D-21, Pitfall 2).

    ## Config Resolution (D-27)

    `:repo` is read from `Application.fetch_env!(:sigra, :repo)` — mirrors
    `EmailDelivery` exactly (`:repo` is a top-level `:sigra` key, not nested under
    `:audit`). `:audit_schema` is read from
    `Application.get_env(otp_app, :sigra_config)[:audit][:audit_schema]` following
    the single config-resolution idiom across all Sigra boot diagnostics.
    """

    use Oban.Worker,
      queue: :sigra_audit_forward,
      max_attempts: 5

    require Logger

    @impl Oban.Worker
    def perform(%Oban.Job{args: args, attempt: attempt} = _job) do
      try do
        # Parse thin job args (D-13) — only these three keys are read.
        forwarder_string = args["forwarder"]
        audit_event_id = args["audit_event_id"]
        _occurred_at_iso = args["occurred_at"]

        # Resolve the forwarder module (must be a loaded atom).
        # If the module was removed, cancel the job (non-retryable).
        case resolve_forwarder(forwarder_string) do
          {:error, :unknown_forwarder} ->
            {:cancel, :unknown_forwarder}

          {:ok, forwarder_module} ->
            # Resolve config from Application env (D-27 single config-resolution pattern).
            %{repo: repo, audit_schema: audit_schema} = resolve_config()

            # Reload the audit row by UUID (D-13 — full payload from DB, not args).
            case repo.get(audit_schema, audit_event_id) do
              nil ->
                {:cancel, :audit_event_not_found}

              audit_row ->
                # Build metadata map equivalent to what handle_event/4 receives
                # (same shape as Plan 02's extended emit_telemetry/1 metadata — D-31).
                metadata = %{
                  id: audit_row.id,
                  action: audit_row.action,
                  actor_id: audit_row.actor_id,
                  outcome: audit_row.outcome,
                  occurred_at: audit_row.occurred_at
                }

                # Force :sync so the worker itself does the inline call.
                # The worker IS already async (running in an Oban job process);
                # forcing :sync prevents re-enqueue recursion.
                opts = build_forwarder_opts(repo, audit_schema) ++ [dispatch: :sync]

                perform_forward(forwarder_module, metadata, opts, audit_event_id, attempt)
            end
        end
      rescue
        exception ->
          reason = Exception.message(exception)

          :telemetry.execute(
            [:sigra, :audit, :forward, :error],
            %{count: 1},
            %{
              forwarder: :audit_forward_worker,
              audit_event_id: args["audit_event_id"],
              action: nil,
              reason: exception,
              kind: :error,
              attempt: attempt
            }
          )

          Logger.warning("[Sigra.Workers.AuditForward] perform/1 rescued: #{reason}")

          {:error, reason}
      catch
        :exit, exit_reason ->
          :telemetry.execute(
            [:sigra, :audit, :forward, :error],
            %{count: 1},
            %{
              forwarder: :audit_forward_worker,
              audit_event_id: args["audit_event_id"],
              action: nil,
              reason: exit_reason,
              kind: :exit,
              attempt: attempt
            }
          )

          {:error, {:exit, exit_reason}}

        :throw, thrown_value ->
          :telemetry.execute(
            [:sigra, :audit, :forward, :error],
            %{count: 1},
            %{
              forwarder: :audit_forward_worker,
              audit_event_id: args["audit_event_id"],
              action: nil,
              reason: thrown_value,
              kind: :throw,
              attempt: attempt
            }
          )

          {:error, {:throw, thrown_value}}
      end
    end

    @impl Oban.Worker
    def backoff(%Oban.Job{attempt: attempt}) do
      # Exponential backoff with jitter: ~15s, ~60s (per D-25)
      trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)
    end

    # Private: resolve the forwarder module atom from a string.
    # Uses String.to_existing_atom/1 to prevent atom table exhaustion.
    defp resolve_forwarder(nil), do: {:error, :unknown_forwarder}

    defp resolve_forwarder(forwarder_string) when is_binary(forwarder_string) do
      try do
        module = String.to_existing_atom(forwarder_string)

        if Code.ensure_loaded?(module) do
          {:ok, module}
        else
          {:error, :unknown_forwarder}
        end
      rescue
        ArgumentError ->
          {:error, :unknown_forwarder}
      end
    end

    # Private: resolve Sigra config — repo + audit_schema.
    #
    # :repo mirrors the EmailDelivery pattern (lib/sigra/workers/email_delivery.ex:80):
    # read from Application.fetch_env!(:sigra, :repo). This is correct because :repo
    # is a top-level :sigra key, NOT a key nested under :audit in NimbleOptions
    # (audit: [...] only contains audit_schema, retention_days, etc. — not :repo).
    #
    # :audit_schema reads from the host app's sigra_config/0 audit opts (D-27).
    #
    # Supports Process dictionary override for tests:
    #   Process.put(:sigra_audit_forward_config, %{repo: StubRepo, audit_schema: SomeSchema})
    defp resolve_config do
      case Process.get(:sigra_audit_forward_config) do
        %{} = override ->
          override

        nil ->
          %{
            repo: Application.fetch_env!(:sigra, :repo),
            audit_schema: fetch_audit_schema!()
          }
      end
    end

    # Private: fetch audit_schema from the host app's sigra_config/0.
    # Uses the Application.get_env(otp_app, :sigra_config) pattern (D-27).
    defp fetch_audit_schema! do
      otp_app = Application.get_env(:sigra, :otp_app)

      audit_opts =
        case otp_app && Application.get_env(otp_app, :sigra_config) do
          opts when is_list(opts) -> Keyword.get(opts, :audit, [])
          _ -> []
        end

      Keyword.fetch!(audit_opts, :audit_schema)
    end

    # Private: build per-forwarder opts for the handle_event/4 call.
    # Includes :repo and :audit_schema so the forwarder impl can use them.
    defp build_forwarder_opts(repo, audit_schema) do
      [repo: repo, audit_schema: audit_schema]
    end

    # Private: call the forwarder and handle all return shapes.
    # Returns Oban-compatible tagged tuples. NEVER raises (D-17).
    defp perform_forward(forwarder_module, metadata, opts, audit_event_id, attempt) do
      try do
        if function_exported?(forwarder_module, :handle_event, 4) do
          event = [:sigra, :audit, :log]
          result = forwarder_module.handle_event(event, %{count: 1}, metadata, opts)

          case result do
            :ok ->
              :ok

            {:ok, _} ->
              :ok

            {:error, :schema_mismatch} ->
              {:cancel, :schema_mismatch}

            {:error, :missing_actor} ->
              {:cancel, :schema_mismatch}

            {:error, :invalid_actor_ref} ->
              {:cancel, :schema_mismatch}

            {:error, :missing_repo} ->
              {:cancel, :schema_mismatch}

            {:error, reason} ->
              {:error, reason}

            other ->
              Logger.warning(
                "[Sigra.Workers.AuditForward] Unexpected return from #{inspect(forwarder_module)}: #{inspect(other)}"
              )

              {:error, {:unexpected_return, other}}
          end
        else
          # Forwarder does not implement handle_event/4 convention — log and cancel.
          Logger.warning(
            "[Sigra.Workers.AuditForward] Forwarder #{inspect(forwarder_module)} does not export handle_event/4"
          )

          {:cancel, :unknown_forwarder}
        end
      rescue
        exception ->
          reason = Exception.message(exception)

          :telemetry.execute(
            [:sigra, :audit, :forward, :error],
            %{count: 1},
            %{
              forwarder: :audit_forward_worker,
              audit_event_id: audit_event_id,
              action: metadata[:action],
              reason: exception,
              kind: :error,
              attempt: attempt
            }
          )

          Logger.warning("[Sigra.Workers.AuditForward] Forwarder raised: #{reason}")

          {:error, reason}
      catch
        :exit, exit_reason ->
          :telemetry.execute(
            [:sigra, :audit, :forward, :error],
            %{count: 1},
            %{
              forwarder: :audit_forward_worker,
              audit_event_id: audit_event_id,
              action: metadata[:action],
              reason: exit_reason,
              kind: :exit,
              attempt: attempt
            }
          )

          {:error, {:exit, exit_reason}}

        :throw, thrown_value ->
          :telemetry.execute(
            [:sigra, :audit, :forward, :error],
            %{count: 1},
            %{
              forwarder: :audit_forward_worker,
              audit_event_id: audit_event_id,
              action: metadata[:action],
              reason: thrown_value,
              kind: :throw,
              attempt: attempt
            }
          )

          {:error, {:throw, thrown_value}}
      end
    end
  end
end
