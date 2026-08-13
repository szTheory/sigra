defmodule Sigra.AppLogin.PKCE do
  @moduledoc false

  @verifier ~r/\A[A-Za-z0-9\-._~]{43,128}\z/
  @challenge ~r/\A[A-Za-z0-9_-]{43,128}\z/

  def challenge(verifier) when is_binary(verifier) do
    if valid_verifier?(verifier),
      do: verifier |> then(&:crypto.hash(:sha256, &1)) |> Base.url_encode64(padding: false)
  end

  def challenge(_), do: nil
  def valid_verifier?(value) when is_binary(value), do: Regex.match?(@verifier, value)
  def valid_verifier?(_), do: false
  def valid_challenge?(value) when is_binary(value), do: Regex.match?(@challenge, value)
  def valid_challenge?(_), do: false
end
