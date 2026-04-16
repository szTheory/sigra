defmodule Sigra.Admin.UsersQueryTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Wave 0 contract coverage for the Phase 28 admin user query surface.

  These contracts lock the required query params and operational filter
  semantics before the implementation arrives in Plans 28-02 through 28-04.
  """

  describe "Phase 28 query contracts" do
    @tag :skip
    test "search supports email, id, display name, and organization membership lookups" do
      assert true
    end

    @tag :skip
    test "filters include confirmed, mfa, passkeys, locked, deleted, provider, registered_from, and registered_to" do
      assert true
    end

    @tag :skip
    test "URL-addressable filtering and pagination remain scope-safe for global and organization admins" do
      assert true
    end
  end
end
