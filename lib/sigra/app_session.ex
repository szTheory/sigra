defmodule Sigra.AppSession do
  @moduledoc """
  Digest-only opaque credential issuance and access authentication for host-owned
  first-party app-session schemas.

  The host supplies Ecto schemas through `Sigra.Config`; this module never owns
  generated schema names or migrations.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Sigra.Audit
  alias Sigra.AppSession.RefreshToken
  alias Sigra.Token

  @type result ::
          {:ok, map()}
          | {:error, :app_session_not_configured | :invalid_client_ref | :invalid_token}

  @spec issue(Sigra.Config.t(), struct(), String.t(), keyword()) :: result()
  def issue(config, user, client_ref, _opts \\ []) do
    with {:ok, settings} <- settings(config),
         :ok <- valid_client_ref(client_ref) do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      {access_raw, access_digest} = Token.generate_hashed_token()
      {refresh_raw, refresh_digest} = Token.generate_hashed_token()

      family =
        struct!(settings.family_schema, %{
          user_id: user.id,
          client_ref: client_ref,
          absolute_expires_at: DateTime.add(now, settings.absolute_ttl, :second)
        })

      multi =
        Multi.new()
        |> Multi.insert(:family, family)
        |> Multi.run(:tokens, fn repo, %{family: persisted_family} ->
          insert_tokens(repo, settings, persisted_family.id, access_digest, refresh_digest, now)
        end)

      case config.repo.transaction(multi) do
        {:ok, %{family: persisted_family}} ->
          {:ok,
           %{
             access_token: access_raw,
             refresh_token: refresh_raw,
             family_id: persisted_family.id,
             expires_in: settings.access_ttl
           }}

        {:error, _, _, _} ->
          {:error, :invalid_token}
      end
    end
  end

  @spec authenticate(Sigra.Config.t(), String.t()) :: result()
  def authenticate(config, raw_access_token) do
    with {:ok, settings} <- settings(config),
         {:ok, digest} <- digest(raw_access_token),
         {token, family} when not is_nil(token) <- access_token(config.repo, settings, digest),
         true <- active?(token, family),
         user when not is_nil(user) <- config.repo.get(config.user_schema, family.user_id) do
      {:ok, %{user_id: user.id, family_id: family.id, token_id: token.id}}
    else
      {:error, :app_session_not_configured} = error -> error
      _ -> {:error, :invalid_token}
    end
  end

  @doc """
  Rotates an opaque app-session refresh credential.

  The presented refresh row is locked and classified before the transaction
  consumes it, supersedes the active access credential, and appends a new
  access/refresh pair. Reuse revokes the entire family before the bounded
  error becomes observable.
  """
  @spec refresh(Sigra.Config.t(), String.t()) ::
          {:ok, map()}
          | {:error,
             :app_session_not_configured
             | :invalid_token
             | :token_expired
             | :reuse_detected
             | :app_session_refresh_aborted}
  def refresh(config, raw_refresh_token) do
    with {:ok, _settings} <- settings(config) do
      multi =
        Multi.new()
        |> RefreshToken.build_locked_classify_multi(config, raw_refresh_token)
        |> Multi.merge(fn %{app_session_refresh_classification: {action, token, family}} ->
          action
          |> build_refresh_mutation_multi(config, token, family)
          |> append_refresh_audit(config, family, action)
        end)

      try do
        case config.repo.transaction(multi) do
          {:ok,
           %{
             app_session_refresh_classification: {:rotate, _token, family},
             app_session_refresh_rotate: replacement
           } = changes} ->
            Audit.emit_telemetry_from_changes(changes, [:audit_app_session_refresh])

            {:ok,
             %{
               access_token: replacement.access_token,
               refresh_token: replacement.refresh_token,
               family_id: family.id,
               expires_in: settings_access_ttl(config)
             }}

          {:ok, %{app_session_refresh_classification: {:reuse, _token, _family}} = changes} ->
            Audit.emit_telemetry_from_changes(changes, [:audit_app_session_refresh_reuse])
            {:error, :reuse_detected}

          {:error, :app_session_refresh_classification, reason, _changes}
          when reason in [:invalid_token, :token_expired] ->
            {:error, reason}

          {:error, _step, _reason, _changes} ->
            {:error, :app_session_refresh_aborted}
        end
      rescue
        _exception -> {:error, :app_session_refresh_aborted}
      end
    end
  end

  defp build_refresh_mutation_multi(:rotate, config, token, family) do
    RefreshToken.build_rotate_persist_multi(Multi.new(), config, token, family)
  end

  defp build_refresh_mutation_multi(:reuse, config, _token, family) do
    RefreshToken.build_revoke_family_multi(Multi.new(), config, family)
  end

  defp append_refresh_audit(multi, config, family, action) do
    case Keyword.get(Map.get(config, :audit, []), :audit_schema) do
      nil ->
        multi

      audit_schema ->
        {audit_action, audit_step, outcome} =
          case action do
            :rotate -> {"session.app_refresh", :audit_app_session_refresh, "success"}
            :reuse -> {"session.app_refresh_reuse", :audit_app_session_refresh_reuse, "failure"}
          end

        Audit.log_multi_safe(
          multi,
          audit_action,
          repo: config.repo,
          audit_schema: audit_schema,
          actor_id: family.user_id,
          target_id: family.user_id,
          outcome: outcome,
          metadata: %{
            family_id: family.id,
            kind: "app_session",
            lifecycle: Atom.to_string(action)
          },
          audit_multi_step: audit_step
        )
    end
  end

  defp insert_tokens(repo, settings, family_id, access_digest, refresh_digest, now) do
    access =
      struct!(settings.token_schema, %{
        family_id: family_id,
        kind: :access,
        digest: access_digest,
        expires_at: DateTime.add(now, settings.access_ttl, :second)
      })

    refresh =
      struct!(settings.token_schema, %{
        family_id: family_id,
        kind: :refresh,
        digest: refresh_digest,
        expires_at: DateTime.add(now, settings.refresh_idle_ttl, :second)
      })

    with {:ok, _} <- repo.insert(access),
         {:ok, _} <- repo.insert(refresh) do
      {:ok, :inserted}
    end
  end

  defp access_token(repo, settings, digest) do
    repo.one(
      from(token in settings.token_schema,
        join: family in ^settings.family_schema,
        on: token.family_id == family.id,
        where: token.digest == ^digest and token.kind == :access,
        select: {token, family}
      )
    )
  end

  defp active?(token, family) do
    now = DateTime.utc_now()

    is_nil(token.consumed_at) and is_nil(token.superseded_at) and is_nil(token.revoked_at) and
      is_nil(family.revoked_at) and DateTime.compare(now, token.expires_at) == :lt and
      DateTime.compare(now, family.absolute_expires_at) == :lt
  end

  defp settings_access_ttl(%{app_session: app_session}), do: app_session[:access_ttl]

  defp settings(%{app_session: app_session}) do
    with family_schema when is_atom(family_schema) <- app_session[:family_schema],
         token_schema when is_atom(token_schema) <- app_session[:token_schema],
         true <- Code.ensure_loaded?(family_schema) and Code.ensure_loaded?(token_schema),
         true <-
           app_session[:access_ttl] < app_session[:refresh_idle_ttl] and
             app_session[:refresh_idle_ttl] <= app_session[:absolute_ttl] do
      {:ok,
       %{
         family_schema: family_schema,
         token_schema: token_schema,
         access_ttl: app_session[:access_ttl],
         refresh_idle_ttl: app_session[:refresh_idle_ttl],
         absolute_ttl: app_session[:absolute_ttl]
       }}
    else
      _ -> {:error, :app_session_not_configured}
    end
  end

  defp valid_client_ref(ref) when is_binary(ref) and byte_size(ref) in 1..255, do: :ok
  defp valid_client_ref(_), do: {:error, :invalid_client_ref}

  defp digest(raw) when is_binary(raw) do
    case Base.url_decode64(raw, padding: false) do
      {:ok, decoded} -> {:ok, Token.hash_token(decoded)}
      :error -> {:error, :invalid_token}
    end
  end

  defp digest(_), do: {:error, :invalid_token}
end
