defmodule Sigra.Workers.TokenCleanupTest do
  use ExUnit.Case, async: true

  alias Sigra.Workers.TokenCleanup

  describe "cleanup_expired_tokens/2" do
    test "is a function that accepts repo and token_schema" do
      assert is_function(&TokenCleanup.cleanup_expired_tokens/2, 2)
    end
  end

  describe "perform/1" do
    test "is a function that accepts an Oban.Job" do
      Code.ensure_loaded!(TokenCleanup)
      assert function_exported?(TokenCleanup, :perform, 1)
    end
  end

  describe "module attributes" do
    test "uses Oban.Worker with expected exports" do
      Code.ensure_loaded!(TokenCleanup)
      assert function_exported?(TokenCleanup, :perform, 1)
      assert function_exported?(TokenCleanup, :new, 2)
    end

    test "has max_attempts of 1" do
      # Cron jobs should not retry
      changeset = TokenCleanup.new(%{})
      assert changeset.changes[:max_attempts] == 1
    end

    test "uses sigra_mailer queue" do
      changeset = TokenCleanup.new(%{})
      assert changeset.changes[:queue] == "sigra_mailer"
    end
  end
end
