defmodule ExampleWeb.TestDbProbeController do
  @moduledoc """
  Test-only read-only DB introspection endpoint for Playwright OAuth specs.
  Mounted only when `EXAMPLE_DB_PROBE_ENABLED=1`. Never ship to production.
  Citation: 87-CONTEXT.md D-87-05; threat model T-87-01.
  """

  use ExampleWeb, :controller

  alias Example.Repo
  alias Ecto.Adapters.SQL

  def show(conn, %{"table" => "user_identities", "user_email" => email}) do
    result =
      SQL.query!(
        Repo,
        """
        SELECT ui.provider, ui.provider_uid
        FROM user_identities AS ui
        JOIN users AS u ON u.id = ui.user_id
        WHERE u.email = $1
        ORDER BY ui.provider, ui.provider_uid
        """,
        [email]
      )

    rows =
      Enum.map(result.rows, fn [provider, provider_uid] ->
        %{provider: provider, provider_uid: provider_uid}
      end)

    json(conn, %{count: length(rows), rows: rows})
  end

  def show(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "unsupported probe"})
  end
end
