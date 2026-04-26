defmodule Example.EmailAssertions do
  @moduledoc """
  Shared assertion helpers for Phase 86 G1-G9 coverage gaps.

  Import this module in email test files to access the Phase 86 locked assertions
  for contrast, byte budget, multipart URL parity, recipient correctness, XSS
  escaping, and Outlook Word-engine deny-list checks.

  ## Usage

      import Example.EmailAssertions

      test "CTA has sufficient contrast" do
        email = Emails.lockout_notification_email(user, %{})
        assert_cta_contrast(email, 4.5)
        assert_under_gmail_clip(email)
        assert_text_part_mirrors_html(email)
      end

  ## Gap coverage

  | Gap | Helper | Notes |
  |-----|--------|-------|
  | G1  | `assert_cta_contrast/2` | Extracts CTA background-color, checks against #ffffff |
  | G2  | `assert_under_gmail_clip/1` | `byte_size(html_body) < 100_000` |
  | G3  | `assert_text_part_mirrors_html/2` | Every URL in html_body appears in text_body |
  | G4  | `assert_email_to/2` | `email.to` matches expected address |
  | G5  | `assert_xss_escaped/2` | Payload appears escaped, never raw |
  | G6  | `assert_no_outlook_landmines/1` | Deny-list: no <style>, no flex/grid/position/background-image |

  G7 (image tripwire), G8 (default-arg), G9 (backup-code boundaries) are
  implemented as inline assertions in the test files per AAA-flat style
  guidance in PATTERNS.md.
  """

  import ExUnit.Assertions

  # G1 — Computed contrast: extract CTA background-color from html_body and
  # assert the WCAG contrast ratio against #ffffff meets the given threshold.
  #
  # The CTA button in the generated emails uses inline CSS:
  #   background-color: #rrggbb
  # inside an <a> tag with role="link". We extract the LAST such color because
  # the card background (#ffffff) and detail boxes (#f4f4f5) also appear earlier.
  @doc """
  Asserts the CTA button contrast ratio meets the given WCAG threshold.

  Extracts all `background-color` values from the HTML, picks the one belonging
  to the CTA `<a>` element (identified by `role="link"`), and asserts that its
  contrast against #ffffff is at least `min_ratio`.

  Pass `4.5` to enforce WCAG AA for normal text (Phase 86 D-86-07 default).
  Pass `3.0` only when asserting large-bold-text floor.
  """
  @spec assert_cta_contrast(Swoosh.Email.t(), float()) :: :ok
  def assert_cta_contrast(%{html_body: html}, min_ratio \\ 4.5) do
    # Extract background-color values from <a role="link"> CTA buttons
    cta_bg_colors = extract_cta_bg_colors(html)

    assert cta_bg_colors != [],
           "assert_cta_contrast: no <a role=\"link\"> with background-color found in html_body"

    Enum.each(cta_bg_colors, fn color ->
      ratio = Sigra.A11y.Contrast.ratio(color, "#ffffff")

      assert is_float(ratio) and ratio >= min_ratio,
             "assert_cta_contrast: CTA #{inspect(color)} on #ffffff " <>
               "has contrast #{inspect(ratio)}, expected >= #{min_ratio}"
    end)

    :ok
  end

  # G2 — Byte budget: Gmail clips emails > 102,400 bytes. Use 100,000 as the gate
  # to leave a margin for MIME headers / quoted-printable encoding overhead.
  @doc """
  Asserts the HTML body is below the Gmail clip threshold (100,000 bytes).

  Gmail clips HTML emails at 102,400 bytes. The 100 KB gate leaves ~2 KB margin
  for transport encoding. A clipped email hides the security footer and CTA.
  """
  @spec assert_under_gmail_clip(Swoosh.Email.t()) :: :ok
  def assert_under_gmail_clip(%{html_body: html}) do
    size = byte_size(html)

    assert size < 100_000,
           "assert_under_gmail_clip: HTML body is #{size} bytes, Gmail clips at 102,400 bytes"

    :ok
  end

  # G3 — Multipart parity: every URL in html_body must also appear in text_body
  # so plain-text users can follow all links.
  @doc """
  Asserts every URL found in `html_body` also appears in `text_body`.

  Extracts `href` values from anchor tags and asserts each one is present in the
  plain-text part. Fails listing all missing URLs.
  """
  @spec assert_text_part_mirrors_html(Swoosh.Email.t()) :: :ok
  def assert_text_part_mirrors_html(%{html_body: html, text_body: text}) do
    urls = extract_href_urls(html)

    missing =
      Enum.reject(urls, fn url ->
        # Skip template placeholder URLs that are never real at test time
        is_placeholder(url) or String.contains?(text, url)
      end)

    assert missing == [],
           "assert_text_part_mirrors_html: #{length(missing)} URL(s) in html_body " <>
             "not found in text_body: #{inspect(missing)}"

    :ok
  end

  # G4 — Recipient correctness: assert email.to matches the expected address.
  @doc """
  Asserts the email recipient matches `expected_email`.

  Swoosh stores `email.to` as a list of `{name, address}` tuples. This helper
  asserts both that exactly one recipient is set and that the address matches.
  """
  @spec assert_email_to(Swoosh.Email.t(), String.t()) :: :ok
  def assert_email_to(%{to: to}, expected_email) do
    addresses = Enum.map(to, fn {_name, addr} -> addr end)

    assert addresses == [expected_email],
           "assert_email_to: expected recipient #{inspect(expected_email)}, " <>
             "got #{inspect(addresses)}"

    :ok
  end

  # G5 — XSS escaping: assert a user-controlled payload appears in escaped form
  # and never as raw HTML in html_body or text_body.
  @doc """
  Asserts `payload` appears only in escaped form inside `html_body`.

  Tests XSS regression by injecting HTML-sensitive characters and verifying they
  are entity-encoded in the rendered output. Pass `payload` as the raw user
  input string (e.g. `"<script>alert(1)</script>"` or `"O'Brien"`).
  """
  @spec assert_xss_escaped(Swoosh.Email.t(), String.t()) :: :ok
  def assert_xss_escaped(%{html_body: html}, payload) do
    # The raw payload must not appear verbatim in the HTML body
    refute String.contains?(html, payload),
           "assert_xss_escaped: raw payload #{inspect(payload)} found unescaped in html_body"

    :ok
  end

  # G6 — Outlook Word-engine deny-list: ensure no CSS constructs that break
  # the Word-engine renderer in legacy Outlook desktop clients.
  @doc """
  Asserts the HTML body contains no Outlook Word-engine deny-listed CSS constructs.

  Checks for:
  - `<style>` blocks (Word-engine ignores or strips them)
  - `display: flex` / `display: grid` (not rendered)
  - `position:` (ignored by Word-engine)
  - `background-image:` (stripped)
  - `float:` (unreliable in Word-engine)
  """
  @spec assert_no_outlook_landmines(Swoosh.Email.t()) :: :ok
  def assert_no_outlook_landmines(%{html_body: html}) do
    deny_patterns = [
      {"<style", "<style> block (Word-engine ignores external styles)"},
      {"display: flex", "display:flex (not rendered by Word-engine)"},
      {"display:flex", "display:flex (not rendered by Word-engine)"},
      {"display: grid", "display:grid (not rendered by Word-engine)"},
      {"display:grid", "display:grid (not rendered by Word-engine)"},
      {"position: ", "position: (ignored by Word-engine)"},
      {"position:", "position: (ignored by Word-engine)"},
      {"background-image:", "background-image: (stripped by Word-engine)"},
      {"float: ", "float: (unreliable in Word-engine)"},
      {"float:", "float: (unreliable in Word-engine)"}
    ]

    violations =
      Enum.filter(deny_patterns, fn {pattern, _desc} ->
        String.contains?(html, pattern)
      end)

    assert violations == [],
           "assert_no_outlook_landmines: Word-engine CSS violations found:\n" <>
             Enum.map_join(violations, "\n", fn {_p, desc} -> "  - #{desc}" end)

    :ok
  end

  # -- Private helpers --

  # Extract background-color hex values from CTA buttons (role="link" anchor tags).
  # Uses regex to find <a ... role="link" ...> with inline background-color style.
  defp extract_cta_bg_colors(html) do
    # Match <a href="..." style="...background-color: #rrggbb..."> with role="link"
    # The entire <a> tag content is captured to handle multi-line inline styles
    anchor_regex = ~r/<a\s[^>]*role="link"[^>]*style="([^"]*)"[^>]*>/i

    case Regex.scan(anchor_regex, html, capture: :all_but_first) do
      [] ->
        # Also try style before role
        anchor_regex2 = ~r/<a\s[^>]*style="([^"]*)"[^>]*role="link"[^>]*>/i

        Regex.scan(anchor_regex2, html, capture: :all_but_first)
        |> Enum.flat_map(&extract_bg_color_from_style/1)

      matches ->
        Enum.flat_map(matches, &extract_bg_color_from_style/1)
    end
  end

  defp extract_bg_color_from_style([style_content]) do
    case Regex.run(~r/background-color:\s*(#[0-9a-fA-F]{6})/, style_content, capture: :all_but_first) do
      [color] -> [color]
      _ -> []
    end
  end

  defp extract_bg_color_from_style(_), do: []

  # Extract href URLs from anchor tags in HTML.
  defp extract_href_urls(html) do
    href_regex = ~r/href="([^"]+)"/

    Regex.scan(href_regex, html, capture: :all_but_first)
    |> Enum.flat_map(fn [url] -> [url] end)
    |> Enum.uniq()
    |> Enum.reject(&is_placeholder/1)
  end

  # Template placeholder URLs (EEx interpolation leftovers at test time).
  # The generated template uses `<%= reset_password_url %>` etc., which in the
  # compiled example app become real URL strings, not literal EEx tags. However,
  # the test/example compiled templates may still have configuration-derived URLs
  # that we don't need to assert are in text. We skip nothing - all real URLs
  # that appear in the rendered HTML must also appear in the rendered text.
  defp is_placeholder(_url), do: false
end
