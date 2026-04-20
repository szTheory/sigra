defmodule Sigra.MFAAuditAtomicityTest do
  use ExUnit.Case, async: false

  alias Sigra.{Config, MFA}
  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule MfaCredential do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "user_mfa_credentials" do
      field(:user_id, :binary_id)
      field(:type, :string)
      field(:encrypted_secret, :binary)
      field(:last_used_at, :utc_datetime_usec)
      field(:last_verified_step, :integer)
      field(:failed_attempts, :integer, default: 0)
      field(:locked_until, :utc_datetime_usec)
      field(:enabled_at, :utc_datetime_usec)
      timestamps(type: :utc_datetime_usec)
    end

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [
        :user_id,
        :type,
        :encrypted_secret,
        :last_used_at,
        :last_verified_step,
        :failed_attempts,
        :locked_until,
        :enabled_at
      ])
      |> Ecto.Changeset.validate_required([
        :user_id,
        :type,
        :encrypted_secret,
        :last_verified_step,
        :failed_attempts,
        :enabled_at
      ])
    end
  end

  defmodule BackupCode do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "user_mfa_backup_codes" do
      field(:user_id, :binary_id)
      field(:hashed_code, :string)
      field(:used_at, :utc_datetime_usec)
      field(:inserted_at, :utc_datetime_usec)
    end
  end

  defmodule UserStub do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "users" do
      field(:mfa_trust_epoch, :integer, default: 0)
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    for t <- ["user_mfa_backup_codes", "user_mfa_credentials", "audit_events", "users"] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE users (
        id uuid PRIMARY KEY,
        mfa_trust_epoch integer NOT NULL DEFAULT 0
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE user_mfa_credentials (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        type varchar(32) NOT NULL,
        encrypted_secret bytea NOT NULL,
        last_verified_step integer,
        last_used_at timestamp,
        failed_attempts integer NOT NULL DEFAULT 0,
        locked_until timestamp,
        enabled_at timestamp NOT NULL,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE user_mfa_backup_codes (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        hashed_code text NOT NULL,
        used_at timestamp,
        inserted_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE audit_events (
        id uuid PRIMARY KEY,
        occurred_at timestamp NOT NULL DEFAULT now(),
        action varchar(255) NOT NULL,
        outcome varchar(32) NOT NULL DEFAULT 'success',
        actor_id uuid,
        actor_type varchar(64) NOT NULL DEFAULT 'user',
        target_id uuid,
        target_type varchar(64),
        ip_address varchar(64),
        user_agent varchar(512),
        metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
        organization_id uuid,
        effective_user_id uuid,
        inserted_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      "TRUNCATE TABLE user_mfa_backup_codes, user_mfa_credentials, audit_events, users RESTART IDENTITY CASCADE",
      []
    )

    %{repo: repo}
  end

  defp cfg(repo, audit? \\ true) do
    audit_kw = if audit?, do: [audit_schema: AuditTestEvent], else: []

    Config.new!(
      Keyword.merge(
        [
          repo: repo,
          user_schema: UserStub,
          otp_app: :sigra,
          mfa: [
            totp_drift_steps: 1,
            backup_code_count: 2,
            lockout_threshold: 5,
            lockout_duration: 900
          ]
        ],
        audit: audit_kw
      )
    )
  end

  test "confirm_enrollment commits credential, backup codes, and mfa.enroll.success audit together",
       %{
         repo: repo
       } do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    {:ok, %{raw_secret: raw}} = MFA.enroll(config, account: "u@example.com")
    now = System.system_time(:second)
    code = NimbleTOTP.verification_code(raw, time: now)

    assert {:ok, %{credential: _cred, backup_codes: [_a, _b]}} =
             MFA.confirm_enrollment(config, user, raw, code,
               mfa_credential_schema: MfaCredential,
               backup_code_schema: BackupCode
             )

    assert count(repo, "user_mfa_credentials") == 1
    assert count(repo, "user_mfa_backup_codes") == 2
    assert count_where(repo, "audit_events", "action = 'mfa.enroll.success'") == 1
  end

  test "rolls back enrollment when audit insert is rejected by database guard", %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_atomicity_guard CHECK (action <> 'mfa.enroll.success')
      """,
      []
    )

    try do
      user = %{id: Ecto.UUID.generate()}
      config = cfg(repo)
      {:ok, %{raw_secret: raw}} = MFA.enroll(config, account: "u@example.com")
      now = System.system_time(:second)
      code = NimbleTOTP.verification_code(raw, time: now)

      assert_raise Ecto.ConstraintError, fn ->
        MFA.confirm_enrollment(config, user, raw, code,
          mfa_credential_schema: MfaCredential,
          backup_code_schema: BackupCode
        )
      end

      assert count(repo, "user_mfa_credentials") == 0
      assert count(repo, "user_mfa_backup_codes") == 0
      assert count(repo, "audit_events") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_atomicity_guard",
        []
      )
    end
  end

  test "verify TOTP success updates credential and writes mfa.verify.success audit", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()

    {:ok, _} =
      repo.insert(
        MfaCredential.changeset(%MfaCredential{}, %{
          user_id: user.id,
          type: "totp",
          encrypted_secret: raw,
          last_verified_step: 0,
          failed_attempts: 0,
          locked_until: nil,
          enabled_at: now
        })
      )

    code = NimbleTOTP.verification_code(raw, time: System.system_time(:second))

    assert {:ok, :verified} =
             MFA.verify(config, user, code, mfa_credential_schema: MfaCredential)

    assert count_where(repo, "audit_events", "action = 'mfa.verify.success'") == 1
  end

  test "verify_backup success writes two audit rows ordered by id", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()
    [{plain, hashed}] = Sigra.MFA.BackupCodes.generate(1)

    {:ok, _} =
      repo.insert(
        MfaCredential.changeset(%MfaCredential{}, %{
          user_id: user.id,
          type: "totp",
          encrypted_secret: raw,
          last_verified_step: 0,
          failed_attempts: 0,
          locked_until: nil,
          enabled_at: now
        })
      )

    {:ok, _} =
      repo.insert(%BackupCode{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        hashed_code: hashed,
        used_at: nil,
        inserted_at: now
      })

    assert {:ok, :consumed, _} =
             MFA.verify_backup(config, user, plain,
               mfa_credential_schema: MfaCredential,
               backup_code_schema: BackupCode
             )

    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT action FROM audit_events ORDER BY inserted_at ASC, id ASC",
        []
      )

    actions = Enum.map(rows, fn [a] -> a end)
    assert actions == ["mfa.verify.success", "mfa.backup_code_used"]
  end

  test "disable rolls back when audit insert is rejected by database guard", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)

    {:ok, _} = repo.insert(%UserStub{id: user.id, mfa_trust_epoch: 0})

    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()

    {:ok, _} =
      repo.insert(
        MfaCredential.changeset(%MfaCredential{}, %{
          user_id: user.id,
          type: "totp",
          encrypted_secret: raw,
          last_verified_step: 0,
          failed_attempts: 0,
          locked_until: nil,
          enabled_at: now
        })
      )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_disable_atomicity_guard CHECK (action <> 'mfa.disable')
      """,
      []
    )

    try do
      code = NimbleTOTP.verification_code(raw, time: System.system_time(:second))

      assert_raise Ecto.ConstraintError, fn ->
        MFA.disable(config, user, code,
          mfa_credential_schema: MfaCredential,
          backup_code_schema: BackupCode
        )
      end

      assert count(repo, "user_mfa_credentials") == 1
      assert count_where(repo, "audit_events", "action = 'mfa.disable'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_disable_atomicity_guard",
        []
      )
    end
  end

  defp count(repo, table) do
    %{rows: [[n]]} = Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM #{table}", [])
    n
  end

  defp count_where(repo, table, where) do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM #{table} WHERE #{where}", [])

    n
  end
end
