defmodule P18DocRangeDelimitedSigils do
  @doc """
  A normal doc range remains recognized by the fixture.
  """
  def normal, do: :ok

  @doc ~s|
  This non-quote sigil doc range must detect .planning/.
  |
  def pipe_delimited, do: :ok

  @doc ~S(
  This paired sigil doc range must also detect .planning/.
  )
  def paired_delimited, do: :ok
end
