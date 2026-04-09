defmodule Sigra.Audit.QueryTest do
  use ExUnit.Case, async: true

  # Wave 0 scaffold. Sigra.Audit.Query lands in Plan 02.

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
      field(:inserted_at, :utc_datetime_usec)
    end
  end

  describe "build/2 filter composition (D-12)" do
    test "actor_id filter adds a where clause" do
      q = Query.build(TestSchema, actor_id: "abc")
      assert inspect(q) =~ "actor_id"
    end

    test "action exact match" do
      q = Query.build(TestSchema, action: "auth.login.success")
      assert inspect(q) =~ "action"
    end

    test "action_prefix uses LIKE with escaped prefix" do
      q = Query.build(TestSchema, action_prefix: "auth.")
      assert inspect(q) =~ ~r/like|LIKE/
    end

    test "outcome filter adds a where clause" do
      q = Query.build(TestSchema, outcome: "failure")
      assert inspect(q) =~ "outcome"
    end

    test "from/to time bounds add where clauses" do
      now = DateTime.utc_now()
      q = Query.build(TestSchema, from: now, to: now)
      s = inspect(q)
      assert s =~ "inserted_at"
    end

    test "target_id and target_type compose" do
      q = Query.build(TestSchema, target_id: "abc", target_type: "User")
      s = inspect(q)
      assert s =~ "target_id"
      assert s =~ "target_type"
    end

    test "multiple filters compose" do
      q = Query.build(TestSchema, actor_id: "abc", outcome: "failure")
      s = inspect(q)
      assert s =~ "actor_id"
      assert s =~ "outcome"
    end
  end

  describe "paginate/3" do
    test "with nil cursor orders desc + limit+1" do
      q0 = Query.build(TestSchema, [])
      q1 = Query.paginate(q0, nil, 50)
      assert inspect(q1) =~ "51"
    end

    test "with cursor adds or-expanded tiebreak (RESEARCH A3)" do
      q0 = Query.build(TestSchema, [])
      dt = DateTime.utc_now()
      q1 = Query.paginate(q0, {dt, "cursor-id"}, 50)
      assert inspect(q1) =~ "inserted_at"
    end
  end
end
