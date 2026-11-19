import { randomUUID } from "node:crypto";
import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import {
  assertGenericRegistrationResponse,
  signInManually,
} from "../helpers/registration";

type MailboxMessage = {
  html_body: string | null;
  text_body: string | null;
  to: string[];
};

async function waitForLiveViewReady(page: Page) {
  await page.locator("[data-phx-session].phx-connected").waitFor({
    state: "attached",
  });
}

async function confirmationCodeFromMailbox(page: Page, recipient: string) {
  let confirmationCode: string | null = null;

  await expect
    .poll(
      async () => {
        confirmationCode = await page.evaluate(async (emailAddress) => {
          const response = await fetch("/dev/mailbox/json");
          if (!response.ok) return null;

          const mailbox = (await response.json()) as {
            data: MailboxMessage[];
          };
          const message = mailbox.data.find((entry) =>
            entry.to.includes(emailAddress),
          );
          if (!message?.html_body) return null;

          const parsed = new DOMParser().parseFromString(
            message.html_body,
            "text/html",
          );
          const paragraphs = Array.from(parsed.querySelectorAll("p"), (node) =>
            node.textContent?.trim() ?? "",
          );
          const htmlText = parsed.body.textContent ?? "";
          const identityLines = (message.text_body ?? "")
            .split(/\r?\n/)
            .filter((line) => /\b(?:Sigra|Kiln)\b/i.test(line));
          if (/\b(?:Sigra|Kiln)\b/i.test(htmlText)) return null;
          if (identityLines.some((line) => line.trim() !== "Authentication by Sigra")) return null;
          const labelIndex = paragraphs.findIndex((paragraph) =>
            paragraph.includes("Your confirmation code:"),
          );
          const candidate = paragraphs[labelIndex + 1] ?? "";

          return /^[0-9](?: [0-9]){5}$/.test(candidate) ? candidate : null;
        }, recipient);

        return confirmationCode;
      },
      {
        message: `Waiting for the spaced confirmation code addressed to ${recipient}`,
        intervals: [250, 500, 1_000, 2_000],
        timeout: 30_000,
      },
    )
    .not.toBeNull();

  if (!confirmationCode) {
    throw new Error(`No spaced confirmation code found for ${recipient}`);
  }

  return confirmationCode;
}

test("generated confirmation accepts the literal email code paste and announces retry feedback", async ({
  page,
}) => {
  const email = `confirmation-${randomUUID()}@example.test`;
  const password = "CorrectHorseBatteryStaple123!";

  await page.goto("/users/register");
  await waitForLiveViewReady(page);
  await page.getByRole("textbox", { name: "Email" }).fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Create an account" }).click();
  await assertGenericRegistrationResponse(page);
  await signInManually(page, email, password);

  const confirmationCode = await confirmationCodeFromMailbox(page, email);
  expect(confirmationCode).toMatch(/^[0-9](?: [0-9]){5}$/);

  await page.goto("/users/confirm");
  await waitForLiveViewReady(page);
  await expect(page.locator("body")).not.toContainText(/\b(?:Sigra|Kiln)\b/i);
  const { violations } = await new AxeBuilder({ page })
    .include("main")
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();
  expect(
    violations,
    `generated confirmation axe violations: ${JSON.stringify(violations).slice(0, 2000)}`,
  ).toHaveLength(0);
  const codeInput = page.getByRole("textbox", { name: "Confirmation code" });
  await expect(codeInput).toBeVisible();

  const wrongCode = `${confirmationCode[0] === "0" ? "1" : "0"}${confirmationCode.slice(1).replaceAll(" ", "")}`;
  await codeInput.fill(wrongCode);
  await page.getByRole("button", { name: "Confirm email" }).click();
  await expect(page.getByRole("alert")).toContainText(
    "Invalid confirmation code. Please try again.",
  );

  await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);
  await page.evaluate((value) => navigator.clipboard.writeText(value), confirmationCode);
  await codeInput.fill("");
  await codeInput.click();
  await codeInput.press("ControlOrMeta+V");
  await expect(codeInput).toHaveValue(confirmationCode);
  await page.getByRole("button", { name: "Confirm email" }).click();

  await expect(page.getByRole("status")).toContainText(
    "Your email has been confirmed.",
  );
  await expect(
    page.getByRole("heading", { name: "Email confirmed", exact: true }),
  ).toBeVisible();
});
