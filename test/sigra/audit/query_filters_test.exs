defmodule Sigra.Audit.QueryFiltersTest do
  @moduledoc """
  Wave 0 tests for the three new `Sigra.Audit.Query` filter keys plus the
  strict whitelist enforcement (D-15 breaking change).

  Created as `@tag :skip` stubs by Plan 15-01 Task 0 and un-skipped by
  Plan 15-01 Task 1 when the filters are implemented.
  """
  use ExUnit.Case, async: true

  alias Sigra.Audit.Query

  defmodule TestSchema do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "audit_events" do
      field(:action, :string)
      field(:outcome, :string)
      field(:actor_id, :binary_id)
      field(:target_id, :binary_id)
      field(:target_type, :string)
      field(:organization_id, :binary_id)
      field(:effective_user_id, :binary_id)
      field(:inserted_at, :utc_datetime_usec)
    end
  end


  test "build/2 filters by :organization_id equality" do
    id = Ecto.UUID.generate()
    q = Query.build(TestSchema, organization_id: id)
    s = inspect(q)
    assert s =~ "organization_id"
  end


  test "build/2 filters by :organization_id nil => IS NULL" do
    q = Query.build(TestSchema, organization_id: nil)
    s = inspect(q)
    assert s =~ "organization_id"
    assert s =~ ~r/is_nil|IS NULL/i
  end


  test "build/2 filters by :effective_user_id equality and nil" do
    id = Ecto.UUID.generate()
    q1 = Query.build(TestSchema, effective_user_id: id)
    q2 = Query.build(TestSchema, effective_user_id: nil)
    assert inspect(q1) =~ "effective_user_id"
    assert inspect(q2) =~ ~r/is_nil|IS NULL/i
  end


  test "build/2 :organization_scope {:only, org_id} filters strict" do
    id = Ecto.UUID.generate()
    q = Query.build(TestSchema, organization_scope: {:only, id})
    s = inspect(q)
    assert s =~ "organization_id"
    refute s =~ ~r/is_nil|IS NULL/i
  end


  test "build/2 :organization_scope {:including_global, org_id} returns rows with matching org_id OR NULL org_id" do
    id = Ecto.UUID.generate()
    q = Query.build(TestSchema, organization_scope: {:including_global, id})
    s = inspect(q)
    assert s =~ "organization_id"
    assert s =~ ~r/is_nil|IS NULL/i
  end


  test "build/2 raises ArgumentError on unknown filter key (breaking change per D-15)" do
    assert_raise ArgumentError, ~r/unknown filter key/, fn ->
      Query.build(TestSchema, actor: "wrong")
    end
  end
end
