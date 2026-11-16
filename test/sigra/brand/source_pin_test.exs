defmodule Sigra.Brand.SourcePinTest do
  @moduledoc """
  BPOL-02 source pin for the vendored brand book.

  `brand/` is a byte-exact, vendored copy of the brand book. The root
  `brand.sha256` manifest, written in stock `shasum -a 256 -c` format, pins
  every regular file under it. This is the one drift test for that pin: it
  regenerates the manifest in memory from the working tree and diffs it
  against the committed file.

  The same module carries the privacy scan of every vendored file: home-directory
  paths, non-`.test` emails, local file URLs, and embedded SVG, PDF, PNG and JPG
  metadata. The scan is a pure function (`scan_binary/2`) so planted-failure
  controls can prove it flags what it claims to flag. It has no URL rule and no
  allowlist, so a clean result on the real tree is never obtained by weakening it.

  Personal names are not scanned here: a name cannot be written into test source,
  so the phase gate derives it at run time and greps the whole tree instead.
  Home-directory shapes are assembled from fragments below for the same reason.

  Pure filesystem and stdlib `:crypto` and `JSON`; no database is touched. The
  repo root is resolved from `__DIR__`, never from the working directory.

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

  # Book provenance: brand/brand.json must stay the v2.0 edition.
  @book_version "2.0"
  @book_date "November 13, 2026"

  # Home-directory prefixes are built from fragments so this file never contains
  # one literally (the repo-wide privacy grep would otherwise match the scanner).
  @slash "/"
  @users_dir @slash <> "Users" <> @slash
  @home_dir @slash <> "home" <> @slash

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>
  @png_metadata_chunks ["tEXt", "iTXt", "zTXt", "eXIf"]
  @binary_exts ~w(.pdf .png .jpg .jpeg .ico .ttf .otf .woff .woff2)

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

  describe "book provenance" do
    test "brand/brand.json is the v2.0 edition dated November 13, 2026" do
      book = @root |> Path.join("brand/brand.json") |> File.read!() |> JSON.decode!()

      assert book["version"] == @book_version
      assert book["date"] == @book_date
    end
  end

  describe "privacy scan of the real tree" do
    test "no vendored file carries a home path, non-test email, local file URL or author metadata" do
      contents = read_files(@root)
      exts = contents |> Map.keys() |> Enum.map(&(&1 |> Path.extname() |> String.downcase()))

      findings =
        contents
        |> Enum.sort()
        |> Enum.flat_map(fn {path, bytes} -> scan_binary(path, bytes) end)

      # Non-vacuous: every metadata rule family has at least one real file to run on.
      assert map_size(contents) > 0
      assert Enum.all?([".svg", ".pdf", ".png", ".jpg", ".ttf"], &(&1 in exts))

      assert findings == [], privacy_message(findings)
    end

    test "the PDF and PNG walkers actually read the real files they are scanning" do
      contents = read_files(@root)

      for {path, bytes} <- contents, Path.extname(path) == ".pdf" do
        # Creator and Producer both parsed out of the real Info dictionary.
        assert length(pdf_info_values(bytes)) >= 2, "no Info values parsed from #{path}"
      end

      for {path, bytes} <- contents, Path.extname(path) == ".png" do
        # A real PNG walks cleanly from its header chunk to IEND.
        assert {:ok, ["IHDR" | _] = types} = png_chunk_types(bytes), "bad chunk walk: #{path}"
        assert List.last(types) == "IEND"
      end
    end
  end

  describe "scan_binary/2 planted-failure controls" do
    test "flags a macOS home-directory path" do
      bytes = "logo exported from " <> @users_dir <> "someone/brand/logo.svg"

      assert {:home_path, "planted/note.txt"} in scan_binary("planted/note.txt", bytes)
    end

    test "flags a Linux home-directory path" do
      bytes = "cached at " <> @home_dir <> "someone/.cache/logo.png"

      assert {:home_path, "planted/note.md"} in scan_binary("planted/note.md", bytes)
    end

    test "flags a Windows user-profile path" do
      bytes = "C:" <> "\\" <> "Users" <> "\\" <> "someone" <> "\\logo.png"

      assert {:windows_profile, "planted/note.txt"} in scan_binary("planted/note.txt", bytes)
    end

    test "flags a macOS temp path" do
      bytes = "rendered into /private/var/folders/xx/logo.png"

      assert {:private_var_path, "planted/note.txt"} in scan_binary("planted/note.txt", bytes)
    end

    test "flags an email whose domain does not end in .test" do
      bytes = "contact " <> "someone" <> "@" <> "example.com" <> " for access"

      assert {:email, "planted/note.md"} in scan_binary("planted/note.md", bytes)
    end

    test "flags an absolute local file URL" do
      bytes = ~s(<img src=") <> "file:" <> "//" <> "/tmp/logo.png" <> ~s(">)

      assert {:file_url, "planted/page.html"} in scan_binary("planted/page.html", bytes)
    end

    test "flags an SVG metadata element" do
      bytes = ~s(<svg xmlns="http://www.w3.org/2000/svg"><metadata>x</metadata></svg>)

      assert {:svg_metadata, "planted/logo.svg"} in scan_binary("planted/logo.svg", bytes)
    end

    test "flags SVG editor and creator markers" do
      for marker <- ["dc:creator", "inkscape:version", "sodipodi:docname"] do
        bytes = ~s(<svg #{marker}="x"></svg>)

        assert {:svg_metadata, "planted/logo.svg"} in scan_binary("planted/logo.svg", bytes)
      end
    end

    test "flags a PNG that carries a tEXt chunk" do
      bytes = png_with_chunks([{"IHDR", <<0::104>>}, {"tEXt", "Author\0x"}, {"IEND", ""}])

      assert {:png_chunk, "planted/logo.png"} in scan_binary("planted/logo.png", bytes)
    end

    test "flags a PDF that carries an /Author key" do
      bytes = "%PDF-1.4\n1 0 obj\n<< /Author (x) /Producer (Skia/PDF) >>\nendobj\n"

      assert {:pdf_author, "planted/book.pdf"} in scan_binary("planted/book.pdf", bytes)
    end

    test "flags a path shape inside a PDF Creator value that contains escaped parentheses" do
      bytes =
        "%PDF-1.4\n<< /Creator (Exporter \\(build 7\\) at " <>
          @users_dir <> "someone/out) /Producer (Skia/PDF) >>\n"

      assert {:pdf_info_value, "planted/book.pdf"} in scan_binary("planted/book.pdf", bytes)
    end

    test "flags a JPG that carries an Exif block" do
      bytes = <<0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x10>> <> "Exif\0\0" <> "padding"

      assert {:jpg_exif, "planted/photo.jpg"} in scan_binary("planted/photo.jpg", bytes)
    end

    test "flags a home path hidden in the printable strings of a binary font" do
      bytes =
        <<0, 1, 0, 0, 0xFF, 0xFE>> <> "built in " <> @home_dir <> "someone/fonts" <> <<0, 0>>

      assert {:home_path, "planted/face.ttf"} in scan_binary("planted/face.ttf", bytes)
    end
  end

  describe "scan_binary/2 narrowness controls" do
    test "does not flag a bare file:// inside a benign comment" do
      bytes = "catch { /* file:// or an older browser: fall back */ }"

      assert scan_binary("planted/page.html", bytes) == []
    end

    test "has no URL rule: a plain https URL on an example host is not a finding" do
      bytes = ~s(<meta property="x" content="https://example.com/a/b.jpg">)

      assert scan_binary("planted/index.html", bytes) == []
    end

    test "does not flag an email on a .test domain" do
      bytes = "someone" <> "@" <> "demo.example.test"

      assert scan_binary("planted/note.md", bytes) == []
    end

    test "does not substring-match chunk names inside PNG chunk data" do
      bytes = png_with_chunks([{"IHDR", <<0::104>>}, {"IDAT", "xxtEXtxxeXIfxx"}, {"IEND", ""}])

      assert scan_binary("planted/logo.png", bytes) == []
    end

    test "flags a malformed PNG instead of silently passing it" do
      bytes = @png_signature <> <<0, 0, 255, 255, "IDAT", 1, 2, 3>>

      assert {:png_malformed, "planted/logo.png"} in scan_binary("planted/logo.png", bytes)
    end

    test "does not flag a clean JPG with a JFIF header only" do
      bytes = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10>> <> "JFIF\0" <> "padding"

      assert scan_binary("planted/photo.jpg", bytes) == []
    end

    test "does not flag a clean SVG or a PDF without author metadata" do
      svg = ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8"><path d="M0 0h8"/></svg>)

      pdf =
        "%PDF-1.4\n<< /Title (Book) /Creator (Mozilla/5.0 \\(X11\\)) /Producer (Skia/PDF) >>\n"

      assert scan_binary("planted/logo.svg", svg) == []
      assert scan_binary("planted/book.pdf", pdf) == []
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

  # -- privacy scan ----------------------------------------------------------

  # Pure scan of one file's bytes. Returns a list of `{kind, path}` findings;
  # `[]` means clean. Dispatches on the file extension.
  defp scan_binary(path, bytes) do
    ext = path |> Path.extname() |> String.downcase()

    kinds =
      text_kinds(scan_text_input(ext, bytes)) ++
        case ext do
          ".svg" -> svg_kinds(bytes)
          ".pdf" -> pdf_kinds(bytes)
          ".png" -> png_kinds(bytes)
          jpg when jpg in [".jpg", ".jpeg"] -> jpg_kinds(bytes)
          _ -> []
        end

    kinds |> Enum.uniq() |> Enum.map(&{&1, path})
  end

  # Text-like files are scanned whole; binaries only by their printable-string runs.
  defp scan_text_input(ext, bytes) when ext in @binary_exts do
    ~r/[\x20-\x7E]{6,}/ |> Regex.scan(bytes) |> Enum.map_join("\n", &hd/1)
  end

  defp scan_text_input(_ext, bytes), do: bytes

  # Rules that apply to every file. Built at call time (not stored in module
  # attributes) so the home-directory prefixes stay fragment-built.
  defp text_kinds(text) do
    name = ~S{[^/\s"'<>]+}

    rules = [
      {:home_path, Regex.compile!(Regex.escape(@users_dir) <> name)},
      {:home_path, Regex.compile!(Regex.escape(@home_dir) <> name)},
      {:windows_profile,
       Regex.compile!(~S{[A-Za-z]:[\\/]+} <> "Users" <> ~S{[\\/]+[^\\/\s"'<>]+}, "i")},
      {:private_var_path, ~r{/private/var/}},
      # Only the absolute local form (three slashes plus a path); a bare
      # "file://" in prose or a code comment is not a finding.
      {:file_url, ~r{file:///\S}}
    ]

    for({kind, regex} <- rules, Regex.match?(regex, text), do: kind) ++ email_kinds(text)
  end

  defp email_kinds(text) do
    ~r/[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})/
    |> Regex.scan(text)
    |> Enum.reject(fn [_, domain] -> String.ends_with?(String.downcase(domain), ".test") end)
    |> Enum.map(fn _ -> :email end)
  end

  defp svg_kinds(text) do
    markers = [~r/<metadata[\s>\/]/i, ~r/dc:creator/i, ~r/inkscape:/i, ~r/sodipodi/i]

    if Enum.any?(markers, &Regex.match?(&1, text)), do: [:svg_metadata], else: []
  end

  defp pdf_kinds(bytes) do
    author = if Regex.match?(~r{/Author[\s(<]}, bytes), do: [:pdf_author], else: []

    info =
      if Enum.any?(pdf_info_values(bytes), &(text_kinds(&1) != [])),
        do: [:pdf_info_value],
        else: []

    author ++ info
  end

  # String values of the /Creator and /Producer keys (balanced, backslash-escaped parens).
  defp pdf_info_values(bytes) do
    ~r{/(?:Creator|Producer)\s*\(}
    |> Regex.scan(bytes, return: :index)
    |> Enum.map(fn [{start, len}] ->
      rest = binary_part(bytes, start + len, byte_size(bytes) - start - len)
      read_pdf_literal(rest, 0, [])
    end)
  end

  defp read_pdf_literal(<<")", _::binary>>, 0, acc), do: finish_literal(acc)

  defp read_pdf_literal(<<")", rest::binary>>, depth, acc),
    do: read_pdf_literal(rest, depth - 1, [")" | acc])

  defp read_pdf_literal(<<"(", rest::binary>>, depth, acc),
    do: read_pdf_literal(rest, depth + 1, ["(" | acc])

  defp read_pdf_literal(<<"\\", c, rest::binary>>, depth, acc),
    do: read_pdf_literal(rest, depth, [<<c>> | acc])

  defp read_pdf_literal(<<c, rest::binary>>, depth, acc),
    do: read_pdf_literal(rest, depth, [<<c>> | acc])

  defp read_pdf_literal(<<>>, _depth, acc), do: finish_literal(acc)

  defp finish_literal(acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  # Walks length-prefixed chunks; never substring-searches the whole file.
  defp png_kinds(bytes) do
    case png_chunk_types(bytes) do
      {:ok, types} ->
        if Enum.any?(types, &(&1 in @png_metadata_chunks)), do: [:png_chunk], else: []

      :error ->
        [:png_malformed]
    end
  end

  defp png_chunk_types(<<@png_signature, rest::binary>>), do: walk_png_chunks(rest, [])
  defp png_chunk_types(_), do: :error

  defp walk_png_chunks(<<len::32, type::binary-size(4), rest::binary>>, acc)
       when byte_size(rest) >= len + 4 do
    <<_data::binary-size(len), _crc::binary-size(4), tail::binary>> = rest

    case {type, tail} do
      {"IEND", <<>>} -> {:ok, Enum.reverse([type | acc])}
      {"IEND", _trailing} -> :error
      _ -> walk_png_chunks(tail, [type | acc])
    end
  end

  defp walk_png_chunks(_rest, _acc), do: :error

  defp jpg_kinds(bytes) do
    if :binary.match(bytes, "Exif\0\0") == :nomatch, do: [], else: [:jpg_exif]
  end

  # `[{path_or_tag, bytes}]` chunk list -> a PNG binary. CRCs are not checked by the scanner.
  defp png_with_chunks(chunks) do
    for {type, payload} <- chunks, into: @png_signature do
      <<byte_size(payload)::32, type::binary-size(4), payload::binary, 0::32>>
    end
  end

  defp privacy_message(findings) do
    lines = Enum.map_join(findings, "\n    ", fn {kind, path} -> "#{path}  (#{kind})" end)

    """
    Privacy scan found disallowed content in vendored brand/ files:

        #{lines}

    Do not weaken the scan to make it pass. A finding means the vendored bytes carry a
    local path, a personal email or embedded author metadata. Record the file and stop:
    re-vendoring a cleaned copy is an upstream change that needs the owner.
    """
  end
end
