defmodule Sigra.AppLogin do
  @moduledoc """
  Hosted first-party app-login exchange facade.

  The exchange consumes an already-approved, digest-only hosted attempt and
  composes Phase 245 issuance into the same database transaction.
  """

  alias Ecto.Multi
  alias Sigra.Audit
  alias Sigra.AppLogin.Attempt

  @spec exchange_hosted(Sigra.Config.t(), String.t(), String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, :invalid_code}
  def exchange_hosted(config, code, verifier, profile, callback) do
    multi =
      Multi.new()
      |> Attempt.build_locked_hosted_exchange_multi(config, code, verifier, profile, callback)

    try do
      case config.repo.transaction(multi) do
        {:ok, %{app_session_issue: credentials} = changes} ->
          Audit.emit_telemetry_from_changes(changes, [:audit_app_login_exchange])
          {:ok, credentials}

        {:error, _step, _reason, _changes} ->
          {:error, :invalid_code}
      end
    rescue
      _exception -> {:error, :invalid_code}
    end
  end
end
