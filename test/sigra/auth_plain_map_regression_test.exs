defmodule Sigra.AuthPlainMapRegressionTest do
  @moduledoc """
  Regression test for AR-10-01 and AR-10-02 (Phase 10 security audit).

  Historical bug: `Sigra.Auth.request_password_reset/3` and
  `Sigra.Auth.request_magic_link/3` both constructed a plain `%{}` map and
  passed it to `repo.insert!/1`. At runtime this raises
  `Protocol.UndefinedError` for `Ecto.Queryable` because `insert!/1` requires
  an `Ecto.Changeset` or a struct that implements the Ecto schema protocols.

  Existing tests in `Sigra.AuthTest` missed the bug because they mocked
  `insert!/1` with a plain-map matcher (`fn %{token: _, context: _}...`),
  so the plain-map path was exercised end-to-end in the mock and never
  touched real Ecto.

  This regression test uses a stub Repo whose `insert!/1` function clause
  only matches **structs**. If either call site reverts to a plain map, the
  stub raises `FunctionClauseError` and this test turns red.

  It also asserts:
    * The inserted value is a struct of the schema module passed via
      `:user_token_schema`, proving `struct!(user_token_schema, attrs)` is
      used (not `struct!(SomeHardcodedSchema, attrs)`).
    * Both functions raise `KeyError` when `:user_token_schema` is missing,
      proving the option is wired as required.
  """

  use ExUnit.Case, async: false

  alias Sigra.Auth

  @secret_key_base String.duplicate("a", 64)

  # --------------------------------------------------------------------------
  # Test fixtures: minimal User schema and a real UserToken Ecto schema
  # --------------------------------------------------------------------------

  defmodule TestUser do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :integer, autogenerate: false}
    embedded_schema do
      field :email, :string
      field :hashed_password, :string
      field :confirmed_at, :utc_datetime
    end
  end

  defmodule TestUserToken do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :integer, autogenerate: false}
    schema "user_tokens" do
      field :token, :binary
      field :context, :string
      field :sent_to, :string
      field :user_id, :integer

      timestamps(type: :utc_datetime)
    end
  end

  # --------------------------------------------------------------------------
  # StubRepo: an in-process capturing repo whose insert!/1 ONLY matches
  # structs. This is the regression guard: a plain map will blow up with
  # FunctionClauseError here, which is the same failure mode
  # Ecto.Adapters.SQL.Sandbox would produce at runtime (Protocol.UndefinedError
  # for Ecto.Queryable). The point is that the bug is caught, not the exact
  # exception class.
  #
  # We use the process dictionary to capture the inserted struct so the
  # assertions can verify struct identity and field values.
  # --------------------------------------------------------------------------

  defmodule StubRepo do
    @moduledoc false

    def put_user(user), do: Process.put(:stub_repo_user, user)

    def get_by(_schema, _clauses) do
      Process.get(:stub_repo_user)
    end

    # REGRESSION GUARD: function head only matches structs.
    # A plain map passed here raises FunctionClauseError.
    def insert!(%_{} = struct) do
      rows = Process.get(:stub_repo_rows, [])
      Process.put(:stub_repo_rows, [struct | rows])
      struct
    end

    def transact(%Ecto.Multi{} = multi) do
      ops = Ecto.Multi.to_list(multi)

      case ops do
        [{step, {:insert, %Ecto.Changeset{} = cs, _}}] ->
          struct = Ecto.Changeset.apply_changes(cs)
          inserted = insert!(struct)
          {:ok, %{step => inserted}}

        [{step, {:insert, %_{} = struct, _}}] ->
          inserted = insert!(struct)
          {:ok, %{step => inserted}}

        _ ->
          raise ArgumentError,
                "StubRepo.transact/1 only supports single-insert multis in this regression harness; got #{inspect(ops)}"
      end
    end

    def all(_schema) do
      Process.get(:stub_repo_rows, []) |> Enum.reverse()
    end
  end

  setup do
    Process.put(:stub_repo_rows, [])
    Process.put(:stub_repo_user, nil)
    :ok
  end

  # --------------------------------------------------------------------------
  # request_password_reset/3 — AR-10-01 regression
  # --------------------------------------------------------------------------

  describe "request_password_reset/3 plain-map regression (AR-10-01)" do
    test "inserts a real %TestUserToken{} struct and returns {:ok, {token, url}}" do
      user = %TestUser{id: 1, email: "reset@example.com"}
      StubRepo.put_user(user)

      opts = [
        user_schema: TestUser,
        user_token_schema: TestUserToken,
        secret_key_base: @secret_key_base,
        url_fun: fn token -> "http://example.com/reset/" <> token end
      ]

      assert {:ok, {encoded_token, url}} =
               Auth.request_password_reset(StubRepo, "reset@example.com", opts)

      assert is_binary(encoded_token)
      assert String.starts_with?(url, "http://example.com/reset/")

      rows = StubRepo.all(TestUserToken)

      # Regression guard: row must be a real TestUserToken struct, not a plain map.
      assert [%TestUserToken{} = inserted] = rows
      assert inserted.context == "reset_password"
      assert inserted.sent_to == "reset@example.com"
      assert inserted.user_id == 1
      assert is_binary(inserted.token)
    end

    test "raises KeyError when :user_token_schema opt is missing" do
      user = %TestUser{id: 1, email: "reset@example.com"}
      StubRepo.put_user(user)

      opts = [
        user_schema: TestUser,
        secret_key_base: @secret_key_base,
        url_fun: fn t -> t end
      ]

      assert_raise KeyError, ~r/user_token_schema/, fn ->
        Auth.request_password_reset(StubRepo, "reset@example.com", opts)
      end
    end
  end

  # --------------------------------------------------------------------------
  # request_magic_link/3 — AR-10-02 regression
  # --------------------------------------------------------------------------

  describe "request_magic_link/3 plain-map regression (AR-10-02)" do
    test "inserts a real %TestUserToken{} struct and returns {:ok, {token, url}}" do
      user = %TestUser{id: 2, email: "magic@example.com"}
      StubRepo.put_user(user)

      opts = [
        user_schema: TestUser,
        user_token_schema: TestUserToken,
        url_fun: fn token -> "http://example.com/magic/" <> token end
      ]

      assert {:ok, {raw_token, url}} =
               Auth.request_magic_link(StubRepo, "magic@example.com", opts)

      assert is_binary(raw_token)
      assert String.starts_with?(url, "http://example.com/magic/")

      rows = StubRepo.all(TestUserToken)

      assert [%TestUserToken{} = inserted] = rows
      assert inserted.context == "magic_link"
      assert inserted.sent_to == "magic@example.com"
      assert inserted.user_id == 2
      assert is_binary(inserted.token)
    end

    test "raises KeyError when :user_token_schema opt is missing" do
      user = %TestUser{id: 2, email: "magic@example.com"}
      StubRepo.put_user(user)

      opts = [
        user_schema: TestUser,
        url_fun: fn t -> t end
      ]

      assert_raise KeyError, ~r/user_token_schema/, fn ->
        Auth.request_magic_link(StubRepo, "magic@example.com", opts)
      end
    end
  end
end
