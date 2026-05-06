defmodule Sigra.Admin.Webhooks.Actions do
  @moduledoc """
  Global-admin-safe webhook subscription mutations and secret actions.
  """

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope
  alias Sigra.Admin.Webhooks.Detail

  @spec create(map(), Scope.t(), map() | keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def create(config, %Scope{} = admin_scope, attrs) do
    Authorizer.authorize_global!(admin_scope)
    Sigra.Webhooks.create_subscription(config, attrs)
  end

  @spec update(map(), Scope.t(), binary(), map() | keyword()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def update(config, %Scope{} = admin_scope, subscription_id, attrs)
      when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Detail.load_subscription_record!(config, subscription_id)
    Sigra.Webhooks.update_subscription(config, subscription, attrs)
  end

  @spec enable(map(), Scope.t(), binary()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def enable(config, %Scope{} = admin_scope, subscription_id) when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Detail.load_subscription_record!(config, subscription_id)
    Sigra.Webhooks.enable_subscription(config, subscription)
  end

  @spec disable(map(), Scope.t(), binary()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def disable(config, %Scope{} = admin_scope, subscription_id) when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Detail.load_subscription_record!(config, subscription_id)
    Sigra.Webhooks.disable_subscription(config, subscription)
  end

  @spec reveal_secret(map(), Scope.t(), binary()) :: {:ok, %{subscription: struct(), signing_secret: binary()}}
  def reveal_secret(config, %Scope{} = admin_scope, subscription_id) when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Detail.load_subscription_record!(config, subscription_id)
    {:ok, %{subscription: subscription, signing_secret: subscription.signing_secret}}
  end

  @spec rotate_secret(map(), Scope.t(), binary()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def rotate_secret(config, %Scope{} = admin_scope, subscription_id) when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Detail.load_subscription_record!(config, subscription_id)
    Sigra.Webhooks.update_subscription(config, subscription, %{signing_secret: generate_secret()})
  end

  defp generate_secret do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
