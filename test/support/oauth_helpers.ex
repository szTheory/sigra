defmodule Sigra.Test.OAuthHelpers do
  @moduledoc "Shared fixtures for OAuth tests."

  def mock_user_info(overrides \\ %{}) do
    Map.merge(
      %{
        "sub" => "provider_uid_123",
        "email" => "oauth@example.com",
        "name" => "OAuth User",
        "picture" => "https://example.com/avatar.jpg",
        "email_verified" => true,
        "raw" => %{}
      },
      overrides
    )
  end

  def mock_token(overrides \\ %{}) do
    Map.merge(
      %{
        "access_token" => "mock_access_token",
        "refresh_token" => "mock_refresh_token",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      },
      overrides
    )
  end
end

# Shared mock schemas used across OAuth test files
defmodule Sigra.Test.MockUser do
  use Ecto.Schema

  schema "users" do
    field :email, :string
    field :hashed_password, :string
    field :confirmed_at, :utc_datetime
    field :failed_login_attempts, :integer, default: 0
    timestamps()
  end
end

defmodule Sigra.Test.MockIdentity do
  use Ecto.Schema

  schema "user_identities" do
    field :user_id, :integer
    field :provider, :string
    field :provider_uid, :string
    field :encrypted_access_token, :binary
    field :encrypted_refresh_token, :binary
    field :token_expires_at, :utc_datetime
    field :provider_email, :string
    field :provider_name, :string
    field :provider_avatar_url, :string
    field :metadata, :map, default: %{}
    field :last_used_at, :utc_datetime
    timestamps()
  end
end

defmodule Sigra.Test.MockSession do
end

defmodule Sigra.Test.MockSessionStore do
  def create(_user_id, _metadata, _opts), do: {:ok, %Sigra.Session{}}
end

defmodule Sigra.Test.MockRepo do
  def get_by(Sigra.Test.MockIdentity, clauses) do
    # For link_provider test: return existing identity when user_id present
    if clauses[:provider] == "google" and clauses[:user_id] do
      %Sigra.Test.MockIdentity{
        id: 1,
        provider: "google",
        provider_uid: "uid_123",
        user_id: clauses[:user_id]
      }
    else
      nil
    end
  end

  def get_by(Sigra.Test.MockUser, _clauses), do: nil
  def get_by(_, _), do: nil

  def insert(%Ecto.Changeset{} = changeset) do
    result =
      changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.put(:id, System.unique_integer([:positive]))

    {:ok, result}
  end

  def insert(struct) when is_map(struct) do
    {:ok, Map.put(struct, :id, System.unique_integer([:positive]))}
  end

  def insert!(struct) do
    Map.put(struct, :id, System.unique_integer([:positive]))
  end

  def update(changeset) do
    {:ok, Ecto.Changeset.apply_changes(changeset)}
  end

  def delete(struct) do
    {:ok, struct}
  end

  def transaction(%Ecto.Multi{} = multi) do
    steps = Ecto.Multi.to_list(multi)

    Enum.reduce_while(steps, {:ok, %{}}, fn
      {name, {:run, fun}}, {:ok, acc} ->
        case fun.(__MODULE__, acc) do
          {:ok, result} -> {:cont, {:ok, Map.put(acc, name, result)}}
          {:error, reason} -> {:halt, {:error, name, reason, acc}}
        end

      {name, {:insert, changeset, _opts}}, {:ok, acc} ->
        result =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.put(:id, System.unique_integer([:positive]))

        {:cont, {:ok, Map.put(acc, name, result)}}
    end)
  end

  def delete_all(_query), do: {0, nil}

  def aggregate(_, :count), do: 0
end

# -- Callback-specific mock repos --

defmodule Sigra.Test.CallbackRepo.ExistingIdentity do
  @moduledoc false

  def get_by(Sigra.Test.MockIdentity, clauses) do
    if clauses[:provider_uid] == "provider_uid_123" do
      %Sigra.Test.MockIdentity{
        id: 1,
        user_id: 42,
        provider: clauses[:provider] || "google",
        provider_uid: "provider_uid_123",
        provider_email: "old@example.com",
        provider_name: "Old Name"
      }
    else
      nil
    end
  end

  def get_by(Sigra.Test.MockUser, _), do: nil

  def get!(Sigra.Test.MockUser, 42) do
    %{
      id: 42,
      email: "oauth@example.com",
      hashed_password: nil,
      confirmed_at: ~U[2026-01-01 00:00:00Z]
    }
  end

  def update(changeset) do
    {:ok, Ecto.Changeset.apply_changes(changeset)}
  end

  def insert(_struct), do: {:ok, %{id: 1}}
end

defmodule Sigra.Test.CallbackRepo.EmailMismatch do
  @moduledoc false

  def get_by(Sigra.Test.MockIdentity, clauses) do
    if clauses[:provider] == "google" and clauses[:provider_uid] == "provider_uid_123" do
      %Sigra.Test.MockIdentity{
        id: 1,
        user_id: 42,
        provider: "google",
        provider_uid: "provider_uid_123"
      }
    else
      nil
    end
  end

  def get_by(Sigra.Test.MockUser, clauses) do
    if clauses[:email] == "oauth@example.com" do
      %{id: 99, email: "oauth@example.com", hashed_password: nil}
    else
      nil
    end
  end

  def get!(Sigra.Test.MockUser, 42) do
    %{id: 42, email: "different@example.com", hashed_password: nil}
  end
end

defmodule Sigra.Test.CallbackRepo.EmailMatch do
  @moduledoc false

  def get_by(Sigra.Test.MockIdentity, _), do: nil

  def get_by(Sigra.Test.MockUser, clauses) do
    if clauses[:email] == "oauth@example.com" do
      %{id: 50, email: "oauth@example.com", hashed_password: "$argon2id$hash"}
    else
      nil
    end
  end
end

defmodule Sigra.Test.CallbackRepo.NewUser do
  @moduledoc false

  def get_by(Sigra.Test.MockIdentity, _), do: nil
  def get_by(Sigra.Test.MockUser, _), do: nil

  def transaction(%Ecto.Multi{} = multi) do
    steps = Ecto.Multi.to_list(multi)

    Enum.reduce_while(steps, {:ok, %{}}, fn
      {name, {:run, fun}}, {:ok, acc} ->
        case fun.(__MODULE__, acc) do
          {:ok, result} -> {:cont, {:ok, Map.put(acc, name, result)}}
          {:error, reason} -> {:halt, {:error, name, reason, acc}}
        end

      {name, {:insert, changeset, _opts}}, {:ok, acc} ->
        result =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.put(:id, System.unique_integer([:positive]))

        {:cont, {:ok, Map.put(acc, name, result)}}

      {name, {:changeset, changeset_fn, _opts}}, {:ok, acc} ->
        changeset = changeset_fn.(acc)

        result =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.put(:id, System.unique_integer([:positive]))

        {:cont, {:ok, Map.put(acc, name, result)}}
    end)
  end

  def insert(%Ecto.Changeset{} = changeset) do
    result =
      changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.put(:id, System.unique_integer([:positive]))

    {:ok, result}
  end

  def insert(struct) when is_map(struct) do
    {:ok, Map.put(struct, :id, System.unique_integer([:positive]))}
  end
end
