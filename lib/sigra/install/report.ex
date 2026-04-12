defmodule Sigra.Install.Report do
  @moduledoc """
  Record-as-you-go accumulator for installer decisions, rendered as
  a 4-column post-install summary (GEN-05).

  The walker threads a `Report` through every `run_feature/3` call
  and every file write, injection, and skip flows through one of the
  `record_*` functions. At the end of the walk,
  `render_summary/1` emits a stable 4-column table.

  This replaces the ad-hoc `Mix.shell().info([:yellow, "* skipping ", ...])`
  inline prints scattered through `lib/mix/tasks/sigra.install.ex`.
  """

  defstruct generated: [],
            modified: [],
            skipped: [],
            manual_actions: []

  @type skipped_entry :: %{path: Path.t(), reason: String.t()}
  @type t :: %__MODULE__{
          generated: [Path.t()],
          modified: [Path.t()],
          skipped: [skipped_entry()],
          manual_actions: [String.t()]
        }

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec record_generated(t(), Path.t()) :: t()
  def record_generated(%__MODULE__{} = r, path) when is_binary(path) do
    %{r | generated: [path | r.generated]}
  end

  @spec record_modified(t(), Path.t()) :: t()
  def record_modified(%__MODULE__{} = r, path) when is_binary(path) do
    %{r | modified: [path | r.modified]}
  end

  @spec record_skipped(t(), Path.t(), String.t()) :: t()
  def record_skipped(%__MODULE__{} = r, path, reason)
      when is_binary(path) and is_binary(reason) do
    %{r | skipped: [%{path: path, reason: reason} | r.skipped]}
  end

  @spec record_manual_action(t(), String.t()) :: t()
  def record_manual_action(%__MODULE__{} = r, instruction) when is_binary(instruction) do
    %{r | manual_actions: [instruction | r.manual_actions]}
  end

  @headers {"Generated", "Modified", "Skipped", "Manual Action"}

  @doc """
  Renders the 4-column summary table as iodata. Column order is
  `Generated | Modified | Skipped | Manual Action`. Entries within a
  column are sorted alphabetically so snapshot tests are stable.

  Column widths are padded to the maximum of (header width, longest
  entry in that column) so long paths don't break alignment. An empty
  report still emits a valid header row.
  """
  @spec render_summary(t()) :: iodata()
  def render_summary(%__MODULE__{} = r) do
    gen = Enum.sort(r.generated)
    mod = Enum.sort(r.modified)
    skip = r.skipped |> Enum.sort_by(& &1.path) |> Enum.map(&"#{&1.path} (#{&1.reason})")
    man = Enum.sort(r.manual_actions)

    columns = [gen, mod, skip, man]
    {h1, h2, h3, h4} = @headers
    headers = [h1, h2, h3, h4]

    widths =
      headers
      |> Enum.zip(columns)
      |> Enum.map(fn {header, col} ->
        col
        |> Enum.map(&String.length/1)
        |> Enum.concat([String.length(header)])
        |> Enum.max()
      end)

    header_row = render_row(headers, widths)
    separator = widths |> Enum.map(&String.duplicate("-", &1)) |> Enum.join("-+-")

    max_rows = columns |> Enum.map(&length/1) |> Enum.max()

    body =
      if max_rows == 0 do
        []
      else
        for i <- 0..(max_rows - 1) do
          cells = Enum.map(columns, fn col -> Enum.at(col, i) || "" end)
          [render_row(cells, widths), "\n"]
        end
      end

    [
      "\n=== Sigra Install Summary ===\n",
      header_row,
      "\n",
      separator,
      "\n",
      body,
      "\n"
    ]
  end

  defp render_row(cells, widths) do
    cells
    |> Enum.zip(widths)
    |> Enum.map(fn {cell, width} -> String.pad_trailing(cell, width) end)
    |> Enum.join(" | ")
  end
end
