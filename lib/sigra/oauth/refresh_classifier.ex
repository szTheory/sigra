defmodule Sigra.OAuth.RefreshClassifier do
  @moduledoc """
  Normalizes Assent and provider-specific OAuth token refresh errors into stable
  Sigra categories.

  Uses map-based struct matching rather than bare `%Assent.SomeStruct{}` patterns
  so this module compiles correctly in host apps that do not have Assent in their
  deps (Assent is an optional Sigra dependency). The `:__struct__` field is always
  present in Elixir structs, so matching on it is equivalent to matching on the
  struct type but does not require the module to be loaded at compile time.
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

  # Assent.RequestError — standard OAuth2 error responses
  def classify(
        {:error,
         %{__struct__: Assent.RequestError, response: %{"error" => "invalid_grant"}}}
      ),
      do: :reauth_required

  def classify(
        {:error,
         %{__struct__: Assent.RequestError, response: %{"error" => error}}}
      )
      when error in ["invalid_client", "unauthorized_client", "unsupported_grant_type", "invalid_scope"],
      do: :misconfigured

  def classify(
        {:error,
         %{__struct__: Assent.RequestError, response: %{"error" => error}}}
      )
      when error in ["server_error", "temporarily_unavailable"],
      do: :temporarily_unavailable

  # Assent.InvalidResponseError — provider-wrapped error responses
  def classify(
        {:error,
         %{__struct__: Assent.InvalidResponseError, response: %{body: %{"error" => "invalid_grant"}}}}
      ),
      do: :reauth_required

  def classify(
        {:error,
         %{__struct__: Assent.InvalidResponseError, response: %{body: %{"error" => error}}}}
      )
      when error in ["invalid_client", "unauthorized_client", "unsupported_grant_type", "invalid_scope"],
      do: :misconfigured

  def classify(
        {:error,
         %{__struct__: Assent.InvalidResponseError, response: %{body: %{"error" => error}}}}
      )
      when error in ["server_error", "temporarily_unavailable"],
      do: :temporarily_unavailable

  # Assent.CallbackError — callback-phase errors
  def classify({:error, %{__struct__: Assent.CallbackError, error: "invalid_grant"}}),
    do: :reauth_required

  def classify({:error, :unknown_provider}), do: :unknown_provider

  # Fallback
  def classify(_), do: :invalid_response
end
