defmodule Sigra.Test.Brand.RegenGuard do
  @moduledoc """
  Test-only guard for the opt-in fixture writers of the brand suite.

  Four environment variables make a brand test rewrite a committed fixture
  instead of only reading it:

    * `SIGRA_BRAND_COPY=regen` rewrites the three copy inventories,
    * `SIGRA_BRAND_COPY_BASELINE=init` initializes copy-baseline scopes,
    * `SIGRA_BRAND_BASELINE=extend` extends the frozen-surface baseline,
    * `SIGRA_BRAND_LEGACY=write` writes the legacy-profile fixture.

  A writer that runs before its own equality or ratchet assertion makes that
  assertion compare a file with itself, so it passes whatever the sources say.
  That is acceptable as a deliberate local maintainer action and never in CI,
  where a stray variable (an exported shell, an auto-loaded env file) would turn
  a failing contract green. `requested?/3` therefore raises when a writer is
  requested while `CI` is `true` or `1`, so the run fails loudly instead.

  Every opt-in read in `test/sigra/brand` and `test/support/brand` goes through
  this module. `Sigra.Brand.RegenGuardTest` fails when a file reads the
  environment directly, so a new writer cannot skip the guard.
  """

  @ci_values ["true", "1"]

  @typedoc "An environment: variable name to value, as `System.get_env/0` returns it."
  @type env :: %{optional(String.t()) => String.t()}

  @doc "The process environment. Helpers take it as a default argument so tests can plant one."
  @spec environment() :: env()
  def environment, do: System.get_env()

  @doc """
  True when `env` (default: the process environment) marks a CI run: `CI` is
  `true` or `1`, case-insensitive.
  """
  @spec ci?(env()) :: boolean()
  def ci?(env \\ environment()) do
    env |> Map.get("CI", "") |> String.trim() |> String.downcase() |> Kernel.in(@ci_values)
  end

  @doc """
  True when `env` sets `name` to exactly `value`, which is how a writer is
  requested. Raises `RuntimeError` when it is requested under CI.
  """
  @spec requested?(String.t(), String.t(), env()) :: boolean()
  def requested?(name, value, env \\ environment()) do
    cond do
      Map.get(env, name) != value ->
        false

      ci?(env) ->
        raise "#{name}=#{value} rewrites a committed brand fixture and is a local maintainer " <>
                "action. It is refused when CI is set (CI=true), because a writer that runs " <>
                "before its own assertion turns the contract green whatever the sources say. " <>
                "Unset #{name} and run the writer locally."

      true ->
        true
    end
  end
end
