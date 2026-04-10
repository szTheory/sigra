defmodule Example.Accounts.Encrypted.Binary do
  @moduledoc """
  Test-only passthrough Ecto type standing in for a cloak_ecto encrypted binary.

  The generated Sigra templates reference `Example.Accounts.Encrypted.Binary` for
  at-rest encryption of MFA secrets and OAuth tokens. The installer does not
  currently generate a real cloak_ecto vault. For the committed example app
  (plan 10-06), we provide a passthrough type so compilation and the test-suite
  smoke flows work end-to-end. A production app MUST replace this with a real
  `Cloak.Ecto.Binary` subtype backed by a `Cloak.Vault`.
  """
  use Ecto.Type

  @impl true
  def type, do: :binary

  @impl true
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(nil), do: {:ok, nil}
  def dump(_), do: :error

  @impl true
  def load(value) when is_binary(value), do: {:ok, value}
  def load(nil), do: {:ok, nil}
  def load(_), do: :error
end
