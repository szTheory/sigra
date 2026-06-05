defmodule Sigra.Admin do
  @moduledoc """
  Shared admin utility helpers used across admin LiveView surfaces.
  """

  @doc """
  Returns the count of accounts that need admin review.
  Counts locked + deletion-scheduled accounts.
  """
  def needs_review(counts) do
    Map.get(counts, :locked, 0) + Map.get(counts, :deleted, 0)
  end
end
