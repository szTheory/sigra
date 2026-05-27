defmodule Sigra.DataExportTest do
  use ExUnit.Case, async: true

  alias Sigra.DataExport

  defmodule TestSession do
    use Ecto.Schema

    schema "test_sessions" do
      field :user_id, :integer
      field :hashed_token, :binary
      field :type, :string
      field :ip, :string
      field :user_agent, :string
      field :last_active_at, :utc_datetime_usec
      field :sudo_at, :utc_datetime_usec
      field :active_organization_id, :integer

      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule TestIdentity do
    use Ecto.Schema

    schema "test_identities" do
      field :user_id, :integer
      field :provider, :string
      field :provider_uid, :string
      field :provider_email, :string
      field :provider_name, :string
      field :provider_avatar_url, :string
      field :metadata, :map, default: %{}
      field :last_used_at, :utc_datetime
      field :encrypted_access_token, :binary
      field :encrypted_refresh_token, :binary

      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule TestAuditEvent do
    use Ecto.Schema

    schema "test_audit_events" do
      field :action, :string
      field :outcome, :string
      field :actor_id, :integer
      field :effective_user_id, :integer
      field :target_id, :integer
      field :target_type, :string
      field :organization_id, :integer
      field :ip_address, :string
      field :user_agent, :string
      field :metadata, :map
      field :occurred_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end

  defmodule TestMfaCredential do
    use Ecto.Schema

    schema "test_mfa_credentials" do
      field :user_id, :integer
      field :type, :string
      field :enabled_at, :utc_datetime_usec
      field :last_used_at, :utc_datetime_usec
      field :last_verified_step, :integer
      field :locked_until, :utc_datetime_usec
      field :failed_attempts, :integer
      field :encrypted_secret, :binary

      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule TestBackupCode do
    use Ecto.Schema

    schema "test_backup_codes" do
      field :user_id, :integer
      field :hashed_code, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end

  defmodule TestPasskey do
    use Ecto.Schema

    schema "test_passkeys" do
      field :user_id, :integer
      field :credential_id, :binary
      field :public_key, :binary
      field :nickname, :string
      field :device_hint, :string
      field :transports, {:array, :string}, default: []
      field :last_used_at, :utc_datetime_usec
      field :sign_count, :integer
      field :rp_id, :string
      field :aaguid, Ecto.UUID

      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule TestMembership do
    use Ecto.Schema

    schema "test_memberships" do
      field :organization_id, :integer
      field :user_id, :integer
      field :role, Ecto.Enum, values: [:owner, :admin, :member]

      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule FakeRepo do
    @now ~U[2026-04-01 12:00:00Z]
    @rows %{
      TestSession => [
        %TestSession{
          id: 10,
          user_id: 1,
          hashed_token: <<1, 2, 3>>,
          type: "standard",
          ip: "203.0.113.10",
          user_agent: "Firefox",
          last_active_at: @now,
          sudo_at: @now,
          active_organization_id: 200,
          inserted_at: @now,
          updated_at: @now
        }
      ],
      TestIdentity => [
        %TestIdentity{
          id: 11,
          user_id: 1,
          provider: "github",
          provider_uid: "gh_123",
          provider_email: "user@example.com",
          provider_name: "Example User",
          provider_avatar_url: "https://example.test/avatar.png",
          metadata: %{nickname: "example", email_verified: true},
          last_used_at: @now,
          encrypted_access_token: <<4, 5, 6>>,
          encrypted_refresh_token: <<7, 8, 9>>,
          inserted_at: @now,
          updated_at: @now
        }
      ],
      TestAuditEvent => [
        %TestAuditEvent{
          id: 12,
          action: "auth.login",
          outcome: "success",
          actor_id: 1,
          effective_user_id: 1,
          target_id: 1,
          target_type: "user",
          organization_id: 200,
          ip_address: "203.0.113.10",
          user_agent: "Firefox",
          metadata: %{method: "password"},
          occurred_at: @now,
          inserted_at: @now
        },
        %TestAuditEvent{
          id: 17,
          action: "organization.active_auto_reassigned",
          outcome: "success",
          actor_id: 2,
          effective_user_id: 2,
          target_id: 1,
          target_type: "organization",
          organization_id: 1,
          ip_address: "203.0.113.11",
          user_agent: "Firefox",
          metadata: %{reason: "colliding organization id"},
          occurred_at: @now,
          inserted_at: @now
        }
      ],
      TestMfaCredential => [
        %TestMfaCredential{
          id: 13,
          user_id: 1,
          type: "totp",
          enabled_at: @now,
          last_used_at: @now,
          last_verified_step: 123,
          locked_until: nil,
          failed_attempts: 0,
          encrypted_secret: <<10, 11, 12>>,
          inserted_at: @now,
          updated_at: @now
        }
      ],
      TestBackupCode => [
        %TestBackupCode{
          id: 14,
          user_id: 1,
          hashed_code: "hashed-code",
          inserted_at: @now
        }
      ],
      TestPasskey => [
        %TestPasskey{
          id: 15,
          user_id: 1,
          credential_id: <<13, 14, 15>>,
          public_key: <<16, 17, 18>>,
          nickname: "MacBook",
          device_hint: "platform",
          transports: ["internal"],
          last_used_at: @now,
          sign_count: 9,
          rp_id: "example.test",
          aaguid: "00000000-0000-0000-0000-000000000000",
          inserted_at: @now,
          updated_at: @now
        }
      ],
      TestMembership => [
        %TestMembership{
          id: 16,
          organization_id: 200,
          user_id: 1,
          role: :admin,
          inserted_at: @now,
          updated_at: @now
        }
      ]
    }

    def all(%Ecto.Query{from: %{source: {_source, schema}}, wheres: wheres, select: select}) do
      assert wheres != []
      assert select != nil

      Map.fetch!(@rows, schema)
    end

    def aggregate(%Ecto.Query{from: %{source: {_source, schema}}, wheres: wheres}, :count, :id) do
      assert wheres != []

      @rows
      |> Map.fetch!(schema)
      |> length()
    end
  end

  describe "export_auth_data/3" do
    test "returns {:ok, map} with versioned export sections" do
      user = %{
        id: 1,
        email: "test@example.com",
        confirmed_at: ~U[2026-01-01 00:00:00Z],
        inserted_at: ~U[2026-01-01 00:00:00Z]
      }

      # Without schemas, sessions and identities default to empty lists
      assert {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.schema_version == 1
      assert %DateTime{} = data.exported_at
      assert Map.has_key?(data, :account)
      assert Map.has_key?(data, :sessions)
      assert Map.has_key?(data, :identities)
      assert Map.has_key?(data, :audit)
      assert Map.has_key?(data, :mfa)
      assert Map.has_key?(data, :organizations)
      assert Map.has_key?(data, :enterprise)
      assert Map.has_key?(data, :omissions)
    end

    test "account map contains raw lifecycle fields and scheduled lifecycle status" do
      scheduled_deletion_at =
        DateTime.utc_now()
        |> DateTime.add(3, :day)
        |> DateTime.truncate(:second)

      user = %{
        id: 42,
        email: "user@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-03-15 12:00:00Z],
        deleted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        scheduled_deletion_at: scheduled_deletion_at
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.account.id == 42
      assert data.account.email == "user@example.com"
      assert data.account.confirmed_at == nil
      assert data.account.inserted_at == ~U[2026-03-15 12:00:00Z]
      assert data.account.deleted_at == user.deleted_at
      assert data.account.scheduled_deletion_at == scheduled_deletion_at
      assert %{state: :scheduled, days_remaining: days_remaining} = data.account.lifecycle_status
      assert days_remaining in 0..3
    end

    test "account lifecycle status reports deleted users" do
      user = %{
        id: 43,
        email: "deleted@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-03-15 12:00:00Z],
        deleted_at: ~U[2026-03-16 12:00:00Z],
        scheduled_deletion_at: nil
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.account.lifecycle_status == %{state: :deleted}
    end

    test "account lifecycle status reports not scheduled users" do
      user = %{
        id: 44,
        email: "active@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-03-15 12:00:00Z],
        deleted_at: nil,
        scheduled_deletion_at: nil
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.account.lifecycle_status == %{state: :not_scheduled}
    end

    test "optional sections degrade honestly without schemas" do
      user = %{
        id: 1,
        email: "test@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00Z]
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.sessions == []
      assert data.identities == []
      assert data.audit == []
      assert data.mfa.credentials == []
      assert data.mfa.passkeys == []
      assert data.mfa.backup_codes.count == 0
      assert data.organizations.memberships == []
      assert data.enterprise.exported == false

      assert data.omissions == [
               %{section: :sessions, schema_option: :session_schema},
               %{section: :identities, schema_option: :identity_schema},
               %{section: :audit, schema_option: :audit_schema},
               %{section: :mfa_credentials, schema_option: :mfa_credential_schema},
               %{section: :passkeys, schema_option: :user_passkey_schema},
               %{section: :backup_codes, schema_option: :backup_code_schema},
               %{section: :memberships, schema_option: :membership_schema}
             ]
    end

    test "configured schemas serialize curated safe auth data" do
      user = %{
        id: 1,
        email: "test@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00Z]
      }

      assert {:ok, data} =
               DataExport.export_auth_data(FakeRepo, user,
                 session_schema: TestSession,
                 identity_schema: TestIdentity,
                 audit_schema: TestAuditEvent,
                 mfa_credential_schema: TestMfaCredential,
                 backup_code_schema: TestBackupCode,
                 user_passkey_schema: TestPasskey,
                 membership_schema: TestMembership
               )

      assert [session] = data.sessions

      assert_includes_only(session, [
        :id,
        :type,
        :ip,
        :user_agent,
        :last_active_at,
        :sudo_at,
        :active_organization_id,
        :inserted_at,
        :updated_at
      ])

      refute Map.has_key?(session, :hashed_token)

      assert [identity] = data.identities

      assert_includes_only(identity, [
        :id,
        :provider,
        :provider_uid,
        :provider_email,
        :provider_name,
        :provider_avatar_url,
        :metadata,
        :last_used_at,
        :inserted_at,
        :updated_at
      ])

      refute Map.has_key?(identity, :encrypted_access_token)
      refute Map.has_key?(identity, :encrypted_refresh_token)

      assert [audit] = data.audit
      refute Enum.any?(data.audit, &(&1.action == "organization.active_auto_reassigned"))

      assert_includes_only(audit, [
        :id,
        :action,
        :outcome,
        :actor_id,
        :effective_user_id,
        :target_id,
        :target_type,
        :organization_id,
        :ip_address,
        :user_agent,
        :metadata,
        :occurred_at,
        :inserted_at
      ])

      assert [mfa_credential] = data.mfa.credentials

      assert_includes_only(mfa_credential, [
        :id,
        :type,
        :enabled_at,
        :last_used_at,
        :last_verified_step,
        :locked_until,
        :failed_attempts,
        :inserted_at,
        :updated_at
      ])

      refute Map.has_key?(mfa_credential, :encrypted_secret)

      assert [passkey] = data.mfa.passkeys

      assert_includes_only(passkey, [
        :id,
        :nickname,
        :device_hint,
        :transports,
        :last_used_at,
        :sign_count,
        :rp_id,
        :aaguid,
        :inserted_at,
        :updated_at
      ])

      refute Map.has_key?(passkey, :credential_id)
      refute Map.has_key?(passkey, :public_key)

      assert data.mfa.backup_codes.count == 1
      refute Map.has_key?(data.mfa.backup_codes, :hashed_code)
      refute inspect(data.mfa.backup_codes) =~ "hashed_code"

      assert [membership] = data.organizations.memberships

      assert_includes_only(membership, [
        :id,
        :organization_id,
        :user_id,
        :role,
        :inserted_at,
        :updated_at
      ])
    end
  end

  describe "behaviour" do
    test "defines export_user_data/1 callback" do
      callbacks = Sigra.DataExport.behaviour_info(:callbacks)
      assert {:export_user_data, 1} in callbacks
    end
  end

  defp assert_includes_only(row, expected_fields) do
    actual_fields =
      row
      |> normalize_export_row()
      |> Map.keys()
      |> Enum.reject(&(&1 == :__meta__))
      |> Enum.sort()

    assert actual_fields == Enum.sort(expected_fields)
  end

  defp normalize_export_row(%{__struct__: _} = row), do: Map.from_struct(row)
  defp normalize_export_row(row) when is_map(row), do: row
end
