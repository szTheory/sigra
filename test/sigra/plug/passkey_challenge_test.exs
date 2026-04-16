defmodule Sigra.Plug.PasskeyChallengeTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Sigra.Plug.PasskeyChallenge

  @registration_slot "sigra_passkey_registration_challenge"
  @authentication_slot "sigra_passkey_authentication_challenge"
  @purpose "sigra-passkey-challenge"

  defmodule TestUser do
    defstruct [:id]
  end

  defp config(overrides \\ []) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: TestUser,
      secret_key_base: String.duplicate("abcdef0123456789", 4),
      passkeys: [
        rp_id: "example.com",
        origin: "https://example.com",
        user_verification: :preferred,
        attestation: :none,
        timeout_ms: 60_000
      ]
    ]

    Sigra.Config.new!(Keyword.merge(base, overrides))
  end

  defp session_conn do
    conn(:post, "/passkeys")
    |> init_test_session(%{})
    |> fetch_session()
  end

  defp challenge_token(conn, slot) do
    conn
    |> fetch_session()
    |> get_session(slot)
    |> Map.fetch!("token")
  end

  defp issue_both_slots(conn, cfg) do
    {conn, registration_challenge} =
      PasskeyChallenge.issue(conn, :registration, cfg, bytes: "registration-session-bytes")

    {conn, authentication_challenge} =
      PasskeyChallenge.issue(conn, :authentication, cfg, bytes: "authentication-session-bytes")

    {conn, registration_challenge, authentication_challenge}
  end

  describe "issue/4" do
    test "registration issue generates non-empty challenge bytes without explicit bytes" do
      conn = session_conn()
      cfg = config()

      {_issued_conn, challenge} = PasskeyChallenge.issue(conn, :registration, cfg)

      assert %Wax.Challenge{} = challenge
      assert is_binary(challenge.bytes)
      assert byte_size(challenge.bytes) >= 32
    end

    test "authentication issue signs generated challenge bytes into the session token" do
      conn = session_conn()
      cfg = config()

      {issued_conn, challenge} = PasskeyChallenge.issue(conn, :authentication, cfg)

      assert %Wax.Challenge{} = challenge
      assert is_binary(challenge.bytes)
      assert byte_size(challenge.bytes) >= 32

      assert {:ok, %{"c" => encoded_bytes}} =
               Sigra.Token.verify(
                 cfg.secret_key_base,
                 @purpose,
                 challenge_token(issued_conn, @authentication_slot), max_age: 60)

      assert Base.url_decode64(encoded_bytes, padding: false) == {:ok, challenge.bytes}
    end

    test "stores only the registration slot and returns a Wax.Challenge" do
      conn = session_conn()
      cfg = config()

      {issued_conn, challenge} =
        PasskeyChallenge.issue(conn, :registration, cfg, bytes: "registration-challenge")

      assert %Wax.Challenge{} = challenge
      assert challenge.bytes == "registration-challenge"

      assert get_session(issued_conn, @registration_slot) == %{
               "token" => challenge_token(issued_conn, @registration_slot)
             }

      assert get_session(issued_conn, @authentication_slot) == nil

      assert {:ok, %{"c" => encoded_bytes}} =
               Sigra.Token.verify(
                 cfg.secret_key_base,
                 @purpose,
                 challenge_token(issued_conn, @registration_slot), max_age: 60)

      assert Base.url_decode64(encoded_bytes, padding: false) == {:ok, "registration-challenge"}
    end

    test "explicit bytes remain respected for deterministic setup" do
      conn = session_conn()
      cfg = config()

      {_issued_conn, challenge} =
        PasskeyChallenge.issue(conn, :authentication, cfg, bytes: "deterministic-bytes")

      assert challenge.bytes == "deterministic-bytes"
    end

    test "stores only the authentication slot and returns a Wax.Challenge" do
      conn = session_conn()
      cfg = config()

      {issued_conn, challenge} =
        PasskeyChallenge.issue(conn, :authentication, cfg, bytes: "authentication-challenge")

      assert %Wax.Challenge{} = challenge
      assert challenge.bytes == "authentication-challenge"

      assert get_session(issued_conn, @authentication_slot) == %{
               "token" => challenge_token(issued_conn, @authentication_slot)
             }

      assert get_session(issued_conn, @registration_slot) == nil

      assert {:ok, %{"c" => encoded_bytes}} =
               Sigra.Token.verify(
                 cfg.secret_key_base,
                 @purpose,
                 challenge_token(issued_conn, @authentication_slot), max_age: 60)

      assert Base.url_decode64(encoded_bytes, padding: false) == {:ok, "authentication-challenge"}
    end
  end

  describe "verify/5" do
    test "passes the reconstructed server challenge to the callback and clears the matching slot on success" do
      cfg = config()

      {conn, _challenge} =
        PasskeyChallenge.issue(session_conn(), :registration, cfg,
          bytes: "server-registration-bytes"
        )

      client_supplied_bytes = "browser-registration-bytes"

      assert {:ok, verified_conn, :verified} =
               PasskeyChallenge.verify(conn, :registration, cfg, [], fn challenge ->
                 assert %Wax.Challenge{} = challenge
                 assert challenge.bytes == "server-registration-bytes"
                 refute challenge.bytes == client_supplied_bytes
                 {:ok, :verified}
               end)

      assert get_session(verified_conn, @registration_slot) == nil
    end

    test "returns an error and preserves the slot when the callback fails" do
      cfg = config()

      {conn, _challenge} =
        PasskeyChallenge.issue(session_conn(), :registration, cfg,
          bytes: "retryable-registration-bytes"
        )

      stored_session = get_session(conn, @registration_slot)

      assert {:error, verified_conn, :verification_failed} =
               PasskeyChallenge.verify(conn, :registration, cfg, [], fn challenge ->
                 assert challenge.bytes == "retryable-registration-bytes"
                 {:error, :verification_failed}
               end)

      assert get_session(verified_conn, @registration_slot) == stored_session
    end

    test "registration verification does not consume the authentication slot" do
      cfg = config()

      {conn, _registration_challenge, _authentication_challenge} =
        issue_both_slots(session_conn(), cfg)

      authentication_session = get_session(conn, @authentication_slot)

      assert {:ok, verified_conn, :registration_ok} =
               PasskeyChallenge.verify(conn, :registration, cfg, [], fn challenge ->
                 assert challenge.bytes == "registration-session-bytes"
                 {:ok, :registration_ok}
               end)

      assert get_session(verified_conn, @registration_slot) == nil
      assert get_session(verified_conn, @authentication_slot) == authentication_session
    end

    test "authentication verification does not consume the registration slot" do
      cfg = config()

      {conn, _registration_challenge, _authentication_challenge} =
        issue_both_slots(session_conn(), cfg)

      registration_session = get_session(conn, @registration_slot)

      assert {:ok, verified_conn, :authentication_ok} =
               PasskeyChallenge.verify(conn, :authentication, cfg, [], fn challenge ->
                 assert challenge.bytes == "authentication-session-bytes"
                 {:ok, :authentication_ok}
               end)

      assert get_session(verified_conn, @authentication_slot) == nil
      assert get_session(verified_conn, @registration_slot) == registration_session
    end

    test "returns an error before invoking the callback when the stored token is tampered" do
      cfg = config()

      {conn, _challenge} =
        PasskeyChallenge.issue(session_conn(), :authentication, cfg,
          bytes: "authentication-bytes"
        )

      token = challenge_token(conn, @authentication_slot)
      mid = div(byte_size(token), 2)
      <<prefix::binary-size(mid), byte, suffix::binary>> = token
      tampered = <<prefix::binary, Bitwise.bxor(byte, 0x01)::8, suffix::binary>>

      tampered_conn =
        conn
        |> put_session(@authentication_slot, %{"token" => tampered})
        |> fetch_session()

      assert {:error, verified_conn, :invalid} =
               PasskeyChallenge.verify(tampered_conn, :authentication, cfg, [], fn _challenge ->
                 send(self(), :tampered_callback_reached)
                 flunk("callback should not be invoked for tampered tokens")
               end)

      refute_received :tampered_callback_reached
      assert get_session(verified_conn, @authentication_slot) == %{"token" => tampered}
    end

    test "returns an error before invoking the callback when the stored token is expired" do
      cfg = config()

      expired =
        Sigra.Token.generate(
          cfg.secret_key_base,
          @purpose,
          %{"c" => Base.url_encode64("expired-registration-bytes", padding: false)},
          signed_at: System.os_time(:second) - 61
        )

      expired_conn =
        session_conn()
        |> put_session(@registration_slot, %{"token" => expired})
        |> fetch_session()

      assert {:error, verified_conn, :expired} =
               PasskeyChallenge.verify(expired_conn, :registration, cfg, [], fn _challenge ->
                 flunk("callback should not be invoked for expired tokens")
               end)

      assert get_session(verified_conn, @registration_slot) == %{"token" => expired}
    end
  end
end
