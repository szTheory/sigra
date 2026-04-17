defmodule Sigra.Plug.ForbidDuringImpersonation do
  @moduledoc """
  Blocks sensitive mutations while impersonation is active.
  """

  @behaviour Plug

  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias Sigra.Audit

  @default_message "You can't perform this action while impersonating."
  @default_audit_action "admin.impersonation.denied"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    scope = conn.assigns[:current_scope]

    if impersonating?(scope) do
      audit = denial_audit(scope, opts)

      maybe_log_denial(conn, scope, audit, opts)

      conn
      |> Plug.Conn.assign(:sigra_impersonation_denial_audit, audit)
      |> deny(opts, audit)
      |> Plug.Conn.halt()
    else
      conn
    end
  end

  defp impersonating?(%{impersonating_from: %_{}}), do: true
  defp impersonating?(%{impersonating_from: impersonator}) when is_map(impersonator), do: true
  defp impersonating?(_scope), do: false

  defp denial_audit(scope, opts) do
    %{
      action: Keyword.get(opts, :audit_action, @default_audit_action),
      scope: %{
        actor_id: nested_id(scope, :impersonating_from),
        effective_user_id: nested_id(scope, :user)
      },
      metadata: Keyword.get(opts, :audit_metadata, %{})
    }
  end

  defp nested_id(scope, key) when is_map(scope) do
    scope
    |> Map.get(key)
    |> case do
      nil -> nil
      value when is_map(value) -> Map.get(value, :id)
      _ -> nil
    end
  end

  defp nested_id(_scope, _key), do: nil

  defp maybe_log_denial(conn, scope, audit, opts) do
    audit_opts =
      case Keyword.get(opts, :audit_opts_fun) do
        fun when is_function(fun, 2) -> fun.(conn, scope)
        _ -> Keyword.get(opts, :audit_opts, [])
      end

    Audit.log_safe(
      audit.action,
      scope,
      Keyword.merge(
        audit_opts,
        actor_id: audit.scope.actor_id,
        target_id: audit.scope.effective_user_id,
        outcome: "failure",
        metadata: audit.metadata
      )
    )
  end

  defp deny(conn, opts, audit) do
    message = Keyword.get(opts, :message, @default_message)

    case Keyword.get(opts, :redirect_to) do
      nil ->
        error_handler = Keyword.fetch!(opts, :error_handler)
        error_handler.auth_error(
          conn,
          :insufficient_scope,
          opts |> Keyword.put(:message, message) |> Keyword.put(:audit, audit)
        )

      redirect_to ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: redirect_to)
    end
  end
end
