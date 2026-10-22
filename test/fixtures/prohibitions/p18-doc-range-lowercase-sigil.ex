defmodule P18DocRangeLowercaseSigil do
  @doc """
  A normal doc range remains recognized by the fixture.
  """
  def normal, do: :ok

  @doc ~s"""
  This lowercase string-sigil doc range must detect .planning/.
  """
  def lowercase, do: :ok
end
