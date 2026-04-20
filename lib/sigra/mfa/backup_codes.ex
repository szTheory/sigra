defmodule Sigra.MFA.BackupCodes do
  @moduledoc """
  Backup code generation, hashing, and atomic consumption.

  Backup codes are single-use recovery codes displayed to the user during
  MFA enrollment. They are stored as SHA-256 hashes in the database and
  consumed atomically via `UPDATE ... WHERE used_at IS NULL`.

  ## Format

  Codes use XXXX-XXXX format (8 numeric digits, dash-separated).
  Verification strips dashes and spaces before hashing (D-12).

  ## Security Properties

  - Generated with `:crypto.strong_rand_bytes/1` (cryptographically secure)
  - Stored as SHA-256 hex hashes -- never retrievable after initial display (D-13, D-20)
  - Consumed atomically to prevent race conditions (D-16)
  - Hash-to-hash comparison in DB sidesteps timing attacks (Pitfall 5)
  """

  import Ecto.Query

  @doc """
  Generates a list of `{formatted_code, sha256_hex_hash}` tuples.

  Each code is an 8-digit number formatted as "XXXX-XXXX".
  The hash is the SHA-256 hex digest of the normalized (digits-only) code.

  ## Examples

      iex> codes = Sigra.MFA.BackupCodes.generate(8)
      iex> length(codes)
      8

  """
  @doc since: "0.6.0"
  @spec generate(pos_integer()) :: [{String.t(), String.t()}]
  def generate(count \\ 8) do
    Enum.map(1..count, fn _ ->
      raw_int = uniform_random(100_000_000)

      digits = raw_int |> Integer.to_string() |> String.pad_leading(8, "0")
      formatted = String.slice(digits, 0, 4) <> "-" <> String.slice(digits, 4, 4)
      hashed = :crypto.hash(:sha256, digits) |> Base.encode16(case: :lower)
      {formatted, hashed}
    end)
  end

  @doc """
  Normalizes a submitted code (strips dashes/spaces) and returns its SHA-256 hex hash.

  ## Examples

      iex> Sigra.MFA.BackupCodes.hash("1234-5678")
      Sigra.MFA.BackupCodes.hash("12345678")

  """
  @doc since: "0.6.0"
  @spec hash(String.t()) :: String.t()
  def hash(submitted_code) when is_binary(submitted_code) do
    normalized = String.replace(submitted_code, ~r/[\s\-]/, "")
    :crypto.hash(:sha256, normalized) |> Base.encode16(case: :lower)
  end

  @doc """
  Atomically consumes a backup code for the given user.

  Normalizes the submitted code, hashes it, and performs an atomic
  `UPDATE ... SET used_at = NOW() WHERE hashed_code = ? AND used_at IS NULL`.

  Returns `{:ok, :consumed}` if a matching unused code was found and consumed,
  or `{:error, :invalid_backup_code}` if no match.

  ## Parameters

  - `repo` - The Ecto repo module
  - `backup_code_schema` - The generated backup code Ecto schema module
  - `user_id` - The user's ID
  - `submitted_code` - The raw code submitted by the user
  """
  @doc since: "0.6.0"
  @spec consume(module(), module(), term(), String.t()) ::
          {:ok, :consumed} | {:error, :invalid_backup_code}
  def consume(repo, backup_code_schema, user_id, submitted_code) do
    hashed = hash(submitted_code)
    now = DateTime.utc_now()

    from(bc in backup_code_schema,
      where: bc.user_id == ^user_id and bc.hashed_code == ^hashed and is_nil(bc.used_at),
      update: [set: [used_at: ^now]]
    )
    |> repo.update_all([])
    |> case do
      {1, _} -> {:ok, :consumed}
      {0, _} -> {:error, :invalid_backup_code}
    end
  end

  @doc """
  Returns the count of unused backup codes for a user.
  """
  @doc since: "0.6.0"
  @spec remaining_count(module(), module(), term()) :: non_neg_integer()
  def remaining_count(repo, backup_code_schema, user_id) do
    from(bc in backup_code_schema,
      where: bc.user_id == ^user_id and is_nil(bc.used_at),
      select: count(bc.id)
    )
    |> repo.one()
  end

  @doc """
  Appends backup-code replacement steps (`delete_all` + `insert_all`) to an
  `Ecto.Multi`.

  Returns `{multi, formatted_codes}` so callers can wrap the operation in
  `repo.transaction/1` alongside other steps (for example audit rows).

  `now` defaults to `DateTime.utc_now/0` and is used for each row's
  `inserted_at`, matching `confirm_enrollment/5` bulk inserts.
  """
  @doc since: "0.6.0"
  @spec append_replace_steps(Ecto.Multi.t(), module(), term(), pos_integer()) ::
          {Ecto.Multi.t(), [String.t()]}
  @spec append_replace_steps(Ecto.Multi.t(), module(), term(), pos_integer(), DateTime.t()) ::
          {Ecto.Multi.t(), [String.t()]}
  def append_replace_steps(%Ecto.Multi{} = multi, backup_code_schema, user_id, count, now \\ DateTime.utc_now()) do
    codes = generate(count)

    entries =
      Enum.map(codes, fn {_formatted, hashed} ->
        %{
          user_id: user_id,
          hashed_code: hashed,
          used_at: nil,
          inserted_at: now
        }
      end)

    formatted_codes = Enum.map(codes, &elem(&1, 0))

    multi =
      multi
      |> Ecto.Multi.delete_all(
        :delete_backup_codes,
        from(bc in backup_code_schema, where: bc.user_id == ^user_id)
      )
      |> Ecto.Multi.insert_all(:insert_backup_codes, backup_code_schema, entries)

    {multi, formatted_codes}
  end

  @doc """
  Regenerates backup codes for a user.

  Deletes all existing codes and inserts fresh ones inside a single
  `Repo.transaction/1`. Returns the raw formatted codes for display (shown
  once, never retrievable again).

  ## Parameters

  - `repo` - The Ecto repo module
  - `backup_code_schema` - The generated backup code Ecto schema module
  - `user_id` - The user's ID
  - `count` - Number of codes to generate
  """
  @doc since: "0.6.0"
  @spec regenerate(module(), module(), term(), pos_integer()) ::
          {:ok, [String.t()]}
  def regenerate(repo, backup_code_schema, user_id, count) do
    Sigra.Telemetry.span([:sigra, :mfa, :backup_codes, :regenerate], %{user_id: user_id}, fn ->
      now = DateTime.utc_now()
      {multi, formatted_codes} = append_replace_steps(Ecto.Multi.new(), backup_code_schema, user_id, count, now)

      case repo.transaction(multi) do
        {:ok, _} ->
          {:ok, formatted_codes}

        {:error, failed, reason, _changes} ->
          raise "Sigra.MFA.BackupCodes.regenerate/4 unexpected transaction failure " <>
                  "at #{inspect(failed)}: #{inspect(reason)}"
      end
    end)
  end

  # Rejection sampling to eliminate modulo bias. A 4-byte unsigned integer
  # has max value 4,294,967,295. Values >= floor(2^32 / range) * range are
  # rejected to ensure uniform distribution across [0, range).
  @max_uint32 4_294_967_296
  defp uniform_random(range) when range > 0 do
    limit = div(@max_uint32, range) * range

    n =
      :crypto.strong_rand_bytes(4)
      |> :binary.decode_unsigned()

    if n >= limit do
      uniform_random(range)
    else
      rem(n, range)
    end
  end
end
