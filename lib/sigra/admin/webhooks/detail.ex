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
      rotation: build_rotation_detail(subscription),
      recent_deliveries: recent_deliveries
    }
  end

  @spec load_delivery!(map(), Scope.t(), binary()) :: map()
  def load_delivery!(config, %Scope{} = admin_scope, delivery_id) when is_binary(delivery_id) do
    Authorizer.authorize_global!(admin_scope)

    delivery = load_delivery_record!(config, delivery_id)
    attempts = list_attempts(config, delivery)
    replay_parent = load_replay_parent(config, delivery)
    replay_root = load_replay_root(config, delivery)
    replay_children = list_replay_children(config, delivery)
    replay = replay_status(config, delivery, replay_children)

    %{
      delivery: delivery,
      attempts: attempts,
      policy: build_policy_detail(delivery),
      replay: replay,
      replay_parent: replay_parent,
      replay_root: replay_root,
      replay_children: replay_children
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

  defp load_replay_parent(config, delivery) do
    case Map.get(delivery, :replayed_from_webhook_delivery_id) do
      parent_id when is_binary(parent_id) ->
        config.repo.get(Sigra.Webhooks.delivery_schema!(config), parent_id)

      _other ->
        nil
    end
  end

  defp load_replay_root(config, delivery) do
    root_id = Map.get(delivery, :replay_root_webhook_delivery_id) || Map.get(delivery, :id)
    config.repo.get(Sigra.Webhooks.delivery_schema!(config), root_id)
  end

  defp list_replay_children(config, delivery) do
    delivery_schema = Sigra.Webhooks.delivery_schema!(config)

    from(child in delivery_schema,
      where: child.replayed_from_webhook_delivery_id == ^delivery.id,
      order_by: [asc: child.inserted_at, asc: child.id]
    )
    |> config.repo.all()
  end

  defp replay_status(config, delivery, replay_children) do
    reason =
      cond do
        Map.get(delivery, :status) != "dead_lettered" or
            is_nil(Map.get(delivery, :dead_lettered_at)) ->
          :not_dead_lettered

        delivery_context_incomplete?(config, delivery) ->
          :delivery_context_incomplete

        subscription_disabled?(config, delivery) ->
          :subscription_disabled

        replay_children != [] ->
          :replay_already_exists

        true ->
          nil
      end

    %{eligible?: is_nil(reason), reason: reason}
  end

  defp build_rotation_detail(subscription) do
    state = Map.get(subscription, :rotation_state) || :stable

    active_fingerprint =
      Map.get(subscription, :signing_secret_fingerprint) ||
        fingerprint(Map.get(subscription, :signing_secret))

    next_fingerprint =
      Map.get(subscription, :next_signing_secret_fingerprint) ||
        fingerprint(Map.get(subscription, :next_signing_secret))

    %{
      state: state,
      active_fingerprint: active_fingerprint,
      next_fingerprint: next_fingerprint,
      signing_mode: signing_mode(state),
      next_step: next_step(state)
    }
  end

  defp signing_mode(:overlap_active),
    do: "Sigra signs deliveries with both the current and next secret."

  defp signing_mode(:completed),
    do: "Sigra signs deliveries with the promoted active secret only."

  defp signing_mode(_state), do: "Sigra signs deliveries with the current active secret only."

  defp next_step(:stable), do: "Prepare a new secret before updating the receiver."

  defp next_step(:prepared),
    do: "Update the receiver to accept both current and previous secrets, then start overlap."

  defp next_step(:overlap_active),
    do: "Wait for at least one successful overlap-window delivery, then complete the rotation."

  defp next_step(:completed),
    do: "Keep the new secret active and verify a post-retirement delivery succeeds."

  defp fingerprint(secret) when is_binary(secret) do
    secret
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  defp fingerprint(_secret), do: nil

  defp build_policy_detail(delivery) do
    if Map.get(delivery, :last_error_category) == "local_policy_error" do
      %{
        blocked?: true,
        reason: Map.get(delivery, :terminal_reason),
        detail: Map.get(delivery, :last_error_detail)
      }
    else
      %{blocked?: false, reason: nil, detail: nil}
    end
  end

  defp delivery_context_incomplete?(config, delivery) do
    Map.get(delivery, :terminal_reason) in [
      "delivery_dependency_missing",
      "orphaned_terminal_issue"
    ] or
      is_nil(
        config.repo.get(
          Sigra.Webhooks.subscription_schema!(config),
          delivery.webhook_subscription_id
        )
      ) or
      is_nil(config.repo.get(Sigra.Webhooks.event_schema!(config), delivery.webhook_event_id))
  end

  defp subscription_disabled?(config, delivery) do
    case config.repo.get(
           Sigra.Webhooks.subscription_schema!(config),
           delivery.webhook_subscription_id
         ) do
      %{enabled: false} -> true
      _other -> false
    end
  end
end
