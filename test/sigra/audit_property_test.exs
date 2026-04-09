defmodule Sigra.Audit.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  # Wave 0 scaffold. Sigra.Audit.Cursor and Sigra.Audit.Changeset land in Plan 02.

  alias Sigra.Audit.{Changeset, Cursor}
  alias Sigra.Test.AuditEvent, as: TestEvent

  property "cursor roundtrip for arbitrary (DateTime, UUID)" do
    check all(
            ts <- integer(0..4_000_000_000_000_000),
            uuid <- binary(length: 36)
          ) do
      dt = DateTime.from_unix!(ts, :microsecond)
      cursor = Cursor.encode(dt, uuid)
      assert {:ok, {^dt, ^uuid}} = Cursor.decode(cursor)
    end
  end

  property "forbidden keys always rejected" do
    check all(
            key <- member_of(Changeset.forbidden_keys()),
            value <- string(:printable, min_length: 1, max_length: 20)
          ) do
      event = %TestEvent{}

      attrs = %{
        action: "test.event.one",
        outcome: "success",
        occurred_at: DateTime.utc_now(),
        metadata: %{key => value}
      }

      cs = Changeset.changeset(event, attrs, allow_reserved: true)
      refute cs.valid?
    end
  end

  property "valid action regex generator always passes (D-19)" do
    check all(
            seg1 <- string(?a..?z, min_length: 1, max_length: 6),
            seg2 <- string(?a..?z, min_length: 1, max_length: 6)
          ) do
      action = seg1 <> "." <> seg2
      event = %TestEvent{}

      attrs = %{
        action: action,
        outcome: "success",
        occurred_at: DateTime.utc_now(),
        metadata: %{}
      }

      cs = Changeset.changeset(event, attrs, allow_reserved: true)
      assert cs.valid?, "expected #{action} to be valid"
    end
  end
end
