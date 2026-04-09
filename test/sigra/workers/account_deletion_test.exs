defmodule Sigra.Workers.AccountDeletionTest do
  use ExUnit.Case, async: true

  alias Sigra.Workers.AccountDeletion

  describe "module configuration" do
    test "uses Oban.Worker" do
      Code.ensure_loaded!(AccountDeletion)
      assert function_exported?(AccountDeletion, :perform, 1)
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

      defmodule TestUserSchemaNotFound do
      end

      job = %Oban.Job{
        args: %{
          "user_id" => 999,
          "strategy" => "soft_delete",
          "repo" => "Sigra.Workers.AccountDeletionTest.TestRepoNotFound",
          "user_schema" => "Sigra.Workers.AccountDeletionTest.TestUserSchemaNotFound"
        }
      }

      assert {:ok, :user_not_found} = AccountDeletion.perform(job)
    end

    test "returns {:ok, :not_scheduled} when user is not scheduled for deletion" do
      defmodule TestRepoNotScheduled do
        def get(_schema, _id) do
          %{id: 1, deleted_at: nil, scheduled_deletion_at: nil}
        end
      end

      defmodule TestUserSchemaNotScheduled do
      end

      job = %Oban.Job{
        args: %{
          "user_id" => 1,
          "strategy" => "soft_delete",
          "repo" => "Sigra.Workers.AccountDeletionTest.TestRepoNotScheduled",
          "user_schema" => "Sigra.Workers.AccountDeletionTest.TestUserSchemaNotScheduled"
        }
      }

      assert {:ok, :not_scheduled} = AccountDeletion.perform(job)
    end

    test "uses Module.safe_concat for repo resolution (T-8-10 mitigation)" do
      source = File.read!("lib/sigra/workers/account_deletion.ex")
      assert source =~ "Module.safe_concat"
    end

    test "uses String.to_existing_atom for strategy resolution (T-8-10 mitigation)" do
      source = File.read!("lib/sigra/workers/account_deletion.ex")
      assert source =~ "String.to_existing_atom"
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
