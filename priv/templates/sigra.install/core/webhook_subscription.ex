defmodule <%= context_module %>.WebhookSubscription do
  @moduledoc """
  Schema for durable outbound webhook subscriptions.

  Subscriptions persist explicit event-type lists, enabled-state semantics,
  and an encrypted signing secret so generated hosts can manage webhook
  receivers without leaking plaintext credentials.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_subscriptions" do
    field :endpoint_url, :string
    field :event_types, {:array, :string}, default: []
    field :enabled, :boolean, default: true
    field :description, :string
    field :signing_secret, <%= context_module %>.Encrypted.Binary, redact: true
    field :next_signing_secret, <%= context_module %>.Encrypted.Binary, redact: true
    field :rotation_state, Ecto.Enum,
      values: [:stable, :prepared, :overlap_active, :completed],
      default: :stable

    field :rotation_prepared_at, :utc_datetime_usec
    field :rotation_overlap_started_at, :utc_datetime_usec
    field :rotation_retire_after_at, :utc_datetime_usec
    field :rotation_completed_at, :utc_datetime_usec
    field :rotation_last_changed_by_user_id, :binary_id
    field :signing_secret_fingerprint, :string
    field :next_signing_secret_fingerprint, :string

    has_many :webhook_deliveries, <%= context_module %>.WebhookDelivery

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :endpoint_url,
      :event_types,
      :enabled,
      :description,
      :signing_secret,
      :next_signing_secret,
      :rotation_state,
      :rotation_prepared_at,
      :rotation_overlap_started_at,
      :rotation_retire_after_at,
      :rotation_completed_at,
      :rotation_last_changed_by_user_id,
      :signing_secret_fingerprint,
      :next_signing_secret_fingerprint
    ])
    |> validate_required([:endpoint_url, :event_types, :enabled, :signing_secret])
  end
end
