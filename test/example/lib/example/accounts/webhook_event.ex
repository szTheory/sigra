defmodule Example.Accounts.WebhookEvent do
  @moduledoc """
  Append-only public webhook event rows.

  The payload column stores the stable public snapshot that downstream
  receivers consume; later plans fan this row out into retryable deliveries.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_events" do
    field :event_id, :string
    field :type, :string
    field :schema_version, :string
    field :occurred_at, :utc_datetime_usec
    field :payload, :map, default: %{}
    field :actor_id, :binary_id
    field :actor_type, :string
    field :organization_id, :binary_id
    field :request_id, :string

    has_many :webhook_deliveries, Example.Accounts.WebhookDelivery

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :event_id,
      :type,
      :schema_version,
      :occurred_at,
      :payload,
      :actor_id,
      :actor_type,
      :organization_id,
      :request_id
    ])
    |> validate_required([:event_id, :type, :schema_version, :occurred_at, :payload])
    |> unique_constraint(:event_id)
  end
end
