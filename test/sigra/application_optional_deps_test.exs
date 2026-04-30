defmodule Sigra.ApplicationOptionalDepsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Sigra.Application

  describe "maybe_warn_audit_cleanup_fallback/2" do
    test "warns only when retention is configured and Oban is unavailable" do
      log =
        capture_log(fn ->
          assert :ok =
                   Application.maybe_warn_audit_cleanup_fallback(30, fn
                     Oban -> false
                   end)
        end)

      assert log =~ "retention_days=30"
      assert log =~ "Oban is not loaded"
    end

    test "stays quiet when retention is unset or Oban is available" do
      assert capture_log(fn ->
               assert :ok = Application.maybe_warn_audit_cleanup_fallback(nil, fn _ -> false end)
               assert :ok = Application.maybe_warn_audit_cleanup_fallback(30, fn Oban -> true end)
             end) == ""
    end
  end

  describe "compile_warning_rows/1" do
    test "returns host-proven warnings only for enabled missing compile-warning features" do
      rows =
        Application.compile_warning_rows(
          jwt: [enabled: true],
          dependency_loaded?: fn spec -> spec.dependency != :joken end
        )

      assert [%{feature: :jwt, dependency: :joken, evidence: "jwt[:enabled] == true"}] = rows
    end

    test "ignores advisory and inactive optional dependencies" do
      assert [] =
               Application.compile_warning_rows(
                 oauth_enabled?: true,
                 dependency_loaded?: fn _spec -> false end
               )
    end
  end
end
