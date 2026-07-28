defmodule <%= app_module %>.SigraAdminAccess do
  @moduledoc """
  Host-owned platform-admin grant API used by the generated policy and Mix tasks.

  Grants apply only to existing, confirmed, non-deleted accounts. Grant and
  revoke mutations commit their audit event in the same database transaction.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias <%= context_module %>, as: Auth
  alias <%= context_module %>.<%= schema_alias %>, as: User
  alias <%= context_module %>.PlatformAdminGrant
  alias <%= repo_module %>, as: Repo

  @type mutation_state :: :granted | :already_granted | :revoked | :already_revoked

  @doc "Returns true when the scope or user has an active persisted grant."
  def platform_admin?(%{user: %User{} = user}), do: platform_admin?(user)

  def platform_admin?(%User{id: user_id}) do
    Repo.exists?(from g in PlatformAdminGrant, where: g.user_id == ^user_id and is_nil(g.revoked_at))
  end

  def platform_admin?(_), do: false

  @doc "Grants platform-admin access to an eligible account. Repeat-safe."
  @spec grant(String.t() | struct()) ::
          {:ok, struct(), mutation_state()} | {:error, atom() | Ecto.Changeset.t()}
  def grant(email_or_user) do
    with {:ok, user} <- eligible_user(email_or_user) do
      Multi.new()
      |> Multi.run(:grant, fn repo, _changes -> upsert_active_grant(repo, user) end)
      |> append_audit_if_mutated("sigra.admin.grant", user.id, :granted)
      |> Repo.transaction()
      |> case do
        {:ok, %{grant: {grant, state}} = changes} ->
          Sigra.Audit.emit_telemetry_from_changes(changes)
          {:ok, grant, state}

        {:error, :grant, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        {:error, _step, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  @doc "Revokes an account's platform-admin grant. Repeat-safe."
  @spec revoke(String.t() | struct()) ::
          {:ok, struct() | nil, mutation_state()} | {:error, atom() | Ecto.Changeset.t()}
  def revoke(email_or_user) do
    with {:ok, user} <- existing_user(email_or_user) do
      Multi.new()
      |> Multi.run(:grant, fn repo, _changes -> revoke_active_grant(repo, user) end)
      |> append_audit_if_mutated("sigra.admin.revoke", user.id, :revoked)
      |> Repo.transaction()
      |> case do
        {:ok, %{grant: {grant, state}} = changes} ->
          Sigra.Audit.emit_telemetry_from_changes(changes)
          {:ok, grant, state}

        {:error, :grant, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        {:error, _step, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  @doc "Lists active grants with their users preloaded."
  def list_active do
    PlatformAdminGrant
    |> where([grant], is_nil(grant.revoked_at))
    |> order_by([grant], asc: grant.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc "Returns the account and whether it currently has access."
  def check(email) when is_binary(email) do
    with {:ok, user} <- existing_user(email) do
      {:ok, user, platform_admin?(user)}
    end
  end

  defp eligible_user(email_or_user) do
    with {:ok, user} <- existing_user(email_or_user),
         :ok <- require_confirmed(user),
         :ok <- require_active(user) do
      {:ok, user}
    end
  end

  defp existing_user(%User{} = user), do: {:ok, user}

  defp existing_user(email) when is_binary(email) do
    case Auth.get_user_by_email(String.trim(email)) do
      %User{} = user -> {:ok, user}
      nil -> {:error, :user_not_found}
    end
  end

  defp existing_user(_), do: {:error, :user_not_found}

  defp require_confirmed(%User{confirmed_at: nil}), do: {:error, :user_unconfirmed}
  defp require_confirmed(%User{}), do: :ok

  defp require_active(%User{deleted_at: deleted_at}) when not is_nil(deleted_at),
    do: {:error, :user_deleted}

  defp require_active(%User{}), do: :ok

  defp upsert_active_grant(repo, user) do
    case repo.get_by(PlatformAdminGrant, user_id: user.id) do
      %PlatformAdminGrant{revoked_at: nil} = grant ->
        {:ok, {grant, :already_granted}}

      %PlatformAdminGrant{} = grant ->
        grant
        |> PlatformAdminGrant.changeset(%{revoked_at: nil})
        |> repo.update()
        |> mutation_result(:granted)

      nil ->
        %PlatformAdminGrant{}
        |> PlatformAdminGrant.changeset(%{user_id: user.id, revoked_at: nil})
        |> repo.insert()
        |> mutation_result(:granted)
    end
  end

  defp revoke_active_grant(repo, user) do
    case repo.get_by(PlatformAdminGrant, user_id: user.id) do
      nil ->
        {:ok, {nil, :already_revoked}}

      %PlatformAdminGrant{revoked_at: revoked_at} = grant when not is_nil(revoked_at) ->
        {:ok, {grant, :already_revoked}}

      %PlatformAdminGrant{} = grant ->
        grant
        |> PlatformAdminGrant.changeset(%{revoked_at: DateTime.utc_now()})
        |> repo.update()
        |> mutation_result(:revoked)
    end
  end

  defp mutation_result({:ok, grant}, state), do: {:ok, {grant, state}}
  defp mutation_result({:error, changeset}, _state), do: {:error, changeset}

  defp append_audit(multi, action, target_id) do
    Sigra.Audit.log_multi_safe(
      multi,
      action,
      Auth.sigra_config()
      |> Sigra.Auth.audit_opts_from_config()
      |> Keyword.merge(
        actor_id: nil,
        actor_type: "system",
        target_id: target_id,
        target_type: "user",
        metadata: %{source: "mix_task"}
      )
    )
  end

  defp append_audit_if_mutated(multi, action, target_id, mutated_state) do
    Multi.merge(multi, fn %{grant: {_grant, state}} ->
      if state == mutated_state do
        append_audit(Multi.new(), action, target_id)
      else
        Multi.new()
      end
    end)
  end
end
