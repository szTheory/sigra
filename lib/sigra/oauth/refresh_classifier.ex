defmodule Sigra.OAuth.RefreshClassifier do
  @moduledoc """
  Normalizes Assent and provider-specific OAuth token refresh errors into stable
  Sigra categories.
  """

  @type classification ::
          :reauth_required
          | :temporarily_unavailable
          | :misconfigured
          | :invalid_response
          | :unknown_provider

  @doc """
  Classifies an error returned from a provider refresh call into a stable category.
  """
  @spec classify(term()) :: classification()

  # Matches standard OAuth2 error responses inside Assent.RequestError or Assent.InvalidResponseError
  def classify({:error, %Assent.RequestError{response: %{"error" => "invalid_grant"}}}), do: :reauth_required
  def classify({:error, %Assent.InvalidResponseError{response: %{body: %{"error" => "invalid_grant"}}}}), do: :reauth_required

  def classify({:error, %Assent.RequestError{response: %{"error" => error}}})
      when error in ["invalid_client", "unauthorized_client", "unsupported_grant_type", "invalid_scope"] do
    :misconfigured
  end

  def classify({:error, %Assent.InvalidResponseError{response: %{body: %{"error" => error}}}})
      when error in ["invalid_client", "unauthorized_client", "unsupported_grant_type", "invalid_scope"] do
    :misconfigured
  end

  def classify({:error, %Assent.RequestError{response: %{"error" => error}}})
      when error in ["server_error", "temporarily_unavailable"] do
    :temporarily_unavailable
  end

  def classify({:error, %Assent.InvalidResponseError{response: %{body: %{"error" => error}}}})
      when error in ["server_error", "temporarily_unavailable"] do
    :temporarily_unavailable
  end

  # Matches Assent.CallbackError directly
  def classify({:error, %Assent.CallbackError{error: "invalid_grant"}}), do: :reauth_required

  def classify({:error, :unknown_provider}), do: :unknown_provider
  
  # Fallback
  def classify(_), do: :invalid_response
end
