import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { expect, test as base, type BrowserContext, type Page } from "@playwright/test";
import { TEST_PASSWORD } from "../helpers/fixtures";

type AdminThemeAuth = { storagePath: string; consumerContextIds: string[] };
type WorkerFixtures = { adminThemeAuth: AdminThemeAuth };
type TestFixtures = { context: BrowserContext; page: Page };

function safePart(value: string | undefined, fallback: string) {
  const safe = (value ?? "").replace(/[^a-zA-Z0-9._-]+/g, "_").replace(/^\.+|\.+$/g, "").slice(0, 60);
  return safe || fallback;
}

export function createAdminThemeStoragePath(root: string, env = process.env, pid = process.pid, nonce = crypto.randomBytes(8).toString("hex")) {
  const identity = [
    safePart(env.GITHUB_RUN_ID, "local"),
    safePart(env.GITHUB_JOB ?? env.CI_JOB_NAME, "job"),
    safePart(env.PGDATABASE, "database"),
    `pid-${pid}`,
    safePart(nonce, "invocation"),
  ].join("-");
  return path.join(root, "test-results", ".auth", `admin-theme-${identity}.json`);
}

export const adminThemeTest = base.extend<TestFixtures, WorkerFixtures>({
  adminThemeAuth: [async ({ browser }, use, workerInfo) => {
    const root = workerInfo.config.rootDir;
    const storagePath = createAdminThemeStoragePath(root);
    const authDir = path.dirname(storagePath);
    fs.mkdirSync(authDir, { recursive: true, mode: 0o700 });
    fs.chmodSync(authDir, 0o700);
    const email = `platform-admin+theme-${process.pid}-${crypto.randomBytes(6).toString("hex")}@example.test`;
    const consumerContextIds: string[] = [];
    let authStorageMode: number | null = null;
    const diagnosticPath = process.env.SIGRA_ADMIN_THEME_DIAGNOSTICS;
    const record = (cleanupComplete = false) => {
      if (!diagnosticPath) return;
      const diagnostic = {
        registered_admin_count: 1,
        storage_filename: path.basename(storagePath),
        storage_mode: authStorageMode,
        database_identity: safePart(process.env.PGDATABASE, "database"),
        consumer_context_ids: consumerContextIds,
        cleanup_complete: cleanupComplete,
      };
      fs.mkdirSync(path.dirname(diagnosticPath), { recursive: true });
      fs.writeFileSync(diagnosticPath, `${JSON.stringify(diagnostic, null, 2)}\n`, { mode: 0o600 });
    };
    const setupContext = await browser.newContext({ storageState: undefined });
    try {
      const page = await setupContext.newPage();
      const baseURL = String(workerInfo.project.use.baseURL ?? process.env.SIGRA_EXAMPLE_URL ?? "http://localhost:4000");
      await page.goto(new URL("/users/register", baseURL).toString());
      await page.waitForSelector("[data-phx-session].phx-connected", { state: "attached" });
      await page.fill('input[name="user[email]"]', email);
      await page.fill('input[name="user[password]"]', TEST_PASSWORD);
      await page.locator('form:has(input[name="user[password]"])').first().evaluate((form) => (form as HTMLFormElement).requestSubmit());
      await expect(page).not.toHaveURL(/\/users\/register/);
      const authFile = fs.openSync(storagePath, "wx", 0o600);
      fs.closeSync(authFile);
      await setupContext.storageState({ path: storagePath });
      fs.chmodSync(storagePath, 0o600);
      authStorageMode = fs.statSync(storagePath).mode & 0o777;
      record();
      await use({ storagePath, consumerContextIds });
    } finally {
      await setupContext.close();
      fs.rmSync(storagePath, { force: true });
      try { fs.rmdirSync(authDir); } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOTEMPTY" && (error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      }
      record(true);
    }
  }, { scope: "worker" }],
  context: async ({ browser, baseURL, viewport, isMobile, deviceScaleFactor, hasTouch, colorScheme, adminThemeAuth }, use) => {
    const context = await browser.newContext({
      baseURL,
      viewport,
      isMobile,
      deviceScaleFactor,
      hasTouch,
      colorScheme,
      storageState: adminThemeAuth.storagePath,
    });
    adminThemeAuth.consumerContextIds.push(crypto.randomUUID());
    try { await use(context); } finally { await context.close(); }
  },
  page: async ({ context }, use) => {
    const page = await context.newPage();
    await use(page);
  },
});

