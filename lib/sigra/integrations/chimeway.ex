# Sigra.Integrations.Chimeway — conditionally compiled (ECOS-09, D-01, D-02).
#
# Host wiring: `{:chimeway, "~> 1.0"}` + runtime `config :sigra, chimeway: [enabled: true]`.
# Local dev path override: set CHIMEWAY_PATH when adding the optional dep in host mix.exs.

if Code.ensure_loaded?(Chimeway) do
  defmodule Sigra.Integrations.Chimeway do
    @moduledoc """
    Sigra → Chimeway auth notification bridge (ECOS-09).

    Conditionally compiled when optional `:chimeway` dep is present.
    Triggers identifier-only `Chimeway.trigger/3` calls for magic link and
    confirmation-code flows; sensitive URL/code values live in
    `PendingDelivery` until notifier `rendering/2` reads and deletes them.

    ## Idempotency keys

    - Magic link: `sigra.magic_link:{user_id}:{token_inserted_at_iso}`
    - Confirmation code: `sigra.confirmation_code:{user_id}:{confirmation_id}` where
      `confirmation_id` is the inserted link-token row id (opaque ref).

    ## MFA stand-in

    Confirmation-code dispatch stands in for ECOS-09 "MFA token dispatch" until Sigra
    ships dedicated outbound MFA OTP APIs (D-05).
    """

    @compile {:no_warn_undefined, [Chimeway, Chimeway.Notifier]}

    alias Sigra.Integrations.Chimeway.PendingDelivery

    @doc false
    def enabled? do
      Application.get_env(:sigra, :chimeway, [])[:enabled] != false
    end

    @doc false
    def repo do
      Application.get_env(:sigra, :repo) || Sigra.Repo
    end

    @doc false
    def dispatch_magic_link(_repo, _user, _raw_token, _url, _opts \\ []),
      do: {:error, :not_implemented}

    @doc false
    def dispatch_magic_link_after_request(_repo, _email, _opts \\ []),
      do: {:error, :not_implemented}

    @doc false
    def dispatch_confirmation_code(_repo, _user, _encoded_token, _code, _url, _opts \\ []),
      do: {:error, :not_implemented}

    @doc false
    def dispatch_confirmation_after_generate(_repo, _user, _opts \\ []),
      do: {:error, :not_implemented}

    defmodule PendingDelivery do
      @moduledoc false

      @table :sigra_chimeway_pending_delivery

      @doc false
      def put(idempotency_key, secrets_map)
          when is_binary(idempotency_key) and is_map(secrets_map) do
        ensure_table!()
        :ets.insert(@table, {idempotency_key, secrets_map})
        :ok
      end

      @doc false
      def fetch!(idempotency_key) when is_binary(idempotency_key) do
        ensure_table!()

        case :ets.lookup(@table, idempotency_key) do
          [{^idempotency_key, secrets}] -> secrets
          [] -> raise ArgumentError, "no pending delivery for idempotency_key #{inspect(idempotency_key)}"
        end
      end

      @doc false
      def pop!(idempotency_key) when is_binary(idempotency_key) do
        secrets = fetch!(idempotency_key)
        :ets.delete(@table, idempotency_key)
        secrets
      end

      @doc false
      def delete_all do
        ensure_table!()
        :ets.delete_all_objects(@table)
        :ok
      end

      defp ensure_table! do
        case :ets.info(@table) do
          :undefined ->
            :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

          _ ->
            :ok
        end
      end
    end
  end
end
