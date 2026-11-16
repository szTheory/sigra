defmodule Sigra.Test.Brand.CssGap do
  @moduledoc """
  Test-only measure of the shipped-CSS gap (BGEN-04, planning decision OQ2).

  Library-owned admin markup (`lib/sigra/admin/**`) and the generated admin shell
  (`priv/templates/sigra.install/admin/**`) emit `sg-*` classes. A host gets its
  styling from the one stylesheet the installer copies,
  `priv/templates/sigra.install/admin/sigra_admin.css`. Any class the markup
  emits that this file does not define renders unstyled in a generated host, even
  though the example application (which carries its own `app.css`) looks fine.

  This module computes that set:

    * `used_classes/0` - `sg-*` tokens inside `class="..."` / `class={...}`
      attributes of the markup roots.
    * `defined_classes/0` - `.sg-*` selectors in the shipped stylesheet.
    * `undefined_classes/0` - `gap/2` of the two.

  The committed baseline `test/fixtures/brand/css-undefined-classes.txt` records
  today's undefined set. It is shrink-only, the opposite direction of the
  frozen-surface ratchet (which is add-only over names): `check_growth/2` fails
  when a class is undefined but not in the baseline, and `check_stale/2` fails
  when a baseline entry has become defined, so the file can only get shorter.

  `gap/2`, `check_growth/2` and `check_stale/2` are pure so the controls in the
  test can plant a class into either side in memory and watch the check fail.

  Nothing here evaluates repo content, and the repo root comes from `__DIR__`,
  never the working directory.
  """

  @root Path.expand("../../..", __DIR__)
  @admin_css "priv/templates/sigra.install/admin/sigra_admin.css"
  @baseline "test/fixtures/brand/css-undefined-classes.txt"
  # Directories are walked with a wildcard; binaries (svg, png) and non-UTF-8
  # files are skipped.
  @markup_roots ["lib/sigra/admin/**/*", "priv/templates/sigra.install/admin/**/*"]

  @doc "Repo-relative path of the committed shrink-only baseline."
  @spec baseline_path() :: String.t()
  def baseline_path, do: @baseline

  @doc """
  Classes the markup emits that the shipped stylesheet does not define, sorted.
  """
  @spec undefined_classes() :: [String.t()]
  def undefined_classes, do: gap(used_classes(), defined_classes())

  @doc """
  The undefined set for a used set and a defined set (any enumerables of class
  names), as a sorted list: `used - defined`.
  """
  @spec gap(Enumerable.t(), Enumerable.t()) :: [String.t()]
  def gap(used, defined) do
    used
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(defined))
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc "`sg-*` classes emitted by the library and generated-shell markup."
  @spec used_classes() :: MapSet.t(String.t())
  def used_classes do
    @markup_roots
    |> repo_texts()
    |> Enum.flat_map(&markup_classes/1)
    |> MapSet.new()
  end

  @doc "`sg-*` classes with a selector in the shipped `sigra_admin.css`."
  @spec defined_classes() :: MapSet.t(String.t())
  def defined_classes do
    @root
    |> Path.join(@admin_css)
    |> File.read!()
    |> css_selectors()
    |> MapSet.new()
  end

  @doc """
  The committed baseline: one class per line, blank lines and `#` comments
  ignored. Returned in file order so the test can check it is sorted.
  """
  @spec baseline() :: [String.t()]
  def baseline do
    @root
    |> Path.join(@baseline)
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end

  @doc """
  `:ok` when every undefined class is already in the baseline; otherwise an error
  naming the classes the undefined set has grown by.
  """
  @spec check_growth(Enumerable.t(), Enumerable.t()) :: :ok | {:error, String.t()}
  def check_growth(baseline, undefined) do
    case gap(undefined, baseline) do
      [] ->
        :ok

      grown ->
        {:error,
         "the shipped-CSS gap grew by #{length(grown)} class(es): #{Enum.join(grown, ", ")}. " <>
           "Define them in priv/templates/sigra.install/admin/sigra_admin.css; do not add them to #{@baseline}."}
    end
  end

  @doc """
  `:ok` when every baseline entry is still undefined; otherwise an error naming
  the entries to remove, so the baseline can only shrink.
  """
  @spec check_stale(Enumerable.t(), Enumerable.t()) :: :ok | {:error, String.t()}
  def check_stale(baseline, undefined) do
    case gap(baseline, undefined) do
      [] ->
        :ok

      stale ->
        {:error,
         "remove from baseline (#{@baseline}): #{Enum.join(stale, ", ")}. " <>
           "These classes are now defined in the shipped stylesheet, so the baseline must shrink."}
    end
  end

  # -- extraction (copied from the frozen-surface test, which keeps its own private) --

  # `.sg-name` selectors; the leading dot is dropped so a class has the same
  # spelling in CSS and in markup.
  defp css_selectors(css) do
    ~r/\.(sg-[A-Za-z0-9_-]*)/
    |> Regex.scan(css)
    |> Enum.map(fn [_whole, captured] -> captured end)
  end

  # Class names inside `class="..."` and `class={...}` attributes. Tokens ending
  # in a hyphen are interpolation fragments (for example `sg-metric-` before a
  # `\#{...}`), not class names, and are dropped.
  defp markup_classes(text) do
    token = ~r/(?<![A-Za-z0-9_-])sg-[A-Za-z0-9_-]*/

    ~r/class=(?:"([^"]*)"|\{(.*?)\})/s
    |> Regex.scan(text)
    |> Enum.flat_map(fn [_whole | groups] -> groups end)
    |> Enum.flat_map(&Regex.scan(token, &1))
    |> Enum.map(&hd/1)
    |> Enum.reject(&String.ends_with?(&1, "-"))
  end

  # Text of every UTF-8 regular file under the given wildcards, sorted by path.
  defp repo_texts(globs) do
    globs
    |> Enum.flat_map(&Path.wildcard(Path.join(@root, &1), match_dot: true))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.filter(&File.regular?/1)
    |> Enum.reject(&String.ends_with?(&1, [".svg", ".png"]))
    |> Enum.map(&File.read!/1)
    |> Enum.filter(&String.valid?/1)
  end
end
