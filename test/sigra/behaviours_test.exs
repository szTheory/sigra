defmodule Sigra.BehavioursTest do
  use ExUnit.Case, async: true

  describe "Sigra.Hasher behaviour" do
    test "defines hash_password/1 callback" do
      callbacks = Sigra.Hasher.behaviour_info(:callbacks)

      assert {:hash_password, 1} in callbacks
    end

    test "defines verify_password/2 callback" do
      callbacks = Sigra.Hasher.behaviour_info(:callbacks)

      assert {:verify_password, 2} in callbacks
    end

    test "defines no_user_verify/0 callback" do
      callbacks = Sigra.Hasher.behaviour_info(:callbacks)

      assert {:no_user_verify, 0} in callbacks
    end
  end

  describe "Sigra.Hashers.Argon2 implementation" do
    test "implements @behaviour Sigra.Hasher" do
      behaviours =
        Sigra.Hashers.Argon2.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Sigra.Hasher in behaviours
    end

    test "hash_password/1 produces Argon2id hash" do
      hash = Sigra.Hashers.Argon2.hash_password("test_password")

      assert String.starts_with?(hash, "$argon2id$")
    end

    test "verify_password/2 verifies correctly" do
      hash = Sigra.Hashers.Argon2.hash_password("test_password")

      assert Sigra.Hashers.Argon2.verify_password("test_password", hash) == true
      assert Sigra.Hashers.Argon2.verify_password("wrong", hash) == false
    end

    test "no_user_verify/0 returns :ok" do
      assert Sigra.Hashers.Argon2.no_user_verify() == :ok
    end
  end

  describe "Sigra.Mailer behaviour" do
    test "defines deliver/3 callback" do
      callbacks = Sigra.Mailer.behaviour_info(:callbacks)

      assert {:deliver, 3} in callbacks
    end
  end

  describe "Sigra.SessionStore behaviour" do
    test "defines fetch/2 callback" do
      callbacks = Sigra.SessionStore.behaviour_info(:callbacks)

      assert {:fetch, 2} in callbacks
    end

    test "defines create/3 callback" do
      callbacks = Sigra.SessionStore.behaviour_info(:callbacks)

      assert {:create, 3} in callbacks
    end

    test "defines delete/2 callback" do
      callbacks = Sigra.SessionStore.behaviour_info(:callbacks)

      assert {:delete, 2} in callbacks
    end
  end

  describe "Sigra.RateLimiter behaviour" do
    test "defines check_rate/3 callback" do
      callbacks = Sigra.RateLimiter.behaviour_info(:callbacks)

      assert {:check_rate, 3} in callbacks
    end
  end

  describe "Sigra.RateLimiters.Noop" do
    test "implements @behaviour Sigra.RateLimiter" do
      behaviours =
        Sigra.RateLimiters.Noop.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Sigra.RateLimiter in behaviours
    end

    test "check_rate/3 always returns {:allow, 1}" do
      assert Sigra.RateLimiters.Noop.check_rate("key", 10, 60_000) == {:allow, 1}
      assert Sigra.RateLimiters.Noop.check_rate("other", 1, 1) == {:allow, 1}
    end
  end

  describe "Sigra.Testing" do
    test "assert_password_hashed/1 passes for Argon2id hash" do
      user = %{hashed_password: Sigra.Crypto.hash_password("password")}

      assert Sigra.Testing.assert_password_hashed(user) == true
    end

    test "assert_password_hashed/1 raises for non-Argon2id hash" do
      user = %{hashed_password: "plaintext"}

      assert_raise ExUnit.AssertionError, fn ->
        Sigra.Testing.assert_password_hashed(user)
      end
    end

    test "assert_session_created/1 is a stub that returns true" do
      assert Sigra.Testing.assert_session_created(%{}) == true
    end

    test "assert_token_sent/2 delegates to Swoosh assertions" do
      assert_raise ExUnit.AssertionError, fn ->
        Sigra.Testing.assert_token_sent("user@example.com", :confirm)
      end
    end

    test "with_test_mailer/1 executes the given function" do
      result = Sigra.Testing.with_test_mailer(fn -> :executed end)

      assert result == :executed
    end
  end
end
