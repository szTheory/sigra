defmodule SigraInstallGoldenTmp.Accounts.Encrypted.Binary do
  @moduledoc """
  PASSTHROUGH STUB — REPLACE IN PRODUCTION.

  This is a development-only Ecto.Type that stores values in plaintext.
  Production apps MUST replace this with a Cloak.Vault-backed type. See
  https://hexdocs.pm/cloak_ecto for setup.

  The generated Sigra schemas (`SigraInstallGoldenTmp.Accounts.UserMFACredential`,
  `SigraInstallGoldenTmp.Accounts.UserApiToken`) reference `SigraInstallGoldenTmp.Accounts.Encrypted.Binary`
  for at-rest encryption of MFA secrets and OAuth/API tokens. Until you
  wire a real `Cloak.Ecto.Binary` subtype backed by a `Cloak.Vault`, these
  values are stored as plaintext — do not ship this stub to production.
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
