defmodule Sigra.MFAAuditAtomicityTest do
  use Sigra.Test.PostgresCase, async: false

  defmodule EnrollInvalidCodeTelemetryHandler do
    @moduledoc false
    def handle_event(event, measurements, metadata, parent) do
      send(parent, {:enroll_invalid_code_telemetry, event, measurements, metadata})
    end
  end

  import Ecto.Query

  alias Sigra.{Config, MFA}
  alias Sigra.Test.AuditEvent, as: AuditTestEvent

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

  setup %{repo: repo} do
    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE IF NOT EXISTS users (
        id uuid PRIMARY KEY,
        mfa_trust_epoch integer NOT NULL DEFAULT 0
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE IF NOT EXISTS user_mfa_credentials (
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
      CREATE TABLE IF NOT EXISTS user_mfa_backup_codes (
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
      CREATE TABLE IF NOT EXISTS audit_events (
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

  test "verify TOTP success rolls back credential updates when mfa.verify.success audit is blocked",
       %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()

    {:ok, cred} =
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

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_verify_success_audit_guard CHECK (action <> 'mfa.verify.success')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        MFA.verify(config, user, code, mfa_credential_schema: MfaCredential)
      end

      assert count_where(repo, "audit_events", "action = 'mfa.verify.success'") == 0
      {:ok, id_bin} = Ecto.UUID.dump(cred.id)

      %{rows: [[step]]} =
        Ecto.Adapters.SQL.query!(
          repo,
          "SELECT last_verified_step FROM user_mfa_credentials WHERE id = $1",
          [id_bin]
        )

      assert step == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_verify_success_audit_guard",
        []
      )
    end
  end

  test "verify wrong TOTP rolls back lockout increment when mfa.verify.failure audit is blocked",
       %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()

    {:ok, cred} =
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
      ADD CONSTRAINT mfa_totp_verify_failure_guard CHECK (action <> 'mfa.verify.failure')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        MFA.verify(config, user, "000000", mfa_credential_schema: MfaCredential)
      end

      {:ok, id_bin} = Ecto.UUID.dump(cred.id)

      %{rows: [[attempts]]} =
        Ecto.Adapters.SQL.query!(
          repo,
          "SELECT failed_attempts FROM user_mfa_credentials WHERE id = $1",
          [id_bin]
        )

      assert attempts == 0
      assert count_where(repo, "audit_events", "action = 'mfa.verify.failure'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_totp_verify_failure_guard",
        []
      )
    end
  end

  test "verify wrong TOTP at threshold 1 rolls back when mfa.lockout audit is blocked",
       %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}

    config =
      Config.new!(
        Keyword.merge(
          [
            repo: repo,
            user_schema: UserStub,
            otp_app: :sigra,
            mfa: [
              totp_drift_steps: 1,
              backup_code_count: 2,
              lockout_threshold: 1,
              lockout_duration: 900
            ]
          ],
          audit: [audit_schema: AuditTestEvent]
        )
      )

    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()

    {:ok, cred} =
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
      ADD CONSTRAINT mfa_totp_lockout_guard CHECK (action <> 'mfa.lockout')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        MFA.verify(config, user, "000000", mfa_credential_schema: MfaCredential)
      end

      {:ok, id_bin} = Ecto.UUID.dump(cred.id)

      %{rows: [[attempts]]} =
        Ecto.Adapters.SQL.query!(
          repo,
          "SELECT failed_attempts FROM user_mfa_credentials WHERE id = $1",
          [id_bin]
        )

      assert attempts == 0
      assert count_where(repo, "audit_events", "action = 'mfa.verify.failure'") == 0
      assert count_where(repo, "audit_events", "action = 'mfa.lockout'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_totp_lockout_guard",
        []
      )
    end
  end

  test "regenerate backup codes success rolls back when mfa.backup_codes_regenerate audit is blocked",
       %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()
    good = NimbleTOTP.verification_code(raw, time: System.system_time(:second))
    codes = Sigra.MFA.BackupCodes.generate(2)

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

    for {_plain, hashed} <- codes do
      {:ok, _} =
        repo.insert(%BackupCode{
          id: Ecto.UUID.generate(),
          user_id: user.id,
          hashed_code: hashed,
          used_at: nil,
          inserted_at: now
        })
    end

    backup_count_before = count(repo, "user_mfa_backup_codes")

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_regen_success_guard CHECK (action <> 'mfa.backup_codes_regenerate')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        MFA.regenerate_backup_codes(config, user, {:totp, good},
          mfa_credential_schema: MfaCredential,
          backup_code_schema: BackupCode
        )
      end

      assert count(repo, "user_mfa_backup_codes") == backup_count_before
      assert count_where(repo, "audit_events", "action = 'mfa.backup_codes_regenerate'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_regen_success_guard",
        []
      )
    end
  end

  test "regenerate backup codes wrong TOTP rolls back when mfa.verify.failure audit is blocked",
       %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()
    codes = Sigra.MFA.BackupCodes.generate(2)

    {:ok, cred} =
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

    for {_plain, hashed} <- codes do
      {:ok, _} =
        repo.insert(%BackupCode{
          id: Ecto.UUID.generate(),
          user_id: user.id,
          hashed_code: hashed,
          used_at: nil,
          inserted_at: now
        })
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_regen_verify_failure_guard CHECK (action <> 'mfa.verify.failure')
      """,
      []
    )

    try do
      assert_raise Ecto.ConstraintError, fn ->
        MFA.regenerate_backup_codes(config, user, {:totp, "000000"},
          mfa_credential_schema: MfaCredential,
          backup_code_schema: BackupCode
        )
      end

      {:ok, id_bin} = Ecto.UUID.dump(cred.id)

      %{rows: [[attempts]]} =
        Ecto.Adapters.SQL.query!(
          repo,
          "SELECT failed_attempts FROM user_mfa_credentials WHERE id = $1",
          [id_bin]
        )

      assert attempts == 0
      assert count_where(repo, "audit_events", "action = 'mfa.verify.failure'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_regen_verify_failure_guard",
        []
      )
    end
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

  test "verify_backup wrong code emits mfa.verify.failure with backup_code metadata", %{
    repo: repo
  } do
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

    wrong = plain <> "x"

    assert {:error, :invalid_backup_code, _} =
             MFA.verify_backup(config, user, wrong,
               mfa_credential_schema: MfaCredential,
               backup_code_schema: BackupCode
             )

    assert count_where(repo, "audit_events", "action = 'mfa.verify.failure'") >= 1

    %{rows: [[meta]]} =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT metadata::text FROM audit_events WHERE action = 'mfa.verify.failure' ORDER BY inserted_at DESC LIMIT 1",
        []
      )

    assert meta =~ "backup_code"
  end

  test "verify_backup wrong code rolls back lockout increment when audit insert is blocked", %{
    repo: repo
  } do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    raw = NimbleTOTP.secret()
    now = DateTime.utc_now()
    [{plain, hashed}] = Sigra.MFA.BackupCodes.generate(1)

    {:ok, cred} =
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

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_backup_verify_failure_guard CHECK (action <> 'mfa.verify.failure')
      """,
      []
    )

    try do
      wrong = plain <> "0"

      assert_raise Ecto.ConstraintError, fn ->
        MFA.verify_backup(config, user, wrong,
          mfa_credential_schema: MfaCredential,
          backup_code_schema: BackupCode
        )
      end

      {:ok, id_bin} = Ecto.UUID.dump(cred.id)

      %{rows: [[attempts]]} =
        Ecto.Adapters.SQL.query!(
          repo,
          "SELECT failed_attempts FROM user_mfa_credentials WHERE id = $1",
          [id_bin]
        )

      assert attempts == 0
      assert count_where(repo, "audit_events", "action = 'mfa.verify.failure'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_backup_verify_failure_guard",
        []
      )
    end
  end

  test "confirm_enrollment insert_failed writes durable mfa.enroll.failure after enrollment rolls back",
       %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE user_mfa_backup_codes
      ADD CONSTRAINT mfa_enroll_backup_guard CHECK (false)
      """,
      []
    )

    try do
      user = %{id: Ecto.UUID.generate()}
      config = cfg(repo)
      {:ok, %{raw_secret: raw}} = MFA.enroll(config, account: "u@example.com")
      now = System.system_time(:second)
      code = NimbleTOTP.verification_code(raw, time: now)

      assert {:error, %Ecto.Changeset{}} =
               MFA.confirm_enrollment(config, user, raw, code,
                 mfa_credential_schema: MfaCredential,
                 backup_code_schema: BackupCode
               )

      assert count(repo, "user_mfa_credentials") == 0
      assert count(repo, "user_mfa_backup_codes") == 0

      assert count_where(repo, "audit_events", "action = 'mfa.enroll.failure'") >= 1

      %{rows: [[meta]]} =
        Ecto.Adapters.SQL.query!(
          repo,
          "SELECT metadata::text FROM audit_events WHERE action = 'mfa.enroll.failure' ORDER BY inserted_at DESC LIMIT 1",
          []
        )

      assert meta =~ "insert_failed"
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE user_mfa_backup_codes DROP CONSTRAINT IF EXISTS mfa_enroll_backup_guard",
        []
      )
    end
  end

  test "confirm_enrollment insert_failed failure-audit rolls back when audit row is blocked",
       %{repo: repo} do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE user_mfa_backup_codes
      ADD CONSTRAINT mfa_enroll_backup_guard_insert_failed CHECK (false)
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_enroll_failure_audit_guard CHECK (action <> 'mfa.enroll.failure')
      """,
      []
    )

    try do
      user = %{id: Ecto.UUID.generate()}
      config = cfg(repo)
      {:ok, %{raw_secret: raw}} = MFA.enroll(config, account: "u@example.com")
      now = System.system_time(:second)
      code = NimbleTOTP.verification_code(raw, time: now)

      assert {:error, %Ecto.Changeset{}} =
               MFA.confirm_enrollment(config, user, raw, code,
                 mfa_credential_schema: MfaCredential,
                 backup_code_schema: BackupCode
               )

      assert count(repo, "user_mfa_credentials") == 0
      assert count(repo, "user_mfa_backup_codes") == 0
      assert count_where(repo, "audit_events", "action = 'mfa.enroll.failure'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_enroll_failure_audit_guard",
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE user_mfa_backup_codes DROP CONSTRAINT IF EXISTS mfa_enroll_backup_guard_insert_failed",
        []
      )
    end
  end

  test "confirm_enrollment invalid TOTP writes mfa.enroll.failure when audit enabled", %{
    repo: repo
  } do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)
    {:ok, %{raw_secret: raw}} = MFA.enroll(config, account: "u@example.com")

    assert {:error, :invalid_code} =
             MFA.confirm_enrollment(config, user, raw, "000000",
               mfa_credential_schema: MfaCredential,
               backup_code_schema: BackupCode
             )

    assert count(repo, "user_mfa_credentials") == 0
    assert count(repo, "user_mfa_backup_codes") == 0
    assert count_where(repo, "audit_events", "action = 'mfa.enroll.failure'") == 1

    %{rows: [[meta]]} =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT metadata::text FROM audit_events WHERE action = 'mfa.enroll.failure' ORDER BY inserted_at DESC LIMIT 1",
        []
      )

    assert meta =~ "invalid_code"
    assert meta =~ "totp"
  end

  test "confirm_enrollment invalid TOTP skips audit when audit disabled", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo, false)
    {:ok, %{raw_secret: raw}} = MFA.enroll(config, account: "u@example.com")

    assert {:error, :invalid_code} =
             MFA.confirm_enrollment(config, user, raw, "000000",
               mfa_credential_schema: MfaCredential,
               backup_code_schema: BackupCode
             )

    assert count_where(repo, "audit_events", "action = 'mfa.enroll.failure'") == 0
  end

  test "confirm_enrollment invalid TOTP emits log_safe_error when failure audit blocked", %{
    repo: repo
  } do
    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_enroll_invalid_code_failure_guard CHECK (action <> 'mfa.enroll.failure')
      """,
      []
    )

    try do
      user = %{id: Ecto.UUID.generate()}
      config = cfg(repo)
      {:ok, %{raw_secret: raw}} = MFA.enroll(config, account: "u@example.com")

      ref =
        :telemetry.attach(
          {__MODULE__, :enroll_invalid_code_guard},
          [:sigra, :audit, :log_safe_error],
          &EnrollInvalidCodeTelemetryHandler.handle_event/4,
          self()
        )

      try do
        assert {:error, :invalid_code} =
                 MFA.confirm_enrollment(config, user, raw, "000000",
                   mfa_credential_schema: MfaCredential,
                   backup_code_schema: BackupCode
                 )

        assert count_where(repo, "audit_events", "action = 'mfa.enroll.failure'") == 0

        assert_receive {:enroll_invalid_code_telemetry, [:sigra, :audit, :log_safe_error],
                        %{count: 1}, %{action: "mfa.enroll.failure", reason: reason}}

        assert reason in [:constraint_violation, :invalid_changeset]
      after
        :telemetry.detach(ref)
      end
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_enroll_invalid_code_failure_guard",
        []
      )
    end
  end

  test "audit_backup_codes_regenerate inserts mfa.backup_codes_regenerate audit row", %{
    repo: repo
  } do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)

    assert :ok = MFA.audit_backup_codes_regenerate(config, user, 10)

    assert count_where(repo, "audit_events", "action = 'mfa.backup_codes_regenerate'") == 1

    row =
      repo.one!(
        from(e in AuditTestEvent,
          where: e.action == "mfa.backup_codes_regenerate",
          select: e
        )
      )

    assert row.actor_id == user.id
    assert row.metadata["count"] == 10
  end

  test "audit_trust_browser inserts mfa.trust_browser audit row", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)

    assert :ok = MFA.audit_trust_browser(config, user)

    assert count_where(repo, "audit_events", "action = 'mfa.trust_browser'") == 1

    row =
      repo.one!(from(e in AuditTestEvent, where: e.action == "mfa.trust_browser", select: e))

    assert row.actor_id == user.id
  end

  test "audit_backup_codes_regenerate is no-op when audit_schema absent", %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo, false)

    assert :ok = MFA.audit_backup_codes_regenerate(config, user, 3)
    assert count(repo, "audit_events") == 0
  end

  test "audit_backup_codes_regenerate leaves no row when audit insert blocked by CHECK guard",
       %{repo: repo} do
    user = %{id: Ecto.UUID.generate()}
    config = cfg(repo)

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_adhoc_regen_audit_guard CHECK (action <> 'mfa.backup_codes_regenerate')
      """,
      []
    )

    try do
      assert :ok = MFA.audit_backup_codes_regenerate(config, user, 5)
      assert count_where(repo, "audit_events", "action = 'mfa.backup_codes_regenerate'") == 0
    after
      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_adhoc_regen_audit_guard",
        []
      )
    end
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
