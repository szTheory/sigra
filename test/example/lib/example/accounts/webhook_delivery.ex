defmodule Example.Accounts.WebhookDelivery do
  @moduledoc """
  Delivery summary rows for outbound webhooks.

  Each row represents one subscription-specific delivery record with its own
  stable `delivery_id`, distinct from the shared public event's `event_id`.
  Phase 98 expands this row into the cheap operator summary while detailed
  history lives in append-only `WebhookDeliveryAttempt` rows.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_deliveries" do
    field :delivery_id, :string
    field :status, :string, default: "pending"
    field :attempt_count, :integer, default: 0
    field :endpoint_url, :string
    field :dispatched_at, :utc_datetime_usec
    field :last_attempted_at, :utc_datetime_usec
    field :next_attempt_at, :utc_datetime_usec
    field :last_http_status, :integer
    field :last_error_category, :string
    field :last_error_detail, :string
    field :dead_lettered_at, :utc_datetime_usec
    field :terminal_reason, :string
    field :replayed_from_webhook_delivery_id, :binary_id
    field :replay_root_webhook_delivery_id, :binary_id
    field :replayed_at, :utc_datetime_usec
    field :replayed_by_user_id, :binary_id
    field :replay_source, :string

    belongs_to :webhook_subscription, Example.Accounts.WebhookSubscription
    belongs_to :webhook_event, Example.Accounts.WebhookEvent
    has_many :attempts, Example.Accounts.WebhookDeliveryAttempt

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [
      :delivery_id,
      :status,
      :attempt_count,
      :endpoint_url,
      :dispatched_at,
      :last_attempted_at,
      :next_attempt_at,
      :last_http_status,
      :last_error_category,
      :last_error_detail,
      :dead_lettered_at,
      :terminal_reason,
      :replayed_from_webhook_delivery_id,
      :replay_root_webhook_delivery_id,
      :replayed_at,
      :replayed_by_user_id,
      :replay_source,
      :webhook_subscription_id,
      :webhook_event_id
    ])
    |> validate_required([
      :delivery_id,
      :status,
      :attempt_count,
      :endpoint_url,
      :webhook_subscription_id,
      :webhook_event_id
    ])
    |> assoc_constraint(:webhook_subscription)
    |> assoc_constraint(:webhook_event)
    |> unique_constraint(:delivery_id)
    |> unique_constraint(:replayed_from_webhook_delivery_id,
      name: :webhook_deliveries_replayed_from_unique_index
    )
  end
end
