defmodule Sigra.Email.CssLintTest do
  @moduledoc """
  Unit tests for the caniemail CSS allowlist/deny-list lint gate.

  Tests verify that Sigra.Email.CssLint can evaluate rendered email HTML against
  the vendored Gmail web / new Outlook web / Apple Mail policy without any
  network access.

  Phase 86 D-86-02, D-86-03, D-86-09.
  """
  use ExUnit.Case, async: true

  alias Sigra.Email.CssLint

  # Minimal safe email HTML with only allow-listed CSS properties
  @safe_html """
  <!DOCTYPE html>
  <html lang="en">
  <body style="background-color: #f4f4f5;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
      <tr>
        <td style="padding: 24px; color: #3f3f46; font-size: 16px; font-family: sans-serif;">
          <p style="margin: 0 0 12px 0; font-weight: 600;">Hello</p>
          <a href="https://example.test/reset" style="background-color: #1d4ed8; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 700; font-size: 16px;" role="link">
            Reset password
          </a>
        </td>
      </tr>
    </table>
  </body>
  </html>
  """

  # HTML with denied CSS properties that break Outlook / GMail layout
  @unsafe_html_flex """
  <!DOCTYPE html>
  <html lang="en">
  <body>
    <div style="display: flex; background-color: #ffffff;">
      <p style="color: #000000;">Hello</p>
    </div>
  </body>
  </html>
  """

  @unsafe_html_grid """
  <!DOCTYPE html>
  <html lang="en">
  <body>
    <div style="display: grid; gap: 10px;">
      <p>Hello</p>
    </div>
  </body>
  </html>
  """

  @unsafe_html_position """
  <!DOCTYPE html>
  <html lang="en">
  <body>
    <div style="position: absolute; top: 0;">
      <p>Hello</p>
    </div>
  </body>
  </html>
  """

  @unsafe_html_bg_image """
  <!DOCTYPE html>
  <html lang="en">
  <body>
    <div style="background-image: url(https://example.com/logo.png); background-color: #fff;">
      <p>Hello</p>
    </div>
  </body>
  </html>
  """

  @unsafe_html_style_block """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <style>
      body { background-color: #f4f4f5; }
      .cta { background-color: #1d4ed8; }
    </style>
  </head>
  <body>
    <p>Hello</p>
  </body>
  </html>
  """

  describe "lint/1" do
    test "returns :ok for HTML using only allow-listed CSS properties" do
      assert :ok = CssLint.lint(@safe_html)
    end

    test "returns error for display:flex (not supported by Gmail/Outlook/Apple Mail)" do
      assert {:error, violations} = CssLint.lint(@unsafe_html_flex)
      assert is_list(violations)
      assert length(violations) > 0
      assert Enum.any?(violations, &String.contains?(&1, "flex"))
    end

    test "returns error for display:grid (not supported by Gmail/Outlook/Apple Mail)" do
      assert {:error, violations} = CssLint.lint(@unsafe_html_grid)
      assert is_list(violations)
      assert Enum.any?(violations, &String.contains?(&1, "grid"))
    end

    test "returns error for position: (ignored by Outlook Word-engine)" do
      assert {:error, violations} = CssLint.lint(@unsafe_html_position)
      assert is_list(violations)
      assert Enum.any?(violations, &String.contains?(&1, "position"))
    end

    test "returns error for background-image: (stripped by Outlook Word-engine)" do
      assert {:error, violations} = CssLint.lint(@unsafe_html_bg_image)
      assert is_list(violations)
      assert Enum.any?(violations, &String.contains?(&1, "background-image"))
    end

    test "returns error for <style> block (Word-engine ignores external styles)" do
      assert {:error, violations} = CssLint.lint(@unsafe_html_style_block)
      assert is_list(violations)
      assert Enum.any?(violations, &String.contains?(&1, "style"))
    end

    test "returns multiple violations when multiple deny-listed constructs are present" do
      combined = """
      <!DOCTYPE html>
      <html>
      <head><style>body { background: #fff; }</style></head>
      <body>
        <div style="display: flex; position: absolute;">Hello</div>
      </body>
      </html>
      """

      assert {:error, violations} = CssLint.lint(combined)
      assert length(violations) >= 2
    end
  end

  describe "allowlist/0" do
    test "returns a map with clients, allow_css, and deny_css keys" do
      policy = CssLint.allowlist()
      assert is_map(policy)
      assert Map.has_key?(policy, "clients")
      assert Map.has_key?(policy, "allow_css")
      assert Map.has_key?(policy, "deny_css")
    end

    test "clients list includes gmail-web, outlook-web-new, and apple-mail-macos" do
      %{"clients" => clients} = CssLint.allowlist()
      assert "gmail-web" in clients
      assert "outlook-web-new" in clients
      assert "apple-mail-macos" in clients
    end

    test "allow_css includes common safe properties" do
      %{"allow_css" => allowed} = CssLint.allowlist()
      assert "background-color" in allowed
      assert "color" in allowed
      assert "font-size" in allowed
      assert "padding" in allowed
    end

    test "deny_css includes the four Word-engine landmine constructs" do
      %{"deny_css" => denied} = CssLint.allowlist()
      assert "display:flex" in denied or Enum.any?(denied, &String.contains?(&1, "flex"))
      assert "display:grid" in denied or Enum.any?(denied, &String.contains?(&1, "grid"))
      assert "position" in denied or Enum.any?(denied, &String.contains?(&1, "position"))
      assert "background-image" in denied or Enum.any?(denied, &String.contains?(&1, "background-image"))
    end
  end
end
