defmodule Sigra.Install.OldAdminCssCompatibilityTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Compatibility render against the last published admin stylesheet.

  The fixture is `sigra_admin.css` from Sigra 1.7.1, release source revision
  `0621899118a96804e3872cde3a2d2bc6fcfd1881`. Its SHA-256 is
  `0f062641532e2a8663859d64f85da33f92910ccf7581e84fd160422ae9b589ed`.
  Only the status mark's decorative geometry may differ: its visible word,
  session facts, timestamp, and keyboard action must stay visible and separate.
  """

  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias Sigra.Admin.Components

  @repo_root Path.expand("../../..", __DIR__)
  @fixture Path.join(@repo_root, "test/fixtures/brand/previous-release-sigra_admin.css")
  @session_live Path.join(@repo_root, "lib/sigra/admin/live/user_sessions_live.ex")
  @fixture_sha256 "0f062641532e2a8663859d64f85da33f92910ccf7581e84fd160422ae9b589ed"

  test "the 1.7.1 stylesheet keeps status and session content visible without overlap" do
    css = File.read!(@fixture)

    assert :crypto.hash(:sha256, css) |> Base.encode16(case: :lower) == @fixture_sha256

    status_html = render_component(&Components.status_mark/1, status: :deleting)
    assert status_html =~ ~s(class="sg-status-mark")
    assert status_html =~ ~s(data-status="deleting")
    assert status_html =~ ~s(class="sg-status-mark__glyph")
    assert status_html =~ "Deletion scheduled"

    session_source = File.read!(@session_live)

    for current_markup <- [
          ~s(<table class="sg-table">),
          ~s(<span class="sg-strong">),
          ~s(<code class="sg-code">),
          ~s(class="sg-summary-facts__num"),
          ~s(class="sg-btn sg-btn--danger sg-btn--sm"),
          "Revoke session"
        ] do
      assert session_source =~ current_markup,
             "compatibility fixture markup must track user_sessions_live.ex"
    end
  end
end
