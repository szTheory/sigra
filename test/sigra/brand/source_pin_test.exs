defmodule Sigra.Brand.SourcePinTest do
  @moduledoc """
  BPOL-02 source pin for the vendored brand book.

  `brand/` is a byte-exact, vendored copy of the brand book. The root
  `brand.sha256` manifest, written in stock `shasum -a 256 -c` format, pins
  every regular file under it. This is the one drift test for that pin: it
  regenerates the manifest in memory from the working tree and diffs it
  against the committed file.

  Pure filesystem and stdlib `:crypto`; no database is touched. The repo root
  is resolved from `__DIR__`, never from the working directory.

  Red-ness is proven only by the in-memory controls below. Never mutate a real
  file under `brand/` to demonstrate that the pin can fail.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @brand_dir "brand"
  @manifest_path "brand.sha256"
  @gitattributes_path ".gitattributes"
  @gitattributes_line "brand/** -text linguist-vendored"
  @regen_command "find brand -type f ! -name .DS_Store -print0 | " <>
                   "LC_ALL=C sort -z | xargs -0 shasum -a 256 > brand.sha256"

  describe "manifest pin" do
    test "brand.sha256 matches every byte of the working tree under brand/" do
      actual = @root |> read_files() |> hash_map()
      committed_text = read_manifest_text()

      diff = diff_maps(parse_manifest(committed_text), actual)

      if diff != [], do: flunk(drift_message(diff))

      # Equal paths and hashes could still hide a reordered or reformatted manifest.
      assert committed_text == render_manifest(actual),
             "brand.sha256 has the right hashes but is not byte-sorted or is badly formatted. " <>
               "Regenerate it from the repo root:\n\n  #{@regen_command}\n"
    end

    test "the pin is non-vacuous: brand/ exists, is non-empty and the manifest has one line per file" do
      files = list_files(@root)
      manifest_lines = manifest_lines(read_manifest_text())

      assert File.dir?(Path.join(@root, @brand_dir)),
             "#{@brand_dir}/ not found under #{@root}; the pin cannot verify anything"

      assert files != []
      assert "brand/brand.json" in files
      assert "brand/tokens.json" in files
      assert length(manifest_lines) == length(files)
    end

    test ".gitattributes keeps brand/ byte-exact and marks it vendored" do
      lines =
        @root
        |> Path.join(@gitattributes_path)
        |> File.read!()
        |> String.replace("\r\n", "\n")
        |> String.split("\n")

      assert @gitattributes_line in lines
    end
  end

  describe "diff_maps/2 positive controls" do
    test "reports exactly the changed path when one byte of one file is mutated" do
      contents = read_files(@root)
      path = "brand/brand.json"
      mutated = Map.update!(contents, path, &(&1 <> "x"))

      diff = diff_maps(hash_map(contents), hash_map(mutated))

      assert diff == [{:changed, path}]
    end

    test "reports exactly the removed path when one file is dropped from the tree" do
      hashes = @root |> read_files() |> hash_map()
      path = "brand/tokens.json"

      diff = diff_maps(hashes, Map.delete(hashes, path))

      assert diff == [{:removed, path}]
    end

    test "reports exactly the added path when one extra file appears in the tree" do
      hashes = @root |> read_files() |> hash_map()
      path = "brand/zz-extra-file.txt"

      diff = diff_maps(hashes, Map.put(hashes, path, sha256_hex("extra")))

      assert diff == [{:added, path}]
    end

    test "reports nothing when the two maps are identical" do
      hashes = @root |> read_files() |> hash_map()

      assert diff_maps(hashes, hashes) == []
    end
  end

  # -- pure helpers ----------------------------------------------------------

  # Repo-relative paths of every regular file under brand/, byte-sorted.
  defp list_files(root) do
    root
    |> Path.join("#{@brand_dir}/**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.reject(&(Path.basename(&1) == ".DS_Store"))
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.sort()
  end

  defp read_files(root) do
    Map.new(list_files(root), fn path -> {path, File.read!(Path.join(root, path))} end)
  end

  # %{path => bytes} -> %{path => lowercase hex sha256}
  defp hash_map(contents) do
    Map.new(contents, fn {path, bytes} -> {path, sha256_hex(bytes)} end)
  end

  defp sha256_hex(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  # `shasum -a 256 -c` format: "<hex>  <path>\n", byte-sorted by path.
  defp render_manifest(hashes) do
    hashes
    |> Enum.sort()
    |> Enum.map_join(fn {path, hex} -> "#{hex}  #{path}\n" end)
  end

  defp read_manifest_text do
    @root |> Path.join(@manifest_path) |> File.read!() |> String.replace("\r\n", "\n")
  end

  defp manifest_lines(text) do
    text |> String.split("\n") |> Enum.reject(&(String.trim(&1) == ""))
  end

  defp parse_manifest(text) do
    text
    |> manifest_lines()
    |> Map.new(fn line ->
      case Regex.run(~r/\A([0-9a-f]{64})  (\S.*)\z/, line) do
        [_, hex, path] -> {path, hex}
        nil -> raise ArgumentError, "malformed #{@manifest_path} line: #{inspect(line)}"
      end
    end)
  end

  # `expected` is the committed manifest, `actual` the working tree.
  defp diff_maps(expected, actual) do
    added = for {path, _} <- actual, not is_map_key(expected, path), do: {:added, path}
    removed = for {path, _} <- expected, not is_map_key(actual, path), do: {:removed, path}

    changed =
      for {path, hex} <- actual, is_map_key(expected, path), expected[path] != hex do
        {:changed, path}
      end

    Enum.sort(added ++ removed ++ changed)
  end

  defp drift_message(diff) do
    group = fn kind ->
      diff
      |> Enum.filter(&(elem(&1, 0) == kind))
      |> Enum.map_join("\n      ", &elem(&1, 1))
    end

    """
    brand/ differs from brand.sha256.

      Added (in brand/ but not in the manifest):
          #{group.(:added)}

      Removed (in the manifest but not in brand/):
          #{group.(:removed)}

      Changed (bytes differ from the manifest):
          #{group.(:changed)}

    brand/ is a byte-pinned vendored copy of the brand book. A change to it is an
    upstream change: re-vendor, then regenerate the manifest from the repo root:

      #{@regen_command}
    """
  end
end
