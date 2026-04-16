defmodule Sigra.Passkeys.Authentication do
  @moduledoc """
  WebAuthn authentication ceremony helpers.
  """

  require Logger

  alias Sigra.Passkeys.{CoseKey, SignCountPolicy}

  @schema_opts [
    user_passkey_schema: [type: {:or, [:atom, nil]}, default: nil]
  ]

  @type assertion :: %{
          required(:credential_id) => binary(),
          required(:authenticator_data) => binary(),
          required(:signature) => binary(),
          required(:client_data_json) => binary(),
          required(:challenge) => Wax.Challenge.t(),
          optional(:user_handle) => binary() | String.t() | nil
        }

  @spec new_challenge(Sigra.Config.t(), keyword()) :: Wax.Challenge.t()
  def new_challenge(%Sigra.Config{} = config, opts \\ []) do
    passkeys = config.passkeys
    bytes = Keyword.get(opts, :bytes) || :crypto.strong_rand_bytes(32)

    Wax.new_authentication_challenge(
      origin: Keyword.get(passkeys, :origin),
      rp_id: Keyword.get(passkeys, :rp_id),
      user_verification: passkeys |> Keyword.get(:user_verification, :preferred) |> to_string(),
      timeout: Keyword.get(passkeys, :timeout_ms, 60_000),
      bytes: bytes
    )
  end

  @spec verify(Sigra.Config.t(), map(), assertion(), keyword()) ::
          {:ok, struct(), Wax.AuthenticatorData.t()}
          | {:error, :credential_not_owned}
          | {:error, term()}
  def verify(%Sigra.Config{} = config, user, assertion, opts \\ []) do
    validated = NimbleOptions.validate!(opts, @schema_opts)
    schema =
      Keyword.get(validated, :user_passkey_schema) || config.passkeys[:user_passkey_schema] ||
        raise ArgumentError,
              "authenticate requires :user_passkey_schema in opts or config.passkeys[:user_passkey_schema]"

    credential_id = Map.fetch!(assertion, :credential_id)

    case config.repo.get_by(schema, user_id: user.id, credential_id: credential_id) do
      nil ->
        {:error, :credential_not_owned}

      row ->
        with :ok <- assert_user_handle(user, Map.get(assertion, :user_handle)),
             :ok <- maybe_warn_on_rp_id_drift(config, row, credential_id),
             {:ok, auth_data} <- do_authenticate(row, assertion) do
          {:ok, row, auth_data}
        end
    end
  end

  @spec handle_sign_count(non_neg_integer(), non_neg_integer(), SignCountPolicy.policy(), map()) ::
          :ok | {:regression, SignCountPolicy.policy(), map()}
  def handle_sign_count(stored, presented, policy, metadata \\ %{}) do
    case SignCountPolicy.evaluate(stored, presented, policy) do
      :ok -> :ok
      {:regression, mode} -> {:regression, mode, Map.put(metadata, :policy_applied, mode)}
    end
  end

  defp assert_user_handle(_user, nil), do: :ok

  defp assert_user_handle(user, user_handle) do
    if to_string(user_handle) == to_string(user.id) do
      :ok
    else
      {:error, :credential_not_owned}
    end
  end

  defp maybe_warn_on_rp_id_drift(config, row, credential_id) do
    current_rp_id = config.passkeys[:rp_id]

    if row.rp_id && current_rp_id && row.rp_id != current_rp_id do
      Logger.warning(
        "passkey rp_id drift: stored=#{inspect(row.rp_id)} current=#{inspect(current_rp_id)} credential_id=#{Base.url_encode64(credential_id, padding: false)}"
      )
    end

    :ok
  end

  defp do_authenticate(row, assertion) do
    credentials = [{row.credential_id, CoseKey.deserialize(row.public_key)}]

    case Wax.authenticate(
           row.credential_id,
           Map.fetch!(assertion, :authenticator_data),
           Map.fetch!(assertion, :signature),
           Map.fetch!(assertion, :client_data_json),
           Map.fetch!(assertion, :challenge),
           credentials
         ) do
      {:ok, auth_data} -> {:ok, auth_data}
      {:error, reason} -> {:error, reason}
    end
  end
end
