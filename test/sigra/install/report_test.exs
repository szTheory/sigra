defmodule Sigra.Install.ReportTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Report

  test "new/0 returns a struct with four empty lists" do
    r = Report.new()
    assert r.generated == []
    assert r.modified == []
    assert r.skipped == []
    assert r.manual_actions == []
  end

  test "record_* functions accumulate in their respective columns" do
    r =
      Report.new()
      |> Report.record_generated("lib/my_app/user.ex")
      |> Report.record_modified("lib/my_app_web/router.ex")
      |> Report.record_skipped("priv/repo/migrations/20260411_x.exs", "already exists")
      |> Report.record_manual_action("Add SIGRA_SECRET to .env")

    assert r.generated == ["lib/my_app/user.ex"]
    assert r.modified == ["lib/my_app_web/router.ex"]
    assert [%{path: "priv/repo/migrations/20260411_x.exs", reason: "already exists"}] = r.skipped
    assert r.manual_actions == ["Add SIGRA_SECRET to .env"]
  end

  test "record_skipped/3 captures both path and reason" do
    r =
      Report.new()
      |> Report.record_skipped("a.exs", "already exists")
      |> Report.record_skipped("b.exs", "already injected")

    reasons = r.skipped |> Enum.map(& &1.reason) |> Enum.sort()
    assert reasons == ["already exists", "already injected"]
  end

  test "render_summary/1 output contains all four column headers and recorded entries" do
    summary =
      Report.new()
      |> Report.record_generated("a.ex")
      |> Report.record_generated("b.ex")
      |> Report.record_skipped("c.exs", "existing")
      |> Report.record_manual_action("set SIGRA_SECRET")
      |> Report.render_summary()
      |> IO.iodata_to_binary()

    assert summary =~ "Generated"
    assert summary =~ "Modified"
    assert summary =~ "Skipped"
    assert summary =~ "Manual Action"
    assert summary =~ "a.ex"
    assert summary =~ "b.ex"
    assert summary =~ "c.exs"
    assert summary =~ "existing"
    assert summary =~ "set SIGRA_SECRET"
  end

  test "render_summary/1 on an empty report still produces headers" do
    out = Report.new() |> Report.render_summary() |> IO.iodata_to_binary()
    assert out =~ "Generated"
    assert out =~ "Modified"
    assert out =~ "Skipped"
    assert out =~ "Manual Action"
  end

  test "render_summary/1 sorts entries within a column (snapshot stability)" do
    out =
      Report.new()
      |> Report.record_generated("z.ex")
      |> Report.record_generated("a.ex")
      |> Report.render_summary()
      |> IO.iodata_to_binary()

    a_idx = :binary.match(out, "a.ex") |> elem(0)
    z_idx = :binary.match(out, "z.ex") |> elem(0)
    assert a_idx < z_idx
  end

  test "render_summary/1 pads columns to at least header width (long-path alignment)" do
    # Entry longer than any header — ensure no truncation + no trailing empty row.
    long = String.duplicate("x", 80) <> ".ex"

    out =
      Report.new()
      |> Report.record_generated(long)
      |> Report.render_summary()
      |> IO.iodata_to_binary()

    assert out =~ long
    # No trailing empty-row artifact (the max..max+1 off-by-one bug)
    lines = out |> String.trim_trailing("\n") |> String.split("\n")
    refute List.last(lines) |> String.trim() == ""
  end
end
