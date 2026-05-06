defmodule Sigra.Webhooks.EventCatalog do
  @moduledoc """
  Canonical public webhook event registry.
  """

  alias Sigra.Webhooks.Serializers

  @events %{
    "organization_membership.created" => %{
      resource: :organization_membership,
      serializer: Serializers.OrganizationMembership
    },
    "organization_membership.deleted" => %{
      resource: :organization_membership,
      serializer: Serializers.OrganizationMembership
    },
    "organization_membership.updated" => %{
      resource: :organization_membership,
      serializer: Serializers.OrganizationMembership
    },
    "service_account.created" => %{
      resource: :service_account,
      serializer: Serializers.ServiceAccount
    },
    "service_account.revoked" => %{
      resource: :service_account,
      serializer: Serializers.ServiceAccount
    },
    "session.created" => %{
      resource: :session,
      serializer: Serializers.Session
    },
    "session.revoked" => %{
      resource: :session,
      serializer: Serializers.Session
    },
    "user.created" => %{
      resource: :user,
      serializer: Serializers.User
    },
    "user.deleted" => %{
      resource: :user,
      serializer: Serializers.User
    },
    "user.updated" => %{
      resource: :user,
      serializer: Serializers.User
    }
  }

  @spec all() :: [String.t()]
  def all do
    @events
    |> Map.keys()
    |> Enum.sort()
  end

  @spec valid?(String.t()) :: boolean()
  def valid?(event_type) when is_binary(event_type), do: Map.has_key?(@events, event_type)
  def valid?(_event_type), do: false

  @spec fetch!(String.t()) :: map()
  def fetch!(event_type) when is_binary(event_type), do: Map.fetch!(@events, event_type)

  @spec serializer_for!(String.t()) :: module()
  def serializer_for!(event_type) do
    event_type
    |> fetch!()
    |> Map.fetch!(:serializer)
  end

  @spec resource_for!(String.t()) :: atom()
  def resource_for!(event_type) do
    event_type
    |> fetch!()
    |> Map.fetch!(:resource)
  end
end
