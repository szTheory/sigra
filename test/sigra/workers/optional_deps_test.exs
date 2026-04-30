defmodule Sigra.Workers.OptionalDepsTest do
  use ExUnit.Case, async: true

  alias Sigra.OptionalDeps.MissingDependencyError
  alias Sigra.Workers.AccountDeletion
  alias Sigra.Workers.AuditCleanup
  alias Sigra.Workers.CleanupExpiredInvitations
  alias Sigra.Workers.TokenCleanup

  @workers [
    {AccountDeletion, %{"user_id" => 1, "repo" => "Elixir.Sigra.Repo", "user_schema" => "Elixir.Sigra.User"}},
    {AuditCleanup, %{"repo" => "Elixir.Sigra.Repo", "audit_schema" => "Elixir.Sigra.AuditEvent"}},
    {TokenCleanup, %{"repo" => "Elixir.Sigra.Repo", "token_schema" => "Elixir.Sigra.UserToken"}},
    {CleanupExpiredInvitations,
     %{
       "organization_id" => nil,
       "actor_id" => nil,
       "repo" => "Elixir.Sigra.Repo",
       "invitation_schema" => "Elixir.Sigra.OrganizationInvitation",
       "scope_module" => "Elixir.Sigra.Scope",
       "retention_days" => 30
     }}
  ]

  describe "queue-backed workers stay loadable without compile-time disappearance" do
    test "worker modules remain defined" do
      Enum.each(@workers, fn {worker, _args} ->
        assert Code.ensure_loaded?(worker)
      end)
    end

    test "first queue-backed interaction raises the tagged missing async dependency error" do
      Enum.each(@workers, fn {worker, args} ->
        assert_raise MissingDependencyError, ~r/optional dependency missing for lifecycle_jobs/, fn ->
          worker.new(args, dependency_loaded?: fn _spec -> false end)
        end
      end)
    end
  end
end
