defmodule Sigra.OAuth.EnterpriseReconciliation do
  @moduledoc """
  Library-owned enterprise user and membership reconciliation.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Sigra.Auth
  alias Sigra.Organizations
  alias Sigra.Organizations.Invitations

  @type refusal_reason ::
          :ambiguous_email_match
          | :provider_subject_conflict
          | :unsafe_email_claim

  @spec reconcile(map(), atom(), map(), map(), map()) ::
          {:ok, atom(), map(), map()} | {:error, refusal_reason()}
  def reconcile(config, provider, user_info, token, enterprise_context) do
    provider_str = provider |> to_string() |> String.downcase()
    provider_uid = to_string(user_info["sub"])
    normalized_email = Auth.normalize_email(user_info["email"])
    organizations_config = organizations_config(config)

    with {:ok, identity_match} <-
           resolve_identity_match(
             config,
             provider_str,
             provider_uid,
             normalized_email,
             enterprise_context.connection_id
           ),
         {:ok, principal} <-
           resolve_principal(config, identity_match, user_info, normalized_email) do
      do_reconcile(
        config,
        organizations_config,
        provider,
        provider_str,
        provider_uid,
        user_info,
        token,
        enterprise_context,
        normalized_email,
        principal
      )
    end
  end

  defp do_reconcile(
         config,
         organizations_config,
         provider,
         provider_str,
         provider_uid,
         user_info,
         token,
         enterprise_context,
         normalized_email,
         principal
       ) do
    identity_schema = config.identity_schema
    user_schema = config.user_schema
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    metadata =
      enterprise_identity_metadata(
        enterprise_context,
        principal.identity && Map.get(principal.identity, :metadata)
      )

    {multi, action, principal_key, identity_key} =
      case principal.mode do
        :existing_identity ->
          changeset =
            principal.identity
            |> Ecto.Changeset.change(
              identity_updates(principal.identity, user_info, token, metadata, now)
            )

          {
            Multi.new() |> Multi.update(:identity, changeset),
            :logged_in,
            nil,
            :identity
          }

        :auto_claim ->
          identity_changeset =
            identity_schema
            |> struct()
            |> Ecto.Changeset.change(%{
              user_id: principal.user.id,
              provider: provider_str,
              provider_uid: provider_uid,
              provider_email: normalized_email,
              provider_name: user_info["name"],
              provider_avatar_url: user_info["picture"],
              encrypted_access_token: token["access_token"],
              encrypted_refresh_token: token["refresh_token"],
              token_expires_at: Sigra.OAuth.compute_token_expires_at(token),
              metadata: metadata,
              last_used_at: now
            })

          {
            Multi.new() |> Multi.insert(:identity, identity_changeset),
            :logged_in,
            nil,
            :identity
          }

        :jit_create ->
          trust_email = Keyword.get(config.oauth, :trust_provider_email, true)

          confirmed_at =
            if trust_email and user_info["email_verified"] == true, do: now, else: nil

          user_changeset =
            user_schema
            |> struct()
            |> Ecto.Changeset.change(%{
              email: normalized_email,
              confirmed_at: confirmed_at
            })

          identity_changeset = fn %{user: user} ->
            identity_schema
            |> struct()
            |> Ecto.Changeset.change(%{
              user_id: user.id,
              provider: provider_str,
              provider_uid: provider_uid,
              provider_email: normalized_email,
              provider_name: user_info["name"],
              provider_avatar_url: user_info["picture"],
              encrypted_access_token: token["access_token"],
              encrypted_refresh_token: token["refresh_token"],
              token_expires_at: Sigra.OAuth.compute_token_expires_at(token),
              metadata: metadata,
              last_used_at: now
            })
          end

          {
            Multi.new()
            |> Multi.insert(:user, user_changeset)
            |> Multi.insert(:identity, identity_changeset),
            :registered,
            :user,
            :identity
          }
      end

    {multi, membership_key, membership_outcome} =
      append_membership_reconciliation(
        multi,
        organizations_config,
        enterprise_context,
        principal,
        principal_key,
        normalized_email
      )

    case config.repo.transaction(multi) do
      {:ok, changes} ->
        user =
          case principal_key do
            nil -> principal.user
            key -> Map.fetch!(changes, key)
          end

        _identity = Map.fetch!(changes, identity_key)
        _membership = changes[membership_key]

        {:ok, action, user,
         %{
           type: Keyword.get(config.oauth, :session_type, :remember_me),
           auth_method: :oauth,
           provider: provider,
           active_organization_id: enterprise_context.organization_id,
           enterprise_connection_id: enterprise_context.connection_id,
           enterprise_routing_source: enterprise_context.routing_source,
           enterprise_reconciliation_outcome: membership_outcome
         }}

      {:error, _step, %Ecto.Changeset{} = changeset, _changes} ->
        if unique_constraint?(changeset) do
          {:error, :provider_subject_conflict}
        else
          {:error, :unsafe_email_claim}
        end

      {:error, _step, reason, _changes}
      when reason in [:provider_subject_conflict, :unsafe_email_claim] ->
        {:error, reason}

      {:error, _step, _reason, _changes} ->
        {:error, :unsafe_email_claim}
    end
  end

  defp resolve_identity_match(config, provider_str, provider_uid, normalized_email, connection_id) do
    repo = config.repo
    identity_schema = config.identity_schema
    user_schema = config.user_schema

    case repo.get_by(identity_schema, provider: provider_str, provider_uid: provider_uid) do
      nil ->
        {:ok, nil}

      identity ->
        if identity_connection_id(identity) == connection_id do
          user = repo.get!(user_schema, identity.user_id)

          case find_users_by_normalized_email(repo, user_schema, normalized_email) do
            [%{id: other_id}] when other_id != user.id ->
              {:error, :provider_subject_conflict}

            _ ->
              {:ok, %{identity: identity, user: user}}
          end
        else
          {:error, :provider_subject_conflict}
        end
    end
  end

  defp resolve_principal(
         _config,
         %{identity: _identity, user: _user} = match,
         _user_info,
         _normalized_email
       ) do
    {:ok, %{mode: :existing_identity, identity: match.identity, user: match.user}}
  end

  defp resolve_principal(config, nil, user_info, normalized_email) do
    email_verified = user_info["email_verified"] == true
    users = find_users_by_normalized_email(config.repo, config.user_schema, normalized_email)

    cond do
      not email_verified or is_nil(normalized_email) or normalized_email == "" ->
        {:ok, %{mode: :jit_create, identity: nil, user: nil}}

      length(users) == 1 ->
        {:ok, %{mode: :auto_claim, identity: nil, user: hd(users)}}

      length(users) > 1 ->
        {:error, :ambiguous_email_match}

      true ->
        {:ok, %{mode: :jit_create, identity: nil, user: nil}}
    end
  end

  defp append_membership_reconciliation(
         multi,
         organizations_config,
         enterprise_context,
         principal,
         principal_key,
         normalized_email
       ) do
    org = %{id: enterprise_context.organization_id}

    membership_or_user_ref =
      case principal_key do
        nil -> principal.user
        key -> {:changes_key, key}
      end

    user_for_precheck =
      case membership_or_user_ref do
        %_{} = user -> user
        _ -> nil
      end

    existing_membership =
      if user_for_precheck do
        organizations_config.repo.get_by(
          organizations_config.schemas.membership,
          organization_id: enterprise_context.organization_id,
          user_id: user_for_precheck.id
        )
      end

    cond do
      existing_membership ->
        {
          multi
          |> Multi.run(:existing_membership, fn _repo, _changes -> {:ok, existing_membership} end),
          :existing_membership,
          :existing_membership
        }

      true ->
        case Invitations.accept_exact_pending_multi(
               organizations_config,
               org,
               membership_or_user_ref,
               normalized_email
             ) do
          {:ok, invite_multi} ->
            {Multi.append(multi, invite_multi), :membership, :invitation_consumed}

          :not_found ->
            membership_multi =
              Organizations.add_member_multi(
                organizations_config,
                %{user: user_for_precheck, membership: nil, active_organization: org},
                org,
                membership_or_user_ref,
                :member
              )

            {Multi.append(multi, membership_multi), :membership, :jit_created}
        end
    end
  end

  defp identity_updates(identity, user_info, token, metadata, now) do
    %{last_used_at: now, metadata: metadata}
    |> maybe_put(:provider_email, user_info["email"])
    |> maybe_put(:provider_name, user_info["name"])
    |> maybe_put(:provider_avatar_url, user_info["picture"])
    |> maybe_put(:encrypted_access_token, token["access_token"])
    |> maybe_put(:encrypted_refresh_token, token["refresh_token"])
    |> maybe_put(:token_expires_at, Sigra.OAuth.compute_token_expires_at(token))
    |> merge_metadata(identity)
  end

  defp merge_metadata(updates, identity) do
    metadata =
      enterprise_identity_metadata(nil, Map.get(identity, :metadata))
      |> Map.merge(Map.get(updates, :metadata, %{}))

    Map.put(updates, :metadata, metadata)
  end

  defp enterprise_identity_metadata(nil, metadata), do: normalize_metadata(metadata)

  defp enterprise_identity_metadata(enterprise_context, metadata) do
    metadata
    |> normalize_metadata()
    |> Map.put("enterprise_connection_id", enterprise_context.connection_id)
    |> Map.put("enterprise_organization_id", enterprise_context.organization_id)
  end

  defp identity_connection_id(identity) do
    metadata = Map.get(identity, :metadata) || %{}

    Map.get(identity, :enterprise_connection_id) ||
      Map.get(metadata, "enterprise_connection_id") ||
      Map.get(metadata, :enterprise_connection_id)
  end

  defp find_users_by_normalized_email(_repo, _user_schema, nil), do: []
  defp find_users_by_normalized_email(_repo, _user_schema, ""), do: []

  defp find_users_by_normalized_email(repo, user_schema, normalized_email) do
    cond do
      function_exported?(repo, :enterprise_users_by_email, 2) ->
        repo.enterprise_users_by_email(user_schema, normalized_email)

      function_exported?(repo, :all, 1) ->
        fields = user_schema.__schema__(:fields)

        query =
          if :deleted_at in fields do
            from(u in user_schema,
              where: field(u, :email) == ^normalized_email and is_nil(field(u, :deleted_at))
            )
          else
            from(u in user_schema, where: field(u, :email) == ^normalized_email)
          end

        repo.all(query)

      true ->
        case repo.get_by(user_schema, email: normalized_email) do
          nil -> []
          user -> [user]
        end
    end
  end

  defp organizations_config(config) do
    schemas =
      Map.get(config, :schemas, %{})
      |> Map.put_new(:user, config.user_schema)

    %{
      repo: config.repo,
      schemas: schemas,
      roles: Map.get(config, :roles, [:owner, :admin, :member]),
      owner_role: Map.get(config, :owner_role, :owner),
      audit_schema: get_in(config, [:audit, :audit_schema]),
      hooks: Map.get(config, :hooks, [])
    }
  end

  defp unique_constraint?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {_message, meta}} ->
      meta[:constraint] == :unique
    end)
  end

  defp normalize_metadata(nil), do: %{}
  defp normalize_metadata(metadata) when is_map(metadata), do: metadata

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
