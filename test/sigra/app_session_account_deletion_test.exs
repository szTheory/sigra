defmodule Sigra.AppSessionAccountDeletionTest do
  use Sigra.Test.PostgresCase, async: false

  alias Sigra.Account.Deletion
  alias Sigra.AppSession

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_account_deletion_users" do
      field :email, :string
      field :deleted_at, :utc_datetime_usec
      field :scheduled_deletion_at, :utc_datetime_usec
      field :original_email, :string
      field :pending_email, :string
      field :hashed_password, :string
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Family do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_account_deletion_families" do
      field :user_id, :binary_id
      field :client_ref, :string
      field :absolute_expires_at, :utc_datetime_usec
      field :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Token do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_account_deletion_tokens" do
      field :family_id, :binary_id
      field :kind, Ecto.Enum, values: [:access, :refresh]
      field :digest, :binary
      field :expires_at, :utc_datetime_usec
      field :consumed_at, :utc_datetime_usec
      field :superseded_at, :utc_datetime_usec
      field :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule OrdinaryToken do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "sigra_account_deletion_ordinary_tokens" do
      field :user_id, :binary_id
      timestamps(type: :utc_datetime_usec)
    end

    def by_user_and_contexts_query(user, _contexts) do
      import Ecto.Query
      from(token in __MODULE__, where: token.user_id == ^user.id)
    end
  end

  defmodule FailingDeleteHook do
    def on_delete(_multi, _context), do: {:error, :deletion_hook_failed}
  end

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_account_deletion_users (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), email text NOT NULL,
          deleted_at timestamp, scheduled_deletion_at timestamp, original_email text,
          pending_email text, hashed_password text, inserted_at timestamp NOT NULL DEFAULT now(),
          updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_account_deletion_families (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
          user_id uuid NOT NULL REFERENCES sigra_account_deletion_users(id) ON DELETE CASCADE,
          client_ref varchar(255) NOT NULL, absolute_expires_at timestamp NOT NULL,
          revoked_at timestamp, inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_account_deletion_tokens (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
          family_id uuid NOT NULL REFERENCES sigra_account_deletion_families(id) ON DELETE CASCADE,
          kind varchar(16) NOT NULL, digest bytea NOT NULL, expires_at timestamp NOT NULL,
          consumed_at timestamp, superseded_at timestamp, revoked_at timestamp,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE IF NOT EXISTS sigra_account_deletion_ordinary_tokens (
          id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), user_id uuid NOT NULL,
          inserted_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "CREATE UNIQUE INDEX IF NOT EXISTS sigra_account_deletion_tokens_digest_idx ON sigra_account_deletion_tokens (digest)",
        []
      )
    end)

    :ok
  end

  setup %{repo: repo} do
    {:ok, user} =
      repo.insert(%User{email: "delete-app-session@example.com", hashed_password: "hash"})

    %{user: user, config: config(repo)}
  end

  test "scheduling deletion revokes only the user's app credentials in the deactivation transaction",
       %{repo: repo, config: config, user: user} do
    {:ok, other_user} = repo.insert(%User{email: "other-delete-app-session@example.com"})
    {:ok, %OrdinaryToken{}} = repo.insert(%OrdinaryToken{user_id: user.id})

    assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
             AppSession.issue(config, user, "ios-delete")

    assert {:ok, %{access_token: other_access, family_id: other_family_id}} =
             AppSession.issue(config, other_user, "ios-other")

    assert {:ok, scheduled, _scheduled_at} = Deletion.schedule(repo, user, deletion_opts(config))
    assert not is_nil(scheduled.deleted_at)
    assert not is_nil(scheduled.scheduled_deletion_at)
    assert repo.aggregate(OrdinaryToken, :count) == 0
    assert not is_nil(repo.get!(Family, family_id).revoked_at)
    assert Enum.all?(tokens(repo, family_id), &(not is_nil(&1.revoked_at)))
    assert {:error, :invalid_token} = AppSession.authenticate(config, access)
    assert {:error, :invalid_token} = AppSession.refresh(config, refresh)
    assert {:ok, %{family_id: ^other_family_id}} = AppSession.authenticate(config, other_access)
  end

  test "a later deletion hook failure rolls back deactivation and app-session revocation", %{
    repo: repo,
    config: config,
    user: user
  } do
    {:ok, %OrdinaryToken{}} = repo.insert(%OrdinaryToken{user_id: user.id})

    assert {:ok, %{access_token: access, refresh_token: refresh, family_id: family_id}} =
             AppSession.issue(config, user, "ios-rollback")

    failing_config = %{config | hooks: [on_delete: {FailingDeleteHook, :on_delete}]}

    assert {:error, :deletion_hook_failed} =
             Deletion.schedule(repo, user, deletion_opts(failing_config))

    assert is_nil(repo.get!(User, user.id).deleted_at)
    assert repo.aggregate(OrdinaryToken, :count) == 1
    assert is_nil(repo.get!(Family, family_id).revoked_at)
    assert Enum.all?(tokens(repo, family_id), &is_nil(&1.revoked_at))
    assert {:ok, %{family_id: ^family_id}} = AppSession.authenticate(config, access)
    assert {:ok, _} = AppSession.refresh(config, refresh)
  end

  test "scheduled app credentials remain invalid through soft, anonymize, and hard-delete finalization",
       %{repo: repo, config: config} do
    for strategy <- [:soft_delete, :anonymize, :hard_delete] do
      {:ok, current_user} =
        repo.insert(%User{
          email: "#{strategy}-delete-app-session@example.com",
          hashed_password: "hash"
        })

      assert {:ok, %{access_token: access, family_id: family_id}} =
               AppSession.issue(config, current_user, "#{strategy}-client")

      assert {:ok, scheduled, _} = Deletion.schedule(repo, current_user, deletion_opts(config))

      assert {:ok, ^strategy} =
               Deletion.execute(repo, scheduled, deletion_opts(config, strategy: strategy))

      assert {:error, :invalid_token} = AppSession.authenticate(config, access)

      if strategy == :hard_delete do
        assert repo.get(User, scheduled.id) == nil
        assert repo.get(Family, family_id) == nil
        assert tokens(repo, family_id) == []
      end
    end
  end

  defp config(repo) do
    Sigra.Config.new!(
      repo: repo,
      user_schema: User,
      app_session: [family_schema: Family, token_schema: Token]
    )
  end

  defp deletion_opts(config, overrides \\ []) do
    Keyword.merge(
      [
        config: config,
        changeset_fn: fn user, attrs -> Ecto.Changeset.change(user, attrs) end,
        token_query_fn: &OrdinaryToken.by_user_and_contexts_query/2
      ],
      if(strategy = Keyword.get(overrides, :strategy),
        do: [config: %{config | deletion: [strategy: strategy]}],
        else: []
      )
    )
  end

  defp tokens(repo, family_id),
    do: repo.all(Ecto.Query.from(token in Token, where: token.family_id == ^family_id))
end
