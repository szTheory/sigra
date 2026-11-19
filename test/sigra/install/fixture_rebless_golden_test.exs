defmodule Mix.Tasks.Sigra.Fixture.ReblessGoldenTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @task_source "lib/mix/tasks/sigra.fixture.rebless_golden.ex"

  test "help is recognized and branched before any writer lifecycle operation" do
    source = File.read!(@task_source)

    assert source =~ "{:help, _argv}", "expected an explicit read-only help branch"

    help_branch = :binary.match(source, "{:help, _argv}") |> elem(0)

    for lifecycle_call <- [
          "Mix.env(:test)",
          "Mix.Task.run(\"loadpaths\")",
          "Mix.Task.run(\"compile\")",
          "InstallFixture.setup_tmp_app()",
          "File.write!(target_stdout, stdout)"
        ] do
      assert help_branch < :binary.match(source, lifecycle_call) |> elem(0),
             "expected --help to branch before #{lifecycle_call}"
    end
  end

  test "help prints usage and does not invoke the lifecycle callback" do
    parent = self()

    output =
      capture_io(fn ->
        assert :ok ==
                 Mix.Tasks.Sigra.Fixture.ReblessGolden.run_with_lifecycle(["--help"], fn _mode ->
                   send(parent, :lifecycle_invoked)
                 end)
      end)

    assert output =~ "Usage: MIX_ENV=test mix sigra.fixture.rebless_golden"
    assert output =~ "--check"
    refute_received :lifecycle_invoked
  end

  test "unknown switches fail before invoking the lifecycle callback" do
    assert_invalid_argv(["--unknown"])
  end

  test "unexpected positionals fail before invoking the lifecycle callback" do
    assert_invalid_argv(["fixture"])
  end

  test "help combined with invalid extra input is rejected" do
    assert_invalid_argv(["--help", "--unknown"])
    assert_invalid_argv(["--help", "extra"])
    assert_invalid_argv(["--help", "--check"])
  end

  test "no arguments and --check select their documented modes" do
    assert :write ==
             Mix.Tasks.Sigra.Fixture.ReblessGolden.run_with_lifecycle([], fn mode -> mode end)

    assert :check ==
             Mix.Tasks.Sigra.Fixture.ReblessGolden.run_with_lifecycle(["--check"], fn mode ->
               mode
             end)
  end

  defp assert_invalid_argv(argv) do
    parent = self()

    assert_raise Mix.Error, fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Sigra.Fixture.ReblessGolden.run_with_lifecycle(argv, fn mode ->
          send(parent, {:lifecycle_invoked, mode})
        end)
      end)
    end

    refute_received {:lifecycle_invoked, _mode}
  end
end
