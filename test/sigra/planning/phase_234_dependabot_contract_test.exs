defmodule Sigra.Planning.Phase234DependabotContractTest do
  use ExUnit.Case, async: true

  @dependabot_path ".github/dependabot.yml"
  @expected_entries MapSet.new([
                      {"github-actions", "/"},
                      {"mix", "/"},
                      {"npm", "/test/example/priv/playwright"}
                    ])

  test "Dependabot owns exactly the three locked weekly ecosystems" do
    yaml = File.read!(@dependabot_path)
    entries = parse_updates!(yaml)

    assert length(entries) == 3
    assert MapSet.new(Enum.map(entries, &{&1.ecosystem, &1.directory})) == @expected_entries
    assert Enum.all?(entries, &(&1.interval == "weekly"))
    assert Enum.uniq_by(entries, &{&1.ecosystem, &1.directory}) == entries

    assert_manifest_pair!("/", "mix.exs", "mix.lock")
    assert_manifest_pair!("/test/example/priv/playwright", "package.json", "package-lock.json")

    assert yaml =~ ~r/package-ecosystem: "github-actions"[\s\S]*?prefix: "ci"/
    assert yaml =~ ~r/package-ecosystem: "mix"[\s\S]*?prefix: "deps"/
    assert yaml =~ ~r/package-ecosystem: "npm"[\s\S]*?prefix: "deps"/
    assert length(Regex.scan(~r/- "dependencies"/, yaml)) == 3
  end

  test "Dependabot parser fails closed with named diagnostics" do
    fixtures = [
      {"missing directory", "  - package-ecosystem: mix\n    schedule:\n      interval: weekly\n", "directory"},
      {"missing interval", "  - package-ecosystem: mix\n    directory: /\n    schedule:\n", "interval"},
      {"duplicate ecosystem directory", two_updates("mix", "/", "mix", "/"), "duplicate"},
      {"unknown ecosystem", single_update("bundler", "/"), "unknown ecosystem"},
      {"malformed indentation", "  - package-ecosystem: mix\n   directory: /\n", "malformed"},
      {"nonexistent manifest directory", single_update("npm", "/missing"), "manifest"}
    ]

    Enum.each(fixtures, fn {name, updates, expected_diagnostic} ->
      assert {:error, diagnostic} = parse_updates("version: 2\nupdates:\n" <> updates), name
      assert diagnostic != "", name
      assert diagnostic =~ expected_diagnostic, "#{name}: #{diagnostic}"
    end)
  end

  defp single_update(ecosystem, directory) do
    "  - package-ecosystem: #{ecosystem}\n    directory: #{directory}\n    schedule:\n      interval: weekly\n"
  end

  defp two_updates(first_ecosystem, first_directory, second_ecosystem, second_directory) do
    single_update(first_ecosystem, first_directory) <> single_update(second_ecosystem, second_directory)
  end

  defp parse_updates!(yaml) do
    case parse_updates(yaml) do
      {:ok, entries} -> entries
      {:error, diagnostic} -> flunk(diagnostic)
    end
  end

  defp parse_updates(yaml) do
    try do
      {:ok, yaml |> parse_updates_syntax!() |> validate_entries!()}
    rescue
      error in ExUnit.AssertionError -> {:error, Exception.message(error)}
    end
  end

  defp parse_updates_syntax!(yaml) do
    lines = String.split(yaml, "\n", trim: false)

    case lines do
      ["version: 2", "updates:" | update_lines] -> parse_blocks!(update_lines)
      _ -> flunk("Dependabot config must begin with version: 2 followed by updates:")
    end
  end

  defp parse_blocks!(lines) do
    {entries, current, _section} =
      Enum.reduce(lines, {[], nil, nil}, fn line, {entries, current, section} ->
        case line do
          "" -> {entries, current, section}
          "  - package-ecosystem: " <> value ->
            {finish_entry!(entries, current), %{ecosystem: scalar!(value, "package-ecosystem")}, nil}

          "    directory: " <> value ->
            {entries, put_field!(current, :directory, scalar!(value, "directory")), nil}

          "    schedule:" ->
            {entries, current, :schedule}

          "      interval: " <> value when section == :schedule ->
            {entries, put_field!(current, :interval, scalar!(value, "interval")), :schedule}

          "    commit-message:" when current != nil ->
            {entries, current, :commit_message}

          "      prefix: " <> _value when section == :commit_message ->
            {entries, current, :commit_message}

          "    labels:" when current != nil ->
            {entries, current, :labels}

          "      - " <> _value when section == :labels ->
            {entries, current, :labels}

          _ ->
            flunk("malformed Dependabot update block: #{inspect(line)}")
        end
      end)

    entries = finish_entry!(entries, current)

    if entries == [] do
      flunk("Dependabot config must contain at least one update block")
    end

    entries
  end

  defp validate_entries!(entries) do
    expected_directories = %{
      "github-actions" => "/",
      "mix" => "/",
      "npm" => "/test/example/priv/playwright"
    }

    Enum.each(entries, fn %{ecosystem: ecosystem, directory: directory} ->
      expected_directory = Map.get(expected_directories, ecosystem)

      unless expected_directory do
        flunk("unknown ecosystem #{inspect(ecosystem)}")
      end

      {manifest, lockfile} =
        case ecosystem do
          "github-actions" -> {nil, nil}
          "mix" -> {"mix.exs", "mix.lock"}
          "npm" -> {"package.json", "package-lock.json"}
        end

      if manifest && not manifest_pair_exists?(directory, manifest, lockfile) do
        flunk("missing manifest or lockfile for #{ecosystem} at #{directory}")
      end

      unless directory == expected_directory do
        flunk("unknown directory #{inspect(directory)} for #{ecosystem}")
      end
    end)

    tuples = Enum.map(entries, &{&1.ecosystem, &1.directory})

    if length(tuples) != MapSet.size(MapSet.new(tuples)) do
      flunk("duplicate package-ecosystem/directory entry")
    end

    entries
  end

  defp finish_entry!(entries, nil), do: entries

  defp finish_entry!(entries, entry) do
    Enum.each([:ecosystem, :directory, :interval], fn field ->
      unless Map.has_key?(entry, field), do: flunk("Dependabot update missing #{field}")
    end)

    [entry | entries]
  end

  defp put_field!(nil, _field, _value), do: flunk("Dependabot field appears before update block")

  defp put_field!(entry, field, value) do
    if Map.has_key?(entry, field), do: flunk("Dependabot update repeats #{field}")
    Map.put(entry, field, value)
  end

  defp scalar!(value, field) do
    value = String.trim(value)

    case value do
      "\"" <> rest -> quoted_scalar!(rest, "\"", field)
      "'" <> rest -> quoted_scalar!(rest, "'", field)
      "" -> flunk("Dependabot #{field} cannot be empty")
      _ -> value
    end
  end

  defp quoted_scalar!(rest, quote, field) do
    if String.ends_with?(rest, quote) do
      String.trim_trailing(rest, quote)
    else
      flunk("Dependabot #{field} has an unclosed quote")
    end
  end

  defp assert_manifest_pair!(directory, manifest, lockfile) do
    assert manifest_pair_exists?(directory, manifest, lockfile), "missing #{directory}/#{manifest} or #{lockfile}"
  end

  defp manifest_pair_exists?(directory, manifest, lockfile) do
    root = Path.expand("../../..", __DIR__)
    path = directory |> String.trim_leading("/") |> then(&Path.join(root, &1))

    File.exists?(Path.join(path, manifest)) and File.exists?(Path.join(path, lockfile))
  end
end
