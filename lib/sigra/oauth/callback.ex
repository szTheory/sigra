defmodule Sigra.OAuth.Callback do
  @moduledoc """
  Processes OAuth callback data and routes to the appropriate account action.

  After successful token exchange, this module determines the correct path:

  1. **Existing identity** -- identity found by `(provider, provider_uid)`.
     Updates identity fields (D-31) and logs user in.
  2. **Email match** -- no identity, but a user with the same email exists.
     Returns `{:link_confirmation_required, ...}` for the controller to
     redirect to login (D-01, D-02).
  3. **New user** -- no identity and no email match. Registers user with
     `confirmed_at` set if provider email is trusted (D-42). Creates identity
     and session in a single transaction (Pitfall 6: race condition safety).
  4. **No email** -- provider didn't return email. Error (D-08).
  5. **UID/email conflict** -- provider_uid maps to identity A but email
     matches user B. Blocked with generic error (D-09).

  Identity lookups are always by `(provider, provider_uid)`, never by
  email alone (D-32).
  """

  require Logger

  alias Ecto.Multi
  alias Sigra.Audit
  alias Sigra.Error.OAuthError
  alias Sigra.EnterpriseRouting
  alias Sigra.Telemetry

  @doc """
  Processes an OAuth callback and routes to the appropriate account action.

  ## Parameters

  - `config` - Sigra config map with `:repo`, `:user_schema`, `:identity_schema`, `:oauth`, `:session`
  - `provider` - Provider atom (e.g., `:google`)
  - `user_info` - Normalized user info map from the strategy wrapper
  - `token` - Token map from the provider

  ## Returns

  - `{:ok, :registered, user, session}` - new user registered
  - `{:ok, :logged_in, user, session}` - existing identity login
  - `{:link_confirmation_required, %{provider: p, email: e, provider_uid: uid}}` - email match
  - `{:error, %OAuthError{error_code: :no_email}}` - provider returned no email
  - `{:error, %OAuthError{error_code: :email_mismatch}}` - UID/email cross-account conflict
  """
  @doc since: "0.5.0"
  @spec process_callback(map(), atom(), map(), map(), keyword()) ::
          {:ok, atom(), map(), map()}
          | {:link_confirmation_required, map()}
          | {:error, %OAuthError{}}
  def process_callback(config, provider, user_info, token, opts \\ []) do
    email = user_info["email"]

    # D-08: No email check
    if is_nil(email) or email == "" do
      Logger.error("OAuth callback for #{provider}: provider returned no email")
      {:error, %OAuthError{provider: provider, error_code: :no_email}}
    else
      with {:ok, enterprise_context} <-
             validate_enterprise_context(config, provider, Keyword.get(opts, :enterprise_context)) do
        provider_str = to_string(provider) |> String.downcase()
        provider_uid = to_string(user_info["sub"])

        do_process(config, provider, provider_str, provider_uid, user_info, token, enterprise_context)
      end
    end
  end

  # -- Private --

  defp do_process(config, provider, provider_str, provider_uid, user_info, token, enterprise_context) do
    repo = config.repo
    identity_schema = config.identity_schema
    user_schema = config.user_schema

    # Step 1: Look up identity by (provider, provider_uid) -- D-32
    identity = repo.get_by(identity_schema, provider: provider_str, provider_uid: provider_uid)

    cond do
      # Scenario 1: Existing identity found
      identity != nil ->
        handle_existing_identity(
          config,
          repo,
          identity,
          user_info,
          token,
          provider,
          enterprise_context
        )

      # Scenario 2-3: No identity, check for email match
      true ->
        email = user_info["email"]
        existing_user = repo.get_by(user_schema, email: email)

        if existing_user do
          # D-01: Email match requires login confirmation
          {:link_confirmation_required,
           %{
             provider: provider,
             provider_uid: user_info["sub"],
             email: email
           }}
        else
          # New user registration
          register_oauth_user(config, provider, provider_str, user_info, token, enterprise_context)
        end
    end
  end

  defp handle_existing_identity(
         config,
         repo,
         identity,
         user_info,
         token,
         provider,
         enterprise_context
       ) do
    user_schema = config.user_schema
    user = repo.get!(user_schema, identity.user_id)
    email = user_info["email"]

    # D-09: Check for UID/email cross-account conflict
    if email && user.email != email do
      other_user = repo.get_by(user_schema, email: email)

      if other_user && other_user.id != user.id do
        Logger.error(
          "OAuth UID/email mismatch: provider_uid #{identity.provider_uid} maps to user #{user.id} " <>
            "but email #{email} belongs to user #{other_user.id}"
        )

        return_email_mismatch(provider)
      else
        do_login_with_identity_update(
          config,
          repo,
          identity,
          user,
          user_info,
          token,
          provider,
          enterprise_context
        )
      end
    else
      do_login_with_identity_update(
        config,
        repo,
        identity,
        user,
        user_info,
        token,
        provider,
        enterprise_context
      )
    end
  end

  defp do_login_with_identity_update(
         config,
         repo,
         identity,
         user,
         user_info,
         token,
         provider,
         enterprise_context
       ) do
    # D-31: Update identity fields on every login. D-34: Update last_used_at.
    # Pitfall 2: Only update non-nil fields (Apple name is nil on re-auth).
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    updates =
      %{last_used_at: now}
      |> maybe_put(:provider_email, user_info["email"])
      |> maybe_put(:provider_name, user_info["name"])
      |> maybe_put(:provider_avatar_url, user_info["picture"])
      |> maybe_put(:encrypted_access_token, token["access_token"])
      |> maybe_put(:encrypted_refresh_token, token["refresh_token"])
      |> put_token_expires_at(token)

    changeset = Ecto.Changeset.change(identity, updates)
    provider_label = to_string(provider)

    audit_base =
      oauth_audit_base_opts(config)
      |> Keyword.merge(
        actor_resolver: fn _ -> user.id end,
        target_resolver: fn _ -> user.id end,
        effective_user_id_resolver: fn _ -> user.id end
      )

    multi =
      Multi.new()
      |> Multi.update(:identity, changeset)
      |> Audit.log_multi_safe(
        "oauth.callback.success",
        Keyword.merge(audit_base,
          audit_multi_step: :audit_oauth_login_success,
          outcome: "success",
          metadata_resolver: fn _ -> %{provider: provider_label, outcome: "logged_in"} end
        )
      )
      |> Audit.log_multi_safe(
        "oauth.login_via_oauth",
        Keyword.merge(audit_base,
          audit_multi_step: :audit_oauth_login,
          metadata_resolver: fn _ -> %{provider: provider_label} end
        )
      )

    case repo.transaction(multi) do
      {:ok, changes} ->
        Audit.emit_telemetry_from_changes(changes, [
          :audit_oauth_login_success,
          :audit_oauth_login
        ])

        session_metadata = build_session_metadata(config, provider, enterprise_context)

        Telemetry.event([:sigra, :oauth, :login, :stop], %{}, %{
          user_id: user.id,
          provider: provider_label
        })

        {:ok, :logged_in, user, session_metadata}

      {:error, _step, _reason, _changes} ->
        {:error, %OAuthError{provider: provider, error_code: :provider_error}}
    end
  end

  defp register_oauth_user(config, provider, provider_str, user_info, token, enterprise_context) do
    repo = config.repo
    user_schema = config.user_schema
    identity_schema = config.identity_schema
    trust_email = Keyword.get(config.oauth, :trust_provider_email, true)
    email_verified = user_info["email_verified"] == true

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # D-42: Auto-confirm if trust_provider_email and email_verified
    confirmed_at =
      if trust_email and email_verified do
        now
      else
        nil
      end

    audit_base =
      oauth_audit_base_opts(config)
      |> Keyword.merge(
        actor_resolver: fn %{user: u} -> u.id end,
        target_resolver: fn %{user: u} -> u.id end,
        effective_user_id_resolver: fn %{user: u} -> u.id end
      )

    # Ecto.Multi for race condition safety (Pitfall 6)
    multi =
      Multi.new()
      |> Multi.run(:user, fn _repo, _changes ->
        user_attrs = %{
          email: user_info["email"],
          confirmed_at: confirmed_at
        }

        changeset =
          user_schema
          |> struct()
          |> Ecto.Changeset.change(user_attrs)

        repo.insert(changeset)
      end)
      |> Multi.run(:identity, fn _repo, %{user: user} ->
        identity_attrs = %{
          user_id: user.id,
          provider: provider_str,
          provider_uid: to_string(user_info["sub"]),
          provider_email: user_info["email"],
          provider_name: user_info["name"],
          provider_avatar_url: user_info["picture"],
          encrypted_access_token: token["access_token"],
          encrypted_refresh_token: token["refresh_token"],
          token_expires_at: Sigra.OAuth.compute_token_expires_at(token),
          metadata: %{},
          last_used_at: now
        }

        changeset =
          identity_schema
          |> struct()
          |> Ecto.Changeset.change(identity_attrs)

        repo.insert(changeset)
      end)
      |> Audit.log_multi_safe(
        "oauth.callback.success",
        Keyword.merge(audit_base,
          audit_multi_step: :audit_oauth_registered_success,
          outcome: "success",
          metadata_resolver: fn _ -> %{provider: provider_str, outcome: "registered"} end
        )
      )
      |> Audit.log_multi_safe(
        "oauth.register_via_oauth",
        Keyword.merge(audit_base,
          audit_multi_step: :audit_oauth_registered_register,
          metadata_resolver: fn _ -> %{provider: provider_str} end
        )
      )

    case repo.transaction(multi) do
      {:ok, %{user: user} = changes} ->
        Audit.emit_telemetry_from_changes(changes, [
          :audit_oauth_registered_success,
          :audit_oauth_registered_register
        ])

        session_metadata = build_session_metadata(config, provider, enterprise_context)

        Telemetry.event([:sigra, :oauth, :register, :stop], %{}, %{
          user_id: user.id,
          provider: provider_str
        })

        {:ok, :registered, user, session_metadata}

      {:error, :user, %Ecto.Changeset{} = changeset, _} ->
        Logger.error("OAuth registration failed: #{inspect(changeset.errors)}")
        {:error, %OAuthError{provider: provider, error_code: :provider_error}}

      {:error, step, reason, _} ->
        Logger.error("OAuth registration failed at #{step}: #{inspect(reason)}")
        {:error, %OAuthError{provider: provider, error_code: :provider_error}}
    end
  end

  defp oauth_audit_base_opts(config) do
    audit_config = Map.get(config, :audit, [])

    [
      repo: config.repo,
      audit_schema: Keyword.get(audit_config, :audit_schema)
    ]
  end

  defp build_session_metadata(config, provider, enterprise_context) do
    session_type = Keyword.get(config.oauth, :session_type, :remember_me)

    %{
      type: session_type,
      auth_method: :oauth,
      provider: provider
    }
    |> maybe_put(:active_organization_id, enterprise_context && enterprise_context.organization_id)
    |> maybe_put(:enterprise_connection_id, enterprise_context && enterprise_context.connection_id)
    |> maybe_put(:enterprise_routing_source, enterprise_context && enterprise_context.routing_source)
  end

  defp validate_enterprise_context(_config, _provider, nil), do: {:ok, nil}
  defp validate_enterprise_context(_config, _provider, %{state: nil, session: nil}), do: {:ok, nil}

  defp validate_enterprise_context(config, provider, %{state: state_context, session: session_context}) do
    state_context = normalize_enterprise_context(state_context)
    session_context = normalize_enterprise_context(session_context)

    cond do
      is_nil(state_context) or is_nil(session_context) ->
        {:error, %OAuthError{provider: provider, error_code: :enterprise_context_mismatch}}

      state_context != session_context ->
        {:error, %OAuthError{provider: provider, error_code: :enterprise_context_mismatch}}

      true ->
        case EnterpriseRouting.get_routable_connection(config, %{id: state_context.organization_id}) do
          {:ok, %{connection_id: connection_id}} when connection_id == state_context.connection_id ->
            {:ok, state_context}

          _ ->
            {:error, %OAuthError{provider: provider, error_code: :org_connection_unavailable}}
        end
    end
  end

  defp normalize_enterprise_context(nil), do: nil

  defp normalize_enterprise_context(%{} = enterprise_context) do
    with organization_id when not is_nil(organization_id) <-
           enterprise_context[:organization_id] || enterprise_context["organization_id"],
         connection_id when not is_nil(connection_id) <-
           enterprise_context[:connection_id] || enterprise_context["connection_id"],
         routing_source when not is_nil(routing_source) <-
           enterprise_context[:routing_source] || enterprise_context["routing_source"] do
      %{
        organization_id: organization_id,
        connection_id: connection_id,
        routing_source: routing_source
      }
    else
      _ -> nil
    end
  end

  defp normalize_enterprise_context(_), do: nil

  defp return_email_mismatch(provider) do
    {:error, %OAuthError{provider: provider, error_code: :email_mismatch}}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp put_token_expires_at(map, token) do
    case Sigra.OAuth.compute_token_expires_at(token) do
      nil -> map
      expires_at -> Map.put(map, :token_expires_at, expires_at)
    end
  end
end
