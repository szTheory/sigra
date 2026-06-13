defmodule Sigra.Admin do
  @moduledoc """
  Shared admin utility helpers used across admin LiveView surfaces.
  """

  @doc """
  Returns the count of accounts that need admin review.
  Counts locked + deletion-scheduled accounts.
  """
  @spec needs_review(map()) :: non_neg_integer()
  def needs_review(counts) do
    locked = Map.get(counts, :locked_out, Map.get(counts, :locked, 0))
    deletion_scheduled = Map.get(counts, :deletion_scheduled, Map.get(counts, :deleted, 0))

    locked + deletion_scheduled
  end

  @doc """
  Loads the host Sigra runtime config for admin LiveViews.
  """
  @spec runtime_config!(String.t()) :: Sigra.Config.t()
  def runtime_config!(label) when is_binary(label) do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError, "#{label} requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "#{label} requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end
end
