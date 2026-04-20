defmodule ExampleWeb.Admin.AuditExportController do
  @moduledoc """
  Thin controller seam for admin audit CSV downloads.
  """

  use ExampleWeb, :controller

  alias Example.Accounts

  def index(conn, %{"id" => user_id} = params) do
    case Sigra.Admin.Audit.Export.subject_csv(
           export_config(),
           conn.assigns.admin_scope,
           user_id,
           params
         ) do
      {:ok, csv} ->
        send_csv(conn, csv)

      {:error, _reason} ->
        send_resp(conn, 400, "Invalid audit export filters")
    end
  end

  def index(conn, params) do
    case Sigra.Admin.Audit.Export.csv(export_config(), conn.assigns.admin_scope, params) do
      {:ok, csv} ->
        send_csv(conn, csv)

      {:error, _reason} ->
        send_resp(conn, 400, "Invalid audit export filters")
    end
  end

  defp send_csv(conn, csv) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="audit-export.csv"))
    |> send_resp(200, csv)
  end

  defp export_config do
    %{Accounts.sigra_config() | scope_module: Example.Accounts.Scope}
  end
end
