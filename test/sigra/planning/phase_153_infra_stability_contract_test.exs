defmodule Sigra.Planning.Phase153InfraStabilityContractTest do
  use ExUnit.Case, async: true

  @phase_dir ".planning/phases/153-infra-stability"
  @shared_repo "test/support/postgres_test_repo.ex"
  @postgres_case "test/support/postgres_case.ex"
  @scratch_repo "test/support/audit_query_index_scratch_repo.ex"
  @query_index_test "test/sigra/audit/query_index_test.exs"
  @ci ".github/workflows/ci.yml"

  @live_db_tests [
    "test/sigra/api_token_audit_atomic_test.exs",
    "test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs",
    "test/sigra/mfa_audit_atomicity_test.exs",
    "test/sigra/auth/register_audit_atomicity_test.exs",
    "test/sigra/account_audit_atomicity_test.exs",
    "test/sigra/auth/login_and_lockout_audit_atomicity_test.exs",
    "test/sigra/oauth/oauth_ceremony_audit_test.exs",
    "test/sigra/oauth/oauth_audit_atomicity_test.exs",
    "test/sigra/audit/audit_assertions_test.exs",
    "test/sigra/audit/forwarders/threadline_test.exs",
    "test/sigra/jwt_refresh_audit_cofate_test.exs",
    "test/sigra/audit_multi_step_test.exs",
    "test/sigra/admin/users_query_test.exs",
    "test/sigra/admin/users_actions_test.exs",
    "test/sigra/admin/audit/query_test.exs"
  ]

  test "shared library Postgres repo is sandbox-backed and started centrally" do
    repo = File.read!(@shared_repo)
    helper = File.read!("test/test_helper.exs")
    postgres_case = File.read!(@postgres_case)

    assert repo =~ "pool: Ecto.Adapters.SQL.Sandbox"
    assert repo =~ "ownership_timeout"
    assert helper =~ "Sandbox.mode(Sigra.Test.PostgresRepo, :manual)"
    assert postgres_case =~ ~r/start_owner!\(\s*Sigra\.Test\.PostgresRepo/
    assert postgres_case =~ "stop_owner(sandbox_owner)"
  end

  test "shared-repo live DB tests use owner-per-test sandbox cleanup" do
    for path <- @live_db_tests do
      source = File.read!(path)

      assert source =~ "use Sigra.Test.PostgresCase, async: false"
      refute source =~ "start_supervised!({PostgresRepo, PostgresRepo.default_config()})"
      refute source =~ "start_supervised!({Sigra.Test.PostgresRepo"
      refute source =~ "start_supervised!({@repo, @repo.default_config()})"
      refute source =~ "TRUNCATE TABLE"
    end
  end

  test "storage-destructive query planner proof uses an isolated scratch repo" do
    scratch = File.read!(@scratch_repo)
    query_index = File.read!(@query_index_test)

    assert scratch =~ "defmodule Sigra.Test.AuditQueryIndexScratchRepo"
    assert scratch =~ "sigra_audit_query_index_scratch"
    assert query_index =~ "AuditQueryIndexScratchRepo"
    refute query_index =~ "Application.put_env(:sigra"
    refute query_index =~ "Sigra.Test.PostgresRepo"
  end

  test "existing CI proof lanes remain the phase proof surface" do
    ci = File.read!(@ci)
    plan = File.read!(Path.join(@phase_dir, "153-01-PLAN.md"))

    for lane <- [
          "library_tests",
          "library_tests_dep_off",
          "example_unit_smoke",
          "example_playwright_smoke",
          "generated_admin_playwright_smoke"
        ] do
      assert ci =~ lane
      assert plan =~ lane
    end
  end
end
