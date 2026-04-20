defmodule Sigra.PasswordPolicy do
  @moduledoc """
  NIST-compliant password validation and strength analysis.

  Validates passwords against configurable policy rules and provides
  strength assessment for UI feedback. Follows NIST SP 800-63B guidelines:

  - Minimum 8 characters (configurable)
  - Maximum 72 bytes (bcrypt compatibility)
  - Common password rejection via embedded 10k list
  - Optional composition rules (uppercase, digit, special char)
  - Optional HIBP breached password check

  ## Usage with Ecto Changesets

      changeset
      |> Sigra.PasswordPolicy.validate()

      changeset
      |> Sigra.PasswordPolicy.validate(min_length: 12, require_uppercase: true)

  ## Strength Assessment

      Sigra.PasswordPolicy.check_strength("correcthorsebatterystaple")
      #=> {:strong, []}

      Sigra.PasswordPolicy.check_strength("abc")
      #=> {:weak, ["Use a longer password (at least 8 characters)"]}

  """

  import Ecto.Changeset

  alias Sigra.PasswordPolicy.CommonPasswords

  @default_opts [
    min_length: 8,
    max_bytes: 72,
    require_uppercase: false,
    require_digit: false,
    require_special: false,
    check_common: true,
    check_breached: false,
    password_max_age: nil
  ]

  @doc """
  Validates a password field on an Ecto changeset against the configured policy.

  If the changeset has no `:password` change, returns the changeset unchanged.

  ## Options

  All options from `@default_opts` can be overridden:

  - `:min_length` - Minimum password length (default: 8)
  - `:max_bytes` - Maximum password byte size (default: 72)
  - `:require_uppercase` - Require at least one uppercase letter (default: false)
  - `:require_digit` - Require at least one digit (default: false)
  - `:require_special` - Require at least one special character (default: false)
  - `:check_common` - Check against common passwords list (default: true)
  - `:check_breached` - Check against HIBP API (default: false)

  ## Examples

      changeset |> Sigra.PasswordPolicy.validate()
      changeset |> Sigra.PasswordPolicy.validate(min_length: 12)

  """
  @doc since: "0.2.0"
  @spec validate(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  def validate(changeset, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> validate_min_length(password, opts[:min_length])
        |> validate_max_bytes(password, opts[:max_bytes])
        |> validate_composition(password, opts)
        |> validate_common(password, opts[:check_common])
    end
  end

  @doc """
  Assesses password strength for UI feedback.

  Returns `{strength, suggestions}` where `strength` is `:weak`, `:fair`,
  or `:strong`, and `suggestions` is a list of improvement hints.

  ## Scoring

  - Length: 0-4 chars = 0pts, 5-7 = 1pt, 8-11 = 2pts, 12-15 = 3pts, 16+ = 4pts
  - +1 for mixed case
  - +1 for digits
  - +1 for special characters
  - -2 for common password
  - -1 for >3 repeated consecutive characters
  - -1 for >3 sequential characters

  Thresholds: 0-2 = :weak, 3-4 = :fair, 5+ = :strong

  ## Examples

      iex> Sigra.PasswordPolicy.check_strength("correcthorsebatterystaple")
      {:strong, []}

  """
  @doc since: "0.2.0"
  @spec check_strength(String.t()) :: {:weak | :fair | :strong, [String.t()]}
  def check_strength(password) when is_binary(password) do
    {score, suggestions} = assess(password)

    strength =
      cond do
        score >= 4 -> :strong
        score >= 3 -> :fair
        true -> :weak
      end

    {strength, suggestions}
  end

  @doc """
  Checks if a password has been found in data breaches via the HIBP API.

  Uses the k-Anonymity model: only the first 5 characters of the SHA-1 hash
  are sent to the API, so the full password hash is never transmitted.

  Returns `{:ok, count}` where count is the number of times the password
  appeared in breaches, or `{:error, reason}` on failure.

  Off by default -- must be explicitly enabled.

  ## Examples

      Sigra.PasswordPolicy.check_breached("password")
      #=> {:ok, 3861493}

      Sigra.PasswordPolicy.check_breached("xK9#mP2$vL5")
      #=> {:ok, 0}

  """
  @doc since: "0.2.0"
  @spec check_breached(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def check_breached(password) when is_binary(password) do
    hash = :crypto.hash(:sha, password) |> Base.encode16()
    prefix = String.slice(hash, 0, 5)
    suffix = String.slice(hash, 5, String.length(hash))

    url = ~c"https://api.pwnedpasswords.com/range/#{prefix}"

    case :httpc.request(:get, {url, []}, [{:timeout, 5000}], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        count =
          body
          |> List.to_string()
          |> String.split("\r\n", trim: true)
          |> Enum.find_value(0, fn line ->
            case String.split(line, ":", parts: 2) do
              [hash_suffix, count] ->
                if String.upcase(hash_suffix) == suffix do
                  String.trim(count) |> String.to_integer()
                end

              _ ->
                nil
            end
          end)

        {:ok, count}

      {:ok, {{_, status, _}, _, _}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- Private helpers --

  defp validate_min_length(changeset, password, min_length) do
    if String.length(password) < min_length do
      add_error(changeset, :password, "should be at least %{count} character(s)",
        count: min_length,
        validation: :length,
        kind: :min,
        type: :string
      )
    else
      changeset
    end
  end

  defp validate_max_bytes(changeset, password, max_bytes) do
    if byte_size(password) > max_bytes do
      add_error(changeset, :password, "should be at most %{count} byte(s)",
        count: max_bytes,
        validation: :byte_size
      )
    else
      changeset
    end
  end

  defp validate_composition(changeset, password, opts) do
    changeset
    |> maybe_require(
      :uppercase,
      password,
      opts[:require_uppercase],
      ~r/[A-Z]/,
      "must contain at least one uppercase letter"
    )
    |> maybe_require(
      :digit,
      password,
      opts[:require_digit],
      ~r/[0-9]/,
      "must contain at least one digit"
    )
    |> maybe_require(
      :special,
      password,
      opts[:require_special],
      ~r/[^a-zA-Z0-9]/,
      "must contain at least one special character"
    )
  end

  defp maybe_require(changeset, _rule, _password, false, _regex, _message), do: changeset

  defp maybe_require(changeset, _rule, password, true, regex, message) do
    if Regex.match?(regex, password) do
      changeset
    else
      add_error(changeset, :password, message, validation: :format)
    end
  end

  defp validate_common(changeset, password, true) do
    if CommonPasswords.common?(password) do
      add_error(changeset, :password, "is too common", validation: :exclusion)
    else
      changeset
    end
  end

  defp validate_common(changeset, _password, false), do: changeset

  # -- Strength assessment --

  defp assess(password) do
    len = String.length(password)
    suggestions = []

    # Length score
    {length_score, suggestions} =
      cond do
        len >= 16 -> {4, suggestions}
        len >= 12 -> {3, suggestions}
        len >= 8 -> {2, suggestions}
        len >= 5 -> {1, ["Use a longer password (at least 8 characters)" | suggestions]}
        true -> {0, ["Use a longer password (at least 8 characters)" | suggestions]}
      end

    # Mixed case
    {case_score, suggestions} =
      if Regex.match?(~r/[a-z]/, password) and Regex.match?(~r/[A-Z]/, password) do
        {1, suggestions}
      else
        {0, ["Add a mix of uppercase and lowercase letters" | suggestions]}
      end

    # Digits
    {digit_score, suggestions} =
      if Regex.match?(~r/[0-9]/, password) do
        {1, suggestions}
      else
        {0, ["Add some numbers" | suggestions]}
      end

    # Special chars
    {special_score, suggestions} =
      if Regex.match?(~r/[^a-zA-Z0-9]/, password) do
        {1, suggestions}
      else
        {0, ["Add special characters (!@#$%)" | suggestions]}
      end

    # Common password penalty
    {common_penalty, suggestions} =
      if CommonPasswords.common?(password) do
        {-2, ["Avoid commonly used passwords" | suggestions]}
      else
        {0, suggestions}
      end

    # Repeated chars penalty
    {repeat_penalty, suggestions} =
      if has_repeated_chars?(password) do
        {-1, ["Avoid repeated characters" | suggestions]}
      else
        {0, suggestions}
      end

    # Sequential chars penalty
    {seq_penalty, suggestions} =
      if has_sequential_chars?(password) do
        {-1, ["Avoid sequential characters" | suggestions]}
      else
        {0, suggestions}
      end

    total =
      length_score + case_score + digit_score + special_score +
        common_penalty + repeat_penalty + seq_penalty

    # Only include suggestions relevant to the strength level
    suggestions =
      if total >= 4 do
        []
      else
        Enum.reverse(suggestions)
      end

    {total, suggestions}
  end

  defp has_repeated_chars?(password) do
    password
    |> String.graphemes()
    |> Enum.chunk_every(4, 1, :discard)
    |> Enum.any?(fn chunk ->
      chunk |> Enum.uniq() |> length() == 1
    end)
  end

  defp has_sequential_chars?(password) do
    codepoints = password |> String.to_charlist()

    codepoints
    |> Enum.chunk_every(4, 1, :discard)
    |> Enum.any?(fn [a, b, c, d] ->
      (b - a == 1 and c - b == 1 and d - c == 1) or
        (a - b == 1 and b - c == 1 and c - d == 1)
    end)
  end
end
