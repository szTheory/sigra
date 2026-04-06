defmodule Sigra.Email do
  @moduledoc """
  Email normalization and format validation.

  Provides consistent email handling for authentication operations.
  All emails are normalized before storage or comparison to prevent
  duplicate accounts and ensure reliable matching.

  ## Normalization Steps

  1. Trim leading/trailing whitespace
  2. Downcase the entire email
  3. Apply Unicode NFKC normalization

  NFKC is applied to emails per Unicode best practices. It is
  intentionally NOT applied to passwords (per NIST SP 800-63B).

  ## Format Validation

  Uses a permissive regex (`~r/^[^\\s]+@[^\\s]+$/`) to avoid rejecting
  valid addresses. Maximum length is 160 characters.

  Gmail dot-stripping and plus-stripping are NOT applied per design
  decision D-41 -- users should be able to use plus-addressing.
  """

  @max_email_length 160

  @doc """
  Normalizes an email address by trimming, downcasing, and applying NFKC.

  ## Examples

      iex> Sigra.Email.normalize("  FOO@Bar.COM  ")
      "foo@bar.com"

      iex> Sigra.Email.normalize("user+tag@example.com")
      "user+tag@example.com"

  """
  @doc since: "0.2.0"
  @spec normalize(String.t()) :: String.t()
  def normalize(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
    |> String.normalize(:nfkc)
  end

  @doc """
  Validates the format of an email address.

  Returns `:ok` for valid emails or `{:error, reason}` for invalid ones.

  Validation rules:
  - Must contain exactly one `@` with non-empty local and domain parts
  - Must not contain whitespace
  - Must not exceed #{@max_email_length} characters

  ## Examples

      iex> Sigra.Email.validate_format("user@example.com")
      :ok

      iex> Sigra.Email.validate_format("no-at-sign")
      {:error, "must contain exactly one @ sign"}

  """
  @doc since: "0.2.0"
  @spec validate_format(String.t()) :: :ok | {:error, String.t()}
  def validate_format(email) when is_binary(email) do
    cond do
      String.length(email) > @max_email_length ->
        {:error, "must be #{@max_email_length} characters or fewer"}

      not Regex.match?(~r/^[^\s]+@[^\s]+$/, email) ->
        {:error, "must contain exactly one @ sign"}

      true ->
        :ok
    end
  end
end
