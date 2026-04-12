defmodule Sigra.Testing.AssertAuditLoggedTest do
  use ExUnit.Case, async: true

  # This file is a Wave 0 stub created by Plan 15-01 Task 0 for
  # consumption by Plan 15-02 Task 3 (adds `assert_audit_logged/2` to
  # `lib/sigra/testing.ex` as a thin alias for `assert_audit_event/2`).
  #
  # All tests are @tag :skip until 15-02 implements the helper.
  #
  # Signature note (see Plan 15-02 `deviations` field):
  # `assert_audit_logged(expected :: map(), opts :: keyword())`
  # NOT `assert_audit_logged(repo, fields)` — the D-31 CONTEXT signature
  # was refined during planning after surveying the existing
  # `assert_audit_event/2` at lib/sigra/testing.ex:1150.

  @tag :skip
  test "assert_audit_logged/2 passes when latest row matches given map fields" do
    # 15-02 executor: insert a row via AuditTestEvent then call:
    #   assert assert_audit_logged(%{action: "test.event"}, repo: TestRepo, audit_schema: AuditTestEvent) == true
    flunk("Wave 0 stub — implemented in Plan 15-02 Task 3")
  end

  @tag :skip
  test "assert_audit_logged/2 fails with a clear ExUnit.AssertionError when a field does not match" do
    # 15-02 executor: assert_raise ExUnit.AssertionError, ~r/Expected action/, fn -> ... end
    flunk("Wave 0 stub — implemented in Plan 15-02 Task 3")
  end

  @tag :skip
  test "assert_audit_logged/2 raises FunctionClauseError when first arg is not a map" do
    # 15-02 executor: assert_raise FunctionClauseError, fn ->
    #   assert_audit_logged([action: "test.event"], repo: TestRepo, audit_schema: AuditTestEvent)
    # end
    flunk("Wave 0 stub — implemented in Plan 15-02 Task 3")
  end

  @tag :skip
  test "assert_audit_logged/2 raises KeyError when opts is missing :audit_schema" do
    # 15-02 executor: assert_raise KeyError, fn ->
    #   assert_audit_logged(%{action: "test.event"}, repo: TestRepo)
    # end
    flunk("Wave 0 stub — implemented in Plan 15-02 Task 3")
  end
end
