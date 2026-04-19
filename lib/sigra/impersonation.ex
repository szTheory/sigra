defmodule Sigra.Impersonation do
  @moduledoc """
  Library-owned impersonation orchestration over real Sigra sessions.
  """

  alias Sigra.{Admin, Audit, Auth, Scope, Session}

  @default_idle_timeout 900
  @default_absolute_timeout 1_800

  @type restore_decision :: {:admin_session, binary()} | :login_required

  @spec start(Sigra.Config.t(), Admin.Scope.t(), Session.t(), struct() | map(), keyword()) ::
          {:ok, map()} | {:error, :already_impersonating | :not_allowed | term()}
  def start(
        config,
        %Admin.Scope{} = admin_scope,
        %Session{} = admin_session,
        target_user,
        opts \\ []
      ) do
    admin_user = admin_scope.scope.user
    admin_token = Keyword.get(opts, :admin_token)

    cond do
      impersonating?(admin_scope.scope) ->
        log_denied(config, admin_scope, target_user, :already_impersonating, opts)
        {:error, :already_impersonating}

      authorize_target(admin_scope, target_user) != :ok ->
        log_denied(config, admin_scope, target_user, :not_allowed, opts)
        {:error, :not_allowed}

      true ->
        metadata = %{
          type: :standard,
          impersonator_user_id: admin_user.id,
          impersonator_session_id: admin_session.id
        }

        case Auth.create_session(config, target_user, metadata, opts) do
          {:ok, session} ->
            impersonation_scope =
              Scope.build(config.scope_module, target_user,
                active_organization: admin_scope.organization,
                impersonating_from: admin_user
              )

            Audit.log_safe(
              "admin.impersonation.start",
              impersonation_scope,
              audit_opts(config, opts, %{
                actor_id: admin_user.id,
                target_id: target_user.id,
                metadata: %{
                  impersonation_session_id: session.id,
                  admin_session_id: admin_session.id
                }
              })
            )

            {:ok,
             %{
               session: session,
               restore: restore_decision(admin_token),
               mode: :impersonating
             }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @spec stop(Sigra.Config.t(), struct(), Session.t(), keyword()) :: {:ok, map()}
  def stop(config, scope, %Session{} = session, opts \\ []) do
    restore = restore_decision(Keyword.get(opts, :admin_token))
    actor_id = actor_id(scope)

    :ok = Auth.delete_session(config, session.hashed_token, opts)

    Audit.log_safe(
      "admin.impersonation.stop",
      scope,
      audit_opts(config, opts, %{
        actor_id: actor_id,
        target_id: session.user_id,
        metadata: %{impersonation_session_id: session.id}
      })
    )

    {:ok, %{restore: restore, session_deleted?: true}}
  end

  @spec evaluate_timeout(Sigra.Config.t(), struct(), Session.t(), keyword()) :: {:ok, map()}
  def evaluate_timeout(config, scope, %Session{} = session, opts \\ []) do
    expired? = impersonation_expired?(config, session)
    restore = restore_decision(Keyword.get(opts, :admin_token))

    if expired? do
      Audit.log_safe(
        "admin.impersonation.timeout_expire",
        scope,
        audit_opts(config, opts, %{
          actor_id: actor_id(scope),
          target_id: session.user_id,
          metadata: %{impersonation_session_id: session.id}
        })
      )
    end

    {:ok,
     %{
       expired?: expired?,
       action: if(expired?, do: restore_action(restore), else: :continue),
       restore: restore
     }}
  end

  defp authorize_target(admin_scope, target_user) do
    Admin.Authorizer.authorize_impersonation_target!(admin_scope, target_user)
  rescue
    Admin.Authorizer.UnauthorizedError -> {:error, :not_allowed}
  else
    :ok -> :ok
  end

  defp impersonating?(scope) when is_map(scope) do
    not is_nil(Map.get(scope, :impersonating_from))
  end

  defp impersonating?(_scope), do: false

  defp actor_id(scope) when is_map(scope) do
    case Map.get(scope, :impersonating_from) do
      nil -> get_in(scope, [:user, :id])
      admin -> Map.get(admin, :id)
    end
  end

  defp actor_id(_scope), do: nil

  defp restore_decision(nil), do: :login_required

  defp restore_decision(admin_token) when is_binary(admin_token),
    do: {:admin_session, admin_token}

  defp restore_action({:admin_session, _token}), do: :restore_admin
  defp restore_action(:login_required), do: :force_login

  defp impersonation_expired?(config, %Session{} = session) do
    now = DateTime.utc_now()
    session_config = config.session || []

    idle_limit = Keyword.get(session_config, :impersonation_idle_timeout, @default_idle_timeout)

    absolute_limit =
      Keyword.get(session_config, :impersonation_absolute_timeout, @default_absolute_timeout)

    absolute_expired? =
      is_nil(session.inserted_at) or
        DateTime.diff(now, session.inserted_at, :second) >= absolute_limit

    idle_expired? =
      is_nil(session.last_active_at) or
        DateTime.diff(now, session.last_active_at, :second) >= idle_limit

    absolute_expired? or idle_expired?
  end

  defp audit_opts(config, opts, extra) do
    config
    |> Auth.audit_opts_from_config(
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent)
    )
    |> Keyword.merge(Map.to_list(extra))
  end

  defp log_denied(config, admin_scope, target_user, reason, opts) do
    scope = admin_scope.scope

    Audit.log_safe(
      "admin.impersonation.denied",
      scope,
      audit_opts(config, opts, %{
        actor_id: admin_scope.scope.user.id,
        target_id: Map.get(target_user, :id),
        outcome: "failure",
        metadata: %{reason: reason, organization_id: admin_scope.organization_id}
      })
    )
  end
end
