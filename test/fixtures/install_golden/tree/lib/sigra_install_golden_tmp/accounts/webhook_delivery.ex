defmodule SigraInstallGoldenTmp.Accounts.WebhookDelivery do
  @moduledoc """
  Delivery lineage rows for outbound webhooks.

  Each row represents one subscription-specific delivery record with its own
  stable `delivery_id`, distinct from the shared public event's `event_id`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_deliveries" do
    field :delivery_id, :string
    field :status, :string, default: "pending"
    field :endpoint_url, :string
    field :dispatched_at, :utc_datetime_usec

    belongs_to :webhook_subscription, SigraInstallGoldenTmp.Accounts.WebhookSubscription
    belongs_to :webhook_event, SigraInstallGoldenTmp.Accounts.WebhookEvent

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [
      :delivery_id,
      :status,
      :endpoint_url,
      :dispatched_at,
      :webhook_subscription_id,
      :webhook_event_id
    ])
    |> validate_required([
      :delivery_id,
      :status,
      :endpoint_url,
      :webhook_subscription_id,
      :webhook_event_id
    ])
    |> assoc_constraint(:webhook_subscription)
    |> assoc_constraint(:webhook_event)
    |> unique_constraint(:delivery_id)
  end
end
