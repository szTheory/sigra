defmodule Sigra.Test.Brand.CopyInventory do
  @moduledoc """
  Test-only extractors, renderer and differ for the per-lane copy inventory
  (BCOPY-04).

  Sigra ships user-visible copy in three ownership lanes. Each lane has a
  committed inventory under `test/fixtures/brand/copy-inventory/<lane>.tsv`:

    * `:host` - `Sigra.Branding.Profile` default strings, plus one row stating
      that host-owned CSS and logos carry no Sigra copy.
    * `:generated` - copy in the installer templates under
      `priv/templates/sigra.install/`.
    * `:library` - copy in the library-owned admin LiveViews and components.

  A row is `{file, kind, string}`: a repo-relative file (or a lane note), the
  kind of copy it is, and the string itself. There are no line numbers, so
  moving code inside a file does not churn the inventory. Rows are sorted and
  unique.

  Nothing here evaluates repo content. Valid Elixir is read with
  `Code.string_to_quoted/2` and templates are read with regular expressions.
  Regeneration is opt-in: set `SIGRA_BRAND_COPY=regen` and run the inventory
  test, then review the resulting TSV diff.
  """

  alias Sigra.Branding.Profile

  @root Path.expand("../../..", __DIR__)
  @fixture_dir "test/fixtures/brand/copy-inventory"
  @regen_env "SIGRA_BRAND_COPY"
  @regen_command "SIGRA_BRAND_COPY=regen mix test test/sigra/brand/copy_inventory_test.exs"

  @profile_file "lib/sigra/branding/profile.ex"
  @host_note_file "(host-owned CSS and logos)"
  @host_note "no Sigra copy by design: host-owned CSS and logos carry no Sigra copy, and the Tasklane demo app is out of lane"
  @hex_color ~r/^#[0-9a-fA-F]{6}$/

  @type lane :: :host
  @type row :: {file :: String.t(), kind :: String.t(), string :: String.t()}

  @doc "Lanes that have a committed inventory."
  @spec lanes() :: [lane()]
  def lanes, do: [:host]

  @doc "True only when the opt-in regeneration environment variable is `regen`."
  @spec regenerate?() :: boolean()
  def regenerate?, do: System.get_env(@regen_env) == "regen"

  @doc "The exact command a maintainer runs to regenerate every inventory."
  @spec regen_command() :: String.t()
  def regen_command, do: @regen_command

  @doc "Absolute path of a lane's committed inventory."
  @spec path_for(lane()) :: Path.t()
  def path_for(lane) when lane in [:host] do
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

  def extract(lane) do
    raise ArgumentError, "unknown copy inventory lane: #{inspect(lane)}"
  end

  @doc """
  Renders a lane's rows as TSV text, with `#`-prefixed header lines that state
  the purpose, the lane and the regeneration command.
  """
  @spec render(lane(), [row()]) :: String.t()
  def render(lane, rows) do
    header =
      [
        "# #{@fixture_dir}/#{lane}.tsv - copy inventory, #{lane} lane",
        "#",
        "# WHY THIS FILE EXISTS",
        "# Every user-visible string Sigra ships in this ownership lane. A copy change shows up",
        "# as a reviewed diff of this file instead of passing silently. The inventory test",
        "# asserts this file equals a fresh extraction of the sources, exactly.",
        "#",
        "# FORMAT",
        "# file<TAB>kind<TAB>string. Sorted, unique, no line numbers. A tab, newline, carriage",
        "# return or backslash inside a string is written as \\t, \\n, \\r or \\\\.",
        "# Lines starting with '#' are skipped on read.",
        "#",
        "# DO NOT HAND-EDIT. Regenerate with:",
        "#   #{@regen_command}"
      ]

    body = for {file, kind, string} <- rows, do: Enum.join([file, kind, escape(string)], "\t")

    Enum.join(header ++ body, "\n") <> "\n"
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

  @doc "Writes a lane's freshly extracted and rendered inventory to its fixture path."
  @spec write!(lane()) :: :ok
  def write!(lane) do
    path = path_for(lane)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, render(lane, extract(lane)))
  end

  defp normalize(rows), do: rows |> Enum.uniq() |> Enum.sort()

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
