defmodule Sigra.OAuth.Strategies do
  @moduledoc """
  Resolves provider atoms to their corresponding strategy wrapper modules.

  Named strategies (Google, GitHub, Apple, Facebook) have dedicated wrappers
  that normalize Assent responses to a consistent map shape. Unknown providers
  with a `:strategy` key in their config are handled by the Generic fallback.

  ## Examples

      iex> Sigra.OAuth.Strategies.resolve(:google, [])
      Sigra.OAuth.Strategies.Google

      iex> Sigra.OAuth.Strategies.resolve(:discord, [strategy: Assent.Strategy.Discord])
      Sigra.OAuth.Strategies.Generic

      iex> Sigra.OAuth.Strategies.resolve(:discord, [])
      {:error, :unknown_provider}

  """

  @named_strategies %{
    google: Sigra.OAuth.Strategies.Google,
    github: Sigra.OAuth.Strategies.Github,
    apple: Sigra.OAuth.Strategies.Apple,
    facebook: Sigra.OAuth.Strategies.Facebook
  }

  @doc """
  Resolves a provider atom and its config to the appropriate strategy module.

  Returns the named wrapper module for known providers, `Sigra.OAuth.Strategies.Generic`
  for unknown providers that include a `:strategy` key, or `{:error, :unknown_provider}`
  if neither applies.
  """
  @doc since: "0.1.0"
  @spec resolve(atom(), keyword()) :: module() | {:error, :unknown_provider}
  def resolve(provider, provider_config) do
    case Map.get(@named_strategies, provider) do
      nil ->
        if Keyword.has_key?(provider_config, :strategy) do
          Sigra.OAuth.Strategies.Generic
        else
          {:error, :unknown_provider}
        end

      module ->
        module
    end
  end

  @doc """
  Returns the map of known provider atoms to their strategy wrapper modules.
  """
  @doc since: "0.1.0"
  @spec named_strategies() :: map()
  def named_strategies, do: @named_strategies
end
