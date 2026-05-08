defmodule Sigra.Admin.Webhooks.Actions do
  @moduledoc """
  Global-admin-safe webhook subscription mutations and secret actions.
  """

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope

  @spec create(map(), Scope.t(), map() | keyword()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def create(config, %Scope{} = admin_scope, attrs) do
    Authorizer.authorize_global!(admin_scope)
    Sigra.Webhooks.create_subscription(config, attrs)
  end

  @spec update(map(), Scope.t(), binary(), map() | keyword()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def update(config, %Scope{} = admin_scope, subscription_id, attrs)
      when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Sigra.Webhooks.get_subscription!(config, subscription_id)
    Sigra.Webhooks.update_subscription(config, subscription, attrs)
  end

  @spec enable(map(), Scope.t(), binary()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def enable(config, %Scope{} = admin_scope, subscription_id) when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Sigra.Webhooks.get_subscription!(config, subscription_id)
    Sigra.Webhooks.enable_subscription(config, subscription)
  end

  @spec disable(map(), Scope.t(), binary()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def disable(config, %Scope{} = admin_scope, subscription_id) when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Sigra.Webhooks.get_subscription!(config, subscription_id)
    Sigra.Webhooks.disable_subscription(config, subscription)
  end

  @spec reveal_secret(map(), Scope.t(), binary()) ::
          {:ok, %{subscription: struct(), signing_secret: binary()}}
  def reveal_secret(config, %Scope{} = admin_scope, subscription_id)
      when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    subscription = Sigra.Webhooks.get_subscription!(config, subscription_id)

    with {:ok, signing_secret} <- Sigra.Webhooks.reveal_secret(config, subscription) do
      {:ok, %{subscription: subscription, signing_secret: signing_secret}}
    end
  end

  @spec rotate_secret(map(), Scope.t(), binary()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def rotate_secret(config, %Scope{} = admin_scope, subscription_id)
      when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    Sigra.Webhooks.rotate_secret(config, subscription_id)
  end

  @spec prepare_secret(map(), Scope.t(), binary()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def prepare_secret(config, %Scope{} = admin_scope, subscription_id)
      when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    Sigra.Webhooks.prepare_secret(config, subscription_id, scope: admin_scope.scope)
  end

  @spec discard_prepared_secret(map(), Scope.t(), binary()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def discard_prepared_secret(config, %Scope{} = admin_scope, subscription_id)
      when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    Sigra.Webhooks.discard_prepared_secret(config, subscription_id, scope: admin_scope.scope)
  end

  @spec start_secret_overlap(map(), Scope.t(), binary(), keyword()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def start_secret_overlap(config, %Scope{} = admin_scope, subscription_id, opts \\ [])
      when is_binary(subscription_id) and is_list(opts) do
    Authorizer.authorize_global!(admin_scope)

    Sigra.Webhooks.start_secret_overlap(
      config,
      subscription_id,
      Keyword.put(opts, :scope, admin_scope.scope)
    )
  end

  @spec complete_secret_rotation(map(), Scope.t(), binary()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def complete_secret_rotation(config, %Scope{} = admin_scope, subscription_id)
      when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)
    Sigra.Webhooks.complete_secret_rotation(config, subscription_id, scope: admin_scope.scope)
  end

  @spec replay_delivery(map(), Scope.t(), binary(), keyword()) ::
          {:ok, %{source_delivery: struct(), replay_delivery: struct()}} | {:error, term()}
  def replay_delivery(config, %Scope{} = admin_scope, delivery_id, opts \\ [])
      when is_binary(delivery_id) and is_list(opts) do
    Authorizer.authorize_global!(admin_scope)
    Sigra.Webhooks.replay_delivery(config, delivery_id, admin_scope.scope, opts)
  end
end
