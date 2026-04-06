defmodule Sigra.PasswordPolicy.CommonPasswords do
  @moduledoc """
  Compile-time embedded common password list for rejection checking.

  Embeds ~10,000 common passwords from `priv/data/common_passwords.txt`
  into a `MapSet` at compile time. The file is registered as an
  `@external_resource` so the module recompiles when the list changes.

  ## Usage

      Sigra.PasswordPolicy.CommonPasswords.common?("password")
      #=> true

      Sigra.PasswordPolicy.CommonPasswords.common?("xK9#mP2$vL5")
      #=> false

  Lookups are case-insensitive.
  """

  @external_resource Path.join([__DIR__, "..", "..", "..", "priv", "data", "common_passwords.txt"])

  @passwords @external_resource
             |> File.read!()
             |> String.split("\n", trim: true)
             |> MapSet.new()

  @doc """
  Returns `true` if the given password is in the common passwords list.

  The check is case-insensitive: `"PASSWORD"` matches `"password"`.
  """
  @doc since: "0.2.0"
  @spec common?(String.t()) :: boolean()
  def common?(password) when is_binary(password) do
    MapSet.member?(@passwords, String.downcase(password))
  end
end
