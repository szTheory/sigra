defmodule Sigra.JWT.Validator do
  @moduledoc false

  @required_claims ["iss", "aud", "sub", "iat", "exp", "jti"]

  @spec verify_and_validate(String.t(), Joken.Signer.t(), Sigra.Config.t()) ::
          {:ok, map()} | {:error, :invalid_token}
  def verify_and_validate(jwt, signer, config) when is_binary(jwt) do
    with {:ok, claims} <-
           Joken.verify_and_validate(
             %{},
             jwt,
             signer,
             nil,
             [{Joken.Hooks.RequiredClaims, @required_claims}]
           ),
         :ok <- validate_payload(claims, config),
         :ok <- validate_protected_typ(jwt, config.jwt) do
      {:ok, claims}
    else
      _ -> {:error, :invalid_token}
    end
  rescue
    _ -> {:error, :invalid_token}
  end

  def verify_and_validate(_, _, _), do: {:error, :invalid_token}

  defp validate_payload(claims, config) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    jwt_config = config.jwt
    issuer = Keyword.get(jwt_config, :issuer) || to_string(config.otp_app)

    with true <- is_binary(claims["iss"]) and claims["iss"] == issuer,
         true <- valid_audience?(claims["aud"], Keyword.fetch!(jwt_config, :audience)),
         true <- non_empty_binary?(claims["sub"]),
         true <- is_integer(claims["iat"]),
         true <- is_integer(claims["exp"]) and claims["exp"] > now,
         true <- non_empty_binary?(claims["jti"]),
         :ok <- validate_not_before(claims["nbf"], now) do
      :ok
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp validate_protected_typ(jwt, jwt_config) do
    with {:ok, protected} <- Jason.decode(JOSE.JWS.peek_protected(jwt)),
         typ when is_binary(typ) <- protected["typ"],
         ^typ <- Keyword.fetch!(jwt_config, :typ) do
      :ok
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp valid_audience?(audience, configured) when is_binary(audience),
    do: audience in configured

  defp valid_audience?(audiences, configured) when is_list(audiences) and audiences != [],
    do: Enum.all?(audiences, &non_empty_binary?/1) and Enum.any?(audiences, &(&1 in configured))

  defp valid_audience?(_, _), do: false

  defp validate_not_before(nil, _now), do: :ok
  defp validate_not_before(nbf, now) when is_integer(nbf) and nbf <= now, do: :ok
  defp validate_not_before(_, _), do: {:error, :invalid_token}

  defp non_empty_binary?(value), do: is_binary(value) and byte_size(value) > 0
end
