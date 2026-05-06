defmodule Sigra.WebhooksEventCatalogTest do
  use ExUnit.Case, async: true

  alias Sigra.Webhooks.EventCatalog
  alias Sigra.Webhooks.Serializers

  test "contains the curated Phase 97 event catalog" do
    assert EventCatalog.all() == [
             "organization_membership.created",
             "organization_membership.deleted",
             "organization_membership.updated",
             "service_account.created",
             "service_account.revoked",
             "session.created",
             "session.revoked",
             "user.created",
             "user.deleted",
             "user.updated"
           ]
  end

  test "resolves serializers and resources from one authoritative registry" do
    assert EventCatalog.serializer_for!("user.updated") == Serializers.User
    assert EventCatalog.serializer_for!("session.revoked") == Serializers.Session
    assert EventCatalog.resource_for!("organization_membership.created") == :organization_membership
    assert EventCatalog.valid?("service_account.created")
    refute EventCatalog.valid?("security.lockout")
  end
end
