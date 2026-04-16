defmodule Sigra.Admin.UsersActionsTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Wave 0 contract coverage for Phase 28 admin user actions.

  These tests reserve the action and audit semantics for session revocation
  before the implementation is introduced.
  """

  describe "Phase 28 action contracts" do
    @tag :skip
    test "revoke_session emits audit coverage and keeps scope checks in the library action layer" do
      assert true
    end

    @tag :skip
    test "revoke_all_sessions emits audit coverage and uses the canonical session APIs" do
      assert true
    end

    @tag :skip
    test "audit preview contracts keep revoke semantics and target identity details visible" do
      assert true
    end
  end
end
