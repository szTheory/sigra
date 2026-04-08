defmodule Sigra.JWT.SignerTest do
  use ExUnit.Case, async: true

  alias Sigra.JWT.Signer

  defp config(overrides \\ []) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      secret_key_base: String.duplicate("a", 64),
      jwt: [
        enabled: true,
        algorithm: "HS256"
      ]
    ]

    Sigra.Config.new!(Keyword.merge(base, overrides))
  end

  describe "ensure_joken!/0" do
    test "returns :ok when Joken is loaded" do
      assert :ok = Signer.ensure_joken!()
    end
  end

  describe "create_signer/1 with HS256" do
    test "returns a Joken.Signer struct" do
      signer = Signer.create_signer(config())
      assert %Joken.Signer{} = signer
    end

    test "derives key from secret_key_base using HMAC-SHA256 with salt" do
      cfg = config()
      signer = Signer.create_signer(cfg)

      # Verify the signer uses HS256 algorithm
      assert %Joken.Signer{jws: %JOSE.JWS{alg: {:jose_jws_alg_hmac, :HS256}}} = signer

      # Verify deterministic key derivation: same config produces same signer
      signer2 = Signer.create_signer(cfg)
      assert signer.jwk == signer2.jwk

      # Different secret_key_base produces different signer
      cfg2 = config(secret_key_base: String.duplicate("b", 64))
      signer3 = Signer.create_signer(cfg2)
      refute signer.jwk == signer3.jwk
    end

    test "raises when secret_key_base is nil" do
      assert_raise RuntimeError, ~r/secret_key_base is required/, fn ->
        Signer.create_signer(config(secret_key_base: nil))
      end
    end
  end

  describe "create_signer/1 with RS256" do
    test "returns a Joken.Signer struct with PEM key" do
      # Generate an RSA key for testing
      rsa_key = :public_key.generate_key({:rsa, 2048, 65537})
      pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, rsa_key)])

      cfg = config(jwt: [enabled: true, algorithm: "RS256", private_key: pem])
      signer = Signer.create_signer(cfg)

      assert %Joken.Signer{} = signer
    end
  end
end
