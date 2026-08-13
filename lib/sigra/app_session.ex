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

  @doc """
  Revokes one active app-session family owned by `user`.

  The family selector is bound to the trusted owner in the locked lookup, so
  foreign, missing, and already-revoked families are indistinguishable.
  """
  @spec revoke_family_for_user(Sigra.Config.t(), struct(), term()) ::
          {:ok, map()}
          | {:error, :not_found | :app_session_not_configured | :app_session_revoke_aborted}
  def revoke_family_for_user(config, user, family_id) do
    with {:ok, settings} <- settings(config) do
      multi =
        Multi.new()
        |> Multi.run(:app_session_revoke_family, fn repo, _changes ->
          revoke_owned_family(repo, settings, user.id, family_id)
        end)
        |> append_revoke_family_audit(config, user.id)

      try do
        case config.repo.transaction(multi) do
          {:ok, %{app_session_revoke_family: family} = changes} ->
            Audit.emit_telemetry_from_changes(changes, [:audit_app_session_revoke])
            {:ok, family}

          {:error, :app_session_revoke_family, :not_found, _changes} ->
            {:error, :not_found}

          {:error, _step, _reason, _changes} ->
            {:error, :app_session_revoke_aborted}
        end
      rescue
        _exception -> {:error, :app_session_revoke_aborted}
      end
    end
  end

  @doc """
  Revokes every active app-session family owned by `user`.

  Returns the number of active families changed. The update and optional audit
  share one transaction; audit telemetry is emitted only after commit.
  """
  @spec revoke_all_for_user(Sigra.Config.t(), struct()) ::
          {:ok, non_neg_integer()}
          | {:error, :app_session_not_configured | :app_session_revoke_aborted}
  def revoke_all_for_user(config, user) do
    with {:ok, _settings} <- settings(config) do
      multi =
        Multi.new()
        |> append_revoke_all_multi(config, user, [])
        |> append_revoke_all_audit(config, user.id)

      try do
        case config.repo.transaction(multi) do
          {:ok, %{app_session_revoke_all: %{count: count}} = changes} ->
            Audit.emit_telemetry_from_changes(changes, [:audit_app_session_revoke_all])
            {:ok, count}

          {:error, _step, _reason, _changes} ->
            {:error, :app_session_revoke_aborted}
        end
      rescue
        _exception -> {:error, :app_session_revoke_aborted}
      end
    end
  end

  @doc """
  Appends user-wide app-session revocation to an existing `Ecto.Multi`.

  This schema-agnostic primitive uses the transaction repo and does not start
  its own transaction. Callers that need an audit row compose their own outer
  audit event in the same Multi.
  """
  @spec append_revoke_all_multi(Ecto.Multi.t(), Sigra.Config.t(), struct(), keyword()) ::
          Ecto.Multi.t()
  def append_revoke_all_multi(%Multi{} = multi, config, user, opts \\ []) when is_list(opts) do
    step = Keyword.get(opts, :step, :app_session_revoke_all)

    Multi.run(multi, step, fn repo, _changes ->
      with {:ok, settings} <- settings(config) do
        revoke_all_owned_families(repo, settings, user.id)
      end
    end)
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

  defp revoke_owned_family(repo, settings, user_id, family_id) do
    family =
      repo.one(
        from(family in settings.family_schema,
          where:
            family.id == ^family_id and family.user_id == ^user_id and is_nil(family.revoked_at),
          lock: "FOR UPDATE"
        )
      )

    case family do
      nil ->
        {:error, :not_found}

      family ->
        now = now()

        with {:ok, revoked_family} <- repo.update(Ecto.Changeset.change(family, revoked_at: now)),
             {_, _} <-
               repo.update_all(
                 from(token in settings.token_schema,
                   where: token.family_id == ^family.id and is_nil(token.revoked_at)
                 ),
                 set: [revoked_at: now]
               ) do
          {:ok, revoked_family}
        end
    end
  end

  defp revoke_all_owned_families(repo, settings, user_id) do
    now = now()

    family_ids =
      repo.all(
        from(family in settings.family_schema,
          where: family.user_id == ^user_id and is_nil(family.revoked_at),
          select: family.id,
          lock: "FOR UPDATE"
        )
      )

    {count, _} =
      repo.update_all(
        from(family in settings.family_schema,
          where: family.id in ^family_ids and is_nil(family.revoked_at)
        ),
        set: [revoked_at: now]
      )

    if family_ids != [] do
      repo.update_all(
        from(token in settings.token_schema,
          where: token.family_id in ^family_ids and is_nil(token.revoked_at)
        ),
        set: [revoked_at: now]
      )
    end

    {:ok, %{count: count, family_ids: family_ids}}
  end

  defp append_revoke_family_audit(multi, config, user_id) do
    Audit.log_multi_safe(
      multi,
      "session.app_revoke",
      revoke_audit_opts(config, user_id, :audit_app_session_revoke, fn changes ->
        %{
          family_id: changes.app_session_revoke_family.id,
          kind: "app_session",
          lifecycle: "revoke"
        }
      end)
    )
  end

  defp append_revoke_all_audit(multi, config, user_id) do
    Audit.log_multi_safe(
      multi,
      "session.app_revoke_all",
      revoke_audit_opts(config, user_id, :audit_app_session_revoke_all, fn changes ->
        %{
          count: changes.app_session_revoke_all.count,
          kind: "app_session",
          lifecycle: "revoke_all"
        }
      end)
    )
  end

  defp revoke_audit_opts(config, user_id, audit_multi_step, metadata_resolver) do
    [
      repo: config.repo,
      audit_schema: Keyword.get(Map.get(config, :audit, []), :audit_schema),
      actor_id: user_id,
      target_id: user_id,
      metadata_resolver: metadata_resolver,
      audit_multi_step: audit_multi_step
    ]
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

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)

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
