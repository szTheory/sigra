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

  defp parse_updates!(yaml) do
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

          "    " <> _ when current != nil ->
            {entries, current, :other}

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
      "\"" <> rest -> String.trim_trailing(rest, "\"")
      "'" <> rest -> String.trim_trailing(rest, "'")
      "" -> flunk("Dependabot #{field} cannot be empty")
      _ -> value
    end
  end

  defp assert_manifest_pair!(directory, manifest, lockfile) do
    root = Path.expand("../../..", __DIR__)
    path = directory |> String.trim_leading("/") |> then(&Path.join(root, &1))

    assert File.exists?(Path.join(path, manifest)), "missing #{directory}/#{manifest}"
    assert File.exists?(Path.join(path, lockfile)), "missing #{directory}/#{lockfile}"
  end
end
