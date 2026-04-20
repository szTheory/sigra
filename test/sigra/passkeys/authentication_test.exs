defmodule Sigra.Passkeys.AuthenticationTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Passkeys.{Authentication, CoseKey, Credential}
  alias Sigra.Test.Support.PasskeyFixtures

  setup :verify_on_exit!

  defmodule TestUser do
    defstruct [:id, :email]
  end

  defmodule TestUserPasskey do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "user_passkeys" do
      field :user_id, :binary_id
      field :credential_id, :binary
      field :public_key, :binary
      field :sign_count, :integer, default: 0
      field :aaguid, Ecto.UUID
      field :nickname, :string
      field :device_hint, :string
      field :transports, {:array, :string}, default: []
      field :rp_id, :string
      field :last_used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    def update_changeset(passkey, attrs) do
      cast(passkey, attrs, [:sign_count, :last_used_at, :nickname])
    end
  end

  defp config(overrides \\ []) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: TestUser,
      passkeys: [
        origin: "https://dev.dontneeda.pw",
        rp_id: "dev.dontneeda.pw",
        user_verification: :preferred,
        sign_count_policy: :warn,
        user_passkey_schema: TestUserPasskey
      ],
      audit: [audit_schema: Sigra.Test.AuditEvent]
    ]

    Sigra.Config.new!(Keyword.merge(base, overrides))
  end

  defp user, do: %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"}

  defp assertion_fixture(overrides \\ %{}) do
    {authenticator_data, client_data_json, signature, origin, rp_id, challenge_bytes,
     credential_id, cose_key_cbor} = PasskeyFixtures.simplewebauthn_assertion_fixture()

    challenge = Authentication.new_challenge(config(), bytes: challenge_bytes)
    {:ok, cose_key, ""} = Wax.Utils.CBOR.decode(cose_key_cbor)

    Map.merge(
      %{
        assertion: %{
          credential_id: credential_id,
          authenticator_data: authenticator_data,
          signature: signature,
          client_data_json: client_data_json,
          challenge: challenge
        },
        origin: origin,
        rp_id: rp_id,
        credential_id: credential_id,
        serialized_public_key: CoseKey.serialize(cose_key)
      },
      overrides
    )
  end

  test "verify/4 rejects credentials not owned by the user before wax runs" do
    %{assertion: assertion, credential_id: credential_id} = assertion_fixture()
    current_user = user()

    Sigra.MockRepo
    |> expect(:get_by, fn TestUserPasskey, params ->
      assert params == [user_id: current_user.id, credential_id: credential_id]
      nil
    end)

    assert {:error, :credential_not_owned} =
             Authentication.verify(config(), current_user, assertion)
  end

  test "verify/4 authenticates with a scoped credential lookup and decoded COSE key" do
    %{assertion: assertion, credential_id: credential_id, serialized_public_key: public_key} =
      assertion_fixture()

    current_user = user()
    row = build_row(current_user.id, credential_id, public_key, sign_count: 120)

    Sigra.MockRepo
    |> expect(:get_by, fn TestUserPasskey, params ->
      assert params == [user_id: current_user.id, credential_id: credential_id]
      row
    end)

    assert {:ok, ^row, %Wax.AuthenticatorData{sign_count: 144}} =
             Authentication.verify(config(), current_user, assertion)
  end

  test "verify/4 rejects mismatched user_handle values" do
    %{assertion: assertion, credential_id: credential_id, serialized_public_key: public_key} =
      assertion_fixture()

    current_user = user()
    row = build_row(current_user.id, credential_id, public_key)

    Sigra.MockRepo
    |> expect(:get_by, fn TestUserPasskey, params ->
      assert params == [user_id: current_user.id, credential_id: credential_id]
      row
    end)

    assert {:error, :credential_not_owned} =
             Authentication.verify(
               config(),
               current_user,
               Map.put(assertion, :user_handle, "different-user")
             )
  end

  test "authenticate/4 updates sign_count and last_used_at on success" do
    %{assertion: assertion, credential_id: credential_id, serialized_public_key: public_key} =
      assertion_fixture()

    current_user = user()
    row = build_row(current_user.id, credential_id, public_key, sign_count: 120)
    updated = %{row | sign_count: 144, last_used_at: DateTime.utc_now()}

    Sigra.MockRepo
    |> expect(:get_by, fn TestUserPasskey, params ->
      assert params == [user_id: current_user.id, credential_id: credential_id]
      row
    end)
    |> expect(:transact, fn %Ecto.Multi{} = multi ->
      assert Enum.map(Ecto.Multi.to_list(multi), fn {name, _} -> name end) == [:passkey]
      {:ok, %{passkey: updated}}
    end)

    assert {:ok, %Credential{sign_count: 144}} =
             Sigra.Passkeys.authenticate(config(), current_user, assertion)
  end

  test "authenticate/4 warn mode audits regression and still succeeds" do
    %{assertion: assertion, credential_id: credential_id, serialized_public_key: public_key} =
      assertion_fixture()

    current_user = user()
    row = build_row(current_user.id, credential_id, public_key, sign_count: 200)
    updated = %{row | sign_count: 200, last_used_at: DateTime.utc_now()}

    Sigra.MockRepo
    |> expect(:get_by, fn TestUserPasskey, params ->
      assert params == [user_id: current_user.id, credential_id: credential_id]
      row
    end)
    |> expect(:transact, fn %Ecto.Multi{} = multi ->
      assert Enum.map(Ecto.Multi.to_list(multi), fn {name, _} -> name end) == [:passkey, :audit]

      {:ok,
       %{passkey: updated, audit: %Sigra.Test.AuditEvent{action: "passkey.sign_count_regression"}}}
    end)

    assert {:ok, %Credential{sign_count: 200}} =
             Sigra.Passkeys.authenticate(config(), current_user, assertion)
  end

  test "authenticate/4 require_reauth mode audits regression and returns an error" do
    %{assertion: assertion, credential_id: credential_id, serialized_public_key: public_key} =
      assertion_fixture()

    current_user = user()
    row = build_row(current_user.id, credential_id, public_key, sign_count: 200)

    Sigra.MockRepo
    |> expect(:get_by, fn TestUserPasskey, params ->
      assert params == [user_id: current_user.id, credential_id: credential_id]
      row
    end)
    |> expect(:transact, fn %Ecto.Multi{} = multi ->
      assert Enum.map(Ecto.Multi.to_list(multi), fn {name, _} -> name end) == [:audit]
      {:ok, %{audit: %Sigra.Test.AuditEvent{action: "passkey.sign_count_regression"}}}
    end)

    assert {:error, :sign_count_regression} =
             Sigra.Passkeys.authenticate(
               config(
                 passkeys: [
                   origin: "https://dev.dontneeda.pw",
                   rp_id: "dev.dontneeda.pw",
                   sign_count_policy: :require_reauth,
                   user_passkey_schema: TestUserPasskey
                 ]
               ),
               current_user,
               assertion
             )
  end

  test "authenticate/4 revoke mode deletes the credential and returns an error" do
    %{assertion: assertion, credential_id: credential_id, serialized_public_key: public_key} =
      assertion_fixture()

    current_user = user()
    row = build_row(current_user.id, credential_id, public_key, sign_count: 200)

    Sigra.MockRepo
    |> expect(:get_by, fn TestUserPasskey, params ->
      assert params == [user_id: current_user.id, credential_id: credential_id]
      row
    end)
    |> expect(:transact, fn %Ecto.Multi{} = multi ->
      assert Enum.map(Ecto.Multi.to_list(multi), fn {name, _} -> name end) == [:audit, :passkey]

      {:ok,
       %{audit: %Sigra.Test.AuditEvent{action: "passkey.sign_count_regression"}, passkey: row}}
    end)

    assert {:error, :sign_count_regression} =
             Sigra.Passkeys.authenticate(
               config(
                 passkeys: [
                   origin: "https://dev.dontneeda.pw",
                   rp_id: "dev.dontneeda.pw",
                   sign_count_policy: :revoke,
                   user_passkey_schema: TestUserPasskey
                 ]
               ),
               current_user,
               assertion
             )
  end

  defp build_row(user_id, credential_id, public_key, overrides \\ []) do
    fixture = PasskeyFixtures.passkey_fixture(user_id)

    attrs =
      fixture
      |> Map.from_struct()
      |> Map.merge(%{
        credential_id: credential_id,
        public_key: public_key,
        sign_count: 120,
        rp_id: "dev.dontneeda.pw"
      })
      |> Map.merge(Map.new(overrides))

    struct(TestUserPasskey, attrs)
  end
end
