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

const diagnosticsEnabled = process.env.SIGRA_CI_DIAGNOSTICS === "1";
const diagnosticsRoot = process.env.SIGRA_CI_DIAGNOSTICS_ROOT;
const traceRegistry = process.env.SIGRA_CI_TRACE_REGISTRY;

function diagnosticTracePath(label: string) {
  if (!diagnosticsEnabled || !diagnosticsRoot) return undefined;
  return path.join(diagnosticsRoot, "traces", `${safePart(label, "context")}-${process.pid}-${crypto.randomBytes(8).toString("hex")}.zip`);
}

function registerDiagnosticTrace(tracePath: string | undefined, contextKind: string, unavailableReason?: string) {
  if (!diagnosticsEnabled || !traceRegistry) return;
  fs.mkdirSync(path.dirname(traceRegistry), { recursive: true });
  fs.appendFileSync(traceRegistry, `${JSON.stringify({
    path: tracePath && diagnosticsRoot ? path.relative(diagnosticsRoot, tracePath) : null,
    kind: "trace",
    context_kind: contextKind,
    synthetic_account: true,
    registered: Boolean(tracePath),
    trace_unavailable_reason: unavailableReason ?? null,
  })}\n`, { mode: 0o600 });
}

async function startDiagnosticTrace(context: BrowserContext) {
  if (diagnosticsEnabled) await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
}

async function stopDiagnosticTrace(context: BrowserContext, tracePath?: string) {
  if (diagnosticsEnabled) await context.tracing.stop(tracePath ? { path: tracePath } : undefined);
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
    let setupContext: BrowserContext | undefined;
    let setupTracePath = diagnosticTracePath("admin-theme-setup");
    let setupTraceStarted = false;
    let setupFailed = false;
    try {
      setupContext = await browser.newContext({ storageState: undefined });
      await startDiagnosticTrace(setupContext);
      setupTraceStarted = diagnosticsEnabled;
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
    } catch (error) {
      setupFailed = true;
      if (setupContext && setupTraceStarted && setupTracePath) {
        try {
          await stopDiagnosticTrace(setupContext, setupTracePath);
          registerDiagnosticTrace(setupTracePath, "admin-theme-setup");
        } catch {
          registerDiagnosticTrace(undefined, "admin-theme-setup", "trace_export_failed");
        }
      } else {
        registerDiagnosticTrace(undefined, "admin-theme-setup", setupContext ? "trace_start_failed" : "context_not_created");
      }
      throw error;
    } finally {
      if (setupContext && setupTraceStarted && !setupFailed) {
        try { await stopDiagnosticTrace(setupContext); } catch { registerDiagnosticTrace(undefined, "admin-theme-setup", "trace_discard_failed"); }
      }
      let cleanupError: unknown;
      if (setupContext) {
        try { await setupContext.close(); } catch (error) { cleanupError = error; }
      }
      try {
        fs.rmSync(storagePath, { force: true });
        try { fs.rmdirSync(authDir); } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== "ENOTEMPTY" && (error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
        }
      } catch (error) {
        cleanupError ??= error;
      }
      record(true);
      if (cleanupError && !setupFailed) throw cleanupError;
    }
  }, { scope: "worker" }],
  context: async ({ browser, baseURL, viewport, isMobile, deviceScaleFactor, hasTouch, colorScheme, adminThemeAuth }, use, testInfo) => {
    const context = await browser.newContext({
      baseURL,
      viewport,
      isMobile,
      deviceScaleFactor,
      hasTouch,
      colorScheme,
      storageState: adminThemeAuth.storagePath,
    });
    const contextId = crypto.randomUUID();
    adminThemeAuth.consumerContextIds.push(contextId);
    const tracePath = diagnosticTracePath(`admin-theme-test-${contextId}`);
    let traceStarted = false;
    let primaryError = false;
    try {
      await startDiagnosticTrace(context);
      traceStarted = diagnosticsEnabled;
      await use(context);
    } catch (error) {
      primaryError = true;
      throw error;
    } finally {
      let cleanupError: unknown;
      if (traceStarted) {
        try {
          if (testInfo.status !== testInfo.expectedStatus && tracePath) {
            await stopDiagnosticTrace(context, tracePath);
            registerDiagnosticTrace(tracePath, "admin-theme-test");
          } else {
            await stopDiagnosticTrace(context);
          }
        } catch (error) {
          cleanupError = error;
          registerDiagnosticTrace(undefined, "admin-theme-test", "trace_export_failed");
        }
      }
      try { await context.close(); } catch (error) { cleanupError ??= error; }
      if (cleanupError && !primaryError) throw cleanupError;
    }
  },
  page: async ({ context }, use) => {
    const page = await context.newPage();
    await use(page);
  },
});

