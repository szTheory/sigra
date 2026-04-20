defmodule Sigra.Audit.ChangesetTest do
  use ExUnit.Case, async: true

  # NOTE: This is a Wave 0 test scaffold. The Sigra.Audit.Changeset module
  # is implemented in Plan 02. Tests are RED until then. They are written so
  # that when Plan 02 lands, they turn green without modification.

  alias Sigra.Audit.Changeset
  alias Sigra.Test.AuditEvent, as: TestEvent

  defp base_attrs(overrides \\ %{}) do
    %{
      action: "billing.charge.succeeded",
      outcome: "success",
      occurred_at: DateTime.utc_now(),
      metadata: %{}
    }
    |> Map.merge(overrides)
  end

  describe "changeset/3 action regex (D-19)" do
    test "accepts valid namespaced snake_case actions" do
      for action <- ~w(auth.login.success billing.charge_failed.retry a.b foo_bar.baz_qux) do
        cs =
          Changeset.changeset(%TestEvent{}, base_attrs(%{action: action}), allow_reserved: true)

        assert cs.valid?, "expected #{action} to be valid, got #{inspect(cs.errors)}"
      end
    end

    test "rejects invalid actions" do
      for action <- ~w(Auth.Login foo foo. .foo foo..bar FOO.BAR 1foo.bar) ++ [""] do
        cs =
          Changeset.changeset(%TestEvent{}, base_attrs(%{action: action}), allow_reserved: true)

        refute cs.valid?, "expected #{inspect(action)} to be invalid"
      end
    end
  end

  describe "outcome validation" do
    test "accepts success/failure/error" do
      for outcome <- ~w(success failure error) do
        cs =
          Changeset.changeset(%TestEvent{}, base_attrs(%{outcome: outcome}), allow_reserved: true)

        assert cs.valid?
      end
    end

    test "rejects other values" do
      cs = Changeset.changeset(%TestEvent{}, base_attrs(%{outcome: "ok"}), allow_reserved: true)
      refute cs.valid?
    end
  end

  describe "reserved prefix guardrail (D-17, D-18)" do
    @reserved ~w(auth. session. mfa. oauth. api. account. sigra.)

    test "public mode rejects each reserved prefix" do
      for prefix <- @reserved do
        action = prefix <> "foo.bar"
        cs = Changeset.changeset(%TestEvent{}, base_attrs(%{action: action}))
        refute cs.valid?, "expected #{action} to be rejected in public mode"
        assert {:action, {_, meta}} = Enum.find(cs.errors, fn {k, _} -> k == :action end)
        assert meta[:validation] == :reserved_prefix
      end
    end

    test "allow_reserved: true bypasses for each prefix" do
      for prefix <- @reserved do
        action = prefix <> "foo.bar"

        cs =
          Changeset.changeset(%TestEvent{}, base_attrs(%{action: action}), allow_reserved: true)

        assert cs.valid?
      end
    end
  end

  describe "metadata size cap (D-20)" do
    test "well under default 8KB cap accepts" do
      val = String.duplicate("a", 4_000)

      cs =
        Changeset.changeset(
          %TestEvent{},
          base_attrs(%{metadata: %{"big" => val}}),
          allow_reserved: true
        )

      assert cs.valid?
    end

    test "over-cap rejects with :max_metadata_bytes validation tag" do
      val = String.duplicate("a", 10_000)

      cs =
        Changeset.changeset(
          %TestEvent{},
          base_attrs(%{metadata: %{"big" => val}}),
          allow_reserved: true
        )

      refute cs.valid?
    end

    test "configurable cap is honored" do
      cs =
        Changeset.changeset(
          %TestEvent{},
          base_attrs(%{metadata: %{"k" => "1234567890"}}),
          allow_reserved: true,
          max_metadata_bytes: 8
        )

      refute cs.valid?
    end
  end

  describe "forbidden metadata keys (D-23)" do
    test "each forbidden key in atom form is rejected" do
      for key <- Changeset.forbidden_keys() do
        cs =
          Changeset.changeset(
            %TestEvent{},
            base_attrs(%{metadata: %{key => "secret"}}),
            allow_reserved: true
          )

        refute cs.valid?, "expected atom key #{inspect(key)} to be rejected"
      end
    end

    test "each forbidden key in string form is rejected" do
      for key <- Changeset.forbidden_keys() do
        cs =
          Changeset.changeset(
            %TestEvent{},
            base_attrs(%{metadata: %{Atom.to_string(key) => "secret"}}),
            allow_reserved: true
          )

        refute cs.valid?, "expected string key #{inspect(key)} to be rejected"
      end
    end

    test "benign keys pass" do
      cs =
        Changeset.changeset(
          %TestEvent{},
          base_attrs(%{metadata: %{"provider" => "github", "count" => 3}}),
          allow_reserved: true
        )

      assert cs.valid?
    end
  end
end
