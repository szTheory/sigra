defmodule Sigra.Passkeys.SignCountPolicy do
  @moduledoc """
  Pure sign-count regression policy machine.
  """

  @type policy :: :warn | :require_reauth | :revoke
  @type result :: :ok | {:regression, policy()}

  @spec evaluate(non_neg_integer(), non_neg_integer(), policy()) :: result()
  def evaluate(stored, presented, policy)
      when is_integer(stored) and stored >= 0 and is_integer(presented) and presented >= 0 and
             policy in [:warn, :require_reauth, :revoke] do
    cond do
      stored == 0 and presented == 0 -> :ok
      presented > stored -> :ok
      true -> {:regression, policy}
    end
  end
end
