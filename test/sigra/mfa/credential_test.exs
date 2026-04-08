defmodule Sigra.MFA.CredentialTest do
  use ExUnit.Case, async: true

  alias Sigra.MFA.Credential

  describe "from_schema/1" do
    test "maps schema struct to Credential struct" do
      now = DateTime.utc_now()

      schema = %{
        id: 1,
        user_id: 42,
        type: "totp",
        encrypted_secret: <<1, 2, 3>>,
        last_used_at: now,
        last_verified_step: 100,
        failed_attempts: 2,
        locked_until: nil,
        enabled_at: now,
        inserted_at: now,
        updated_at: now
      }

      credential = Credential.from_schema(schema)

      assert %Credential{} = credential
      assert credential.id == 1
      assert credential.user_id == 42
      assert credential.type == "totp"
      assert credential.encrypted_secret == <<1, 2, 3>>
      assert credential.last_used_at == now
      assert credential.last_verified_step == 100
      assert credential.failed_attempts == 2
      assert credential.locked_until == nil
      assert credential.enabled_at == now
      assert credential.inserted_at == now
      assert credential.updated_at == now
    end

    test "ignores unknown fields from source" do
      schema = %{id: 1, user_id: 42, unknown_field: "ignored"}

      credential = Credential.from_schema(schema)

      assert credential.id == 1
      assert credential.user_id == 42
    end

    test "defaults failed_attempts to 0" do
      credential = Credential.from_schema(%{})

      assert credential.failed_attempts == 0
    end
  end

  describe "to_params/1" do
    test "maps Credential to changeset params" do
      now = DateTime.utc_now()

      credential = %Credential{
        id: 1,
        user_id: 42,
        type: "totp",
        encrypted_secret: <<1, 2, 3>>,
        last_used_at: now,
        last_verified_step: 100,
        failed_attempts: 2,
        locked_until: nil,
        enabled_at: now,
        inserted_at: now,
        updated_at: now
      }

      params = Credential.to_params(credential)

      assert is_map(params)
      assert params.user_id == 42
      assert params.type == "totp"
      assert params.encrypted_secret == <<1, 2, 3>>
      assert params.failed_attempts == 2
      # id, inserted_at, updated_at should be dropped
      refute Map.has_key?(params, :id)
      refute Map.has_key?(params, :inserted_at)
      refute Map.has_key?(params, :updated_at)
    end

    test "removes nil values" do
      credential = %Credential{
        user_id: 42,
        type: "totp",
        locked_until: nil,
        last_used_at: nil
      }

      params = Credential.to_params(credential)

      refute Map.has_key?(params, :locked_until)
      refute Map.has_key?(params, :last_used_at)
      assert params.user_id == 42
    end
  end
end
