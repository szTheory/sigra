defmodule SigraInstallGoldenTmp.Accounts.WebhookDeliveryAttempt do
  @moduledoc """
  Append-only delivery-attempt ledger rows for outbound webhooks.

  Each row captures one send attempt or rare orphan terminal issue keyed by
  the stable `delivery_id`, so operators can inspect delivery history without
  reading queue internals.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_delivery_attempts" do
    field :delivery_id, :string
    field :attempt_number, :integer
    field :endpoint_url, :string
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :response_status, :integer
    field :retryable, :boolean, default: false
    field :retry_after_seconds, :integer
    field :error_category, :string
    field :error_detail, :string
    field :terminal_reason, :string

    belongs_to :webhook_delivery, SigraInstallGoldenTmp.Accounts.WebhookDelivery

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [
      :delivery_id,
      :attempt_number,
      :endpoint_url,
      :started_at,
      :finished_at,
      :response_status,
      :retryable,
      :retry_after_seconds,
      :error_category,
      :error_detail,
      :terminal_reason,
      :webhook_delivery_id
    ])
    |> validate_required([
      :delivery_id,
      :attempt_number,
      :endpoint_url,
      :started_at,
      :retryable
    ])
    |> assoc_constraint(:webhook_delivery)
    |> unique_constraint([:delivery_id, :attempt_number])
  end
end
