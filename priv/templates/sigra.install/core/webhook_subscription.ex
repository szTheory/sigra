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

    has_many :webhook_deliveries, <%= context_module %>.WebhookDelivery

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:endpoint_url, :event_types, :enabled, :description, :signing_secret])
    |> validate_required([:endpoint_url, :event_types, :enabled, :signing_secret])
  end
end
