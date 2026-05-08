defmodule Sigra.WebhooksAuditAtomicityTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Sigra.Auth
  alias Sigra.Test.PostgresRepo

  defmodule WebhookUser do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "webhook_atomicity_users_97" do
      field :email, :string
      field :hashed_password, :string
      timestamps()
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:email, :hashed_password])
      |> validate_required([:email, :hashed_password])
      |> unique_constraint(:email, name: :webhook_atomicity_users_97_email_key)
    end
  end

  defmodule WebhookSubscription do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "webhook_atomicity_subscriptions_97" do
      field :endpoint_url, :string
      field :event_types, {:array, :string}, default: []
      field :enabled, :boolean, default: true
    end
  end

  defmodule WebhookEvent do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "webhook_atomicity_events_97" do
      field :event_id, :string
      field :type, :string
      field :schema_version, :string
      field :occurred_at, :utc_datetime
      field :payload, :map
      field :actor_id, :binary_id
      field :actor_type, :string
      field :organization_id, :binary_id
      field :request_id, :string
    end

    def changeset(struct, attrs) do
      struct
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
    end
  end

  defmodule WebhookDelivery do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "webhook_atomicity_deliveries_97" do
      field :delivery_id, :string
      field :status, :string
      field :endpoint_url, :string
      belongs_to :webhook_subscription, WebhookSubscription, type: :binary_id
      belongs_to :webhook_event, WebhookEvent, type: :binary_id
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [
        :delivery_id,
        :status,
        :endpoint_url,
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
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])
    ensure_oban_jobs_table!(repo)
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS webhook_atomicity_deliveries_97 CASCADE", [])
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS webhook_atomicity_events_97 CASCADE", [])
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS webhook_atomicity_subscriptions_97 CASCADE", [])
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS webhook_atomicity_users_97 CASCADE", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_atomicity_users_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text NOT NULL,
        hashed_password text NOT NULL,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now(),
        CONSTRAINT webhook_atomicity_users_97_email_key UNIQUE (email)
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_atomicity_subscriptions_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        endpoint_url text,
        event_types text[] NOT NULL DEFAULT '{}',
        enabled boolean NOT NULL DEFAULT true
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_atomicity_events_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        event_id text NOT NULL,
        type text NOT NULL,
        schema_version text NOT NULL,
        occurred_at timestamp NOT NULL,
        payload jsonb NOT NULL,
        actor_id uuid,
        actor_type text,
        organization_id uuid,
        request_id text
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE webhook_atomicity_deliveries_97 (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        delivery_id text NOT NULL,
        status text NOT NULL,
        endpoint_url text,
        webhook_subscription_id uuid NOT NULL REFERENCES webhook_atomicity_subscriptions_97(id),
        webhook_event_id uuid NOT NULL REFERENCES webhook_atomicity_events_97(id)
      )
      """,
      []
    )

    %{repo: repo}
  end

  defp ensure_oban_jobs_table!(repo) do
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS oban_jobs CASCADE", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE oban_jobs (
        id bigserial PRIMARY KEY,
        state text NOT NULL DEFAULT 'available',
        queue text NOT NULL DEFAULT 'default',
        worker text NOT NULL,
        args jsonb NOT NULL,
        errors jsonb NOT NULL DEFAULT '[]'::jsonb,
        meta jsonb NOT NULL DEFAULT '{}'::jsonb,
        tags text[] NOT NULL DEFAULT '{}',
        attempt integer NOT NULL DEFAULT 0,
        attempted_by text[],
        max_attempts integer NOT NULL DEFAULT 20,
        priority integer NOT NULL DEFAULT 0,
        attempted_at timestamp,
        cancelled_at timestamp,
        completed_at timestamp,
        discarded_at timestamp,
        inserted_at timestamp NOT NULL DEFAULT now(),
        scheduled_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )
  end

  defp config(repo, enabled \\ true) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: WebhookUser,
      secret_key_base: String.duplicate("a", 64),
      webhooks: [
        enabled: enabled,
        webhook_subscription_schema: WebhookSubscription,
        webhook_event_schema: WebhookEvent,
        webhook_delivery_schema: WebhookDelivery
      ]
    )
  end

  defp register_opts do
    [changeset_fn: fn attrs -> WebhookUser.changeset(%WebhookUser{}, attrs) end]
  end

  test "persists user, webhook event, delivery, and initial job together when local handoff succeeds", %{repo: repo} do
    repo.insert!(%WebhookSubscription{
      endpoint_url: "https://receiver.example/hooks",
      event_types: ["user.created"],
      enabled: true
    })

    assert {:ok, user} =
             Auth.register(
               config(repo),
               %{"email" => "webhook-ok@example.com", "hashed_password" => "hash"},
               register_opts()
             )

    assert user.email == "webhook-ok@example.com"
    assert 1 == repo.aggregate(WebhookUser, :count)
    assert 1 == repo.aggregate(WebhookEvent, :count)
    assert 1 == repo.aggregate(WebhookDelivery, :count)
    assert 1 ==
             repo.aggregate(
               from(job in "oban_jobs", where: job.queue == "sigra_webhooks"),
               :count
             )

    event = repo.one(from(e in WebhookEvent, select: e))
    delivery = repo.one(from(d in WebhookDelivery, select: d))

    assert event.type == "user.created"
    assert get_in(event.payload, ["data", "object", "email"]) == "webhook-ok@example.com"
    assert delivery.webhook_event_id == event.id
  end

  test "rolls back the user insert when delivery persistence fails inside the outer transaction", %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      INSERT INTO webhook_atomicity_subscriptions_97 (endpoint_url, event_types, enabled)
      VALUES (NULL, ARRAY['user.created'], TRUE)
      """,
      []
    )

    assert {:error, %Ecto.Changeset{} = changeset} =
             Auth.register(
               config(repo),
               %{"email" => "webhook-roll@example.com", "hashed_password" => "hash"},
               register_opts()
             )

    assert %{endpoint_url: ["can't be blank"]} = errors_on(changeset)
    assert 0 == repo.aggregate(WebhookUser, :count)
    assert 0 == repo.aggregate(WebhookEvent, :count)
    assert 0 == repo.aggregate(WebhookDelivery, :count)
  end

  test "rolls back the outer mutation when the initial job insert fails inside the local handoff boundary", %{
    repo: repo
  } do
    repo.insert!(%WebhookSubscription{
      endpoint_url: "https://receiver.example/hooks",
      event_types: ["user.created"],
      enabled: true
    })

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE oban_jobs
      ADD CONSTRAINT webhook_atomicity_reject_sigra_queue
      CHECK (queue <> 'sigra_webhooks')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        Auth.register_user_multi(
          %{"email" => "webhook-job-roll@example.com", "hashed_password" => "hash"},
          Keyword.merge(register_opts(), config: config(repo))
        )
        |> repo.transaction()
      end
    after
      Ecto.Adapters.SQL.query!(
        repo,
        """
        ALTER TABLE oban_jobs
        DROP CONSTRAINT IF EXISTS webhook_atomicity_reject_sigra_queue
        """,
        []
      )
    end

    assert 0 == repo.aggregate(WebhookUser, :count)
    assert 0 == repo.aggregate(WebhookEvent, :count)
    assert 0 == repo.aggregate(WebhookDelivery, :count)
    assert 0 ==
             repo.aggregate(
               from(job in "oban_jobs", where: job.queue == "sigra_webhooks"),
               :count
             )
  end

  defp errors_on(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
