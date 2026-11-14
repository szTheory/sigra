defmodule Sigra.Brand.CopyInventoryTest do
  @moduledoc """
  Keeps the committed per-lane copy inventory equal to what the sources
  actually say (BCOPY-04).

  Each lane's TSV under `test/fixtures/brand/copy-inventory/` must equal a fresh
  extraction. A copy change therefore shows up as a reviewed inventory diff.
  Regeneration is opt-in (`SIGRA_BRAND_COPY=regen`); by default the test only
  reads. A positive control proves the equality check can go red.
  """

  use ExUnit.Case, async: true

  alias Sigra.Test.Brand.CopyInventory

  # Written once, before any test reads a TSV, so the async tests never race the
  # regeneration. Off unless the opt-in environment variable is set.
  setup_all do
    if CopyInventory.regenerate?() do
      Enum.each(CopyInventory.lanes(), &CopyInventory.write!/1)
    end

    :ok
  end

  describe "host lane" do
    test "extraction carries the Profile default strings and one lane note" do
      rows = CopyInventory.extract(:host)

      kinds = Enum.map(rows, fn {_file, kind, _string} -> kind end)

      assert rows == Enum.sort(Enum.uniq(rows))
      assert {"lib/sigra/branding/profile.ex", "profile_default:product_name", "Your app"} in rows

      assert {"lib/sigra/branding/profile.ex", "profile_default:logo_alt", "Application logo"} in rows

      assert {"lib/sigra/branding/profile.ex", "profile_default:email_from_name", "Your app"} in rows

      assert Enum.count(kinds, &(&1 == "lane_note")) == 1

      assert Enum.any?(rows, fn {_file, kind, string} ->
               kind == "lane_note" and String.contains?(string, "no Sigra copy by design")
             end)
    end

    test "extraction leaves design-token colors out, because they are not copy" do
      rows = CopyInventory.extract(:host)

      refute Enum.any?(rows, fn {_file, _kind, string} -> String.starts_with?(string, "#") end)
    end

    test "the committed inventory equals the extraction" do
      assert_inventory_current(:host)
    end
  end

  describe "diff_rows/2 positive control" do
    test "reports exactly the planted extra row and the planted missing row" do
      fresh = CopyInventory.extract(:host)
      [missing | kept] = fresh
      extra = {"planted/file.ex", "literal", "A planted row the sources do not have"}

      diff = CopyInventory.diff_rows([extra | kept], fresh)

      assert diff == %{added: [missing], removed: [extra]}
    end

    test "reports nothing when the inputs are equal" do
      fresh = CopyInventory.extract(:host)

      assert CopyInventory.diff_rows(fresh, fresh) == %{added: [], removed: []}
    end
  end

  describe "render/2 and parse/1" do
    test "round-trip losslessly for tabs, newlines, carriage returns and backslashes" do
      rows = [
        {"a/b.ex", "literal", "tab\there"},
        {"a/b.ex", "literal", "line one\nline two"},
        {"a/b.ex", "literal", "carriage\rreturn"},
        {"a/b.ex", "literal", "back\\slash and a literal \\n sequence"},
        {"a/b.ex", "literal", "plain"}
      ]

      parsed = CopyInventory.parse(CopyInventory.render(:host, rows))

      assert parsed == rows
    end

    test "header lines are comments that parse skips" do
      text = CopyInventory.render(:host, [{"a.ex", "literal", "Only row"}])

      assert String.starts_with?(text, "# ")
      assert String.contains?(text, CopyInventory.regen_command())
      assert CopyInventory.parse(text) == [{"a.ex", "literal", "Only row"}]
    end
  end

  defp assert_inventory_current(lane) do
    path = CopyInventory.path_for(lane)

    committed =
      case File.read(path) do
        {:ok, text} ->
          CopyInventory.parse(text)

        {:error, reason} ->
          flunk("""
          Copy inventory for lane #{inspect(lane)} is unreadable (#{inspect(reason)}): #{path}

          Generate it with:

              #{CopyInventory.regen_command()}
          """)
      end

    diff = CopyInventory.diff_rows(committed, CopyInventory.extract(lane))

    if diff.added != [] or diff.removed != [] do
      flunk("""
      The committed #{lane} copy inventory no longer equals the extraction.

      #{format_rows("Rows the sources now have (missing from the TSV)", diff.added)}
      #{format_rows("Rows the TSV has that the sources no longer produce", diff.removed)}
      If this copy change is intended, regenerate the inventory, review the TSV diff, and commit it:

          #{CopyInventory.regen_command()}
      """)
    end
  end

  defp format_rows(_title, []), do: ""

  defp format_rows(title, rows) do
    shown =
      rows
      |> Enum.take(40)
      |> Enum.map_join("\n", fn {file, kind, string} ->
        "    #{file} | #{kind} | #{inspect(string)}"
      end)

    more = if length(rows) > 40, do: "\n    ... and #{length(rows) - 40} more", else: ""

    "#{title} (#{length(rows)}):\n#{shown}#{more}\n"
  end
end
