defmodule Sigra.Admin.Webhooks.Detail do
  @moduledoc """
  Scope-safe loaders for admin webhook subscription and delivery detail pages.
  """

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope

  @recent_delivery_limit 10

  @spec load_subscription!(map(), Scope.t(), binary()) :: map()
  def load_subscription!(config, %Scope{} = admin_scope, subscription_id)
      when is_binary(subscription_id) do
    Authorizer.authorize_global!(admin_scope)

    subscription = load_subscription_record!(config, subscription_id)
    recent_deliveries = list_recent_deliveries(config, subscription.id)

    %{
      subscription: subscription,
      recent_deliveries: recent_deliveries
    }
  end

  @spec load_delivery!(map(), Scope.t(), binary()) :: map()
  def load_delivery!(config, %Scope{} = admin_scope, delivery_id) when is_binary(delivery_id) do
    Authorizer.authorize_global!(admin_scope)

    delivery = load_delivery_record!(config, delivery_id)
    attempts = list_attempts(config, delivery)

    %{
      delivery: delivery,
      attempts: attempts
    }
  end

  @spec load_subscription_record!(map(), binary()) :: struct()
  def load_subscription_record!(config, subscription_id) when is_binary(subscription_id) do
    config.repo.get_by!(Sigra.Webhooks.subscription_schema!(config), id: subscription_id)
  end

  @spec load_delivery_record!(map(), binary()) :: struct()
  def load_delivery_record!(config, delivery_id) when is_binary(delivery_id) do
    config.repo.get_by!(Sigra.Webhooks.delivery_schema!(config), delivery_id: delivery_id)
  end

  defp list_recent_deliveries(config, subscription_id) do
    delivery_schema = Sigra.Webhooks.delivery_schema!(config)

    from(delivery in delivery_schema,
      where: delivery.webhook_subscription_id == ^subscription_id,
      order_by: [desc: delivery.inserted_at, desc: delivery.id],
      limit: ^@recent_delivery_limit
    )
    |> config.repo.all()
  end

  defp list_attempts(config, delivery) do
    attempt_schema = Sigra.Webhooks.delivery_attempt_schema!(config)

    from(attempt in attempt_schema,
      where: attempt.delivery_id == ^delivery.delivery_id,
      order_by: [desc: attempt.attempt_number, desc: attempt.inserted_at, desc: attempt.id]
    )
    |> config.repo.all()
  end
end
