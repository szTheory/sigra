defmodule Sigra.PasswordPolicyTest do
  use ExUnit.Case, async: true

  alias Sigra.PasswordPolicy
  alias Sigra.PasswordPolicy.CommonPasswords

  # Helper to build a changeset-like structure for testing
  defp changeset_with_password(password) do
    data = %{}
    types = %{password: :string}

    {data, types}
    |> Ecto.Changeset.cast(%{password: password}, [:password])
  end

  defp changeset_without_password do
    data = %{}
    types = %{password: :string}

    {data, types}
    |> Ecto.Changeset.cast(%{}, [:password])
  end

  describe "validate/2" do
    test "returns changeset unchanged when no password change" do
      changeset = changeset_without_password()

      result = PasswordPolicy.validate(changeset)

      assert result.valid?
    end

    test "rejects password shorter than min_length (default 8)" do
      changeset = changeset_with_password("xK9mP2v")

      result = PasswordPolicy.validate(changeset)

      refute result.valid?
      password_errors = Keyword.get_values(result.errors, :password)
      assert Enum.any?(password_errors, fn {msg, _} -> msg =~ "at least" end)
    end

    test "accepts password at exactly min_length" do
      changeset = changeset_with_password("12345678")

      result = PasswordPolicy.validate(changeset)

      # Should pass min_length check (may fail common password check)
      min_length_errors =
        Keyword.get_values(result.errors, :password)
        |> Enum.filter(fn {msg, _} -> msg =~ "at least" end)

      assert min_length_errors == []
    end

    test "rejects password over max bytes (72)" do
      long_password = String.duplicate("a", 73)
      changeset = changeset_with_password(long_password)

      result = PasswordPolicy.validate(changeset)

      refute result.valid?
      password_errors = Keyword.get_values(result.errors, :password)
      assert Enum.any?(password_errors, fn {msg, _} -> msg =~ "byte" end)
    end

    test "rejects common password when check_common is true (default)" do
      changeset = changeset_with_password("password")

      result = PasswordPolicy.validate(changeset)

      refute result.valid?
      password_errors = Keyword.get_values(result.errors, :password)
      assert Enum.any?(password_errors, fn {msg, _} -> msg =~ "too common" end)
    end

    test "allows common password when check_common is false" do
      changeset = changeset_with_password("password1234")

      result = PasswordPolicy.validate(changeset, check_common: false)

      # Should pass without common password error (still meets length)
      password_errors = Keyword.get_values(result.errors, :password)
      refute Enum.any?(password_errors, fn {msg, _} -> msg =~ "too common" end)
    end

    test "rejects when require_uppercase is true and no uppercase" do
      changeset = changeset_with_password("alllowercase1!")

      result = PasswordPolicy.validate(changeset, require_uppercase: true, check_common: false)

      refute result.valid?
      password_errors = Keyword.get_values(result.errors, :password)
      assert Enum.any?(password_errors, fn {msg, _} -> msg =~ "uppercase" end)
    end

    test "accepts when require_uppercase is true and has uppercase" do
      changeset = changeset_with_password("Alllowercase1!")

      result = PasswordPolicy.validate(changeset, require_uppercase: true, check_common: false)

      password_errors = Keyword.get_values(result.errors, :password)
      refute Enum.any?(password_errors, fn {msg, _} -> msg =~ "uppercase" end)
    end

    test "rejects when require_digit is true and no digit" do
      changeset = changeset_with_password("NoDigitsHere!!")

      result = PasswordPolicy.validate(changeset, require_digit: true, check_common: false)

      refute result.valid?
      password_errors = Keyword.get_values(result.errors, :password)
      assert Enum.any?(password_errors, fn {msg, _} -> msg =~ "digit" end)
    end

    test "rejects when require_special is true and no special char" do
      changeset = changeset_with_password("NoSpecialHere1")

      result = PasswordPolicy.validate(changeset, require_special: true, check_common: false)

      refute result.valid?
      password_errors = Keyword.get_values(result.errors, :password)
      assert Enum.any?(password_errors, fn {msg, _} -> msg =~ "special" end)
    end

    test "accepts custom min_length" do
      changeset = changeset_with_password("1234567890")

      result = PasswordPolicy.validate(changeset, min_length: 10, check_common: false)

      min_length_errors =
        Keyword.get_values(result.errors, :password)
        |> Enum.filter(fn {msg, _} -> msg =~ "at least" end)

      assert min_length_errors == []
    end
  end

  describe "check_strength/1" do
    test "short password is weak" do
      {strength, suggestions} = PasswordPolicy.check_strength("ab")

      assert strength == :weak
      assert is_list(suggestions)
      assert Enum.any?(suggestions, &(&1 =~ "length" or &1 =~ "longer"))
    end

    test "long diverse password is strong" do
      {strength, _suggestions} = PasswordPolicy.check_strength("correcthorsebatterystaple")

      assert strength == :strong
    end

    test "repeated characters are weak" do
      {strength, suggestions} = PasswordPolicy.check_strength("aaaaaaaaaa")

      assert strength == :weak
      assert is_list(suggestions)
      assert Enum.any?(suggestions, &(&1 =~ "repeat"))
    end

    test "sequential/common password is weak" do
      {strength, suggestions} = PasswordPolicy.check_strength("12345678")

      assert strength == :weak
      assert is_list(suggestions)
    end

    test "medium complexity is fair" do
      # 8 chars (2pts) + mixed case (1pt) + no digits (0) + no special (0) = 3 = fair
      {strength, _} = PasswordPolicy.check_strength("Helloabc")

      assert strength == :fair
    end
  end

  describe "CommonPasswords.common?/1" do
    test "detects 'password' as common" do
      assert CommonPasswords.common?("password") == true
    end

    test "detects uncommon password as not common" do
      assert CommonPasswords.common?("xK9#mP2$vL5") == false
    end

    test "is case-insensitive" do
      assert CommonPasswords.common?("PASSWORD") == true
    end

    test "detects '123456' as common" do
      assert CommonPasswords.common?("123456") == true
    end

    test "detects 'qwerty' as common" do
      assert CommonPasswords.common?("qwerty") == true
    end
  end
end
