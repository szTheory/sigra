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

  Nothing here evaluates repo content.
  """

  @root Path.expand("../../..", __DIR__)
  @brand_json "brand/brand.json"
  @baseline_path "test/fixtures/brand/copy-baseline.json"
  @schema_version "sigra.brand-copy-baseline/v1"
  @init_env "SIGRA_BRAND_COPY_BASELINE"
  @init_command "SIGRA_BRAND_COPY_BASELINE=init mix test test/sigra/brand/copy_contract_test.exs"

  @scopes [:lexicon]

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
  """
  @spec files_for(atom()) :: [String.t()]
  def files_for(:lexicon) do
    @markdown_globs
    |> Enum.flat_map(&Path.wildcard(Path.join(@root, &1)))
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, @root))
    |> Enum.sort()
  end

  @doc """
  Scans in-memory `lines` of `file` under `scope` and returns its hits.

  Does no file I/O. For `:lexicon` the lines are Markdown: fenced code blocks
  and HTML comments are removed first, because the book's words inside a
  command or a comment are not prose. Matching is whole-word and
  case-insensitive. A line yields at most one hit per kind.
  """
  @spec scan_lines(atom(), String.t(), [String.t()]) :: [hit()]
  def scan_lines(:lexicon, file, lines) do
    rules = [{"lexicon", lexicon_regexes()}]

    lines
    |> prose_lines()
    |> Enum.flat_map(&line_hits(:lexicon, file, &1, rules))
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
end
