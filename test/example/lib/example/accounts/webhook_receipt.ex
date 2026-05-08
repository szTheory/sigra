defmodule Example.Accounts.WebhookReceipt do
  @moduledoc """
  Durable receiver-side proof rows for verified Sigra webhook deliveries.

  Each receipt is keyed by the stable `delivery_id` so the generated-host
  receiver proof can correlate cleanly with sender and admin evidence.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_receipts" do
    field :delivery_id, :string
    field :event_id, :string
    field :event_type, :string
    field :payload, :map, default: %{}
    field :raw_body_sha256, :string
    field :signature_timestamp, :integer
    field :verified_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(receipt, attrs) do
    receipt
    |> cast(attrs, [
      :delivery_id,
      :event_id,
      :event_type,
      :payload,
      :raw_body_sha256,
      :signature_timestamp,
      :verified_at
    ])
    |> validate_required([
      :delivery_id,
      :event_id,
      :event_type,
      :payload,
      :raw_body_sha256,
      :signature_timestamp,
      :verified_at
    ])
    |> unique_constraint(:delivery_id)
  end
end
