import fs from "node:fs";
import path from "node:path";

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

export interface GeneratedHostProofBundle {
  runAt: string;
  proofUserEmail: string;
  endpointUrl: string;
  subscriptionId: string;
  subscriptionScreenshot: string;
  sourceDeliveryId: string;
  replayDeliveryId: string;
  rootDeliveryId: string;
  sourceDeliveryStatus: string;
  replayDeliveryStatus: string;
  sourceFailureScreenshot: string;
  sourceDetailScreenshot: string;
  replayDetailScreenshot: string;
  receiverVerification: {
    sourceDelivery: GeneratedHostReceiverVerification | null;
    replayDelivery: GeneratedHostReceiverVerification | null;
  };
}

export interface GeneratedHostReceiverVerification {
  receiverVerifiedAt: string;
  receiverSignatureTimestamp: number;
  rawBodySha256: string;
}

export interface BlockedPolicyProofBundle {
  runAt: string;
  endpointUrl: string;
  blockedDeliveryId: string;
  deliveryStatus: string;
  policyReason: string;
  policyDetail: string;
  failuresScreenshot: string;
  detailScreenshot: string;
}

const repoRoot = path.resolve(__dirname, "../../../../..");
const replayProofDir = path.join(
  repoRoot,
  ".planning/uat-evidence/v1.23/webhook-delivery-replay",
);
const blockedPolicyProofDir = path.join(
  repoRoot,
  ".planning/uat-evidence/v1.23/webhook-policy-operator-truth",
);

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

export async function captureGeneratedHostProofArtifact(
  page: Page,
  testInfo: TestInfo,
  fileName: string,
  proofDir = replayProofDir,
): Promise<string> {
  const screenshotsDir = path.join(proofDir, "screenshots");
  const artifactPath = path.join(screenshotsDir, fileName);

  fs.mkdirSync(screenshotsDir, { recursive: true });

  await page.screenshot({
    path: artifactPath,
    fullPage: true,
  });

  await testInfo.attach(fileName.replace(/\.png$/, ""), {
    path: artifactPath,
    contentType: "image/png",
  });

  return artifactPath;
}

export function writeGeneratedHostProofBundle(bundle: GeneratedHostProofBundle): void {
  fs.mkdirSync(replayProofDir, { recursive: true });

  const manifestPath = path.join(replayProofDir, "manifest.json");
  const readmePath = path.join(replayProofDir, "README.md");

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      {
        generated_at: bundle.runAt,
        proof_user_email: bundle.proofUserEmail,
        subscription_id: bundle.subscriptionId,
        endpoint_url: bundle.endpointUrl,
        source_delivery_id: bundle.sourceDeliveryId,
        replay_delivery_id: bundle.replayDeliveryId,
        root_delivery_id: bundle.rootDeliveryId,
        source_delivery_status: bundle.sourceDeliveryStatus,
        replay_delivery_status: bundle.replayDeliveryStatus,
        receiver_verification: {
          source_delivery: toReceiverVerification(bundle.receiverVerification.sourceDelivery),
          replay_delivery: toReceiverVerification(bundle.receiverVerification.replayDelivery),
        },
        screenshots: {
          subscription: bundle.subscriptionScreenshot,
          failed_source: bundle.sourceFailureScreenshot,
          source_detail: bundle.sourceDetailScreenshot,
          replay_detail: bundle.replayDetailScreenshot,
        },
      },
      null,
      2,
    ),
  );

  fs.writeFileSync(
    readmePath,
    `# Generated Host Replay Proof

Canonical admin and receiver proof for the fail -> inspect -> repair -> replay recovery flow.

- Run at: ${bundle.runAt}
- Proof user prefix: ${bundle.proofUserEmail}
- Subscription ID: ${bundle.subscriptionId}
- Admin endpoint: ${bundle.endpointUrl}
- Admin subscription screenshot: ${bundle.subscriptionScreenshot}

## Delivery lineage

- source delivery id: ${bundle.sourceDeliveryId}
- replay delivery id: ${bundle.replayDeliveryId}
- root delivery id: ${bundle.rootDeliveryId}
- source delivery status: ${bundle.sourceDeliveryStatus}
- replay delivery status: ${bundle.replayDeliveryStatus}

## Receiver verification

- source delivery receiver verification: ${describeReceiverVerification(bundle.receiverVerification.sourceDelivery)}
- replay delivery receiver verification: ${describeReceiverVerification(bundle.receiverVerification.replayDelivery)}

## Screenshots

- failed source row: ${bundle.sourceFailureScreenshot}
- source delivery detail: ${bundle.sourceDetailScreenshot}
- replay delivery detail: ${bundle.replayDetailScreenshot}

Artifacts:
- machine manifest: ${path.relative(replayProofDir, manifestPath)}

This evidence bundle correlates the original failed source row and the replay child row across admin history and receiver verification while keeping \`delivery_id\` dedupe truthful.
`,
  );
}

export function writeBlockedPolicyProofBundle(bundle: BlockedPolicyProofBundle): void {
  fs.mkdirSync(blockedPolicyProofDir, { recursive: true });

  const manifestPath = path.join(blockedPolicyProofDir, "manifest.json");
  const readmePath = path.join(blockedPolicyProofDir, "README.md");

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      {
        generated_at: bundle.runAt,
        endpoint_url: bundle.endpointUrl,
        blocked_delivery_id: bundle.blockedDeliveryId,
        delivery_status: bundle.deliveryStatus,
        policy_reason: bundle.policyReason,
        policy_detail: bundle.policyDetail,
        screenshots: {
          failures_row: bundle.failuresScreenshot,
          delivery_detail: bundle.detailScreenshot,
        },
      },
      null,
      2,
    ),
  );

  fs.writeFileSync(
    readmePath,
    `# Webhook Policy Operator Truth Proof

Blocked destination proof for the generated-host operator workflow.

- Run at: ${bundle.runAt}
- blocked delivery id: ${bundle.blockedDeliveryId}
- endpoint url: ${bundle.endpointUrl}
- delivery status: ${bundle.deliveryStatus}
- policy reason: ${bundle.policyReason}
- policy detail: ${bundle.policyDetail}

## Operator surfaces

- Failures inbox row shows \`Blocked by local policy\`
- Delivery detail shows \`Endpoint policy result\`

## Screenshots

- failures row: ${bundle.failuresScreenshot}
- delivery detail: ${bundle.detailScreenshot}

Artifacts:
- machine manifest: ${path.relative(blockedPolicyProofDir, manifestPath)}
`,
  );
}

function toReceiverVerification(verification: GeneratedHostReceiverVerification | null) {
  if (!verification) {
    return null;
  }

  return {
    verified_at: verification.receiverVerifiedAt,
    signature_timestamp: verification.receiverSignatureTimestamp,
    raw_body_sha256: verification.rawBodySha256,
  };
}

function describeReceiverVerification(verification: GeneratedHostReceiverVerification | null): string {
  if (!verification) {
    return "missing";
  }

  return `verified_at=${verification.receiverVerifiedAt}, signature_timestamp=${verification.receiverSignatureTimestamp}, raw_body_sha256=${verification.rawBodySha256}`;
}
