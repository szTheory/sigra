defmodule Example.Demo.PersonasTest do
  @moduledoc """
  Pure-data assertions for the demo persona catalog.

  Covers the domain-segregation invariant (SEED-05 half) and the password /
  deterministic-secret security posture (SEED-06). No DB access required.
  """
  use ExUnit.Case, async: true

  alias Example.Demo.Personas

  @expected_handles ~w(admin alice bob carol dave frank morgan pat grace zoe)
  @personas_source Path.expand("../../../lib/example/demo/personas.ex", __DIR__)

  describe "all/0 catalog shape" do
    test "returns exactly ten personas with the expected handles" do
      personas = Personas.all()

      assert length(personas) == 10

      handles =
        personas
        |> Enum.map(fn %{email: email} -> email |> String.split("@") |> hd() end)
        |> Enum.sort()

      assert handles == Enum.sort(@expected_handles)
    end

    test "every persona has a non-nil display_name and password" do
      for persona <- Personas.all() do
        assert is_binary(persona.display_name) and persona.display_name != "",
               "expected non-empty display_name for #{persona.email}"

        assert is_binary(persona.password) and persona.password != "",
               "expected non-empty password for #{persona.email}"
      end
    end
  end

  describe "domain segregation (SEED-05)" do
    test "every persona email ends with the demo domain" do
      demo_domain = "@" <> Personas.demo_domain()

      for persona <- Personas.all() do
        assert String.ends_with?(persona.email, demo_domain),
               "#{persona.email} must end with #{demo_domain}"
      end
    end

    test "no persona email contains the CI golden-path domain" do
      for persona <- Personas.all() do
        refute String.contains?(persona.email, "@example.test"),
               "#{persona.email} must not use the @example.test CI fixture domain"
      end
    end
  end

  describe "password policy (SEED-06)" do
    test "every persona password satisfies Sigra.PasswordPolicy" do
      # Sigra.PasswordPolicy.validate/2 operates on an Ecto changeset and only
      # inspects the :password CHANGE. Build a minimal schemaless changeset per
      # persona and assert there is no :password error.
      for persona <- Personas.all() do
        changeset =
          {%{}, %{password: :string}}
          |> Ecto.Changeset.cast(%{password: persona.password}, [:password])
          |> Sigra.PasswordPolicy.validate()

        password_errors = Keyword.get_values(changeset.errors, :password)

        assert password_errors == [],
               "password for #{persona.email} failed policy: #{inspect(password_errors)}"

        assert changeset.valid?,
               "expected valid changeset for #{persona.email}, got #{inspect(changeset.errors)}"
      end
    end
  end

  describe "deterministic demo TOTP secret (SEED-06)" do
    test "demo_totp_secret/0 equals the documented derivation and is 20 bytes" do
      expected = :crypto.hash(:sha256, "sigra-demo-admin-totp-v1") |> binary_part(0, 20)

      secret = Personas.demo_totp_secret()

      assert secret == expected
      assert byte_size(secret) == 20
    end

    test "demo_totp_secret/0 is deterministic across calls" do
      assert Personas.demo_totp_secret() == Personas.demo_totp_secret()
    end
  end

  describe "production-safety label (SEED-06)" do
    test "personas.ex source carries the demo-only warning comment" do
      source = File.read!(@personas_source)

      assert String.contains?(
               source,
               "# Demo-only — intentionally deterministic. Never use in production."
             )
    end
  end
end
