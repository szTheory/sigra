defmodule Sigra.JWT.RefreshToken do
  @moduledoc """
  Refresh token management with family-based reuse detection.

  Refresh tokens are opaque, hashed tokens stored in the `user_tokens` table
  with `context: "api_refresh"`. Each token belongs to a "family" identified
  by a UUID. When a refresh token is rotated, the old token is marked as
  superseded and a new token is created in the same family.

  ## Reuse Detection (Auth0 Pattern)

  If a superseded token is presented for rotation, the entire token family
  is revoked. This detects stolen refresh tokens: if an attacker uses a
  stolen token after the legitimate user has already rotated it, the reuse
  triggers family-wide revocation, protecting both parties.

  ## Storage

  Token metadata (family_id, scopes, superseded_at) is stored as JSON in
  the `sent_to` field of the user_tokens table.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Sigra.Token

  @doc """
  Creates a new refresh token for the given user.

  Returns `{raw_token, token_record}` where `raw_token` is the opaque string
  to send to the client.

  ## Options

  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @spec create(Sigra.Config.t(), struct(), list(String.t()), keyword()) ::
          {String.t(), struct()}
  def create(config, user, scopes, opts \\ []) do
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    family_id = Ecto.UUID.generate()
    do_create(config, user, scopes, family_id, user_token_schema)
  end

  @doc """
  Rotates a refresh token: supersedes the old token and creates a new one
  in the same family.

  Returns `{:ok, raw_new_token, new_record, scopes}` on success.

  ## Reuse Detection

  If the presented token has already been superseded (i.e., it was already
  rotated), this indicates token theft. The entire family is revoked and
  `{:error, :reuse_detected}` is returned.

  ## Options

  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @spec rotate(Sigra.Config.t(), String.t(), keyword()) ::
          {:ok, String.t(), struct(), list(String.t())}
          | {:error, :invalid_token | :token_expired | :reuse_detected}
  def rotate(config, raw_token, opts \\ []) do
    case rotate_with_reuse_meta(config, raw_token, opts) do
      {:error, :reuse_detected, _} -> {:error, :reuse_detected}
      {:error, reason} -> {:error, reason}
      {:ok, new_raw, new_record, scopes} -> {:ok, new_raw, new_record, scopes}
    end
  end

  @doc false
  @spec rotate_with_reuse_meta(Sigra.Config.t(), String.t(), keyword()) ::
          {:ok, String.t(), struct(), list(String.t())}
          | {:error, :invalid_token | :token_expired}
          | {:error, :reuse_detected, %{user_id: term(), family_id: term()}}
  def rotate_with_reuse_meta(config, raw_token, opts \\ []) do
    case classify_refresh_token(config, raw_token, opts) do
      {:error, reason} ->
        {:error, reason}

      {:ok, :reuse, token_record, metadata} ->
        family_id = metadata["family_id"]
        revoke_family(config, family_id, opts)

        {:error, :reuse_detected,
         %{user_id: token_record.user_id, family_id: family_id}}

      {:ok, :rotate, token_record, metadata} ->
        user_token_schema = Keyword.fetch!(opts, :user_token_schema)
        repo = config.repo

        superseded_metadata =
          Map.put(metadata, "superseded_at", DateTime.utc_now() |> DateTime.to_iso8601())

        token_record
        |> Ecto.Changeset.change(sent_to: Jason.encode!(superseded_metadata))
        |> repo.update!()

        user = %{id: token_record.user_id}
        scopes = metadata["scopes"] || []

        {new_raw, new_record} =
          do_create(config, user, scopes, metadata["family_id"], user_token_schema)

        {:ok, new_raw, new_record, scopes}
    end
  end

  @doc false
  @spec classify_refresh_token(Sigra.Config.t(), String.t(), keyword()) ::
          {:ok, :rotate, struct(), map()}
          | {:ok, :reuse, struct(), map()}
          | {:error, :invalid_token | :token_expired}
  def classify_refresh_token(config, raw_token, opts) do
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    hashed =
      case Base.url_decode64(raw_token, padding: false) do
        {:ok, decoded} -> Token.hash_token(decoded)
        :error -> nil
      end

    repo = config.repo
    refresh_ttl = Keyword.get(config.jwt, :refresh_ttl, 30 * 24 * 60 * 60)

    case repo.get_by(user_token_schema, token: hashed, context: "api_refresh") do
      nil ->
        {:error, :invalid_token}

      token_record ->
        metadata = decode_metadata(token_record.sent_to)

        cond do
          metadata["superseded_at"] != nil ->
            {:ok, :reuse, token_record, metadata}

          token_expired?(token_record, refresh_ttl) ->
            {:error, :token_expired}

          true ->
            {:ok, :rotate, token_record, metadata}
        end
    end
  end

  @doc false
  def build_rotate_persist_multi(%Multi{} = multi, token_record, metadata, _config, opts)
      when is_map(metadata) do
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    superseded_metadata =
      Map.put(metadata, "superseded_at", DateTime.utc_now() |> DateTime.to_iso8601())

    multi
    |> Multi.update(
      :jwt_refresh_supersede,
      Ecto.Changeset.change(token_record, sent_to: Jason.encode!(superseded_metadata))
    )
    |> Multi.run(:jwt_refresh_new_token, fn repo, %{jwt_refresh_supersede: superseded_struct} ->
      user = %{id: superseded_struct.user_id}
      scopes = metadata["scopes"] || []
      family_id = metadata["family_id"]
      {raw, insert_struct} = refresh_token_insert_tuple(user, scopes, family_id, user_token_schema)

      case repo.insert(insert_struct) do
        {:ok, record} -> {:ok, {raw, record, scopes}}
        {:error, cs} -> {:error, cs}
      end
    end)
  end

  @doc false
  def build_revoke_family_multi(%Multi{} = multi, _config, family_id, opts) do
    Multi.run(multi, :jwt_reuse_revoke_family, fn repo, _ ->
      user_token_schema = Keyword.fetch!(opts, :user_token_schema)
      now = DateTime.utc_now() |> DateTime.to_iso8601()

      query =
        from(t in user_token_schema,
          where: t.context == "api_refresh",
          where: like(t.sent_to, ^"%\"family_id\":\"#{family_id}\"%")
        )

      tokens = repo.all(query)

      count =
        Enum.reduce(tokens, 0, fn token_record, acc ->
          meta = decode_metadata(token_record.sent_to)

          if meta["superseded_at"] == nil do
            superseded_metadata = Map.put(meta, "superseded_at", now)

            token_record
            |> Ecto.Changeset.change(sent_to: Jason.encode!(superseded_metadata))
            |> repo.update!()

            acc + 1
          else
            acc
          end
        end)

      {:ok, count}
    end)
  end

  @doc """
  Revokes a specific refresh token by marking it as superseded.

  ## Options

  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @spec revoke(Sigra.Config.t(), String.t(), keyword()) ::
          :ok | {:error, :invalid_token}
  def revoke(config, raw_token, opts \\ []) do
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    hashed =
      case Base.url_decode64(raw_token, padding: false) do
        {:ok, decoded} -> Token.hash_token(decoded)
        :error -> nil
      end

    repo = config.repo

    case repo.get_by(user_token_schema, token: hashed, context: "api_refresh") do
      nil ->
        {:error, :invalid_token}

      token_record ->
        metadata = decode_metadata(token_record.sent_to)

        superseded_metadata =
          Map.put(metadata, "superseded_at", DateTime.utc_now() |> DateTime.to_iso8601())

        token_record
        |> Ecto.Changeset.change(sent_to: Jason.encode!(superseded_metadata))
        |> repo.update!()

        :ok
    end
  end

  @doc """
  Revokes all tokens in a family by marking them as superseded.

  ## Options

  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @spec revoke_family(Sigra.Config.t(), String.t(), keyword()) :: {:ok, non_neg_integer()}
  def revoke_family(config, family_id, opts \\ []) do
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    repo = config.repo
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    # Fetch all tokens in the family that are not yet superseded
    query =
      from(t in user_token_schema,
        where: t.context == "api_refresh",
        where: like(t.sent_to, ^"%\"family_id\":\"#{family_id}\"%")
      )

    tokens = repo.all(query)

    count =
      Enum.reduce(tokens, 0, fn token_record, acc ->
        metadata = decode_metadata(token_record.sent_to)

        if metadata["superseded_at"] == nil do
          superseded_metadata = Map.put(metadata, "superseded_at", now)

          token_record
          |> Ecto.Changeset.change(sent_to: Jason.encode!(superseded_metadata))
          |> repo.update!()

          acc + 1
        else
          acc
        end
      end)

    {:ok, count}
  end

  @doc """
  Revokes all refresh tokens for a user.

  Used when a password is changed to invalidate all existing refresh tokens.

  ## Options

  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @spec revoke_all_for_user(Sigra.Config.t(), term(), keyword()) :: {:ok, non_neg_integer()}
  def revoke_all_for_user(config, user_id, opts \\ []) do
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    repo = config.repo

    query =
      from(t in user_token_schema,
        where: t.context == "api_refresh" and t.user_id == ^user_id
      )

    {count, _} = repo.delete_all(query)
    {:ok, count}
  end

  # -- Private --

  defp do_create(config, user, scopes, family_id, user_token_schema) do
    {raw_token, token_struct} = refresh_token_insert_tuple(user, scopes, family_id, user_token_schema)
    {:ok, record} = config.repo.insert(token_struct)
    {raw_token, record}
  end

  defp refresh_token_insert_tuple(user, scopes, family_id, user_token_schema) do
    {raw_token, hashed_token} = Token.generate_hashed_token()

    metadata =
      Jason.encode!(%{
        family_id: family_id,
        scopes: scopes,
        superseded_at: nil
      })

    token_struct =
      struct!(user_token_schema, %{
        token: hashed_token,
        context: "api_refresh",
        sent_to: metadata,
        user_id: user.id
      })

    {raw_token, token_struct}
  end

  defp decode_metadata(nil), do: %{}
  defp decode_metadata(json) when is_binary(json), do: Jason.decode!(json)

  defp token_expired?(token_record, ttl_seconds) do
    inserted_at = token_record.inserted_at
    expiry = DateTime.add(inserted_at, ttl_seconds, :second)
    DateTime.compare(DateTime.utc_now(), expiry) == :gt
  end
end
