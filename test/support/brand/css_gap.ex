defmodule Sigra.Test.Brand.CssGap do
  @moduledoc """
  Test-only coverage check for the shipped admin CSS (BGEN-04).

  Library-owned admin markup and the generated admin shell emit `sg-*` classes.
  A host gets styling from the one stylesheet the installer copies,
  `priv/templates/sigra.install/admin/sigra_admin.css`. Any class that markup
  emits without a selector in that stylesheet can render unstyled in a generated
  host, even when the example app looks correct because it carries extra CSS.

  This module extracts the emitted and defined class sets, computes their gap,
  and provides a coverage check. `gap/2` and `check_coverage/2` are pure so a
  planted missing class proves the regression check can fail.

  The repository root comes from `__DIR__`, never the working directory.
  """

  @root Path.expand("../../..", __DIR__)
  @admin_css "priv/templates/sigra.install/admin/sigra_admin.css"
  # Directories are walked with a wildcard; binaries (svg, png) and non-UTF-8
  # files are skipped.
  @markup_roots ["lib/sigra/admin/**/*", "priv/templates/sigra.install/admin/**/*"]

  @doc "Classes the markup emits that the shipped stylesheet does not define, sorted."
  @spec undefined_classes() :: [String.t()]
  def undefined_classes, do: gap(used_classes(), defined_classes())

  @doc "The undefined set for a used set and a defined set, sorted as used minus defined."
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
    |> Enum.flat_map(fn text -> markup_classes(text) ++ helper_string_classes(text) end)
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

  @doc "`:ok` when every used class has a shipped selector; otherwise an error listing the gap."
  @spec check_coverage(Enumerable.t(), Enumerable.t()) :: :ok | {:error, String.t()}
  def check_coverage(used, defined) do
    case gap(used, defined) do
      [] ->
        :ok

      missing ->
        {:error,
         "the shipped admin CSS does not define #{length(missing)} emitted class(es): " <>
           "#{Enum.join(missing, ", ")}. Define them in priv/templates/sigra.install/admin/sigra_admin.css."}
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

  # Helper functions often return class strings that appear inside a string
  # literal passed to a dynamic `class={...}` attribute, which the markup
  # extractor cannot see. Scan quoted source strings too; the token boundary
  # deliberately excludes `--sg-*` design tokens.
  defp helper_string_classes(text) do
    token = ~r/(?<![A-Za-z0-9_-])sg-[A-Za-z0-9_-]*/

    ~r/"([^"]*)"/s
    |> Regex.scan(text)
    |> Enum.flat_map(fn [_whole, string] -> Regex.scan(token, string) end)
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
