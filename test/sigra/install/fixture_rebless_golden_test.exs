defmodule Mix.Tasks.Sigra.Fixture.ReblessGoldenTest do
  use ExUnit.Case, async: true

  @task_source "lib/mix/tasks/sigra.fixture.rebless_golden.ex"

  test "help is recognized and branched before any writer lifecycle operation" do
    source = File.read!(@task_source)

    assert source =~ "{:help, argv}", "expected an explicit read-only help branch"

    help_branch = :binary.match(source, "{:help, argv}") |> elem(0)

    for lifecycle_call <- [
          "Mix.env(:test)",
          "Mix.Task.run(\"loadpaths\")",
          "Mix.Task.run(\"compile\")",
          "InstallFixture.setup_tmp_app()",
          "File.write!(target_stdout, stdout)"
        ] do
      assert help_branch < (:binary.match(source, lifecycle_call) |> elem(0)),
             "expected --help to branch before #{lifecycle_call}"
    end
  end
end
