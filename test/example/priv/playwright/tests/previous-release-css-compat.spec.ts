import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "@playwright/test";
import { repoRoot } from "../helpers/brandSource";

function compatibilityHtml(): string {
  const css = readFileSync(
    join(repoRoot(), "test/fixtures/brand/previous-release-sigra_admin.css"),
    "utf8",
  );

  return `
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>${css}</style>
  </head>
  <body>
    <main class="sg-stack sg-stack--6">
      <h1 id="support-user">support-user@example.test</h1>
      <div id="support-status">
        <span class="sg-status-mark" data-status="deleting">
          <svg
            class="sg-status-mark__glyph"
            viewBox="0 0 20 20"
            width="20"
            height="20"
            aria-hidden="true"
            focusable="false"
          >
            <rect
              x="2.75"
              y="2.75"
              width="14.5"
              height="14.5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
            />
            <path d="M10 3.5h6.5V10H10z" fill="currentColor" />
          </svg>
          Deletion scheduled
        </span>
      </div>
      <section class="sg-card sg-stack sg-stack--3">
        <h2 class="sg-section-heading">Sessions</h2>
        <div class="sg-table-panel">
          <table class="sg-table">
            <tbody>
              <tr id="support-session">
                <td><span id="session-type" class="sg-strong">Browser session</span></td>
                <td><code id="session-ip" class="sg-code">203.0.113.4</code></td>
                <td class="sg-muted"><span id="activity" class="sg-summary-facts__num">2026-06-04 12:30 PM UTC</span></td>
                <td class="sg-cell-right">
                  <button
                    id="revoke-session"
                    type="button"
                    class="sg-btn sg-btn--danger sg-btn--sm"
                  >
                    Revoke session
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </main>
  </body>
</html>
`;
}

test("the 1.7.1 stylesheet keeps status and session content visible without overlap", async ({
  browser,
}) => {
  const html = compatibilityHtml();

  for (const colorScheme of ["light", "dark"] as const) {
    const page = await browser.newPage({
      viewport: { width: 1280, height: 900 },
      colorScheme,
    });
    await page.setContent(html);

    const result = await page.evaluate(() => {
      const selectors = [
        "#support-user",
        "#support-status",
        "#session-type",
        "#session-ip",
        "#activity",
        "#revoke-session",
      ];
      const visible = (element: Element) => {
        const style = getComputedStyle(element);
        const rect = element.getBoundingClientRect();
        return (
          style.display !== "none" &&
          style.visibility === "visible" &&
          Number(style.opacity) > 0 &&
          rect.width > 0 &&
          rect.height > 0
        );
      };
      const rect = (selector: string) =>
        document.querySelector(selector)!.getBoundingClientRect().toJSON();
      const overlaps = (
        left: ReturnType<typeof rect>,
        right: ReturnType<typeof rect>,
      ) =>
        left.left < right.right - 0.5 &&
        left.right > right.left + 0.5 &&
        left.top < right.bottom - 0.5 &&
        left.bottom > right.top + 0.5;
      const rects = Object.fromEntries(
        selectors.map((selector) => [selector, rect(selector)]),
      );
      const content = selectors.map((selector) => ({
        selector,
        visible: visible(document.querySelector(selector)!),
      }));
      const pairwiseOverlap: string[] = [];

      for (let i = 0; i < selectors.length; i += 1) {
        for (let j = i + 1; j < selectors.length; j += 1) {
          if (overlaps(rects[selectors[i]], rects[selectors[j]])) {
            pairwiseOverlap.push(`${selectors[i]} overlaps ${selectors[j]}`);
          }
        }
      }

      return {
        status: document.querySelector("#support-status")!.textContent!.trim(),
        timestamp: document.querySelector("#activity")!.textContent!.trim(),
        content,
        pairwiseOverlap,
      };
    });

    expect(result.status, `${colorScheme}: status word`).toBe("Deletion scheduled");
    expect(result.timestamp, `${colorScheme}: timestamp`).toBe(
      "2026-06-04 12:30 PM UTC",
    );
    expect(
      result.content.filter((entry) => !entry.visible),
      `${colorScheme}: visible content`,
    ).toEqual([]);
    expect(result.pairwiseOverlap, `${colorScheme}: content must not overlap`).toEqual([]);

    await page.keyboard.press("Tab");
    await expect(page.locator("#revoke-session")).toBeFocused();
    await page.close();
  }
});
