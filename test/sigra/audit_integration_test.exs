defmodule Sigra.AuditIntegrationTest do
  use ExUnit.Case, async: true

  # Wave 0 scaffold. Tests log_multi/3 and the internal __log_internal__/3
  # composed with a business operation. Plan 02 implements log_multi.
  #
  # These tests verify the SHAPE of the Multi composition. Full
  # commit/rollback assertions become meaningful once a sandboxed test repo
  # exists; for now we assert the Multi value contains an :audit step.

  alias Sigra.Audit

  describe "log_multi/3" do
    test "appends an :audit step to an existing Ecto.Multi" do
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:noop, fn _, _ -> {:ok, :ok} end)
        |> Audit.log_multi("billing.subscription.created",
          audit_schema: Sigra.Test.AuditEvent,
          actor_id: Ecto.UUID.generate(),
          metadata: %{plan: "pro"}
        )

      operations = Ecto.Multi.to_list(multi)
      names = Enum.map(operations, fn {name, _} -> name end)
      assert :audit in names
    end

    test "log_multi rejects reserved prefix" do
      assert_raise ArgumentError, fn ->
        Ecto.Multi.new()
        |> Audit.log_multi("auth.login.success",
          audit_schema: Sigra.Test.AuditEvent,
          actor_id: Ecto.UUID.generate()
        )
      end
    end
  end

  describe "__log_internal__/3 (private path used by lib/sigra/auth.ex)" do
    test "bypasses reserved-prefix guardrail (D-15)" do
      multi =
        Ecto.Multi.new()
        |> Audit.__log_internal__("auth.login.success",
          audit_schema: Sigra.Test.AuditEvent,
          actor_id: Ecto.UUID.generate()
        )

      operations = Ecto.Multi.to_list(multi)
      names = Enum.map(operations, fn {name, _} -> name end)
      assert :audit in names
    end

    test "rolls back when an earlier multi step fails (atomicity D-01)" do
      # Build a multi with a failing step before the audit step.
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:fail_first, fn _, _ -> {:error, :boom} end)
        |> Audit.__log_internal__("auth.register.success",
          audit_schema: Sigra.Test.AuditEvent,
          actor_id: Ecto.UUID.generate()
        )

      # Confirm the audit step exists in the multi structure even when an
      # earlier step would fail. Atomicity guarantees rollback at execution
      # time, which Plan 02 will verify with a real Repo.transact/2.
      operations = Ecto.Multi.to_list(multi)
      names = Enum.map(operations, fn {name, _} -> name end)
      assert :audit in names
      assert :fail_first in names
    end
  end
end
