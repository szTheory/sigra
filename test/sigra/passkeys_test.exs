defmodule Sigra.PasskeysTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Passkeys
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

    def create_changeset(passkey \\ %__MODULE__{}, attrs) do
      passkey
      |> cast(attrs, [
        :user_id,
        :credential_id,
        :public_key,
        :sign_count,
        :aaguid,
        :nickname,
        :device_hint,
        :transports,
        :rp_id,
        :last_used_at
      ])
      |> validate_required([:user_id, :credential_id, :public_key])
    end
  end

  defp config(overrides \\ []) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: TestUser,
      passkeys: [
        origin: "https://dev.dontneeda.pw",
        rp_id: "dev.dontneeda.pw",
        attestation: :none,
        user_verification: :preferred,
        max_per_user: 10,
        user_passkey_schema: TestUserPasskey
      ],
      audit: [audit_schema: Sigra.Test.AuditEvent]
    ]

    Sigra.Config.new!(Keyword.merge(base, overrides))
  end

  defp user, do: %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"}

  defp registration_params do
    {attestation_object, client_data_json, _origin, _rp_id, challenge_value} =
      PasskeyFixtures.simplewebauthn_registration_fixture()

    challenge = Sigra.Passkeys.Registration.new_challenge(config(), bytes: challenge_value)

    %{
      attestation_object: attestation_object,
      client_data_json: client_data_json,
      challenge: challenge,
      nickname: "Laptop",
      device_hint: "macOS",
      transports: ["internal", "internal", "hybrid"]
    }
  end

  test "config accepts passkeys options and reserves passkey.* audit prefix" do
    cfg = config()

    assert cfg.passkeys[:sign_count_policy] == :warn
    assert cfg.passkeys[:max_per_user] == 10
    assert "passkey." in cfg.audit[:reserved_prefixes]
  end

  test "register/4 returns a passkey credential and builds atomic multi" do
    current_user = user()
    row = build_row(current_user.id, nickname: "Laptop", rp_id: "dev.dontneeda.pw")

    Sigra.MockRepo
    |> expect(:transact, fn %Ecto.Multi{} = multi ->
      names = Enum.map(Ecto.Multi.to_list(multi), fn {name, _op} -> name end)
      assert names == [:cap_check, :passkey, :audit]
      {:ok, %{cap_check: :ok, passkey: row, audit: %Sigra.Test.AuditEvent{action: "passkey.register.success"}}}
    end)

    assert {:ok, credential} =
             Passkeys.register(config(), current_user, registration_params())

    assert credential.user_id == current_user.id
    assert credential.nickname == "Laptop"
    assert credential.rp_id == "dev.dontneeda.pw"
  end

  test "register/4 surfaces passkey cap reached" do
    Sigra.MockRepo
    |> expect(:transact, fn %Ecto.Multi{} ->
      {:error, :cap_check, {:passkey_cap_reached, %{count: 10, cap: 10}}, %{}}
    end)

    assert {:error, :passkey_cap_reached, %{count: 10, cap: 10}} =
             Passkeys.register(config(), user(), registration_params())
  end

  test "list_for_user/2 maps schema rows to credentials" do
    current_user = user()
    rows = [build_row(current_user.id, nickname: "Desktop"), build_row(current_user.id, nickname: "Phone")]

    Sigra.MockRepo
    |> expect(:all, fn %Ecto.Query{} -> rows end)

    assert [%Sigra.Passkeys.Credential{nickname: "Desktop"}, %Sigra.Passkeys.Credential{nickname: "Phone"}] =
             Passkeys.list_for_user(config(), current_user)
  end

  test "count_for_user/2 delegates to repo aggregate" do
    Sigra.MockRepo
    |> expect(:aggregate, fn %Ecto.Query{}, :count -> 3 end)

    assert Passkeys.count_for_user(config(), user()) == 3
  end

  test "known_transport?/1 recognizes the spec-known transports" do
    assert Passkeys.known_transport?("internal")
    assert Passkeys.known_transport?(:hybrid)
    refute Passkeys.known_transport?("infrared")
  end

  test "rename/5 updates the owning credential and audits the rename" do
    current_user = user()
    row = build_row(current_user.id, nickname: "Laptop")
    updated = %{row | nickname: "Office key"}

    Sigra.MockRepo
    |> expect(:one, fn %Ecto.Query{} -> row end)
    |> expect(:transact, fn %Ecto.Multi{} = multi ->
      names = Enum.map(Ecto.Multi.to_list(multi), fn {name, _op} -> name end)
      assert names == [:passkey, :audit]
      {:ok, %{passkey: updated, audit: %Sigra.Test.AuditEvent{action: "passkey.rename"}}}
    end)

    assert {:ok, credential} =
             Passkeys.rename(config(), current_user, row.credential_id, "Office key")

    assert credential.nickname == "Office key"
  end

  test "rename/5 returns not_found when the credential is not owned by the user" do
    Sigra.MockRepo
    |> expect(:one, fn %Ecto.Query{} -> nil end)

    assert {:error, :not_found} =
             Passkeys.rename(config(), user(), :crypto.strong_rand_bytes(32), "Nope")
  end

  test "delete/4 deletes the owning credential and audits the delete" do
    current_user = user()
    row = build_row(current_user.id, nickname: "Laptop")

    Sigra.MockRepo
    |> expect(:one, fn %Ecto.Query{} -> row end)
    |> expect(:transact, fn %Ecto.Multi{} = multi ->
      names = Enum.map(Ecto.Multi.to_list(multi), fn {name, _op} -> name end)
      assert names == [:passkey, :audit]
      {:ok, %{passkey: row, audit: %Sigra.Test.AuditEvent{action: "passkey.delete"}}}
    end)

    assert {:ok, credential} =
             Passkeys.delete(config(), current_user, row.credential_id)

    assert credential.credential_id == row.credential_id
  end

  test "delete/4 returns not_found when the credential is missing or cross-user" do
    Sigra.MockRepo
    |> expect(:one, fn %Ecto.Query{} -> nil end)

    assert {:error, :not_found} =
             Passkeys.delete(config(), user(), :crypto.strong_rand_bytes(32))
  end

  defp build_row(user_id, overrides) do
    fixture = PasskeyFixtures.passkey_fixture(user_id)

    attrs =
      fixture
      |> Map.from_struct()
      |> Map.merge(Map.new(overrides))

    struct(TestUserPasskey, attrs)
  end
end
