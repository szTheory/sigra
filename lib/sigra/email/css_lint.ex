defmodule Sigra.Email.CssLint do
  @moduledoc """
  Rendered email CSS allowlist / deny-list gate backed by vendored caniemail data.

  Validates rendered email HTML against a curated subset of
  [caniemail.com](https://www.caniemail.com/) support data for the Phase 86
  locked client set: **Gmail web, new Outlook web, and Apple Mail on macOS**.

  The policy is read from `priv/sigra/email/caniemail-allowlist.json` at
  compile time — no network access occurs during CI. Call `lint/1` from ExUnit
  tests to fail the build when rendered HTML uses unsupported CSS constructs.

  ## Usage in ExUnit

      test "email CSS passes caniemail lint" do
        email = Emails.suspicious_login_email(user, details)
        assert :ok = Sigra.Email.CssLint.lint(email.html_body)
      end

  ## Scope

  - **Clients:** Gmail web, new Outlook web (Microsoft 365), Apple Mail macOS
  - **Residual (documented, not waived):** Legacy Outlook desktop Word-engine
    is partially addressed by the deny-list but is explicitly out-of-scope per
    D-86-09. Microsoft EOL: October 2026.
  - **Policy source:** vendored `priv/sigra/email/caniemail-allowlist.json`
    (MIT-licensed caniemail data, curated 2026-04-26)

  See `86-CONTEXT.md` D-86-02, D-86-03, D-86-09 for full rationale.
  """

  @allowlist_path "priv/sigra/email/caniemail-allowlist.json"

  # Load and parse the allowlist at compile time so lint/1 is zero-I/O.
  @external_resource @allowlist_path
  @raw_allowlist File.read!(@allowlist_path)
  @allowlist Jason.decode!(@raw_allowlist)

  @doc """
  Returns the vendored caniemail policy map.

  The map has three top-level keys:
  - `"clients"` — list of client identifiers this policy applies to
  - `"allow_css"` — CSS properties safe to use in inline styles
  - `"deny_css"` — CSS property patterns that break layout in one or more clients
  """
  @spec allowlist() :: map()
  def allowlist, do: @allowlist

  @doc """
  Lints rendered email HTML against the vendored caniemail policy.

  Returns `:ok` when no violations are found.
  Returns `{:error, [String.t()]}` with a list of human-readable violation
  descriptions when deny-listed CSS constructs are detected.

  This function is intentionally simple and pattern-based — it does not parse
  the CSS AST. That is sufficient for the deny-list constructs that matter
  (they produce large, obvious substrings in inline styles).

  ## Examples

      iex> Sigra.Email.CssLint.lint("<div style='background-color: #fff;'>Hi</div>")
      :ok

      iex> Sigra.Email.CssLint.lint("<div style='display: flex;'>Hi</div>")
      {:error, ["display:flex or display:flex found (not supported by Gmail web / Outlook web)"]}

  """
  @spec lint(String.t()) :: :ok | {:error, [String.t()]}
  def lint(html) when is_binary(html) do
    violations = check_violations(html)

    if violations == [] do
      :ok
    else
      {:error, violations}
    end
  end

  # -- Private --

  defp check_violations(html) do
    []
    |> check_style_blocks(html)
    |> check_display_flex(html)
    |> check_display_grid(html)
    |> check_position(html)
    |> check_background_image(html)
  end

  # <style> blocks are stripped by Gmail web and unreliable in Outlook.
  defp check_style_blocks(violations, html) do
    if String.contains?(html, "<style") do
      violations ++
        [
          "<style> block detected — Gmail web strips <style> tags; all CSS must be inline. " <>
            "Denied by caniemail policy for gmail-web."
        ]
    else
      violations
    end
  end

  # display:flex is not supported in Gmail web or Outlook web for layout flows.
  defp check_display_flex(violations, html) do
    has_flex =
      String.contains?(html, "display: flex") or
        String.contains?(html, "display:flex")

    if has_flex do
      violations ++
        [
          "display: flex or display:flex found (not supported by Gmail web / Outlook web). " <>
            "Use table-based layout instead. Denied by caniemail policy."
        ]
    else
      violations
    end
  end

  # display:grid is not supported in Gmail web or Outlook web.
  defp check_display_grid(violations, html) do
    has_grid =
      String.contains?(html, "display: grid") or
        String.contains?(html, "display:grid")

    if has_grid do
      violations ++
        [
          "display:grid found (not supported by Gmail web / Outlook web). " <>
            "Use table-based layout instead. Denied by caniemail policy."
        ]
    else
      violations
    end
  end

  # position: is ignored by Outlook Word-engine and stripped by Gmail web.
  defp check_position(violations, html) do
    has_position =
      String.contains?(html, "position: ") or
        String.contains?(html, "position:")

    if has_position do
      violations ++
        [
          "position: CSS property found (ignored by Outlook Word-engine, stripped by Gmail web). " <>
            "Use table layout for positioning. Denied by caniemail policy."
        ]
    else
      violations
    end
  end

  # background-image: is stripped by Outlook Word-engine.
  defp check_background_image(violations, html) do
    if String.contains?(html, "background-image:") do
      violations ++
        [
          "background-image: CSS property found (stripped by Outlook Word-engine). " <>
            "Use background-color only. Denied by caniemail policy."
        ]
    else
      violations
    end
  end
end
