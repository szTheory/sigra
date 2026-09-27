defmodule P18DocRangePythonLanguage do
  @moduledoc """
  Plain module documentation names Phase 241.
  """

  @doc ~S"""
  Uppercase string-sigil documentation names D-30.
  """
  def uppercase_heredoc, do: :ok

  @doc "Plain one-line documentation names -PLAN.md."
  def plain_one_line, do: :ok

  @typedoc ~S"Uppercase one-line documentation names SC-1."
  @type accepted() :: :ok

  @doc ~s"""
  Lowercase string-sigil documentation names .planning/ but is outside D-30.
  """
  def lowercase_rejected, do: :ok

  @doc ~S|
  Pipe-delimited documentation names .planning/ but is outside D-30.
  |
  def pipe_rejected, do: :ok

  @doc ~S(
  Paired-delimiter documentation names .planning/ but is outside D-30.
  )
  def paired_rejected, do: :ok
end
