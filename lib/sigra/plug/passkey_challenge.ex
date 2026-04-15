defmodule Sigra.Plug.PasskeyChallenge do
  @moduledoc """
  Plug-edge session adapter for passkey ceremony challenges.

  Challenges are stored as signed tokens in ceremony-specific Plug session
  slots. Verification rebuilds the server-authoritative `Wax.Challenge`
  from the signed session payload and only clears the slot after a
  successful callback result.
  """

  alias Sigra.Passkeys.{Authentication, Registration}

  @registration_slot "sigra_passkey_registration_challenge"
  @authentication_slot "sigra_passkey_authentication_challenge"
  @purpose "sigra-passkey-challenge"
  @max_age 60

  @type ceremony :: :registration | :authentication
  @type verifier :: (Wax.Challenge.t() -> {:ok, term()} | {:error, term()})

  @spec issue(Plug.Conn.t(), ceremony(), Sigra.Config.t(), keyword()) ::
          {Plug.Conn.t(), Wax.Challenge.t()}
  def issue(%Plug.Conn{} = conn, ceremony, %Sigra.Config{} = config, opts \\ []) do
    challenge = build_challenge(ceremony, config, opts)

    payload = %{
      "c" => Base.url_encode64(challenge.bytes, padding: false)
    }

    token = Sigra.Token.generate(config.secret_key_base, @purpose, payload, max_age: @max_age)

    updated_conn =
      Plug.Conn.put_session(conn, slot_for!(ceremony), %{
        "token" => token
      })

    {updated_conn, challenge}
  end

  @spec verify(Plug.Conn.t(), ceremony(), Sigra.Config.t(), keyword(), verifier()) ::
          {:ok, Plug.Conn.t(), term()} | {:error, Plug.Conn.t(), term()}
  def verify(%Plug.Conn{} = conn, ceremony, %Sigra.Config{} = config, opts \\ [], callback)
      when is_function(callback, 1) do
    slot = slot_for!(ceremony)

    with {:ok, session_value} <- fetch_slot(conn, slot),
         {:ok, token} <- fetch_token(session_value),
         {:ok, payload} <- Sigra.Token.verify(config.secret_key_base, @purpose, token, max_age: @max_age),
         {:ok, challenge_bytes} <- decode_challenge_bytes(payload) do
      challenge = build_challenge(ceremony, config, Keyword.put(opts, :bytes, challenge_bytes))

      case callback.(challenge) do
        {:ok, result} ->
          {:ok, Plug.Conn.delete_session(conn, slot), result}

        {:error, reason} ->
          {:error, conn, reason}
      end
    else
      {:error, reason} -> {:error, conn, reason}
    end
  end

  defp build_challenge(:registration, config, opts), do: Registration.new_challenge(config, opts)
  defp build_challenge(:authentication, config, opts), do: Authentication.new_challenge(config, opts)

  defp fetch_slot(conn, slot) do
    case Plug.Conn.get_session(conn, slot) do
      nil -> {:error, :missing_challenge}
      %{} = session_value -> {:ok, session_value}
      _other -> {:error, :invalid}
    end
  end

  defp fetch_token(%{"token" => token}) when is_binary(token), do: {:ok, token}
  defp fetch_token(_session_value), do: {:error, :invalid}

  defp decode_challenge_bytes(%{"c" => encoded}) when is_binary(encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, :invalid}
    end
  end

  defp decode_challenge_bytes(_payload), do: {:error, :invalid}

  defp slot_for!(:registration), do: @registration_slot
  defp slot_for!(:authentication), do: @authentication_slot
  defp slot_for!(other), do: raise(ArgumentError, "unsupported passkey ceremony: #{inspect(other)}")
end
