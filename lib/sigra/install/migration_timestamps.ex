defmodule Sigra.Install.MigrationTimestamps do
  @moduledoc """
  Deterministic slot-based timestamp allocator for installer
  migrations (GEN-07).

  Replaces the old `offset_timestamp/1` helper that lived in
  `Mix.Tasks.Sigra.Install` before Phase 11, which based timestamps
  on `:calendar.universal_time`, making re-runs
  non-deterministic and cross-feature ordering implicit. The slot
  allocator:

    1. Walks the canonical feature list in order.
    2. For each feature, iterates `migrations/1` slot entries in the
       order the feature returned them.
    3. Assigns `base_time + N seconds` where `N` is a globally
       incrementing counter across all features.

  This means `Features.Core`'s `:primary` slot always gets an earlier
  timestamp than `Features.Organizations`'s first slot, regardless
  of wall-clock time. Cross-feature ordering is static, not timing-
  dependent.

  Idempotent re-run is handled by the walker layer: if a migration
  file already exists on disk that matches `target_basename`, the
  walker reuses its filename instead of allocating a new timestamp.
  """

  @spec allocate(features :: [module()], base_time :: DateTime.t()) ::
          %{module() => %{atom() => String.t()}}
  def allocate(features, %DateTime{} = base_time) when is_list(features) do
    {result, _counter} =
      Enum.reduce(features, {%{}, 0}, fn feature_mod, {acc, counter} ->
        slots = feature_mod.migrations([])

        {slot_map, new_counter} =
          Enum.reduce(slots, {%{}, counter}, fn {slot_key, _template, _basename}, {map, c} ->
            ts = format_timestamp(base_time, c)
            {Map.put(map, slot_key, ts), c + 1}
          end)

        {Map.put(acc, feature_mod, slot_map), new_counter}
      end)

    result
  end

  @doc false
  @spec next_available(Path.t(), DateTime.t()) :: String.t()
  def next_available(migrations_dir, now \\ DateTime.utc_now())
      when is_binary(migrations_dir) and is_struct(now, DateTime) do
    current_version =
      now
      |> Calendar.strftime("%Y%m%d%H%M%S")
      |> String.to_integer()

    highest_existing =
      migrations_dir
      |> existing_versions()
      |> Enum.max(fn -> 0 end)

    max(current_version, highest_existing + 1)
    |> Integer.to_string()
    |> String.pad_leading(14, "0")
  end

  defp format_timestamp(%DateTime{} = base, offset_seconds) do
    base
    |> DateTime.add(offset_seconds, :second)
    |> Calendar.strftime("%Y%m%d%H%M%S")
  end

  defp existing_versions(migrations_dir) do
    if File.dir?(migrations_dir) do
      migrations_dir
      |> File.ls!()
      |> Enum.flat_map(fn filename ->
        case Regex.run(~r/^(\d{14})_/, filename) do
          [_, version] -> [String.to_integer(version)]
          _ -> []
        end
      end)
    else
      []
    end
  end
end
