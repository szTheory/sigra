if Code.ensure_loaded?(Oban.Worker) do
  defmodule Sigra.Workers.RecoveryRequest do
    @moduledoc """
    Durable Oban adapter for `Sigra.Recovery` requests.

    Job args contain only a trusted configured host identifier and the
    authenticated encrypted request envelope. Host modules are resolved from
    `:sigra, :recovery_hosts`; job arguments never select a module.
    """

    use Oban.Worker, queue: :sigra_recovery, max_attempts: 3

    import Ecto.Query

    alias Sigra.Recovery

    @checkpoint_key "sigra_recovery_v1"

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"host_id" => host_id, "envelope" => envelope}} = job)
        when is_binary(host_id) and is_binary(envelope) do
      with {:ok, handler} <- resolve_handler(host_id),
           secret when is_binary(secret) <- handler.recovery_secret_key_base(),
           repo when is_atom(repo) <- handler.recovery_repo(),
           result <-
             Recovery.process_request(
               job.id,
               host_id,
               envelope,
               handler: handler,
               dispatcher: __MODULE__,
               repo: repo,
               secret_key_base: secret,
               prefix: handler.recovery_oban_prefix()
             ) do
        case result do
          {:ok, :no_delivery} -> {:ok, :no_delivery}
          {:ok, :delivered} -> {:ok, :delivered}
          {:error, :invalid_envelope} -> {:cancel, :invalid_request}
          {:error, _} -> {:error, :recovery_failed}
        end
      else
        {:error, :invalid_envelope} -> {:cancel, :invalid_request}
        {:error, :invalid_checkpoint} -> {:cancel, :invalid_request}
        {:error, :missing_job} -> {:cancel, :missing_job}
        _ -> {:error, :recovery_failed}
      end
    rescue
      _ -> {:error, :recovery_failed}
    end

    def perform(_job), do: {:cancel, :invalid_request}

    @doc false
    def enqueue(host_id, envelope, opts) when is_binary(host_id) and is_binary(envelope) do
      oban = Keyword.get(opts, :oban, Oban)
      queue = Keyword.get(opts, :queue, :sigra_recovery)

      if Sigra.OptionalDeps.oban_available?() and Oban.whereis(oban) != nil and is_atom(queue) do
        args = %{"host_id" => host_id, "envelope" => envelope}
        changeset = new(args, queue: queue, max_attempts: 3)

        case Oban.insert(oban, changeset) do
          {:ok, job} -> {:ok, job}
          {:error, _} -> {:error, :recovery_unavailable}
        end
      else
        {:error, :recovery_unavailable}
      end
    rescue
      _ -> {:error, :recovery_unavailable}
    end

    @doc false
    def checkpoint_once(job_ref, repo, prepare, opts)
        when is_function(prepare, 0) and is_list(opts) do
      host_id = Keyword.fetch!(opts, :host_id)
      secret = Keyword.fetch!(opts, :secret_key_base)
      prefix = Keyword.get(opts, :prefix, "public")

      result =
        repo.transact(fn ->
          query =
            from job in Oban.Job,
              prefix: ^prefix,
              where: job.id == ^job_ref,
              lock: "FOR UPDATE"

          case repo.one(query) do
            nil ->
              {:error, :missing_job}

            job ->
              case Map.get(job.meta || %{}, @checkpoint_key) do
                nil ->
                  persist_checkpoint(repo, job, job_ref, host_id, secret, prepare, prefix)

                encrypted ->
                  case Recovery.decrypt_checkpoint(secret, host_id, job_ref, encrypted) do
                    {:ok, descriptor} -> {:ok, {descriptor, false, %{}}}
                    {:error, _} -> {:error, :invalid_checkpoint}
                  end
              end
          end
        end)

      case result do
        {:ok, {descriptor, fresh?, audit_changes}} ->
          {:ok, descriptor, fresh?, audit_changes}

        {:error, _reason} ->
          {:error, :recovery_failed}

        _ ->
          {:error, :recovery_failed}
      end
    rescue
      _ -> {:error, :recovery_failed}
    end

    defp persist_checkpoint(repo, job, job_ref, host_id, secret, prepare, prefix) do
      case prepare.() do
        {:ok, %{descriptor: descriptor, audit_changes: audit_changes}} ->
          with {:ok, encrypted} <-
                 Recovery.encrypt_checkpoint(secret, host_id, job_ref, descriptor),
               changeset <-
                 Oban.Job.update(job, %{
                   meta: Map.put(job.meta || %{}, @checkpoint_key, encrypted)
                 }),
               {:ok, _updated} <- repo.update(changeset, prefix: prefix) do
            {:ok, {descriptor, true, audit_changes}}
          else
            _ -> {:error, :recovery_failed}
          end

        _ ->
          {:error, :recovery_failed}
      end
    end

    defp resolve_handler(host_id) do
      case Application.get_env(:sigra, :recovery_hosts, %{}) do
        hosts when is_map(hosts) ->
          case Map.get(hosts, host_id) do
            module when is_atom(module) ->
              if Code.ensure_loaded?(module) and
                   function_exported?(module, :recovery_secret_key_base, 0) and
                   function_exported?(module, :recovery_repo, 0) and
                   function_exported?(module, :recovery_oban_prefix, 0) and
                   function_exported?(module, :prepare_recovery_request, 2) and
                   function_exported?(module, :deliver_recovery_request, 1) do
                {:ok, module}
              else
                {:error, :invalid_host}
              end

            _ ->
              {:error, :invalid_host}
          end

        _ ->
          {:error, :invalid_host}
      end
    end
  end
end
