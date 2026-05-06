defmodule Sigra.WebhooksPayloadTest do
  use ExUnit.Case, async: true

  alias Sigra.Webhooks.Payload

  defmodule User do
    defstruct [:id, :email, :display_name, :confirmed_at, :password_hash, :inserted_at, :updated_at]
  end

  defmodule Session do
    defstruct [:id, :user_id, :organization_id, :type, :token, :revoked_at, :last_active_at, :inserted_at]
  end

  defmodule Membership do
    defstruct [:id, :organization_id, :user_id, :role, :audit_metadata, :inserted_at, :updated_at]
  end

  defmodule ServiceAccount do
    defstruct [:id, :organization_id, :name, :scopes, :hashed_client_secret, :revoked_at, :inserted_at]
  end

  test "builds the stable webhook envelope for user events without leaking internal fields" do
    user = %User{
      id: "user_123",
      email: "user@example.com",
      display_name: "User Example",
      password_hash: "secret",
      confirmed_at: ~U[2026-05-06 12:00:00Z],
      inserted_at: ~U[2026-05-06 11:00:00Z],
      updated_at: ~U[2026-05-06 12:30:00Z]
    }

    payload =
      Payload.build("user.updated", user,
        id: "evt_123",
        occurred_at: ~U[2026-05-06 12:31:00Z],
        changes: [:email, :display_name],
        context: %{
          actor: %{type: "user", id: "admin_1"},
          organization: %{id: "org_1"},
          request: %{id: "req_1"}
        }
      )

    assert payload == %{
             "id" => "evt_123",
             "type" => "user.updated",
             "schema_version" => "2026-05-06",
             "occurred_at" => "2026-05-06T12:31:00Z",
             "data" => %{
               "object" => %{
                 "id" => "user_123",
                 "email" => "user@example.com",
                 "display_name" => "User Example",
                 "confirmed_at" => "2026-05-06T12:00:00Z",
                 "created_at" => "2026-05-06T11:00:00Z",
                 "updated_at" => "2026-05-06T12:30:00Z"
               },
               "changes" => ["email", "display_name"]
             },
             "context" => %{
               "actor" => %{"type" => "user", "id" => "admin_1"},
               "organization" => %{"id" => "org_1"},
               "request" => %{"id" => "req_1"}
             }
           }

    refute get_in(payload, ["data", "object", "password_hash"])
  end

  test "serializes session, membership, and service-account resources explicitly" do
    session =
      Payload.build("session.created", %Session{
        id: "sess_1",
        user_id: "user_1",
        organization_id: "org_1",
        type: :standard,
        token: "raw-token",
        last_active_at: ~U[2026-05-06 12:00:00Z],
        inserted_at: ~U[2026-05-06 11:00:00Z]
      })

    membership =
      Payload.build("organization_membership.updated", %Membership{
        id: "mem_1",
        organization_id: "org_1",
        user_id: "user_1",
        role: :admin,
        audit_metadata: %{sensitive: true},
        inserted_at: ~U[2026-05-06 11:00:00Z],
        updated_at: ~U[2026-05-06 12:00:00Z]
      }, changes: ["role"])

    service_account =
      Payload.build("service_account.revoked", %ServiceAccount{
        id: "sa_1",
        organization_id: "org_1",
        name: "CI",
        scopes: ["deploy:write"],
        hashed_client_secret: <<1, 2, 3>>,
        revoked_at: ~U[2026-05-06 12:00:00Z],
        inserted_at: ~U[2026-05-06 11:00:00Z]
      })

    assert get_in(session, ["data", "object"]) == %{
             "id" => "sess_1",
             "user_id" => "user_1",
             "organization_id" => "org_1",
             "type" => "standard",
             "last_active_at" => "2026-05-06T12:00:00Z",
             "created_at" => "2026-05-06T11:00:00Z"
           }

    assert get_in(membership, ["data", "object"]) == %{
             "id" => "mem_1",
             "organization_id" => "org_1",
             "user_id" => "user_1",
             "role" => "admin",
             "created_at" => "2026-05-06T11:00:00Z",
             "updated_at" => "2026-05-06T12:00:00Z"
           }

    assert get_in(membership, ["data", "changes"]) == ["role"]

    assert get_in(service_account, ["data", "object"]) == %{
             "id" => "sa_1",
             "organization_id" => "org_1",
             "name" => "CI",
             "scopes" => ["deploy:write"],
             "revoked_at" => "2026-05-06T12:00:00Z",
             "created_at" => "2026-05-06T11:00:00Z"
           }

    refute get_in(session, ["data", "object", "token"])
    refute get_in(membership, ["data", "object", "audit_metadata"])
    refute get_in(service_account, ["data", "object", "hashed_client_secret"])
  end
end
