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

    status_html = render_component(&Components.status_mark/1, status: :deleting)
    timestamp = Components.activity_value(~U[2026-06-04 12:30:00Z])

    html = """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>#{css}</style>
      </head>
      <body>
        <main class="sg-stack sg-stack--6">
          <h1 id="support-user">support-user@example.test</h1>
          <div id="support-status">#{status_html}</div>
          <section class="sg-card sg-stack sg-stack--3">
            <h2 class="sg-section-heading">Sessions</h2>
            <div class="sg-table-panel">
              <table class="sg-table">
                <tbody>
                  <tr id="support-session">
                    <td><span id="session-type" class="sg-strong">Browser session</span></td>
                    <td><code id="session-ip" class="sg-code">203.0.113.4</code></td>
                    <td class="sg-muted"><span id="activity" class="sg-summary-facts__num">#{timestamp}</span></td>
                    <td class="sg-cell-right"><button id="revoke-session" type="button" class="sg-btn sg-btn--danger sg-btn--sm">Revoke session</button></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </main>
      </body>
    </html>
    """

    html_path =
      Path.join(
        System.tmp_dir!(),
        "sigra-old-css-compat-#{System.unique_integer([:positive])}.html"
      )

    File.write!(html_path, html)
    on_exit(fn -> File.rm(html_path) end)

    node_script = ~S"""
    const assert = require('node:assert/strict');
    const path = require('node:path');
    const { createRequire } = require('node:module');
    const fromPlaywright = createRequire(path.join(process.cwd(), 'test/example/priv/playwright/package.json'));
    const { chromium } = fromPlaywright('playwright-core');
    const fs = require('node:fs');

    (async () => {
      const browser = await chromium.launch({ headless: true });
      try {
        for (const colorScheme of ['light', 'dark']) {
          const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, colorScheme });
          await page.setContent(fs.readFileSync(process.env.SIGRA_COMPAT_HTML, 'utf8'));
          const result = await page.evaluate(() => {
            const visible = (element) => {
              const style = getComputedStyle(element);
              const rect = element.getBoundingClientRect();
              return style.display !== 'none' && style.visibility === 'visible' &&
                Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
            };
            const rect = (selector) => document.querySelector(selector).getBoundingClientRect().toJSON();
            const overlaps = (left, right) =>
              left.left < right.right - 0.5 && left.right > right.left + 0.5 &&
              left.top < right.bottom - 0.5 && left.bottom > right.top + 0.5;
            const selectors = ['#support-user', '#support-status', '#session-type', '#session-ip', '#activity', '#revoke-session'];
            const rects = Object.fromEntries(selectors.map((selector) => [selector, rect(selector)]));
            const content = selectors.map((selector) => ({ selector, visible: visible(document.querySelector(selector)) }));
            const pairwiseOverlap = [];
            for (let i = 0; i < selectors.length; i += 1) {
              for (let j = i + 1; j < selectors.length; j += 1) {
                if (overlaps(rects[selectors[i]], rects[selectors[j]])) {
                  pairwiseOverlap.push(`${selectors[i]} overlaps ${selectors[j]}`);
                }
              }
            }
            return {
              status: document.querySelector('#support-status').innerText.trim(),
              timestamp: document.querySelector('#activity').innerText.trim(),
              content,
              pairwiseOverlap,
            };
          });

          assert.equal(result.status, 'Deletion scheduled', `${colorScheme}: status word`);
          assert.equal(result.timestamp, '2026-06-04 12:30 PM UTC', `${colorScheme}: timestamp`);
          assert.deepEqual(result.content.filter((entry) => !entry.visible), [], `${colorScheme}: visible content`);
          assert.deepEqual(result.pairwiseOverlap, [], `${colorScheme}: content must not overlap`);
          await page.keyboard.press('Tab');
          assert.equal(await page.evaluate(() => document.activeElement.id), 'revoke-session', `${colorScheme}: keyboard action`);
          await page.close();
        }
      } finally {
        await browser.close();
      }
    })().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
    """

    {output, status} =
      System.cmd("node", ["-e", node_script],
        cd: @repo_root,
        env: [{"SIGRA_COMPAT_HTML", html_path}],
        stderr_to_stdout: true
      )

    assert status == 0, "previous-release CSS compatibility browser failed:\n#{output}"
  end
end
