defmodule Sigra.OAuth.Token do
  @moduledoc """
  RFC 6749 token-grant helper for Sigra-managed service accounts.
  """

  alias Sigra.{APIToken.ScopeRegistry, ServiceAccounts, Token}

  @dummy_hash Token.hash_token("sigra_sa_dummy_credential_for_constant_time_compare")

  @type opts :: [
          client_id: String.t(),
          client_secret: String.t(),
          scope: String.t() | nil,
          ip_address: String.t() | nil
        ]

  @spec client_credentials(Sigra.Config.t(), opts()) ::
          {:ok, %{access_token: String.t(), expires_in: pos_integer(), scope: String.t()}}
          | {:error, :invalid_client | :invalid_scope | :service_account_token_issuance_aborted}
  def client_credentials(config, opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    client_secret = Keyword.fetch!(opts, :client_secret)
    requested_scope = Keyword.get(opts, :scope)
    ip_address = Keyword.get(opts, :ip_address)

    credential = ServiceAccounts.fetch_credential_by_client_id(config, client_id)
    hashed_secret = Token.hash_token(client_secret)

    with {:ok, credential} <- verify_credential(credential, hashed_secret),
         {:ok, service_account} <- verify_service_account(config, credential),
         {:ok, scope_list} <- validate_requested_scope(config, service_account, requested_scope),
         {:ok, tokens} <-
           ServiceAccounts.issue_token(
             config,
             service_account
             |> Map.put(:scopes, scope_list)
             |> Map.put(:ip_address, ip_address),
             credential
           ) do
      {:ok, Map.put(tokens, :scope, Enum.join(scope_list, " "))}
    end
  end

  defp verify_credential(nil, submitted_hash) do
    Token.secure_compare(submitted_hash, @dummy_hash)
    {:error, :invalid_client}
  end

  defp verify_credential(%{revoked_at: revoked_at}, submitted_hash) when not is_nil(revoked_at) do
    Token.secure_compare(submitted_hash, @dummy_hash)
    {:error, :invalid_client}
  end

  defp verify_credential(
         %{expires_at: expires_at, hashed_client_secret: stored_hash} = credential,
         submitted_hash
       )
       when not is_nil(expires_at) do
    cond do
      DateTime.compare(expires_at, DateTime.utc_now()) == :lt ->
        Token.secure_compare(submitted_hash, @dummy_hash)
        {:error, :invalid_client}

      true ->
        verify_secret(stored_hash, submitted_hash, credential)
    end
  end

  defp verify_credential(%{hashed_client_secret: stored_hash} = credential, submitted_hash) do
    verify_secret(stored_hash, submitted_hash, credential)
  end

  defp verify_secret(stored_hash, submitted_hash, credential)
       when is_binary(stored_hash) and is_binary(submitted_hash) do
    if Token.secure_compare(stored_hash, submitted_hash) do
      {:ok, credential}
    else
      {:error, :invalid_client}
    end
  end

  defp verify_service_account(config, credential) do
    schema = Keyword.fetch!(config.service_accounts, :service_account_schema)

    case config.repo.get(schema, credential.service_account_id) do
      %{revoked_at: nil} = service_account -> {:ok, service_account}
      _ -> {:error, :invalid_client}
    end
  end

  defp validate_requested_scope(_config, service_account, nil),
    do: {:ok, Map.get(service_account, :scopes, [])}

  defp validate_requested_scope(config, service_account, "") do
    validate_requested_scope(config, service_account, nil)
  end

  defp validate_requested_scope(config, service_account, requested_scope) do
    requested =
      requested_scope
      |> String.split(~r/\s+/, trim: true)

    granted = Map.get(service_account, :scopes, [])

    with :ok <- ScopeRegistry.validate_scopes(config, requested),
         true <- requested -- granted == [] do
      {:ok, requested}
    else
      _ -> {:error, :invalid_scope}
    end
  end
end
