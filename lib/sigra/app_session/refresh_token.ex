defmodule Sigra.AppSession.RefreshToken do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Multi
  alias Sigra.Token

  @doc false
  def build_locked_classify_multi(%Multi{} = multi, config, raw_refresh_token) do
    Multi.run(multi, :app_session_refresh_classification, fn repo, _changes ->
      with {:ok, settings} <- settings(config),
           {:ok, digest} <- digest(raw_refresh_token),
           {token, family} when not is_nil(token) <- locked_refresh(repo, settings, digest) do
        classify(token, family)
      else
        {:error, _reason} = error -> error
        nil -> {:error, :invalid_token}
      end
    end)
  end

  @doc false
  def build_rotate_persist_multi(%Multi{} = multi, config, token, family) do
    Multi.run(multi, :app_session_refresh_rotate, fn repo, _changes ->
      with {:ok, settings} <- settings(config),
           {:ok, pair} <- rotate(repo, settings, token, family) do
        {:ok, pair}
      end
    end)
  end

  @doc false
  def build_revoke_family_multi(%Multi{} = multi, config, family) do
    Multi.run(multi, :app_session_refresh_revoke_family, fn repo, _changes ->
      with {:ok, settings} <- settings(config),
           {:ok, revoked_family} <- revoke_family(repo, settings, family) do
        {:ok, revoked_family}
      end
    end)
  end

  defp locked_refresh(repo, settings, digest) do
    repo.one(
      from(token in settings.token_schema,
        join: family in ^settings.family_schema,
        on: token.family_id == family.id,
        where: token.digest == ^digest and token.kind == :refresh,
        select: {token, family},
        lock: "FOR UPDATE"
      )
    )
  end

  defp classify(token, family) do
    now = now()

    cond do
      not is_nil(token.consumed_at) ->
        {:ok, {:reuse, token, family}}

      not is_nil(token.revoked_at) or not is_nil(token.superseded_at) or
          not is_nil(family.revoked_at) ->
        {:error, :invalid_token}

      expired?(now, token.expires_at) or expired?(now, family.absolute_expires_at) ->
        {:error, :token_expired}

      true ->
        {:ok, {:rotate, token, family}}
    end
  end

  defp rotate(repo, settings, token, family) do
    now = now()
    {access_raw, access_digest} = Token.generate_hashed_token()
    {refresh_raw, refresh_digest} = Token.generate_hashed_token()
    refresh_expiry = min_expiry(now, settings.refresh_idle_ttl, family.absolute_expires_at)

    with {:ok, _consumed} <- repo.update(Ecto.Changeset.change(token, consumed_at: now)),
         {_, _} <-
           repo.update_all(
             from(current in settings.token_schema,
               where: current.family_id == ^family.id and current.kind == :access,
               where:
                 is_nil(current.superseded_at) and is_nil(current.revoked_at) and
                   is_nil(current.consumed_at)
             ),
             set: [superseded_at: now]
           ),
         {:ok, access} <-
           repo.insert(
             struct!(settings.token_schema, %{
               family_id: family.id,
               kind: :access,
               digest: access_digest,
               expires_at: DateTime.add(now, settings.access_ttl, :second)
             })
           ),
         {:ok, refresh} <-
           repo.insert(
             struct!(settings.token_schema, %{
               family_id: family.id,
               kind: :refresh,
               digest: refresh_digest,
               expires_at: refresh_expiry
             })
           ) do
      {:ok,
       %{
         access_token: access_raw,
         refresh_token: refresh_raw,
         access: access,
         refresh: refresh,
         family: family
       }}
    end
  end

  defp revoke_family(repo, settings, family) do
    now = now()

    with {:ok, revoked_family} <- repo.update(Ecto.Changeset.change(family, revoked_at: now)),
         {_, _} <-
           repo.update_all(
             from(token in settings.token_schema,
               where: token.family_id == ^family.id and is_nil(token.revoked_at)
             ),
             set: [revoked_at: now]
           ) do
      {:ok, revoked_family}
    end
  end

  defp settings(%{app_session: app_session}) do
    with family_schema when is_atom(family_schema) <- app_session[:family_schema],
         token_schema when is_atom(token_schema) <- app_session[:token_schema],
         true <- Code.ensure_loaded?(family_schema) and Code.ensure_loaded?(token_schema) do
      {:ok,
       %{
         family_schema: family_schema,
         token_schema: token_schema,
         access_ttl: app_session[:access_ttl],
         refresh_idle_ttl: app_session[:refresh_idle_ttl]
       }}
    else
      _ -> {:error, :app_session_not_configured}
    end
  end

  defp digest(raw) when is_binary(raw) do
    case Base.url_decode64(raw, padding: false) do
      {:ok, decoded} -> {:ok, Token.hash_token(decoded)}
      :error -> {:error, :invalid_token}
    end
  end

  defp digest(_), do: {:error, :invalid_token}

  defp expired?(now, expiry), do: DateTime.compare(now, expiry) != :lt

  defp min_expiry(now, idle_ttl, absolute_expiry) do
    idle_expiry = DateTime.add(now, idle_ttl, :second)

    case DateTime.compare(idle_expiry, absolute_expiry) do
      :gt -> absolute_expiry
      _ -> idle_expiry
    end
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
