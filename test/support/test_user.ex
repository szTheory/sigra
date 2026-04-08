defmodule Sigra.TestUser do
  @moduledoc false
  # Minimal user struct for testing.

  defstruct [:id, :email, :token_epoch, :role]
end
