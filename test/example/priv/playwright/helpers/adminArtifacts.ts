import type { Page, TestInfo } from "@playwright/test";

// Phase 31 Plan 1: shared helpers for admin reviewer artifacts.
//
// This module exists to keep the admin browser suite's screenshot output
// predictable across specs and projects without pulling in a generic page-
// object layer. Callers pass a short logical name ("shell-desktop",
// "allowed-org-mobile", etc.) and the helpers produce:
//
//   * a deterministic file under `testInfo.outputPath(...)` so the artifact
//     lands in the Playwright report tree the CI upload step already knows,
//   * a matching `testInfo.attach(...)` entry so the HTML report surfaces the
//     screenshot against the test even on passing runs, and
//   * a stable artifact name of the form
//     `admin-<slug>-<project>-<slug>.png` that does not vary run-to-run.
//
// Per D-20, D-24, and D-25 the helper is used ONLY for curated reviewer
// artifacts on the shipped admin checkpoints. Raw per-run trace/video
// retention is handled by the Playwright config's selective policy.

export interface CapturedCheckpointOptions {
  /**
   * Short logical name for the checkpoint (e.g. "shell-desktop",
   * "allowed-org-mobile"). Must be stable across runs so reviewers can
   * diff artifacts from one run to the next.
   */
  name: string;
  /**
   * Prefix that groups a set of checkpoints together in the report. Defaults
   * to "admin". Kept short because the full artifact name is
   * `<prefix>-<name>-<project>.png`.
   */
  prefix?: string;
  /**
   * Whether to capture the full scrollable page. Defaults to true so reviewer
   * artifacts show the whole admin surface rather than the fold.
   */
  fullPage?: boolean;
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/**
 * Build the deterministic artifact base name for a checkpoint. Example:
 *   adminArtifactName({ name: "shell-desktop" }, testInfo)
 *   => "admin-shell-desktop-admin-generated"
 *
 * The project name is appended so artifacts from different lanes
 * (chromium, mobile, dark, generated-host) do not collide when uploaded
 * together.
 */
export function adminArtifactName(
  options: CapturedCheckpointOptions,
  testInfo: TestInfo,
): string {
  const prefix = slugify(options.prefix ?? "admin");
  const name = slugify(options.name);
  const project = slugify(testInfo.project.name);

  return [prefix, name, project].filter(Boolean).join("-");
}

/**
 * Capture a named admin checkpoint screenshot and attach it to the test so
 * it lands in the Playwright HTML report as a reviewer artifact.
 *
 * Returns the absolute path so callers can log or diff it if needed.
 */
export async function captureAdminCheckpoint(
  page: Page,
  testInfo: TestInfo,
  options: CapturedCheckpointOptions,
): Promise<string> {
  const base = adminArtifactName(options, testInfo);
  const fileName = `${base}.png`;
  const path = testInfo.outputPath(fileName);

  await page.screenshot({
    path,
    fullPage: options.fullPage ?? true,
  });

  await testInfo.attach(base, {
    path,
    contentType: "image/png",
  });

  return path;
}
