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

    import Ecto.Query

    alias Sigra.Integrations.Chimeway.PendingDelivery

    @doc false
    def enabled? do
      Application.get_env(:sigra, :chimeway, [])[:enabled] != false
    end

    @doc false
    def repo do
      Application.get_env(:sigra, :repo) || Sigra.Repo
    end

    @doc """
    Triggers `sigra.auth.magic_link` after a successful magic-link request.

    Stores the login URL in `PendingDelivery` keyed by idempotency key; trigger
    params contain identifiers only (no `url` or `raw_token`).
    """
    @spec dispatch_magic_link(module(), struct(), String.t(), String.t(), keyword()) ::
            {:ok, map()} | {:duplicate, struct()} | {:error, term()}
    def dispatch_magic_link(repo, user, _raw_token, url, opts \\ []) do
      with true <- enabled?(),
           user_token_schema <- user_token_schema(opts),
           {:ok, token_inserted_at} <-
             fetch_magic_link_token_inserted_at(repo, user, user_token_schema) do
        user_id = user_id_string(user)
        idempotency_key = magic_link_idempotency_key(user_id, token_inserted_at)

        :ok = PendingDelivery.put(idempotency_key, %{url: url})

        trigger_params = %{
          "idempotency_key" => idempotency_key,
          "user_id" => user_id,
          "email" => user.email,
          "kind" => "magic_link"
        }

        trigger_opts =
          [
            idempotency_key: idempotency_key,
            tenant_id: user_id,
            correlation_id: opts[:correlation_id]
          ]
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)

        case Chimeway.trigger(__MODULE__.MagicLinkNotifier, trigger_params, trigger_opts) do
          {:ok, result} -> {:ok, result}
          {:duplicate, event} -> {:duplicate, event}
          {:error, reason} -> {:error, reason}
        end
      else
        false -> {:error, :disabled}
        {:error, reason} -> {:error, reason}
      end
    end

    @doc """
    Calls `Sigra.Auth.request_magic_link/3` then dispatches via Chimeway on success.
    """
    @spec dispatch_magic_link_after_request(module(), String.t(), keyword()) ::
            {:ok, {String.t(), String.t(), map()}}
            | {:ok, :sent}
            | {:error, term()}
    def dispatch_magic_link_after_request(repo, email, opts \\ []) do
      auth_opts =
        opts
        |> Keyword.take([
          :user_schema,
          :user_token_schema,
          :url_fun,
          :rate_limiter,
          :max_requests,
          :window_ms
        ])
        |> Keyword.merge(
          user_schema: Keyword.get(opts, :user_schema, user_schema(opts)),
          user_token_schema: Keyword.get(opts, :user_token_schema, user_token_schema(opts)),
          url_fun: Keyword.fetch!(opts, :url_fun)
        )

      case Sigra.Auth.request_magic_link(repo, email, auth_opts) do
        {:ok, {raw_token, url}} ->
          user = repo.get_by!(auth_opts[:user_schema], email: Sigra.Email.normalize(email))

          case dispatch_magic_link(repo, user, raw_token, url, opts) do
            {:ok, result} -> {:ok, {raw_token, url, result}}
            {:duplicate, event} -> {:ok, {raw_token, url, %{event: event, duplicate: true}}}
            {:error, reason} -> {:error, reason}
          end

        other ->
          other
      end
    end

    @doc false
    def dispatch_confirmation_code(_repo, user, _encoded_token, code, url, opts \\ []) do
      with true <- enabled?(),
           confirmation_id when not is_nil(confirmation_id) <-
             opts[:confirmation_id] || opts["confirmation_id"] do
        user_id = user_id_string(user)
        idempotency_key = confirmation_idempotency_key(user_id, confirmation_id)

        :ok = PendingDelivery.put(idempotency_key, %{code: code, url: url})

        trigger_params = %{
          "idempotency_key" => idempotency_key,
          "user_id" => user_id,
          "email" => user.email,
          "confirmation_id" => to_string(confirmation_id),
          "kind" => "confirmation_code"
        }

        trigger_opts =
          [
            idempotency_key: idempotency_key,
            tenant_id: user_id,
            correlation_id: opts[:correlation_id]
          ]
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)

        case Chimeway.trigger(__MODULE__.ConfirmationCodeNotifier, trigger_params, trigger_opts) do
          {:ok, result} -> {:ok, result}
          {:duplicate, event} -> {:duplicate, event}
          {:error, reason} -> {:error, reason}
        end
      else
        false -> {:error, :disabled}
        nil -> {:error, :missing_confirmation_id}
        {:error, reason} -> {:error, reason}
      end
    end

    @doc """
    Generates confirmation tokens, inserts link/code rows, and dispatches via Chimeway.

    Does not call `Sigra.Delivery.deliver/3` — Chimeway Logger adapter only in Phase 64 tests.
    """
    @spec dispatch_confirmation_after_generate(module(), struct(), keyword()) ::
            {:ok, {String.t(), String.t(), String.t(), map()}} | {:error, term()}
    def dispatch_confirmation_after_generate(repo, user, opts \\ []) do
      user_token_schema = user_token_schema(opts)

      secret_key_base =
        Keyword.get(opts, :secret_key_base) ||
          Application.get_env(:sigra, :secret_key_base) ||
          raise ArgumentError, "secret_key_base required"

      confirmation_url_fun = Keyword.fetch!(opts, :confirmation_url_fun)

      {encoded_token, code, link_struct, code_struct} =
        Sigra.Auth.generate_confirmation_token(repo, user,
          secret_key_base: secret_key_base,
          user_token_schema: user_token_schema
        )

      link_token = repo.insert!(link_struct)
      _code_token = repo.insert!(code_struct)

      url = confirmation_url_fun.(encoded_token)

      case dispatch_confirmation_code(
             repo,
             user,
             encoded_token,
             code,
             url,
             Keyword.put(opts, :confirmation_id, link_token.id)
           ) do
        {:ok, result} -> {:ok, {encoded_token, code, url, result}}
        {:duplicate, event} -> {:ok, {encoded_token, code, url, %{event: event, duplicate: true}}}
        {:error, reason} -> {:error, reason}
      end
    end

    defp confirmation_idempotency_key(user_id, confirmation_id) do
      "sigra.confirmation_code:" <> user_id <> ":" <> to_string(confirmation_id)
    end

    defp magic_link_idempotency_key(user_id, %DateTime{} = inserted_at) do
      "sigra.magic_link:" <> user_id <> ":" <> DateTime.to_iso8601(inserted_at)
    end

    defp magic_link_idempotency_key(user_id, %NaiveDateTime{} = inserted_at) do
      inserted_at
      |> DateTime.from_naive!("Etc/UTC")
      |> then(&magic_link_idempotency_key(user_id, &1))
    end

    defp fetch_magic_link_token_inserted_at(repo, user, user_token_schema) do
      case repo.one(
             from(t in user_token_schema,
               where: t.user_id == ^user.id and t.context == "magic_link",
               order_by: [desc: t.inserted_at],
               limit: 1,
               select: t.inserted_at
             )
           ) do
        nil -> {:error, :magic_link_token_not_found}
        inserted_at -> {:ok, inserted_at}
      end
    end

    defp user_id_string(%{id: id}) when is_integer(id), do: Integer.to_string(id)
    defp user_id_string(%{id: id}) when is_binary(id), do: id

    defp user_schema(opts) do
      Keyword.get(opts, :user_schema) ||
        Application.get_env(:sigra, :user_schema) ||
        raise ArgumentError, "user_schema required"
    end

    defp user_token_schema(opts) do
      Keyword.get(opts, :user_token_schema) ||
        Application.get_env(:sigra, :user_token_schema) ||
        raise ArgumentError, "user_token_schema required"
    end

    defmodule MagicLinkNotifier do
      @moduledoc false

      @behaviour Chimeway.Notifier
      @compile {:no_warn_undefined, [Chimeway.Notifier]}

      alias Sigra.Integrations.Chimeway.PendingDelivery

      @impl true
      def notification_key, do: "sigra.auth.magic_link"

      @impl true
      def version, do: 1

      @impl true
      def recipients(params) do
        email = Map.get(params, :email) || Map.get(params, "email")

        if is_binary(email) and email != "" do
          {:ok, [%{recipient_identity: email, recipient_type: "email"}]}
        else
          {:error, :missing_email}
        end
      end

      @impl true
      def build(params, _recipient) do
        {:ok,
         %{
           user_id: Map.get(params, :user_id) || Map.get(params, "user_id"),
           kind: "magic_link"
         }}
      end

      @impl true
      def channels(_params, _recipient), do: {:ok, [:email]}

      @impl true
      def orchestration(_params, _recipient), do: {:ok, :immediate}

      @impl true
      def rendering(params, _recipient) do
        idempotency_key =
          Map.get(params, "idempotency_key") || Map.get(params, :idempotency_key)

        # Resolve URL at render time; pop deletes from ETS so secrets do not linger.
        _secrets = PendingDelivery.pop!(idempotency_key)

        {:ok,
         %{
           assigns: %{
             "subject" => "Sign in to your account",
             "html_body" => "<p>Use the secure sign-in link we sent you.</p>",
             "text_body" => "Use the secure sign-in link we sent you."
           },
           channels: %{
             email: %{
               render_key: "sigra.auth.magic_link.email",
               render_version: 1
             }
           }
         }}
      end
    end

    defmodule ConfirmationCodeNotifier do
      @moduledoc false

      @behaviour Chimeway.Notifier
      @compile {:no_warn_undefined, [Chimeway.Notifier]}

      alias Sigra.Integrations.Chimeway.PendingDelivery

      @impl true
      def notification_key, do: "sigra.auth.confirmation_code"

      @impl true
      def version, do: 1

      @impl true
      def recipients(params) do
        email = Map.get(params, :email) || Map.get(params, "email")

        if is_binary(email) and email != "" do
          {:ok, [%{recipient_identity: email, recipient_type: "email"}]}
        else
          {:error, :missing_email}
        end
      end

      @impl true
      def build(params, _recipient) do
        {:ok,
         %{
           user_id: Map.get(params, :user_id) || Map.get(params, "user_id"),
           confirmation_id:
             Map.get(params, :confirmation_id) || Map.get(params, "confirmation_id"),
           kind: "confirmation_code"
         }}
      end

      @impl true
      def channels(_params, _recipient), do: {:ok, [:email]}

      @impl true
      def orchestration(_params, _recipient), do: {:ok, :immediate}

      @impl true
      def rendering(params, _recipient) do
        idempotency_key =
          Map.get(params, "idempotency_key") || Map.get(params, :idempotency_key)

        _secrets = PendingDelivery.pop!(idempotency_key)

        {:ok,
         %{
           assigns: %{
             "subject" => "Confirm your account",
             "html_body" => "<p>Enter the confirmation code we sent you.</p>",
             "text_body" => "Enter the confirmation code we sent you."
           },
           channels: %{
             email: %{
               render_key: "sigra.auth.confirmation_code.email",
               render_version: 1
             }
           }
         }}
      end
    end

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
          [{^idempotency_key, secrets}] ->
            secrets

          [] ->
            raise ArgumentError,
                  "no pending delivery for idempotency_key #{inspect(idempotency_key)}"
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
