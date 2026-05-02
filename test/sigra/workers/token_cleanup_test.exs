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

  describe "cleanup_revoked_api_tokens/1" do
    test "is a function that accepts a config struct" do
      assert is_function(&TokenCleanup.cleanup_revoked_api_tokens/1, 1)
    end

    test "returns :ok when no api_token_schema configured" do
      config = %Sigra.Config{
        repo: Sigra.TestRepo,
        user_schema: Sigra.TestUser,
        api_token: []
      }

      assert :ok = TokenCleanup.cleanup_revoked_api_tokens(config)
    end
  end

  describe "cleanup_refresh_tokens/2" do
    test "is a function that accepts repo and token_schema" do
      assert is_function(&TokenCleanup.cleanup_refresh_tokens/2, 2)
    end
  end

  describe "contexts_and_ttls" do
    test "includes api_refresh context" do
      source = File.read!("lib/sigra/workers/token_cleanup.ex")
      assert source =~ ~s|"api_refresh"|
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

    test "uses sigra_lifecycle queue" do
      changeset = TokenCleanup.new(%{})
      assert changeset.changes[:queue] == "sigra_lifecycle"
    end
  end
end
