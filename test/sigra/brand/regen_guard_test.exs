defmodule Sigra.Brand.RegenGuardTest do
  @moduledoc """
  The opt-in fixture writers of the brand suite refuse to run under CI.

  A writer such as `SIGRA_BRAND_COPY=regen` runs before the test that compares
  the fixture with the sources, so the comparison reads back what the writer
  just wrote and passes whatever the sources say. Under `CI=true` that would
  turn a failing contract green, so every writer raises instead. The tests plant
  an environment map; none of them touches the real process environment.
  """

  use ExUnit.Case, async: true

  alias Sigra.Test.Brand.CopyInventory
  alias Sigra.Test.Brand.CopyScan
  alias Sigra.Test.Brand.RegenGuard

  @root Path.expand("../../..", __DIR__)

  describe "ci?/1" do
    test "is true for CI=true and CI=1, whatever the case or padding" do
      for value <- ["true", "TRUE", "True", "1", " true "] do
        assert RegenGuard.ci?(%{"CI" => value}), "CI=#{inspect(value)} must count as CI"
      end
    end

    test "is false when CI is unset, empty, false or 0" do
      for env <- [%{}, %{"CI" => ""}, %{"CI" => "false"}, %{"CI" => "0"}, %{"CI" => "no"}] do
        refute RegenGuard.ci?(env), "#{inspect(env)} must not count as CI"
      end
    end
  end

  describe "requested?/3 (planted environments)" do
    test "is false when the variable is unset or holds another value, in or out of CI" do
      for env <- [%{}, %{"CI" => "true"}] do
        refute RegenGuard.requested?("SIGRA_BRAND_COPY", "regen", env)

        refute RegenGuard.requested?(
                 "SIGRA_BRAND_COPY",
                 "regen",
                 Map.put(env, "SIGRA_BRAND_COPY", "1")
               )
      end
    end

    test "is true outside CI when the variable holds the requesting value" do
      assert RegenGuard.requested?("SIGRA_BRAND_COPY", "regen", %{"SIGRA_BRAND_COPY" => "regen"})

      assert RegenGuard.requested?("SIGRA_BRAND_COPY", "regen", %{
               "SIGRA_BRAND_COPY" => "regen",
               "CI" => "false"
             })
    end

    test "raises naming the variable when it is requested under CI" do
      for ci <- ["true", "1"] do
        env = %{"SIGRA_BRAND_COPY" => "regen", "CI" => ci}

        error =
          assert_raise RuntimeError, fn ->
            RegenGuard.requested?("SIGRA_BRAND_COPY", "regen", env)
          end

        assert error.message =~ "SIGRA_BRAND_COPY=regen"
        assert error.message =~ "refused when CI is set"
      end
    end
  end

  describe "every writer is refused under CI and allowed locally" do
    test "the inventory regeneration flag" do
      assert CopyInventory.regenerate?(%{"SIGRA_BRAND_COPY" => "regen"})
      refute CopyInventory.regenerate?(%{"CI" => "true"})

      assert_raise RuntimeError, ~r/SIGRA_BRAND_COPY=regen.*refused when CI is set/s, fn ->
        CopyInventory.regenerate?(%{"SIGRA_BRAND_COPY" => "regen", "CI" => "true"})
      end
    end

    test "the copy-baseline initialization flag" do
      assert CopyScan.init_requested?(%{"SIGRA_BRAND_COPY_BASELINE" => "init"})
      refute CopyScan.init_requested?(%{"CI" => "true"})

      assert_raise RuntimeError,
                   ~r/SIGRA_BRAND_COPY_BASELINE=init.*refused when CI is set/s,
                   fn ->
                     CopyScan.init_requested?(%{
                       "SIGRA_BRAND_COPY_BASELINE" => "init",
                       "CI" => "true"
                     })
                   end
    end

    test "the frozen-surface extension and legacy-profile write flags share the guard" do
      for {name, value} <- [{"SIGRA_BRAND_BASELINE", "extend"}, {"SIGRA_BRAND_LEGACY", "write"}] do
        assert RegenGuard.requested?(name, value, %{name => value})

        assert_raise RuntimeError, ~r/#{name}=#{value}.*refused when CI is set/s, fn ->
          RegenGuard.requested?(name, value, %{name => value, "CI" => "true"})
        end
      end
    end
  end

  describe "no brand test or helper reads the environment directly" do
    test "every opt-in read goes through the guard, so a new writer cannot skip it" do
      files =
        Path.wildcard(Path.join(@root, "test/sigra/brand/*.exs")) ++
          Path.wildcard(Path.join(@root, "test/support/brand/*.ex"))

      # This module and the guard itself are the only files allowed to name the
      # environment API: the guard reads it, this test describes it.
      exempt = ["test/sigra/brand/regen_guard_test.exs", "test/support/brand/regen_guard.ex"]

      assert length(files) > 10, "the file list is vacuous"

      offenders =
        for file <- files,
            rel = Path.relative_to(file, @root),
            rel not in exempt,
            File.read!(file) =~ ~r/System\.(get_env|fetch_env|fetch_env!)\(/,
            do: rel

      assert offenders == [],
             "These files read the environment directly. Route the read through " <>
               "Sigra.Test.Brand.RegenGuard.requested?/3 so it is refused under CI: #{inspect(offenders)}"
    end

    test "positive control: the pattern does match a direct read" do
      assert ~s|System.get_env("SIGRA_BRAND_X") == "y"| =~
               ~r/System\.(get_env|fetch_env|fetch_env!)\(/
    end
  end
end
