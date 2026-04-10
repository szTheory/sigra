defmodule Sigra.Env do
  @moduledoc """
  Release-safe Mix environment detection.

  In a Mix release, the `:mix` application is intentionally excluded
  (Mix is a build-time tool). Code that calls `Mix.env/0` at runtime
  from inside a release raises `UndefinedFunctionError`.

  This helper guards the call with `function_exported?/3` and falls
  back to `:prod` when Mix is not loaded.
  """

  @doc """
  Returns the current Mix environment, or `:prod` when Mix is unavailable
  (e.g., inside a release).

  ## Examples

      iex> Sigra.Env.current() in [:dev, :test, :prod]
      true
  """
  @spec current() :: atom()
  def current do
    if function_exported?(Mix, :env, 0), do: Mix.env(), else: :prod
  end
end
