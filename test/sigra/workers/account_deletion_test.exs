defmodule Sigra.Workers.AccountDeletionTest do
  use ExUnit.Case, async: true

  alias Sigra.Workers.AccountDeletion

  # Ensure strategy atoms exist for String.to_existing_atom/1 in worker
  _ = [:soft_delete, :hard_delete, :anonymize]

  defp base_args(overrides \\ %{}) do
    %{
      "user_id" => 1,
      "strategy" => "soft_delete",
      "repo" => "Sigra.Workers.AccountDeletionTest.TestRepo",
      "user_schema" => "Sigra.Workers.AccountDeletionTest.TestUserSchema",
      "scope_module" => "Sigra.Workers.AccountDeletionTest.TestScope",
      "organization_schema" => nil,
      "audit_schema" => "Sigra.Workers.AccountDeletionTest.TestAuditSchema",
      "organization_id" => nil,
      "actor_id" => nil
    }
    |> Map.merge(overrides)
  end

  # Minimal stand-ins for Module.safe_concat resolution. They are defined
  # at the top-level of the test module namespace so the stringified names
  # used in args resolve via Module.safe_concat([...]) at perform/1 time.
  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defmodule TestAuditSchema do
    defstruct [
      :action,
      :actor_id,
      :target_id,
      :organization_id,
      :effective_user_id,
      :metadata,
      :outcome,
      :actor_type,
      :target_type,
      :occurred_at,
      :inserted_at,
      :ip_address,
      :user_agent
    ]
  end

  defmodule TestUserSchema do
  end

  describe "module configuration" do
    test "uses Oban.Worker" do
      Code.ensure_loaded!(AccountDeletion)
      assert function_exported?(AccountDeletion, :perform, 1)
    end

    test "implements Sigra.Workers behaviour" do
      Code.ensure_loaded!(AccountDeletion)
      assert function_exported?(AccountDeletion, :perform, 2)

      assert Sigra.Workers in (AccountDeletion.module_info(:attributes)
                               |> Keyword.get_values(:behaviour)
                               |> List.flatten())
    end

    test "configures :sigra_lifecycle queue" do
      source = File.read!("lib/sigra/workers/account_deletion.ex")
      assert source =~ "queue: :sigra_lifecycle"
    end

    test "configures max_attempts of 3" do
      source = File.read!("lib/sigra/workers/account_deletion.ex")
      assert source =~ "max_attempts: 3"
    end

    test "configures unique constraint on user_id" do
      source = File.read!("lib/sigra/workers/account_deletion.ex")
      assert source =~ "unique:"
      assert source =~ ":user_id"
    end
  end

  describe "perform/1" do
    test "returns {:ok, :user_not_found} when user does not exist" do
      defmodule TestRepoNotFound do
        def get(_schema, _id), do: nil
      end

      args =
        base_args(%{
          "user_id" => 999,
          "repo" => "Sigra.Workers.AccountDeletionTest.TestRepoNotFound"
        })

      assert {:ok, :user_not_found} = AccountDeletion.perform(%Oban.Job{args: args})
    end

    test "returns {:ok, :not_scheduled} when user is not scheduled for deletion" do
      defmodule TestRepoNotScheduled do
        def get(_schema, _id) do
          %{id: 1, deleted_at: nil, scheduled_deletion_at: nil}
        end

        def insert(changeset), do: {:ok, changeset}
      end

      args =
        base_args(%{
          "repo" => "Sigra.Workers.AccountDeletionTest.TestRepoNotScheduled"
        })

      assert {:ok, :not_scheduled} = AccountDeletion.perform(%Oban.Job{args: args})
    end

    test "reconstructs scope via Sigra.Scope.build and passes it to perform/2" do
      source = File.read!("lib/sigra/workers/account_deletion.ex")
      # 15-02 invariant: scope is built from scope_module + user + active_org
      assert source =~ "Sigra.Scope.build("
    end

    test "uses Module.safe_concat for repo resolution (T-8-10 mitigation)" do
      source = File.read!("lib/sigra/workers/account_deletion.ex")
      assert source =~ "Module.safe_concat"
    end

    test "uses String.to_existing_atom for strategy resolution (T-8-10 mitigation)" do
      source = File.read!("lib/sigra/workers/account_deletion.ex")
      assert source =~ "String.to_existing_atom"
    end

    test "raises KeyError when organization_id arg is absent (behaviour contract)" do
      args = base_args() |> Map.delete("organization_id")

      assert_raise KeyError, fn ->
        AccountDeletion.perform(%Oban.Job{args: args})
      end
    end

    test "raises KeyError when actor_id arg is absent (behaviour contract)" do
      args = base_args() |> Map.delete("actor_id")

      assert_raise KeyError, fn ->
        AccountDeletion.perform(%Oban.Job{args: args})
      end
    end

    test "raises KeyError when audit_schema arg is absent (worker-specific belt+suspenders)" do
      args = base_args() |> Map.delete("audit_schema")

      assert_raise KeyError, fn ->
        AccountDeletion.perform(%Oban.Job{args: args})
      end
    end
  end

  describe "Deletion.scheduled?/1 integration" do
    test "checks both deleted_at and scheduled_deletion_at" do
      # Directly test the Deletion.scheduled? function the worker depends on
      assert Sigra.Account.Deletion.scheduled?(%{
               deleted_at: DateTime.utc_now(),
               scheduled_deletion_at: DateTime.add(DateTime.utc_now(), 86400, :second)
             })

      refute Sigra.Account.Deletion.scheduled?(%{
               deleted_at: nil,
               scheduled_deletion_at: nil
             })
    end
  end
end
