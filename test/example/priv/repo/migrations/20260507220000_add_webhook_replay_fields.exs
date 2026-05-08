defmodule Example.Repo.Migrations.AddWebhookReplayFields do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE webhook_deliveries
    ADD COLUMN IF NOT EXISTS replayed_from_webhook_delivery_id uuid,
    ADD COLUMN IF NOT EXISTS replay_root_webhook_delivery_id uuid,
    ADD COLUMN IF NOT EXISTS replayed_at timestamp(6) without time zone,
    ADD COLUMN IF NOT EXISTS replayed_by_user_id uuid,
    ADD COLUMN IF NOT EXISTS replay_source varchar(255)
    """)

    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'webhook_deliveries_replayed_from_webhook_delivery_id_fkey'
      ) THEN
        ALTER TABLE webhook_deliveries
        ADD CONSTRAINT webhook_deliveries_replayed_from_webhook_delivery_id_fkey
        FOREIGN KEY (replayed_from_webhook_delivery_id)
        REFERENCES webhook_deliveries(id);
      END IF;
    END
    $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'webhook_deliveries_replay_root_webhook_delivery_id_fkey'
      ) THEN
        ALTER TABLE webhook_deliveries
        ADD CONSTRAINT webhook_deliveries_replay_root_webhook_delivery_id_fkey
        FOREIGN KEY (replay_root_webhook_delivery_id)
        REFERENCES webhook_deliveries(id);
      END IF;
    END
    $$;
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS webhook_deliveries_replay_root_webhook_delivery_id_index
    ON webhook_deliveries (replay_root_webhook_delivery_id)
    """)

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS webhook_deliveries_replayed_from_unique_index
    ON webhook_deliveries (replayed_from_webhook_delivery_id)
    WHERE replayed_from_webhook_delivery_id IS NOT NULL
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS webhook_deliveries_replayed_from_unique_index")
    execute("DROP INDEX IF EXISTS webhook_deliveries_replay_root_webhook_delivery_id_index")

    execute("""
    ALTER TABLE webhook_deliveries
    DROP CONSTRAINT IF EXISTS webhook_deliveries_replayed_from_webhook_delivery_id_fkey,
    DROP CONSTRAINT IF EXISTS webhook_deliveries_replay_root_webhook_delivery_id_fkey
    """)

    execute("""
    ALTER TABLE webhook_deliveries
    DROP COLUMN IF EXISTS replayed_from_webhook_delivery_id,
    DROP COLUMN IF EXISTS replay_root_webhook_delivery_id,
    DROP COLUMN IF EXISTS replayed_at,
    DROP COLUMN IF EXISTS replayed_by_user_id,
    DROP COLUMN IF EXISTS replay_source
    """)
  end
end
