defmodule Sigra.Test.Brand.CopyInventory do
  @moduledoc """
  Test-only extractors, renderer and differ for the per-lane copy inventory
  (BCOPY-04).

  Sigra ships user-visible copy in three ownership lanes. Each lane has a
  committed inventory under `test/fixtures/brand/copy-inventory/<lane>.tsv`:

    * `:host` - `Sigra.Branding.Profile` default strings, plus one row stating
      that host-owned CSS and logos carry no Sigra copy.
    * `:generated` - copy in the installer templates under
      `priv/templates/sigra.install/`: `dgettext("sigra", ...)` msgids, literal
      `put_flash` messages, HEEx text nodes inside `~H` blocks, and literal
      multi-word text in the email builders. Browser-side copy in the `.js`
      hooks, HEEx attribute values, and raw string literals outside those forms
      (error response bodies, keyword values) are not extracted. The header of
      each TSV states this coverage, because a clean inventory diff proves
      nothing about copy in a form that is not covered.
    * `:raw_auth` - raw string forms in generated core, organization and passkey
      sources. It records every double-quoted source token in `.ex`, `.exs` and
      `.js` files, plus HEEx text nodes and selected visible HEEx attributes.
      This deliberately includes code and comments as reviewable rows; it does
      not pretend to classify every string as user-facing copy.
    * `:library` - copy in the library-owned admin LiveViews and components
      (`lib/sigra/admin/**`) and the `safe_message/1` strings in
      `lib/sigra/error.ex`: string literals read from the AST (doc and type
      attributes excluded) and text nodes of `~H` blocks.

  A row is `{file, kind, string}`: a repo-relative file (or a lane note), the
  kind of copy it is, and the string itself. There are no line numbers, so
  moving code inside a file does not churn the inventory. Rows are sorted and
  unique.

  Nothing here evaluates repo content. Valid Elixir is read with
  `Code.string_to_quoted/2` and templates are read with regular expressions.
  Regeneration is opt-in: set `SIGRA_BRAND_COPY=regen` and run the inventory
  test, then review the resulting TSV diff. It is a local maintainer action and
  is refused when `CI` is `true` (`Sigra.Test.Brand.RegenGuard`), because the
  inventory test would otherwise compare the regenerated file with itself.
  """

  alias Sigra.Branding.Profile
  alias Sigra.Test.Brand.RegenGuard

  @root Path.expand("../../..", __DIR__)
  @fixture_dir "test/fixtures/brand/copy-inventory"
  @regen_env "SIGRA_BRAND_COPY"
  @regen_command "SIGRA_BRAND_COPY=regen mix test test/sigra/brand/copy_inventory_test.exs"

  @profile_file "lib/sigra/branding/profile.ex"
  @host_note_file "(host-owned CSS and logos)"
  @host_note "no Sigra copy by design: host-owned CSS and logos carry no Sigra copy, and the Tasklane demo app is out of lane"
  @hex_color ~r/^#[0-9a-fA-F]{6}$/

  @lanes [:host, :generated, :raw_auth, :library]

  @templates_dir "priv/templates/sigra.install"
  @raw_auth_dirs ["core", "organizations", "passkeys"]
  @raw_auth_extensions [".ex", ".exs", ".js"]
  @raw_auth_literal ~r/"((?:[^"\\]|\\.)*)"/s
  @raw_auth_heex ~r/~H"""\n(.*?)\n[ \t]*"""/s
  @raw_auth_attribute ~r/\b(?:aria-label|title|placeholder|label|alt|action)\s*=\s*"([^"]*)"/s
  @raw_auth_exceptions [
    {"(raw-auth coverage exceptions)", "coverage_exception",
     "single-quoted and charlist source forms"},
    {"(raw-auth coverage exceptions)", "coverage_exception",
     "plain EEx/HTML heredoc text outside ~H and double-quoted tokens"},
    {"(raw-auth coverage exceptions)", "coverage_exception",
     "CSS, SVG and JSON under generated core/, organizations/ and passkeys/"},
    {"(raw-auth coverage exceptions)", "coverage_exception",
     "auth-related sources outside generated installer core/, organizations/ and passkeys/"}
  ]
  @admin_glob "lib/sigra/admin/**/*.ex"
  @error_file "lib/sigra/error.ex"

  # Attributes whose bodies are documentation or types, never shipped copy.
  @non_copy_attrs [
    :doc,
    :moduledoc,
    :typedoc,
    :spec,
    :type,
    :typep,
    :opaque,
    :callback,
    :macrocallback
  ]
  # Installer templates are Elixir carrying EEx tags, so they are NOT valid Elixir
  # and are read with regexes only. Every other file type must be classified here:
  # an unknown type raises rather than being silently skipped.
  @elixir_template_exts [".ex", ".exs"]
  @unextracted_template_exts [".css", ".svg", ".json", ".js"]

  # A double-quoted literal body: anything but an unescaped quote.
  @msgid_regex ~r/\bdgettext\(\s*"sigra"\s*,\s*"((?:[^"\\]|\\.)*)"/s
  @flash_regex ~r/\bput_flash\(\s*(?:[a-z_@][\w.@]*\s*,\s*)?:[a-z_]+\s*,\s*"((?:[^"\\]|\\.)*)"/s
  @doc_heredoc ~r/^[ \t]*@(?:moduledoc|doc|typedoc)[ \t]+(?:~[sS])?"""\n.*?\n[ \t]*"""[ \t]*$/ms
  @doc_line ~r/^[ \t]*@(?:moduledoc|doc|typedoc)[ \t]+(?:false|"(?:[^"\\\n]|\\.)*")[ \t]*$/m
  # `#{` at a line start is interpolation inside a heredoc, not a comment.
  @comment_line ~r/^[ \t]*#(?!\{)[^\n]*$/m
  @heex_sigil ~r/~H"""\n(.*?)\n[ \t]*"""/s
  @raw_element ~r/<(script|style)\b.*?<\/\1>/s
  @html_comment ~r/<!--.*?-->/s
  @eex_tag ~r/<%.*?%>/s
  @html_entity ~r/&(?:#\d+|#x[0-9a-fA-F]+|[A-Za-z]+);/
  @heredoc_block ~r/"""\n.*?\n[ \t]*"""/s
  @attribute_line ~r/^[ \t]*@[a-z_]+[ \t].*$/m
  @dgettext_head ~r/\bdgettext\(\s*"sigra"\s*,\s*"(?:[^"\\]|\\.)*"/s
  @quoted_literal ~r/"((?:[^"\\\n]|\\.)*)"/

  @type lane :: :host | :generated | :library
  @type row :: {file :: String.t(), kind :: String.t(), string :: String.t()}

  @doc "Lanes that have a committed inventory."
  @spec lanes() :: [lane()]
  def lanes, do: @lanes

  @doc """
  True only when the opt-in regeneration environment variable is `regen`.

  Raises when it is, and the run is a CI run: see `Sigra.Test.Brand.RegenGuard`.
  `env` defaults to the process environment and exists so tests can plant one.
  """
  @spec regenerate?(RegenGuard.env()) :: boolean()
  def regenerate?(env \\ RegenGuard.environment()),
    do: RegenGuard.requested?(@regen_env, "regen", env)

  @doc "The exact command a maintainer runs to regenerate every inventory."
  @spec regen_command() :: String.t()
  def regen_command, do: @regen_command

  @doc "Absolute path of a lane's committed inventory."
  @spec path_for(lane()) :: Path.t()
  def path_for(lane) when lane in @lanes do
    Path.join([@root, @fixture_dir, "#{lane}.tsv"])
  end

  @doc """
  Extracts a lane's rows from the current sources.

  Returns a sorted, unique list of `{file, kind, string}` tuples.
  """
  @spec extract(lane()) :: [row()]
  def extract(:host) do
    defaults =
      for {key, value} <- Profile.defaults(), is_binary(value), not color_token?(value) do
        {@profile_file, "profile_default:#{key}", value}
      end

    normalize([{@host_note_file, "lane_note", @host_note} | defaults])
  end

  def extract(:generated) do
    templates = Path.join(@root, @templates_dir)

    templates
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.flat_map(&template_rows(&1, Path.relative_to(&1, templates)))
    |> normalize()
  end

  def extract(:raw_auth) do
    @raw_auth_dirs
    |> Enum.flat_map(fn dir ->
      Path.join([@root, @templates_dir, dir, "**/*"])
      |> Path.wildcard()
      |> Enum.filter(&(File.regular?(&1) and Path.extname(&1) in @raw_auth_extensions))
    end)
    |> Enum.flat_map(fn path ->
      path
      |> File.read!()
      |> raw_auth_rows_from_source(Path.relative_to(path, Path.join(@root, @templates_dir)))
    end)
    |> Kernel.++(@raw_auth_exceptions)
    |> normalize()
  end

  def extract(:library) do
    admin = @root |> Path.join(@admin_glob) |> Path.wildcard()

    [Path.join(@root, @error_file) | admin]
    |> Enum.flat_map(&library_rows(&1, Path.relative_to(&1, @root)))
    |> normalize()
  end

  @doc "Extracts the declared raw-auth source forms from one planted source file."
  @spec raw_auth_rows_from_source(String.t(), String.t()) :: [row()]
  def raw_auth_rows_from_source(source, file) do
    literal_rows =
      for [_, value] <- Regex.scan(@raw_auth_literal, source),
          do: {file, "source_token", value}

    heex_rows =
      for [_, body] <- Regex.scan(@raw_auth_heex, source),
          value <- heex_text_lines(body),
          do: {file, "heex_text", value}

    attribute_rows =
      for [_, value] <- Regex.scan(@raw_auth_attribute, source),
          do: {file, "heex_attribute", value}

    normalize(literal_rows ++ heex_rows ++ attribute_rows)
  end

  @doc """
  Returns the text nodes of a HEEx body as trimmed, whitespace-collapsed lines.

  Multi-line tags are consumed whole (newlines inside a tag never leak out), so
  a tag split over several lines cannot leave attribute fragments behind. Tags,
  `{...}` expressions, EEx tags, HTML comments and `<script>`/`<style>`
  elements contribute nothing. Lines with no letter or digit left, once HTML
  entities are removed, are dropped as pure punctuation.

  Raises `ArgumentError` on an unterminated tag or expression, so malformed
  input fails loudly instead of silently dropping the rest of the body.
  """
  @spec heex_text_lines(String.t()) :: [String.t()]
  def heex_text_lines(body) do
    body
    |> remove(@raw_element)
    |> remove(@html_comment)
    |> remove(@eex_tag)
    |> scan_text([])
    |> String.split("\n")
    |> Enum.map(&(&1 |> String.replace(~r/\s+/u, " ") |> String.trim()))
    |> Enum.reject(&noise_line?/1)
  end

  @doc """
  Renders a lane's rows as TSV text, with `#`-prefixed header lines that state
  the purpose, the lane and the regeneration command.
  """
  @spec render(lane(), [row()]) :: String.t()
  def render(lane, rows) do
    body = for {file, kind, string} <- rows, do: Enum.join([file, kind, escape(string)], "\t")

    Enum.join(header_lines(lane) ++ body, "\n") <> "\n"
  end

  @doc """
  The `#`-prefixed header lines `render/2` writes for a lane, without a trailing
  newline. The header states what the extractor covers and what it does not, so
  a clean diff of the inventory is not mistaken for proof that no copy changed.
  """
  @spec header_lines(lane()) :: [String.t()]
  def header_lines(lane) when lane in @lanes do
    [
      "# #{@fixture_dir}/#{lane}.tsv - copy inventory, #{lane} lane",
      "#",
      "# WHY THIS FILE EXISTS",
      "# The user-visible strings of this ownership lane that the extractor reads. A change to",
      "# one of them shows up as a reviewed diff of this file instead of passing silently. The",
      "# inventory test asserts this file equals a fresh extraction of the sources, exactly.",
      "#",
      "# COVERAGE"
    ] ++
      coverage_lines(lane) ++
      [
        "# Copy in a form that is not covered can change without touching this file.",
        "#",
        "# FORMAT",
        "# file<TAB>kind<TAB>string. Sorted, unique, no line numbers. A tab, newline, carriage",
        "# return or backslash inside a string is written as \\t, \\n, \\r or \\\\.",
        "# Lines starting with '#' are skipped on read.",
        "#",
        "# DO NOT HAND-EDIT. Regenerate with:",
        "#   #{@regen_command}"
      ]
  end

  defp coverage_lines(:host) do
    [
      "# Covered: the string defaults of Sigra.Branding.Profile (design-token colors left out),",
      "#   plus one row stating that host-owned CSS and logos carry no Sigra copy.",
      "# Not covered: copy in any module other than the Profile defaults."
    ]
  end

  defp coverage_lines(:generated) do
    [
      "# Covered: dgettext(\"sigra\", ...) msgids, literal put_flash messages, text nodes of ~H",
      "#   blocks, and multi-word literals in the email builders.",
      "# Not covered: browser-side copy in .js hooks (for example the passkey status messages),",
      "#   HEEx attribute values (aria-label, title, placeholder and similar), and raw string",
      "#   literals outside dgettext, put_flash, ~H text and the email builders (for example",
      "#   error response bodies and keyword values)."
    ]
  end

  defp coverage_lines(:raw_auth) do
    [
      "# Covered: every double-quoted source token in .ex, .exs and .js files under",
      "#   generated core/, organizations/ and passkeys/ (including code/comments),",
      "#   text nodes in ~H heredocs, and values named aria-label, title, placeholder,",
      "#   label, alt and action in those sources (wherever assigned). This includes raw forms",
      "#   outside dgettext and JS hook string literals; it is a source-token inventory,",
      "#   not a semantic claim that every row is user-facing copy.",
      "# Not covered: single-quoted/charlist forms, non-HEEx HTML/EEx text outside",
      "#   double-quoted tokens, CSS/SVG/JSON, files outside these three directories,",
      "#   or auth-related source outside the generated installer templates. Each of these",
      "#   exclusions has a coverage_exception row below; remove a row only when covered."
    ]
  end

  defp coverage_lines(:library) do
    [
      "# Covered: string literals in lib/sigra/admin/**/*.ex (doc and type attributes and raise",
      "#   messages excluded), text nodes of ~H blocks, and the safe_message/1 strings in",
      "#   lib/sigra/error.ex.",
      "# Not covered: HEEx attribute values (aria-label, title, placeholder and similar) and",
      "#   library copy outside those files."
    ]
  end

  @doc """
  Parses TSV text back into rows, skipping `#` header lines and blank lines.
  """
  @spec parse(String.t()) :: [row()]
  def parse(text) do
    text
    |> String.split("\n")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.map(fn line ->
      [file, kind, string] = String.split(line, "\t", parts: 3)
      {file, kind, unescape(string)}
    end)
  end

  @doc """
  Diffs a committed inventory against a fresh extraction.

  `added` holds rows the fresh extraction has that the committed inventory
  lacks. `removed` holds rows the committed inventory has that the extraction no
  longer produces. Inputs need not be sorted; both results are sorted.
  """
  @spec diff_rows([row()], [row()]) :: %{added: [row()], removed: [row()]}
  def diff_rows(committed, fresh) do
    committed_set = MapSet.new(committed)
    fresh_set = MapSet.new(fresh)

    %{
      added: fresh_set |> MapSet.difference(committed_set) |> Enum.sort(),
      removed: committed_set |> MapSet.difference(fresh_set) |> Enum.sort()
    }
  end

  @doc """
  Library-lane extraction over one Elixir source string, with no file access.

  `rel` is the repo-relative path used for the rows and for error messages. Uses
  `Code.string_to_quoted/2` only; the source is never evaluated. Raises
  `ArgumentError` naming `rel` when the source does not parse, so a file can
  never be skipped silently.
  """
  @spec library_rows_from_source(String.t(), String.t()) :: [row()]
  def library_rows_from_source(source, rel) do
    case Code.string_to_quoted(source, file: rel) do
      {:ok, ast} ->
        ast
        |> library_scope(rel)
        |> collect_copy()
        |> Enum.map(fn {kind, string} -> {rel, kind, string} end)

      {:error, reason} ->
        raise ArgumentError, "could not parse for the copy inventory: #{inspect(reason)}"
    end
  rescue
    error in ArgumentError ->
      reraise ArgumentError, "#{rel}: #{Exception.message(error)}", __STACKTRACE__
  end

  @doc "Writes a lane's freshly extracted and rendered inventory to its fixture path."
  @spec write!(lane()) :: :ok
  def write!(lane) do
    path = path_for(lane)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, render(lane, extract(lane)))
  end

  defp normalize(rows), do: rows |> Enum.uniq() |> Enum.sort()

  defp remove(text, regex), do: Regex.replace(regex, text, "")

  # -- library lane ----------------------------------------------------------

  defp library_rows(path, rel), do: library_rows_from_source(File.read!(path), rel)

  # Only the `safe_message/1` clauses of Sigra.Error are user-facing copy. The
  # exception defaults beside them are developer messages for logs.
  defp library_scope(ast, @error_file) do
    {_ast, defs} =
      Macro.prewalk(ast, [], fn
        {:def, _meta, [{:safe_message, _, _} | _]} = node, acc -> {node, [node | acc]}
        node, acc -> {node, acc}
      end)

    {:__block__, [], Enum.reverse(defs)}
  end

  defp library_scope(ast, _rel), do: ast

  defp collect_copy(ast) do
    {_ast, acc} = Macro.prewalk(ast, [], &visit/2)
    acc
  end

  # Returning `nil` as the node prunes it: its children are not visited.
  defp visit({:@, _, [{attr, _, _}]}, acc) when attr in @non_copy_attrs, do: {nil, acc}

  # `attr :x, :string, doc: "..."` documents a component for developers.
  defp visit({:doc, _text}, acc), do: {nil, acc}

  # Exception messages are for logs and developers, not shipped copy.
  defp visit({:raise, _, _}, acc), do: {nil, acc}

  defp visit({:sigil_H, _, [{:<<>>, _, [body]}, _modifiers]}, acc) when is_binary(body) do
    lines = for line <- heex_text_lines(body), do: {"heex_text", line}
    {nil, lines ++ acc}
  end

  # Every other sigil (~p paths, ~w word lists, ~r regexes) is not copy.
  defp visit({sigil, _, [{:<<>>, _, _}, _modifiers]} = node, acc) when is_atom(sigil) do
    if String.starts_with?(Atom.to_string(sigil), "sigil_"), do: {nil, acc}, else: {node, acc}
  end

  # A literal passed straight to put_flash is copy even when it is one word.
  defp visit({:put_flash, _, args} = node, acc) when is_list(args) do
    flashes = for arg <- args, is_binary(arg), do: {"literal", arg}
    {node, flashes ++ acc}
  end

  # An interpolated string is one message: keep it whole, `#{...}` included, and
  # look inside the interpolated expressions for further literals. Anything else
  # built with `<<>>` (a bitstring pattern) is not a string and is left alone.
  defp visit({:<<>>, _, parts} = node, acc) do
    if Enum.all?(parts, &string_part?/1) do
      string = Enum.map_join(parts, &interpolation_source/1)

      inner =
        for {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [expr]}, _]} <- parts,
            reduce: [],
            do: (found -> collect_copy(expr) ++ found)

      {nil, inner ++ literal_rows(string) ++ acc}
    else
      {node, acc}
    end
  end

  defp visit(string, acc) when is_binary(string), do: {string, literal_rows(string) ++ acc}
  defp visit(node, acc), do: {node, acc}

  defp string_part?(part) when is_binary(part), do: true
  defp string_part?({:"::", _, [{{:., _, [Kernel, :to_string]}, _, [_expr]}, _]}), do: true
  defp string_part?(_part), do: false

  defp interpolation_source(part) when is_binary(part), do: part

  defp interpolation_source({:"::", _, [{{:., _, [Kernel, :to_string]}, _, [expr]}, _]}) do
    "\#{" <> (expr |> Macro.to_string() |> String.replace(~r/\s*\n\s*/, " ")) <> "}"
  end

  # Prose has a letter and either a space or is a capitalized word ("Locked").
  # Lowercase single words are identifiers, event names and CSS modifiers. SVG
  # path data, strftime formats and CSS class lists also contain spaces and
  # letters, and are not copy.
  defp literal_rows(string) do
    if Regex.match?(~r/\p{L}/u, string) and
         (Regex.match?(~r/\s/u, string) or Regex.match?(~r/^\p{Lu}\p{Ll}+$/u, string)) and
         not svg_path?(string) and not strftime?(string) and not css_classes?(string) do
      [{"literal", string}]
    else
      []
    end
  end

  defp svg_path?(string) do
    Regex.match?(~r/\d/, string) and
      Regex.match?(~r/^[MmLlHhVvCcSsQqTtAaZz][\dMmLlHhVvCcSsQqTtAaZz\s.,+-]*$/, string)
  end

  defp strftime?(string), do: Regex.match?(~r/%[A-Za-z]/, string)

  # Every token is a lowercase hyphenated or underscored identifier, e.g. `sg-tabs__tab`.
  defp css_classes?(string) do
    string
    |> String.split()
    |> Enum.all?(&Regex.match?(~r/^[a-z][a-z0-9]*(?:[-_]+[a-z0-9]+)+$/, &1))
  end

  # -- generated lane --------------------------------------------------------

  defp template_rows(path, rel) do
    case Path.extname(path) do
      ext when ext in @elixir_template_exts ->
        code = path |> File.read!() |> strip_comments_and_docs()

        msgids = for [_, msgid] <- Regex.scan(@msgid_regex, code), do: {rel, "msgid", msgid}
        flashes = for [_, text] <- Regex.scan(@flash_regex, code), do: {rel, "flash", text}

        msgids ++ flashes ++ heex_rows(rel, code) ++ email_rows(rel, code)

      ext when ext in @unextracted_template_exts ->
        []

      ext ->
        raise ArgumentError,
              "unclassified installer template file type #{inspect(ext)}: #{rel}. " <>
                "Classify it in #{inspect(__MODULE__)} before the inventory can claim coverage."
    end
  end

  # Comments and doc attributes are not shipped copy. A heredoc line that starts
  # with an interpolation (`#{...}`) is code, not a comment.
  defp strip_comments_and_docs(text) do
    text |> remove(@doc_heredoc) |> remove(@doc_line) |> remove(@comment_line)
  end

  defp heex_rows(rel, code) do
    for [_, body] <- Regex.scan(@heex_sigil, code),
        line <- heex_text_lines(body),
        do: {rel, "heex_text", line}
  rescue
    error in ArgumentError ->
      reraise ArgumentError, "#{rel}: #{Exception.message(error)}", __STACKTRACE__
  end

  # Email builders: multi-word quoted literals that are not already a msgid. The
  # copy itself is almost entirely `dgettext("sigra", ...)`, captured above; this
  # catches the literal fallbacks that sit beside it.
  defp email_rows(rel, code) do
    if email_template?(rel) do
      code
      |> remove(@heredoc_block)
      |> remove(@attribute_line)
      |> remove(@dgettext_head)
      |> then(&Regex.scan(@quoted_literal, &1))
      |> Enum.map(fn [_, text] -> text end)
      |> Enum.filter(&email_copy?/1)
      |> Enum.map(&{rel, "email_text", &1})
    else
      []
    end
  end

  defp email_template?(rel) do
    base = Path.basename(rel, ".ex")
    base == "emails" or String.ends_with?(base, "_email")
  end

  # At least two alphabetic words, and not interpolated code, an EEx tag or a
  # strftime format string.
  defp email_copy?(text) do
    Regex.match?(~r/[[:alpha:]]+\s+[[:alpha:]]+/u, text) and
      not String.contains?(text, ["\#{", "<%"]) and
      not Regex.match?(~r/%[A-Za-z]/, text)
  end

  defp noise_line?(line) do
    line |> remove(@html_entity) |> String.match?(~r/^[^\p{L}\p{N}]*$/u)
  end

  # Text scanner over a HEEx body: copies text, consumes tags and `{...}`.
  defp scan_text(<<>>, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp scan_text(<<"<", next, rest::binary>>, acc)
       when next in ?a..?z or next in ?A..?Z or next in [?/, ?., ?:] do
    scan_text(skip_tag(rest), acc)
  end

  defp scan_text(<<"{", rest::binary>>, acc), do: scan_text(skip_braces(rest, 1), acc)
  defp scan_text(<<char::utf8, rest::binary>>, acc), do: scan_text(rest, [<<char::utf8>> | acc])

  defp skip_tag(<<>>), do: raise(ArgumentError, "unterminated HEEx tag")
  defp skip_tag(<<">", rest::binary>>), do: rest

  defp skip_tag(<<quote, rest::binary>>) when quote in [?", ?'],
    do: rest |> skip_quoted(quote) |> skip_tag()

  defp skip_tag(<<"{", rest::binary>>), do: rest |> skip_braces(1) |> skip_tag()
  defp skip_tag(<<_char, rest::binary>>), do: skip_tag(rest)

  defp skip_quoted(<<>>, _quote), do: raise(ArgumentError, "unterminated quoted attribute value")
  defp skip_quoted(<<quote, rest::binary>>, quote), do: rest
  defp skip_quoted(<<_char, rest::binary>>, quote), do: skip_quoted(rest, quote)

  defp skip_braces(<<>>, _depth), do: raise(ArgumentError, "unterminated HEEx expression")
  defp skip_braces(<<"}", rest::binary>>, 1), do: rest
  defp skip_braces(<<"}", rest::binary>>, depth), do: skip_braces(rest, depth - 1)
  defp skip_braces(<<"{", rest::binary>>, depth), do: skip_braces(rest, depth + 1)
  defp skip_braces(<<"\"", rest::binary>>, depth), do: rest |> skip_string() |> skip_braces(depth)
  defp skip_braces(<<_char, rest::binary>>, depth), do: skip_braces(rest, depth)

  defp skip_string(<<>>), do: raise(ArgumentError, "unterminated string in HEEx expression")
  defp skip_string(<<"\\", _escaped, rest::binary>>), do: skip_string(rest)
  defp skip_string(<<"\"", rest::binary>>), do: rest
  defp skip_string(<<"\#{", rest::binary>>), do: rest |> skip_braces(1) |> skip_string()
  defp skip_string(<<_char, rest::binary>>), do: skip_string(rest)

  defp color_token?(value), do: Regex.match?(@hex_color, value)

  defp escape(string) do
    String.replace(string, ["\\", "\t", "\n", "\r"], fn
      "\\" -> "\\\\"
      "\t" -> "\\t"
      "\n" -> "\\n"
      "\r" -> "\\r"
    end)
  end

  defp unescape(string) do
    Regex.replace(~r/\\(.)/su, string, fn whole, char ->
      case char do
        "t" -> "\t"
        "n" -> "\n"
        "r" -> "\r"
        "\\" -> "\\"
        _other -> whole
      end
    end)
  end
end
