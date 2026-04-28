defmodule ExampleWeb.TestDbProbeController do
  @moduledoc """
  Test-only read-only DB introspection endpoint for Playwright OAuth specs.
  Mounted only when `EXAMPLE_DB_PROBE_ENABLED=1`. Never ship to production.
  Citation: 87-CONTEXT.md D-87-05; threat model T-87-01.
  """

  use ExampleWeb, :controller

  import Ecto.Query

  alias Example.Accounts.{AuditEvent, User, UserBackupCode}
  alias Example.Repo
  alias Ecto.Adapters.SQL
  alias Sigra.MFA.BackupCodes

  def show(conn, %{"table" => "user_identities", "user_email" => email}) do
    if enabled?() do
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
    else
      send_resp(conn, :not_found, "")
    end
  end

  def show(conn, %{"table" => "user_backup_codes", "user_email" => email, "submitted_code" => code}) do
    if enabled?() do
      hashed = BackupCodes.hash(code)

      with %User{id: user_id} <- Repo.get_by(User, email: email) do
        current_match =
          Repo.exists?(
            from(bc in UserBackupCode,
              where:
                bc.user_id == ^user_id and bc.hashed_code == ^hashed and
                  is_nil(bc.used_at)
            )
          )

        remaining =
          Repo.aggregate(
            from(bc in UserBackupCode,
              where: bc.user_id == ^user_id and is_nil(bc.used_at)
            ),
            :count,
            :id
          )

        json(conn, %{
          current_match: current_match,
          remaining: remaining,
          hash_prefix: String.slice(hashed, 0, 12)
        })
      else
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "user not found"})
      end
    else
      send_resp(conn, :not_found, "")
    end
  end

  def show(conn, %{"table" => "audit_events", "user_email" => email, "action" => action}) do
    if enabled?() do
      with %User{id: user_id} <- Repo.get_by(User, email: email) do
        rows =
          AuditEvent
          |> where([event], event.action == ^action)
          |> where(
            [event],
            event.target_id == ^user_id or event.actor_id == ^user_id or
              event.effective_user_id == ^user_id
          )
          |> order_by([event], desc: event.inserted_at)
          |> limit(3)
          |> select([event], %{
            action: event.action,
            outcome: event.outcome,
            actor_id: event.actor_id,
            target_id: event.target_id,
            effective_user_id: event.effective_user_id,
            inserted_at: event.inserted_at
          })
          |> Repo.all()

        json(conn, %{count: length(rows), rows: rows})
      else
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "user not found"})
      end
    else
      send_resp(conn, :not_found, "")
    end
  end

  def show(conn, _params) do
    if enabled?() do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "unsupported probe"})
    else
      send_resp(conn, :not_found, "")
    end
  end

  defp enabled?, do: System.get_env("EXAMPLE_DB_PROBE_ENABLED") == "1"
end
