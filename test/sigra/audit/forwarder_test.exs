defmodule Sigra.Audit.ForwarderTest do
  use ExUnit.Case, async: true

  # NOTE: This is a Wave 0 contract test for the Sigra.Audit.Forwarder
  # behaviour (Phase 131, FB-01). The behaviour module is implemented in
  # Task 2 of Plan 131-01. Tests are RED until then — they fail at compile
  # time / load time because `Sigra.Audit.Forwarder` does not yet exist.
  # Once Task 2 lands the behaviour module, these tests must turn green
  # without modification.
  #
  # Mirrors `test/sigra/workers/behaviour_test.exs` lines 1-29 — the in-tree
  # precedent for a behaviour-contract test that defines an inline stub
  # module with `@behaviour ... ; def ..., do: :ok`.

  # Stub host module that implements the Sigra.Audit.Forwarder behaviour.
  # Defining this inside the test file is the FB-01 / Success Criterion #5
  # proof: a host can `@behaviour Sigra.Audit.Forwarder` and implement
  # exactly one callback (`attach/1`) without triggering any `@impl` /
  # `@callback` mismatch warnings at compile time. If Sigra.Audit.Forwarder
  # accidentally grows a second callback (e.g. `handle_event/4` per D-33),
  # the compile of this file will warn — `mix compile --warnings-as-errors`
  # then fails, which is exactly the regression signal we want.
  defmodule StubForwarder do
    @behaviour Sigra.Audit.Forwarder

    @impl Sigra.Audit.Forwarder
    def attach(_opts), do: :ok
  end

  describe "Sigra.Audit.Forwarder behaviour contract" do
    test "exposes exactly one callback (attach/1) — D-01, D-33" do
      # D-01: single `attach/1` callback. D-33: NO `handle_event/4` or any
      # payload-shape callback. behaviour_info/1 is the canonical
      # introspection API for a behaviour's exported callbacks.
      assert Sigra.Audit.Forwarder.behaviour_info(:callbacks) == [attach: 1]
    end

    test "moduledoc documents the Mox.defmock test path — D-04" do
      # D-04: the moduledoc mirrors Sigra.RateLimiter's "## Mox Usage"
      # section so adopters see the supported mock pattern.
      # Code.fetch_docs/1 returns the doc tree; we walk to the moduledoc
      # text and assert it contains the literal mock line.
      {:docs_v1, _anno, _lang, _format, moduledoc, _meta, _docs} =
        Code.fetch_docs(Sigra.Audit.Forwarder)

      moduledoc_text =
        case moduledoc do
          %{"en" => text} -> text
          text when is_binary(text) -> text
          _ -> ""
        end

      assert moduledoc_text =~ "Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)",
             "expected moduledoc to document `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)` per D-04, " <>
               "got moduledoc: #{inspect(moduledoc_text)}"
    end

    test "a host module @behaviour-ing Sigra.Audit.Forwarder compiles cleanly — FB-01 / Success Criterion #5" do
      # If this test file loaded at all, the inline `StubForwarder` module
      # at the top of this file compiled successfully against the behaviour.
      # That is the FB-01 proof: a custom forwarder needs only `attach/1`
      # — no second callback, no surprise contract.
      assert function_exported?(StubForwarder, :attach, 1)
      assert StubForwarder.attach([]) == :ok
    end
  end
end
