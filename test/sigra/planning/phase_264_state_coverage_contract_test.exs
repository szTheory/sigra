defmodule Sigra.Planning.Phase264StateCoverageContractTest do
  use ExUnit.Case, async: true

  @branding_path "lib/sigra/admin/live/branding_live.ex"
  @hooks_path "test/example/assets/js/admin_hooks.js"

  @not_applicable_rows [
    {"UI-08", :branding_empty},
    {"UI-09", :branding_loading},
    {"UI-11", :branding_partial},
    {"UI-12", :branding_long_labels},
    {"UI-14", :command_loading},
    {"UI-15", :command_remote_error},
    {"UI-17", :command_partial}
  ]

  defp branding_source, do: File.read!(@branding_path)

  defp command_source do
    source = File.read!(@hooks_path)

    [command_block] =
      Regex.run(
        ~r/var CmdK = \{(.*?)\/\/ ---- ConfirmDialog hook/s,
        source,
        capture: :all_but_first
      )

    command_block
  end

  test "the amended matrix has exactly seven uniquely named N/A invariants" do
    ids = Enum.map(@not_applicable_rows, &elem(&1, 0))

    assert length(ids) == 7
    assert length(Enum.uniq(ids)) == 7
    assert Enum.sort(ids) == ~w(UI-08 UI-09 UI-11 UI-12 UI-14 UI-15 UI-17)

    assert Enum.all?(@not_applicable_rows, fn {_id, invariant} ->
             invariant in [
               :branding_empty,
               :branding_loading,
               :branding_partial,
               :branding_long_labels,
               :command_loading,
               :command_remote_error,
               :command_partial
             ]
           end)
  end

  test "UI-08 empty branding palette is excluded by fixed nonempty palettes" do
    source = branding_source()

    assert length(
             Regex.scan(
               ~r/\{"[a-z_]+", "[^"]+"\}/,
               source |> String.split("@dark_color_fields") |> hd()
             )
           ) == 7

    assert length(Regex.scan(~r/\{"dark_[a-z_]+", "[^"]+"\}/, source)) == 7
    assert source =~ ~s(:for={{name, label} <- @light_color_fields})
    assert source =~ ~s(:for={{name, label} <- @dark_color_fields})
  end

  test "UI-09 branding loading state is excluded by synchronous local field arrays" do
    source = branding_source()

    refute source =~ "Task.async"
    refute source =~ "handle_info"
    refute source =~ "loading"
    assert source =~ "@light_color_fields ["
    assert source =~ "@dark_color_fields ["
    assert source =~ "value={field_value(@draft_params, name)}"
  end

  test "UI-11 partial branding palettes cannot omit a rendered color field" do
    source = branding_source()

    assert length(
             Regex.scan(
               ~r/\{"[a-z_]+", "[^"]+"\}/,
               source |> String.split("@dark_color_fields") |> hd()
             )
           ) == 7

    assert length(Regex.scan(~r/\{"dark_[a-z_]+", "[^"]+"\}/, source)) == 7
    assert length(Regex.scan(~r/value=\{field_value\(@draft_params, name\)\}/, source)) == 2
  end

  test "UI-12 branding labels come from the fixed seven-pair inventories" do
    source = branding_source()
    [light] = Regex.run(~r/@light_color_fields \[(.*?)\n  \]/s, source, capture: :all_but_first)
    [dark] = Regex.run(~r/@dark_color_fields \[(.*?)\n  \]/s, source, capture: :all_but_first)

    assert length(Regex.scan(~r/\{"[a-z_]+", "[^"]+"\}/, light)) == 7
    assert length(Regex.scan(~r/\{"dark_[a-z_]+", "[^"]+"\}/, dark)) == 7
    refute source =~ "label_source"
  end

  test "UI-14 command palette loading state is excluded by its local synchronous source" do
    source = command_source()

    assert source =~ "this.commands = ["
    assert source =~ "this.filtered = this.commands.slice()"
    assert source =~ "self.renderItems(input.value)"
    refute source =~ "fetch("
    refute source =~ "Promise"
    refute source =~ "loading"
  end

  test "UI-15 command palette remote-error state is excluded by its local source" do
    source = command_source()

    assert length(Regex.scan(~r/label: /, source)) == 3
    refute source =~ "fetch("
    refute source =~ "XMLHttpRequest"
    refute source =~ "error"
  end

  test "UI-17 command palette partial results come from the full in-memory filter" do
    source = command_source()

    assert source =~ "this.commands = ["
    assert source =~ "this.commands.filter(function (cmd)"
    assert source =~ "this.filtered = q"
    assert length(Regex.scan(~r/label: /, source)) == 3
  end
end
