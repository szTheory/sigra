defmodule Sigra.Test.Brand.CopyScan do
  @moduledoc """
  Test-only scanner behind `Sigra.Brand.CopyContractTest` (BCOPY-02).

  It reads a scope's files, reduces them to the text a person would read, and
  matches that text against the brand book's wording rules. A match is a *hit*:

      %{scope: "lexicon", kind: "lexicon", file: "README.md", line: "..."}

  `scope` names the scanned surface and `kind` names the rule that matched:

    * `"lexicon"` - a word or phrase from the book's "Do not say" list
      (`brand/brand.json`, `messaging.boilerplate`). Read at call time, never
      retyped, so the pinned book is the single source.
    * `"banned_term"` - a term banned inside one scope.

  Hits carry no line numbers: `line` is the matched text, trimmed and with
  whitespace collapsed (case is kept, matching is case-insensitive). Moving
  code or prose inside a file therefore does not churn the committed baseline.

  ## Baseline

  `test/fixtures/brand/copy-baseline.json` lists the hits that exist today and
  are accepted (the repo's own negations such as "not a hosted service"). It is
  shrink-only: `diff_baseline/2` reports a hit that is not in the baseline as
  new, and a baseline entry with no matching hit as stale. Both fail the test.
  Initialization is opt-in (`SIGRA_BRAND_COPY_BASELINE=init`), writes entries
  only for scopes that are not yet in `initialized_scopes`, and records them
  there. No code path rewrites, shrinks or re-initializes an initialized scope.

  ## Scopes

    * `:lexicon` - `README.md`, `guides/introduction/*.md`, `guides/flows/*.md`.
      Lexicon only, over Markdown prose.
    * `:admin` - the nine admin chrome files the glossary guard watches plus the
      shipped admin templates. The glossary terms, the brand book's phrase-level
      avoid-words and the phrase "admin (operator)" are banned, and so is the
      lexicon.
    * `:generated` - `priv/templates/sigra.install/**` (`.ex`, `.eex`, `.heex`).
      "log in", "log out", "login", "logout", "signin" and "admin (operator)"
      are banned as *copy*, and so is the lexicon.

  For the two code scopes the text is reduced to *copy segments* before any
  matching: string literals, HEEx text nodes (including the string literals
  inside `{...}` expressions) and the values of the `aria-label`, `title`,
  `placeholder`, `label`, `alt` and `action` attributes. Identifiers, function
  names, route paths (`/users/log_in`, `~p"..."`), atoms (telemetry names such as
  `[:sigra, :auth, :logout, :stop]`), comments, `@doc`/`@moduledoc` text and
  every other attribute are never matched. The admin scope keeps the glossary
  guard's carve-out for the auth-replica preview block.

  Source is read with a small purpose-built scanner. Nothing here evaluates repo
  content, and a source it cannot read (an unterminated string, tag or
  expression) raises naming the file instead of being skipped.
  """

  @root Path.expand("../../..", __DIR__)
  @brand_json "brand/brand.json"
  @baseline_path "test/fixtures/brand/copy-baseline.json"
  @schema_version "sigra.brand-copy-baseline/v1"
  @init_env "SIGRA_BRAND_COPY_BASELINE"
  @init_command "SIGRA_BRAND_COPY_BASELINE=init mix test test/sigra/brand/copy_contract_test.exs"

  @scopes [:lexicon, :admin, :generated]

  @admin_files [
    "lib/sigra/admin/live/index_live.ex",
    "lib/sigra/admin/live/organization_live.ex",
    "lib/sigra/admin/live/users_index_live.ex",
    "lib/sigra/admin/live/user_show_live.ex",
    "lib/sigra/admin/live/user_sessions_live.ex",
    "lib/sigra/admin/live/branding_live.ex",
    "lib/sigra/admin/live/audit_index_live.ex",
    "lib/sigra/admin/live/audit_user_live.ex",
    "lib/sigra/admin/components.ex"
  ]
  @templates_dir "priv/templates/sigra.install"
  @code_exts "{ex,eex,heex}"

  # Attribute values that are visible copy. Every other attribute is markup.
  @copy_attrs ~w(aria-label title placeholder label alt action)

  # The admin chrome shows a replica of the host's sign-in screen. Its copy is
  # the host's, so the glossary guard exempts it and so does this scanner.
  @preview_marker "sigra-auth sigra-auth--preview"

  # The glossary guard's terms (test/sigra/admin/glossary_test.exs), adapted.
  # Each entry is `{regex, canonical, description}`.
  @glossary_terms [
    {"\\blog\\s+in\\b", "sign in", "log in (verb)"},
    {"\\blog\\s+out\\b", "sign out", "log out (verb)"},
    {"\\blogout\\b", "sign out", "logout"},
    {"\\bsignin\\b", "sign in", "signin"},
    {"\\bsign\\s+off\\b", "sign out", "sign off"},
    {"\\blogin\\b", "sign-in", "login (noun or modifier)"},
    {"\\blogins\\b", "sessions", "logins (plural noun)"},
    {"\\borg\\b", "organization", "org (abbreviation, use the full word in visible copy)"},
    {"\\bteammates?\\b", "member(s)", "teammate(s)"},
    {"\\bcollaborators?\\b", "member(s)", "collaborator(s)"},
    {"\\bseat\\b", "member", "seat (as person-noun)"}
  ]

  # The generated templates are host-owned auth screens and emails: only the
  # sign-in vocabulary the book retires applies there.
  @generated_terms [
    {"\\blog\\s+in\\b", "sign in", "log in (verb)"},
    {"\\blog\\s+out\\b", "sign out", "log out (verb)"},
    {"\\blogout\\b", "sign out", "logout"},
    {"\\blogin\\b", "sign-in", "login (noun or modifier)"},
    {"\\bsignin\\b", "sign in", "signin"}
  ]

  @operator_term {"\\badmin\\s*\\(operator\\)", "Admin",
                  "admin (operator): the brand book rules plain Admin"}

  # Words from `voice.terms[].avoid` that are ordinary English and would flood
  # the baseline with noise. They are intentionally NOT banned as terms:
  #
  #   delete, cancel   verbs used legitimately on every destructive action
  #   disable          "Disable two-factor" is correct product copy
  #   group, scope     generic nouns ("scope" also names OAuth scopes)
  #   target, subject  "subject" is an email field, "target" an HTML attribute
  #   suspend          canonical in another row of the same table
  #   host, consumer   "host" is a hostname and a technical word in every doc
  #
  # Entries that carry a parenthetical qualifier ("account (as a person)",
  # "remove (for the user)", "WebAuthn (in screens)", "recovery codes
  # (unchecked)") are contextual rules a regex cannot honour, so they are
  # skipped as well.
  @generic_avoid ~w(delete cancel disable group scope target subject suspend host consumer)

  @code_scopes [:admin, :generated]
  @doc_attr ~r/\A(?:moduledoc|doc|typedoc)[ \t]+/
  @eex_installer_tag ~r/<%(?!%).*?%>/s

  @markdown_globs ["README.md", "guides/introduction/*.md", "guides/flows/*.md"]

  @fenced_block ~r/^[ \t]*(`{3,}|~{3,})[^\n]*\n.*?^[ \t]*\1[ \t]*$/ms
  @html_comment ~r/<!--.*?-->/s

  @type hit :: %{
          scope: String.t(),
          kind: String.t(),
          file: String.t(),
          line: String.t()
        }
  @type baseline :: %{initialized_scopes: [String.t()], entries: [hit()]}

  @doc "Scopes this scanner implements, in the order they were added."
  @spec scopes() :: [atom()]
  def scopes, do: @scopes

  @doc "Absolute path of the committed baseline."
  @spec baseline_path() :: Path.t()
  def baseline_path, do: Path.join(@root, @baseline_path)

  @doc """
  The book's "Do not say" words and phrases, read from `brand/brand.json`.

  Takes the first sentence of the `messaging.boilerplate` row labelled
  "Do not say" (the rest of the row explains the rule), drops quotation marks
  and splits it into lowercase terms. Raises if the row is missing, so a
  restructured book cannot silently empty the lexicon.
  """
  @spec lexicon_words() :: [String.t()]
  def lexicon_words do
    row =
      @root
      |> Path.join(@brand_json)
      |> File.read!()
      |> JSON.decode!()
      |> get_in(["messaging", "boilerplate"])
      |> Enum.find(&match?(["Do not say" | _], &1))

    case row do
      [_label, text] ->
        [sentence | _] = String.split(text, ~r/\.\s/, parts: 2)

        sentence
        |> String.replace(["“", "”", "\""], "")
        |> String.split(~r/,\s*|\s+or\s+/u, trim: true)
        |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
        |> Enum.reject(&(&1 == ""))

      nil ->
        raise ArgumentError, "#{@brand_json} messaging.boilerplate has no \"Do not say\" row"
    end
  end

  @doc """
  Repo-relative files a scope scans, sorted.

  `:lexicon` is `README.md`, `guides/introduction/*.md` and `guides/flows/*.md`.
  `:admin` is the nine admin chrome files plus the shipped admin templates under
  `priv/templates/sigra.install/admin/`. `:generated` is every `.ex`, `.eex` and
  `.heex` file under `priv/templates/sigra.install/`; CSS, SVG, JS and JSON files
  carry no scanned copy.
  """
  @spec files_for(atom()) :: [String.t()]
  def files_for(:lexicon) do
    @markdown_globs |> Enum.flat_map(&wildcard/1) |> Enum.sort()
  end

  def files_for(:admin) do
    templates = wildcard("#{@templates_dir}/admin/**/*.#{@code_exts}")
    Enum.sort(@admin_files ++ templates)
  end

  def files_for(:generated) do
    "#{@templates_dir}/**/*.#{@code_exts}" |> wildcard() |> Enum.sort()
  end

  @doc """
  The banned terms of a code scope as `{regex, canonical, description}`.

  `:generated` bans the sign-in vocabulary the book retires. `:admin` adds the
  glossary guard's terms, the phrase-level avoid-words from
  `brand/brand.json` `voice.terms[].avoid` (read at call time, minus the
  ordinary-English words listed in the source) and "admin (operator)".
  """
  @spec banned_terms(atom()) :: [{Regex.t(), String.t(), String.t()}]
  def banned_terms(:generated), do: compile_terms(@generated_terms ++ [@operator_term])

  def banned_terms(:admin) do
    compile_terms(@glossary_terms ++ [@operator_term]) ++ avoid_terms()
  end

  @doc """
  Scans in-memory `lines` of `file` under `scope` and returns its hits.

  Does no file I/O. For `:lexicon` the lines are Markdown: fenced code blocks
  and HTML comments are removed first, because the book's words inside a
  command or a comment are not prose. For `:admin` and `:generated` the lines
  are Elixir or HEEx source, reduced to copy segments first (see the module
  doc); a file under `priv/templates/` also has its installer EEx tags
  (`<%= ... %>`) removed. Matching is whole-word and case-insensitive. A copy
  segment or prose line yields at most one hit per kind.
  """
  @spec scan_lines(atom(), String.t(), [String.t()]) :: [hit()]
  def scan_lines(:lexicon, file, lines) do
    rules = [{"lexicon", lexicon_regexes()}]

    lines
    |> prose_lines()
    |> Enum.flat_map(&line_hits(:lexicon, file, &1, rules))
  end

  def scan_lines(scope, file, lines) when scope in @code_scopes do
    rules = [
      {"banned_term", for({regex, _canonical, _description} <- banned_terms(scope), do: regex)},
      {"lexicon", lexicon_regexes()}
    ]

    scope
    |> copy_segments(file, lines)
    |> Enum.flat_map(&line_hits(scope, file, &1, rules))
  end

  @doc """
  The copy segments of in-memory `lines` of `file` for a code scope (`:admin` or
  `:generated`): exactly the text `scan_lines/3` matches against, trimmed and
  whitespace-collapsed, in source order. Does no file I/O.

  Raises `ArgumentError` naming `file` when the source has an unterminated
  string, heredoc, tag or expression.
  """
  @spec copy_segments(atom(), String.t(), [String.t()]) :: [String.t()]
  def copy_segments(scope, file, lines) when scope in @code_scopes do
    ctx = %{
      carve_out: scope == :admin,
      installer_tags: String.starts_with?(file, "priv/templates/")
    }

    lines |> Enum.join("\n") |> segments(file, ctx)
  end

  @doc "Scans every real file of `scope` and returns its hits, sorted and with duplicates kept."
  @spec scan(atom()) :: [hit()]
  def scan(scope) when scope in @scopes do
    scope
    |> files_for()
    |> Enum.flat_map(fn file ->
      lines = @root |> Path.join(file) |> File.read!() |> String.split("\n")
      scan_lines(scope, file, lines)
    end)
    |> Enum.sort_by(&hit_key/1)
  end

  @doc """
  Normalizes matched text for the baseline: trimmed, every run of whitespace
  collapsed to one space. No line number is ever part of it.
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  @doc """
  Reads the committed baseline. A missing file is an empty, uninitialized
  baseline. A different `schema_version` raises.
  """
  @spec load_baseline() :: baseline()
  def load_baseline do
    path = baseline_path()

    if File.regular?(path) do
      data = path |> File.read!() |> JSON.decode!()

      if data["schema_version"] != @schema_version do
        raise ArgumentError,
              "#{@baseline_path}: schema_version #{inspect(data["schema_version"])}, expected #{inspect(@schema_version)}"
      end

      %{
        initialized_scopes: Map.fetch!(data, "initialized_scopes"),
        entries:
          for entry <- Map.fetch!(data, "entries") do
            %{
              scope: entry["scope"],
              kind: entry["kind"],
              file: entry["file"],
              line: entry["line"]
            }
          end
      }
    else
      %{initialized_scopes: [], entries: []}
    end
  end

  @doc """
  Diffs real `hits` against baseline `entries`, counting duplicates.

  Returns `[new: hits_not_in_baseline, stale: entries_without_a_hit]`. A line
  that occurs twice in one file is two hits and needs two entries, so a
  repeated violation cannot hide behind an existing one.
  """
  @spec diff_baseline([hit()], [hit()]) :: [new: [hit()], stale: [hit()]]
  def diff_baseline(hits, entries) do
    hit_counts = Enum.frequencies_by(hits, &hit_key/1)
    entry_counts = Enum.frequencies_by(entries, &hit_key/1)

    [
      new: surplus(hits, hit_counts, entry_counts),
      stale: surplus(entries, entry_counts, hit_counts)
    ]
  end

  @doc """
  Returns the baseline to write after an opt-in initialization.

  For each scope in `scopes` that is not yet in `initialized_scopes`, calls
  `scan_fun` and adds the hits as entries and the name as initialized, even
  when there are zero hits. Entries of an initialized scope are never touched,
  whatever `scan_fun` returns for it.
  """
  @spec init_baseline(baseline(), [atom()], (atom() -> [hit()])) :: baseline()
  def init_baseline(%{initialized_scopes: done, entries: entries}, scopes, scan_fun) do
    pending = for scope <- scopes, Atom.to_string(scope) not in done, do: scope

    %{
      initialized_scopes: done ++ Enum.map(pending, &Atom.to_string/1),
      entries: entries ++ Enum.flat_map(pending, scan_fun)
    }
  end

  @doc "True only when the opt-in initialization environment variable is `init`."
  @spec init_requested?() :: boolean()
  def init_requested?, do: System.get_env(@init_env) == "init"

  @doc "The exact command a maintainer runs to initialize scopes that are not initialized yet."
  @spec init_command() :: String.t()
  def init_command, do: @init_command

  @doc """
  Opt-in baseline initialization against the real files. Writes the baseline
  only when at least one scope is not initialized yet; otherwise it does nothing.
  """
  @spec init_baseline!() :: :ok
  def init_baseline! do
    current = load_baseline()
    next = init_baseline(current, @scopes, &scan/1)

    if next.initialized_scopes != current.initialized_scopes do
      File.mkdir_p!(Path.dirname(baseline_path()))
      File.write!(baseline_path(), render_baseline(next.initialized_scopes, next.entries))
    end

    :ok
  end

  @doc """
  Renders a baseline deterministically: sorted keys, two-space indent, one key
  per line, `initialized_scopes` sorted with one name per line, and each entry
  on ONE line as an inline object with sorted keys, so a line-oriented grep or
  diff counts real entries. The stdlib `JSON` module only emits compact
  single-line JSON, so it is used here for scalar leaves only.
  """
  @spec render_baseline([String.t()], [hit()]) :: String.t()
  def render_baseline(initialized_scopes, entries) do
    entry_lines =
      entries
      |> Enum.sort_by(&hit_key/1)
      |> Enum.map(&("    " <> entry_json(&1)))

    scope_lines =
      initialized_scopes
      |> Enum.sort()
      |> Enum.map(&("    " <> JSON.encode!(&1)))

    [
      "{",
      "  \"entries\": " <> array(entry_lines) <> ",",
      "  \"initialized_scopes\": " <> array(scope_lines) <> ",",
      "  \"schema_version\": " <> JSON.encode!(@schema_version),
      "}"
    ]
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  # -- baseline rendering ----------------------------------------------------

  defp array([]), do: "[]"
  defp array(lines), do: "[\n" <> Enum.join(lines, ",\n") <> "\n  ]"

  defp entry_json(entry) do
    fields =
      for key <- [:file, :kind, :line, :scope] do
        JSON.encode!(Atom.to_string(key)) <> ": " <> JSON.encode!(Map.fetch!(entry, key))
      end

    "{" <> Enum.join(fields, ", ") <> "}"
  end

  # -- matching --------------------------------------------------------------

  defp hit_key(hit), do: {hit.scope, hit.file, hit.kind, hit.line}

  # The items of `items` whose key occurs more often than in `other_counts`,
  # once per surplus occurrence.
  defp surplus(items, counts, other_counts) do
    items
    |> Enum.uniq_by(&hit_key/1)
    |> Enum.flat_map(fn item ->
      key = hit_key(item)
      extra = Map.fetch!(counts, key) - Map.get(other_counts, key, 0)
      List.duplicate(item, max(extra, 0))
    end)
    |> Enum.sort_by(&hit_key/1)
  end

  # `rules` is `[{kind, [Regex]}]`. A text yields at most one hit per kind.
  defp line_hits(scope, file, text, rules) do
    for {kind, regexes} <- rules, Enum.any?(regexes, &Regex.match?(&1, text)) do
      %{scope: Atom.to_string(scope), kind: kind, file: file, line: normalize(text)}
    end
  end

  # Whole-word, case-insensitive. A space or hyphen inside a phrase matches
  # either, so "zero trust" also catches "zero-trust".
  defp lexicon_regexes do
    for word <- lexicon_words() do
      body =
        word |> String.split(~r/[\s-]+/u, trim: true) |> Enum.map_join("[\\s-]+", &Regex.escape/1)

      Regex.compile!("\\b" <> body <> "\\b", "iu")
    end
  end

  # -- Markdown --------------------------------------------------------------

  defp prose_lines(lines) do
    lines
    |> Enum.join("\n")
    |> then(&Regex.replace(@fenced_block, &1, "\n"))
    |> then(&Regex.replace(@html_comment, &1, ""))
    |> String.split("\n")
  end

  defp wildcard(pattern) do
    @root
    |> Path.join(pattern)
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, @root))
  end

  # -- banned terms ----------------------------------------------------------

  defp compile_terms(terms) do
    for {source, canonical, description} <- terms do
      {Regex.compile!(source, "iu"), canonical, description}
    end
  end

  # Phrase-level and unambiguous avoid-words from the brand book, e.g.
  # "end user", "workspace", "scaffold". Whitespace inside a phrase matches any
  # run of whitespace; a hyphen is literal, so "step-up" does not match
  # "step up".
  defp avoid_terms do
    @root
    |> Path.join(@brand_json)
    |> File.read!()
    |> JSON.decode!()
    |> get_in(["voice", "terms"])
    |> Enum.flat_map(fn %{"term" => term, "avoid" => avoid} ->
      avoid
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.contains?(&1, "(") or &1 in @generic_avoid))
      |> Enum.map(&{avoid_regex(&1), term, "brand book avoid-word: #{&1}"})
    end)
  end

  defp avoid_regex(phrase) do
    body = phrase |> String.split(~r/\s+/u, trim: true) |> Enum.map_join("\\s+", &Regex.escape/1)
    Regex.compile!("\\b" <> body <> "\\b", "iu")
  end

  # -- copy segments ---------------------------------------------------------
  #
  # A small scanner, not a parser: it only has to tell copy from everything else.
  # Each function takes the remaining binary and an accumulator of segments
  # (newest first) and returns the accumulator. An unterminated literal, tag or
  # expression raises `ArgumentError` rather than silently dropping the rest.

  defp segments(text, file, ctx) do
    text
    |> strip_installer_tags(ctx)
    |> code(ctx, [])
    |> Enum.reverse()
  rescue
    error in ArgumentError ->
      reraise ArgumentError, "#{file}: #{Exception.message(error)}", __STACKTRACE__
  end

  # Installer templates carry `<%= ... %>` tags that the installer fills in; a
  # runtime EEx tag inside a `~H` body is written `<%%= ... %>` and is kept.
  defp strip_installer_tags(text, %{installer_tags: true}),
    do: Regex.replace(@eex_installer_tag, text, "")

  defp strip_installer_tags(text, _ctx), do: text

  # Elixir source. Comments, atoms, non-copy sigils and documentation contribute
  # nothing; string literals and `~H` bodies are copy.
  defp code(<<>>, _ctx, acc), do: acc

  defp code(<<"#", rest::binary>>, ctx, acc), do: code(skip_line(rest), ctx, acc)

  defp code(<<"@", rest::binary>>, ctx, acc) do
    case Regex.run(@doc_attr, rest) do
      [head] -> code(skip_doc_value(drop(rest, head)), ctx, acc)
      nil -> code(rest, ctx, acc)
    end
  end

  # `attr :x, :string, doc: "..."` documents a component for developers.
  defp code(<<"doc:", rest::binary>>, ctx, acc) do
    code(skip_doc_value(String.trim_leading(rest, " ")), ctx, acc)
  end

  defp code(<<"~H\"\"\"", rest::binary>>, ctx, acc) do
    {body, rest} = take_heredoc(rest)
    code(rest, ctx, markup(body, :brace, ctx, acc))
  end

  defp code(<<"~H\"", rest::binary>>, ctx, acc) do
    {raw, rest} = take_string(rest)
    code(rest, ctx, markup(raw, :brace, ctx, acc))
  end

  # Every other sigil (~p paths, ~r regexes, ~w word lists, ~s) is not copy.
  defp code(<<"~", name, delimiter, rest::binary>>, ctx, acc)
       when (name in ?a..?z or name in ?A..?Z) and
              delimiter in [?", ?', ?/, ?|, ?(, ?[, ?{, ?<] do
    code(skip_sigil(delimiter, rest), ctx, acc)
  end

  # A quoted atom (`:"some name"`) is an identifier.
  defp code(<<":\"", rest::binary>>, ctx, acc) do
    {_raw, rest} = take_string(rest)
    code(rest, ctx, acc)
  end

  defp code(<<"\"\"\"", rest::binary>>, ctx, acc) do
    {body, rest} = take_heredoc(rest)
    code(rest, ctx, markup(body, :interp, ctx, acc))
  end

  defp code(<<"\"", rest::binary>>, ctx, acc) do
    {raw, rest} = take_string(rest)
    code(rest, ctx, literal(raw, ctx, acc))
  end

  defp code(<<_byte, rest::binary>>, ctx, acc), do: code(rest, ctx, acc)

  # A string literal: its text outside `#{...}` is a segment when it reads as
  # copy, and the expressions inside are scanned for further literals.
  defp literal(raw, ctx, acc) do
    {text, expressions} = split_interpolation(raw)
    acc = Enum.reduce(expressions, acc, &code(&1, ctx, &2))
    text = unescape(text)

    if copy_literal?(text), do: [normalize(text) | acc], else: acc
  end

  # Prose has a letter, is not a route or URL, and either has a space or is a
  # capitalized word ("Locked"). Lowercase single words are identifiers, event
  # names and CSS modifiers.
  defp copy_literal?(text) do
    Regex.match?(~r/\p{L}/u, text) and not route_like?(text) and
      (Regex.match?(~r/\s/u, text) or Regex.match?(~r/^\p{Lu}\p{Ll}+$/u, text))
  end

  defp route_like?(text) do
    trimmed = String.trim_leading(text)
    String.starts_with?(trimmed, "/") or Regex.match?(~r{^[a-z][a-z0-9+.-]*://}i, trimmed)
  end

  defp unescape(text) do
    text |> String.replace("\\\"", "\"") |> String.replace(~r/\\[ntr]/, " ")
  end

  defp skip_doc_value(<<"~", s, "\"\"\"", rest::binary>>) when s in [?s, ?S] do
    rest |> take_heredoc() |> elem(1)
  end

  defp skip_doc_value(<<"\"\"\"", rest::binary>>), do: rest |> take_heredoc() |> elem(1)
  defp skip_doc_value(<<"\"", rest::binary>>), do: rest |> take_string() |> elem(1)
  defp skip_doc_value(rest), do: rest

  defp skip_sigil(?", rest), do: rest |> take_string() |> elem(1)
  defp skip_sigil(delimiter, rest), do: skip_until(rest, closing(delimiter))

  defp closing(?(), do: ?)
  defp closing(?[), do: ?]
  defp closing(?{), do: ?}
  defp closing(?<), do: ?>
  defp closing(delimiter), do: delimiter

  defp skip_until(<<"\\", _escaped, rest::binary>>, close), do: skip_until(rest, close)
  defp skip_until(<<close, rest::binary>>, close), do: rest
  defp skip_until(<<_byte, rest::binary>>, close), do: skip_until(rest, close)
  defp skip_until(<<>>, _close), do: raise(ArgumentError, "unterminated sigil")

  defp skip_line(rest) do
    case :binary.split(rest, "\n") do
      [_comment, remainder] -> remainder
      [_comment] -> <<>>
    end
  end

  defp drop(binary, prefix),
    do: binary_part(binary, byte_size(prefix), byte_size(binary) - byte_size(prefix))

  # The remainder after `rest`'s opening `"""` up to the closing delimiter line.
  defp take_heredoc(rest) do
    case Regex.run(~r/\n[ \t]*"""/, rest, return: :index) do
      [{start, length}] ->
        {binary_part(rest, 0, start),
         binary_part(rest, start + length, byte_size(rest) - start - length)}

      nil ->
        raise ArgumentError, "unterminated heredoc"
    end
  end

  # The raw body of a double-quoted string (after its opening quote), keeping
  # `#{...}` interpolations whole, and what follows the closing quote.
  defp take_string(rest), do: take_string(rest, [])

  defp take_string(<<"\\", char, rest::binary>>, acc), do: take_string(rest, [acc, "\\", char])

  defp take_string(<<"\#{", rest::binary>>, acc) do
    {expression, rest} = take_balanced(rest)
    take_string(rest, [acc, "\#{", expression, "}"])
  end

  defp take_string(<<"\"", rest::binary>>, acc), do: {IO.iodata_to_binary(acc), rest}
  defp take_string(<<char, rest::binary>>, acc), do: take_string(rest, [acc, char])
  defp take_string(<<>>, _acc), do: raise(ArgumentError, "unterminated string literal")

  # The expression up to the `}` that closes an already-opened `{`, skipping
  # string literals, and what follows it.
  defp take_balanced(rest), do: take_balanced(rest, 1, [])

  defp take_balanced(<<"}", rest::binary>>, 1, acc), do: {IO.iodata_to_binary(acc), rest}

  defp take_balanced(<<"}", rest::binary>>, depth, acc),
    do: take_balanced(rest, depth - 1, [acc, "}"])

  defp take_balanced(<<"{", rest::binary>>, depth, acc),
    do: take_balanced(rest, depth + 1, [acc, "{"])

  defp take_balanced(<<"\"", rest::binary>>, depth, acc) do
    {raw, rest} = take_string(rest)
    take_balanced(rest, depth, [acc, "\"", raw, "\""])
  end

  defp take_balanced(<<char, rest::binary>>, depth, acc),
    do: take_balanced(rest, depth, [acc, char])

  defp take_balanced(<<>>, _depth, _acc), do: raise(ArgumentError, "unterminated expression")

  # Splits a raw string body into its text (interpolations removed) and the
  # expressions inside the `#{...}` interpolations.
  defp split_interpolation(raw), do: split_interpolation(raw, [], [])

  defp split_interpolation(<<"\\", char, rest::binary>>, text, expressions) do
    split_interpolation(rest, [text, "\\", char], expressions)
  end

  defp split_interpolation(<<"\#{", rest::binary>>, text, expressions) do
    {expression, rest} = take_balanced(rest)
    split_interpolation(rest, [text, " "], [expression | expressions])
  end

  defp split_interpolation(<<char, rest::binary>>, text, expressions) do
    split_interpolation(rest, [text, char], expressions)
  end

  defp split_interpolation(<<>>, text, expressions) do
    {IO.iodata_to_binary(text), Enum.reverse(expressions)}
  end

  # HEEx and heredoc bodies. `mode` says what opens an expression: `{` in a
  # `~H` body, `#{` in a plain heredoc such as an email body. Text nodes are
  # collected per line; tags, comments, `<script>`/`<style>` and EEx control
  # tags contribute nothing except the copy attributes of a tag.
  defp markup(body, mode, ctx, acc) do
    body |> remove_preview_block(ctx) |> scan_markup(mode, ctx, [], acc)
  end

  defp scan_markup(<<>>, _mode, _ctx, text, acc), do: flush(text, acc)

  defp scan_markup(<<"\n", rest::binary>>, mode, ctx, text, acc) do
    scan_markup(rest, mode, ctx, [], flush(text, acc))
  end

  defp scan_markup(<<"<!--", rest::binary>>, mode, ctx, text, acc) do
    scan_markup(skip_past(rest, "-->"), mode, ctx, text, acc)
  end

  defp scan_markup(<<"<%!--", rest::binary>>, mode, ctx, text, acc) do
    scan_markup(skip_past(rest, "--%>"), mode, ctx, text, acc)
  end

  # A runtime EEx tag: `<%= expr %>` (or `<%%= expr %>` in an installer template)
  # renders an expression, anything else is control flow.
  defp scan_markup(<<"<%", rest::binary>>, mode, ctx, text, acc) do
    {content, rest} = take_until(rest, "%>")

    acc =
      case content do
        "%=" <> expression -> code(expression, ctx, acc)
        "=" <> expression -> code(expression, ctx, acc)
        _control -> acc
      end

    scan_markup(rest, mode, ctx, [text, " "], acc)
  end

  defp scan_markup(<<"<", rest::binary>> = input, mode, ctx, text, acc) do
    case Regex.run(~r/\A<(script|style)\b.*?<\/\1>/s, input) do
      [element | _] ->
        scan_markup(drop(input, element), mode, ctx, text, acc)

      nil ->
        if Regex.match?(~r/\A[A-Za-z.:\/]/, rest) do
          {acc, rest} = take_tag(rest, ctx, acc)
          scan_markup(rest, mode, ctx, [text, " "], acc)
        else
          scan_markup(rest, mode, ctx, [text, "<"], acc)
        end
    end
  end

  defp scan_markup(<<"{", rest::binary>>, :brace, ctx, text, acc) do
    {expression, rest} = take_balanced(rest)
    scan_markup(rest, :brace, ctx, [text, " "], code(expression, ctx, acc))
  end

  defp scan_markup(<<"\#{", rest::binary>>, :interp, ctx, text, acc) do
    {expression, rest} = take_balanced(rest)
    scan_markup(rest, :interp, ctx, [text, " "], code(expression, ctx, acc))
  end

  defp scan_markup(<<char, rest::binary>>, mode, ctx, text, acc) do
    scan_markup(rest, mode, ctx, [text, char], acc)
  end

  defp flush(text, acc) do
    line = text |> IO.iodata_to_binary() |> normalize()
    if Regex.match?(~r/\p{L}/u, line), do: [line | acc], else: acc
  end

  defp skip_past(binary, marker) do
    case :binary.split(binary, marker) do
      [_skipped, rest] -> rest
      [_unterminated] -> raise ArgumentError, "unterminated #{marker} comment"
    end
  end

  defp take_until(binary, marker) do
    case :binary.split(binary, marker) do
      [before, rest] -> {before, rest}
      [_unterminated] -> raise ArgumentError, "unterminated EEx tag"
    end
  end

  # A tag, from just after its `<`. Returns the accumulator with the values of
  # its copy attributes added, and what follows the closing `>`.
  defp take_tag(rest, ctx, acc) do
    [name] = Regex.run(~r/\A[^\s>\/{]*/, rest)
    tag_attrs(drop(rest, name), ctx, acc)
  end

  defp tag_attrs(<<>>, _ctx, _acc), do: raise(ArgumentError, "unterminated tag")
  defp tag_attrs(<<">", rest::binary>>, _ctx, acc), do: {acc, rest}

  # A root attribute expression such as `{@rest}`.
  defp tag_attrs(<<"{", rest::binary>>, ctx, acc) do
    {_expression, rest} = take_balanced(rest)
    tag_attrs(rest, ctx, acc)
  end

  defp tag_attrs(rest, ctx, acc) do
    case Regex.run(~r/\A([^\s=>\/{"']+)[ \t\r\n]*=[ \t\r\n]*/, rest) do
      [head, name] ->
        {acc, rest} = attr_value(drop(rest, head), name in @copy_attrs, ctx, acc)
        tag_attrs(rest, ctx, acc)

      nil ->
        <<_byte, rest::binary>> = rest
        tag_attrs(rest, ctx, acc)
    end
  end

  defp attr_value(<<"\"", rest::binary>>, copy?, ctx, acc) do
    {raw, rest} = take_string(rest)
    {if(copy?, do: attr_literal(raw, ctx, acc), else: acc), rest}
  end

  defp attr_value(<<"{", rest::binary>>, copy?, ctx, acc) do
    {expression, rest} = take_balanced(rest)
    {if(copy?, do: code(expression, ctx, acc), else: acc), rest}
  end

  defp attr_value(<<"'", rest::binary>>, _copy?, _ctx, acc), do: {acc, skip_past(rest, "'")}

  defp attr_value(rest, _copy?, _ctx, acc) do
    [value] = Regex.run(~r/\A[^\s>]*/, rest)
    {acc, drop(rest, value)}
  end

  # The value of a copy attribute is copy whatever its shape, unless it is a route.
  defp attr_literal(raw, ctx, acc) do
    {text, expressions} = split_interpolation(raw)
    acc = Enum.reduce(expressions, acc, &code(&1, ctx, &2))
    text = unescape(text)

    if Regex.match?(~r/\p{L}/u, text) and not route_like?(text),
      do: [normalize(text) | acc],
      else: acc
  end

  # The admin chrome previews the host's sign-in screen inside a `<div>` carrying
  # `@preview_marker`; that block is the host's copy and is not scanned (the same
  # carve-out as the glossary guard). Removes the whole balanced `<div>`.
  defp remove_preview_block(body, %{carve_out: true}) do
    with {marker, _length} <- :binary.match(body, @preview_marker),
         [[{open, _}] | _] <-
           Enum.reverse(Regex.scan(~r/<div\b/, binary_part(body, 0, marker), return: :index)),
         {tag_close, _length} <-
           :binary.match(body, ">", scope: {marker, byte_size(body) - marker}) do
      close = matching_div_end(body, tag_close + 1)

      body
      |> binary_part(0, open)
      |> Kernel.<>(drop_to(body, close))
      |> remove_preview_block(%{carve_out: true})
    else
      _no_block -> body
    end
  end

  defp remove_preview_block(body, _ctx), do: body

  # Offset just past the `</div>` that balances an already-open `<div>`.
  defp matching_div_end(body, from) do
    tokens = Regex.scan(~r/<div\b|<\/div>/, body, return: :index, offset: from)

    Enum.reduce_while(tokens, 1, fn [{start, length}], depth ->
      case binary_part(body, start, length) do
        "</div>" when depth == 1 -> {:halt, {:closed, start + length}}
        "</div>" -> {:cont, depth - 1}
        _open -> {:cont, depth + 1}
      end
    end)
    |> case do
      {:closed, offset} -> offset
      _unbalanced -> raise ArgumentError, "unbalanced <div> in the auth preview block"
    end
  end

  defp drop_to(body, offset), do: binary_part(body, offset, byte_size(body) - offset)
end
