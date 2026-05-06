defmodule Sigra.WebhooksReliableDeliveryAtomicityTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Sigra.Test.PostgresRepo
  alias Sigra.Webhooks

  defmodule Delivery do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "webhook_atomicity_deliveries_98" do
      field :delivery_id, :string
      field :status, :string
      field :attempt_count, :integer, default: 0
      field :endpoint_url, :string
      field :last_attempted_at, :utc_datetime
      field :next_attempt_at, :utc_datetime
      field :last_http_status, :integer
      field :last_error_category, :string
      field :last_error_detail, :string
      field :dead_lettered_at, :utc_datetime
      field :terminal_reason, :string
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :delivery_id,
        :status,
        :attempt_count,
        :endpoint_url,
        :last_attempted_at,
        :next_attempt_at,
        :last_http_status,
        :last_error_category,
        :last_error_detail,
        :dead_lettered_at,
        :terminal_reason
      ])
      |> validate_required([:delivery_id, :status, :attempt_count, :endpoint_url])
      |> maybe_force_failure()
    end

    defp maybe_force_failure(%Ecto.Changeset{} = changeset) do
      if Process.get(:force_delivery_update_failure) do
        add_error(changeset, :status, "forced failure")
      else
        changeset
      end
    end
  end

  defmodule DeliveryAttempt do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "webhook_atomicity_delivery_attempts_98" do
      field :delivery_id, :string
      field :attempt_number, :integer
      field :endpoint_url, :string
      field :started_at, :utc_datetime
      field :finished_at, :utc_datetime
      field :response_status, :integer
      field :retryable, :boolean
      field :retry_after_seconds, :integer
      field :error_category, :string
      field :error_detail, :string
      field :terminal_reason, :string
      field :webhook_delivery_id, :binary_id
    end

    def changeset(struct, attrs) do
      struct
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
      |> validate_required([:delivery_id, :attempt_number, :endpoint_url, :started_at, :retryable])
      |> unique_constraint([:delivery_id, :attempt_number],
        name: :webhook_atomicity_delivery_attempts_98_delivery_attempt_key
      )
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS webhook_atomicity_delivery_attempts_98", [])
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS webhook_atomicity_deliveries_98", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_atomicity_deliveries_98 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        delivery_id text NOT NULL UNIQUE,
        status text NOT NULL,
        attempt_count integer NOT NULL DEFAULT 0,
        endpoint_url text NOT NULL,
        last_attempted_at timestamp,
        next_attempt_at timestamp,
        last_http_status integer,
        last_error_category text,
        last_error_detail text,
        dead_lettered_at timestamp,
        terminal_reason text
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_atomicity_delivery_attempts_98 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        delivery_id text NOT NULL,
        attempt_number integer NOT NULL,
        endpoint_url text NOT NULL,
        started_at timestamp NOT NULL,
        finished_at timestamp,
        response_status integer,
        retryable boolean NOT NULL,
        retry_after_seconds integer,
        error_category text,
        error_detail text,
        terminal_reason text,
        webhook_delivery_id uuid,
        CONSTRAINT webhook_atomicity_delivery_attempts_98_delivery_attempt_key
          UNIQUE (delivery_id, attempt_number)
      )
      """,
      []
    )

    on_exit(fn -> Process.delete(:force_delivery_update_failure) end)

    %{repo: repo}
  end

  test "rolls back the parent summary update when attempt insertion fails", %{repo: repo} do
    delivery =
      repo.insert!(%Delivery{
        delivery_id: "del_atomicity",
        status: "pending",
        attempt_count: 0,
        endpoint_url: "https://receiver.example/hooks"
      })

    attempted_at = DateTime.utc_now() |> DateTime.truncate(:second)

    repo.insert!(%DeliveryAttempt{
      delivery_id: delivery.delivery_id,
      attempt_number: 1,
      endpoint_url: delivery.endpoint_url,
      started_at: attempted_at,
      finished_at: attempted_at,
      retryable: false,
      webhook_delivery_id: delivery.id
    })

    assert {:error, %Ecto.Changeset{}} =
             Webhooks.persist_delivery_outcome(config(repo), delivery, %{
               attempt_number: 1,
               attempted_at: attempted_at,
               finished_at: attempted_at,
               retryable: false,
               response_status: 500,
               error_category: "http_server_error",
               error_detail: "duplicate attempt",
               terminal_reason: "http_4xx_permanent",
               endpoint_url: delivery.endpoint_url
             })

    fetched_delivery = repo.get_by!(Delivery, delivery_id: delivery.delivery_id)
    assert fetched_delivery.status == "pending"
    assert fetched_delivery.attempt_count == 0
    assert 1 == repo.aggregate(DeliveryAttempt, :count)
  end

  test "rolls back the attempt insert when the parent summary update fails", %{repo: repo} do
    delivery =
      repo.insert!(%Delivery{
        delivery_id: "del_forced_failure",
        status: "pending",
        attempt_count: 0,
        endpoint_url: "https://receiver.example/hooks"
      })

    attempted_at = DateTime.utc_now() |> DateTime.truncate(:second)
    Process.put(:force_delivery_update_failure, true)

    assert {:error, %Ecto.Changeset{}} =
             Webhooks.persist_delivery_outcome(config(repo), delivery, %{
               attempt_number: 1,
               attempted_at: attempted_at,
               finished_at: attempted_at,
               retryable: false,
               response_status: 404,
               error_category: "http_client_error",
               error_detail: "forced update failure",
               terminal_reason: "http_4xx_permanent",
               endpoint_url: delivery.endpoint_url
             })

    assert 0 == repo.aggregate(DeliveryAttempt, :count)

    fetched_delivery =
      repo.one!(from(delivery_row in Delivery, where: delivery_row.delivery_id == ^delivery.delivery_id))

    assert fetched_delivery.status == "pending"
    assert fetched_delivery.attempt_count == 0
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: Delivery,
      secret_key_base: String.duplicate("a", 64),
      webhooks: [
        enabled: true,
        webhook_subscription_schema: Delivery,
        webhook_event_schema: Delivery,
        webhook_delivery_schema: Delivery,
        webhook_delivery_attempt_schema: DeliveryAttempt
      ]
    )
  end
end
