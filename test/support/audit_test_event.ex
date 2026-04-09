defmodule Sigra.Test.AuditEvent do
  @moduledoc false
  # Minimal stand-in schema mirroring the generated AuditEvent (D-05).
  # Used by Wave 0 audit tests so they can exercise Sigra.Audit.Changeset
  # validators in isolation, without depending on a host-app schema.

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "audit_events" do
    field(:action, :string)
    field(:outcome, :string)
    field(:actor_id, :binary_id)
    field(:actor_type, :string)
    field(:target_id, :binary_id)
    field(:target_type, :string)
    field(:ip_address, :string)
    field(:user_agent, :string)
    field(:metadata, :map)
    field(:occurred_at, :utc_datetime_usec)
    timestamps(updated_at: false, type: :utc_datetime_usec)
  end
end
