defmodule Sigra.Recovery do
  @moduledoc """
  Lookup-free, durable ingress for password-reset and magic-link requests.

  Public hosts should call `enqueue/3` from recovery request endpoints and
  render only `{:ok, :accepted}`. A configured dispatcher must durably persist
  the encrypted envelope before returning success. It must never fall back to
  synchronous account lookup or delivery.

  Dispatchers implement `enqueue/3` and `checkpoint_once/3`. The checkpoint
  callback must execute `prepare` inside the same transaction that serializes
  the stable job identity and persists its encrypted outcome.
  """

  @envelope_salt "sigra-recovery-request-v1"
  @checkpoint_salt "sigra-recovery-checkpoint-v1"
  # Recovery jobs may sit in a durable queue before the worker starts. Keep
  # the bound finite, but long enough to survive normal queue backlogs and
  # Oban retries. Reset/magic tokens retain their own shorter TTLs.
  @max_age 86_400
  @max_raw_bytes 512

  @callback enqueue(binary(), binary(), keyword()) :: {:ok, term()} | {:error, term()}
  @callback checkpoint_once(term(), module(), (-> term()), keyword()) ::
              {:ok, term(), boolean()} | {:error, term()}

  @doc "Durably admits a reset or magic-link request without account lookup."
  @spec enqueue(:reset | :magic_link, binary(), keyword()) ::
          {:ok, :accepted} | {:error, :rate_limited | :recovery_unavailable}
  def enqueue(operation, address, opts)
      when operation in [:reset, :magic_link] and is_binary(address) do
    with true <- byte_size(address) <= @max_raw_bytes,
         normalized <- Sigra.Email.normalize(address),
         :ok <- Sigra.Email.validate_format(normalized),
         :ok <- check_rate_limit(operation, normalized, opts),
         {:ok, dispatcher, host_id, secret} <- dispatcher_config(opts),
         {:ok, envelope} <- encrypt_envelope(operation, normalized, host_id, secret),
         {:ok, _job} <-
           dispatcher.enqueue(host_id, envelope, Keyword.get(opts, :dispatch_opts, [])) do
      {:ok, :accepted}
    else
      {:error, :rate_limited} -> {:error, :rate_limited}
      _ -> {:error, :recovery_unavailable}
    end
  rescue
    _ -> {:error, :recovery_unavailable}
  catch
    _, _ -> {:error, :recovery_unavailable}
  end

  def enqueue(_, _, _), do: {:error, :recovery_unavailable}

  @doc false
  def decrypt_envelope(envelope, host_id, secret)
      when is_binary(envelope) and is_binary(host_id) do
    case Plug.Crypto.decrypt(secret, @envelope_salt, envelope, max_age: @max_age) do
      {:ok,
       %{"version" => 1, "host_id" => ^host_id, "operation" => operation, "address" => address}}
      when operation in ["reset", "magic_link"] and is_binary(address) ->
        if String.length(address) <= 160 and Sigra.Email.validate_format(address) == :ok do
          {:ok, {if(operation == "reset", do: :reset, else: :magic_link), address}}
        else
          {:error, :invalid_envelope}
        end

      _ ->
        {:error, :invalid_envelope}
    end
  rescue
    _ -> {:error, :invalid_envelope}
  end

  def decrypt_envelope(_, _, _), do: {:error, :invalid_envelope}

  @doc false
  def encrypt_checkpoint(secret, host_id, job_ref, descriptor) do
    {:ok,
     Plug.Crypto.encrypt(
       secret,
       @checkpoint_salt,
       %{
         "version" => 1,
         "host_id" => host_id,
         "job_ref" => to_string(job_ref),
         "descriptor" => descriptor
       }
     )}
  rescue
    _ -> {:error, :encryption_failed}
  end

  @doc false
  def decrypt_checkpoint(secret, host_id, job_ref, checkpoint) when is_binary(checkpoint) do
    expected_ref = to_string(job_ref)

    case Plug.Crypto.decrypt(secret, @checkpoint_salt, checkpoint, max_age: @max_age) do
      {:ok,
       %{
         "version" => 1,
         "host_id" => ^host_id,
         "job_ref" => ref,
         "descriptor" => descriptor
       }}
      when is_binary(ref) ->
        if ref == expected_ref, do: {:ok, descriptor}, else: {:error, :invalid_checkpoint}

      _ ->
        {:error, :invalid_checkpoint}
    end
  rescue
    _ -> {:error, :invalid_checkpoint}
  end

  def decrypt_checkpoint(_, _, _, _), do: {:error, :invalid_checkpoint}

  defp check_rate_limit(operation, normalized, opts) do
    case Keyword.get(opts, :rate_limiter) do
      nil ->
        :ok

      limiter ->
        key =
          if operation == :magic_link,
            do: "magic_link:#{normalized}",
            else: "sigra:reset:#{normalized}"

        max_requests = Keyword.get(opts, :max_requests, 3)
        window_ms = Keyword.get(opts, :window_ms, 900_000)

        case limiter.check_rate(key, max_requests, window_ms) do
          {:allow, _count} -> :ok
          {:deny, _retry_after} -> {:error, :rate_limited}
          _ -> {:error, :rate_limited}
        end
    end
  end

  defp dispatcher_config(opts) do
    with dispatcher when is_atom(dispatcher) <- Keyword.get(opts, :dispatcher),
         true <- Code.ensure_loaded?(dispatcher),
         true <- function_exported?(dispatcher, :enqueue, 3),
         true <- function_exported?(dispatcher, :checkpoint_once, 4),
         host_id when is_binary(host_id) and byte_size(host_id) > 0 and byte_size(host_id) <= 80 <-
           Keyword.get(opts, :host_id),
         secret when is_binary(secret) and byte_size(secret) >= 64 <-
           Keyword.get(opts, :secret_key_base) do
      {:ok, dispatcher, host_id, secret}
    else
      _ -> {:error, :invalid_dispatcher}
    end
  end

  defp encrypt_envelope(operation, address, host_id, secret) do
    payload = %{
      "version" => 1,
      "operation" => Atom.to_string(operation),
      "address" => address,
      "host_id" => host_id
    }

    {:ok, Plug.Crypto.encrypt(secret, @envelope_salt, payload)}
  rescue
    _ -> {:error, :encryption_failed}
  end
end
