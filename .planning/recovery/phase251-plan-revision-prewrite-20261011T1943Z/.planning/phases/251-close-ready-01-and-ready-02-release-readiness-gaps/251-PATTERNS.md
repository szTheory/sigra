# Phase 251: Close READY-01 and READY-02 Release Readiness Gaps - Pattern Map

**Mapped:** 2026-10-11  
**Files analyzed:** 7 likely implementation/evidence files  
**Analogs found:** 6 / 7

The phase research recommends extending the Phase 250 readiness evaluator and its tests, adding a distinct Phase 251 evidence packet and `251-EVIDENCE-SUMMARY.md`, and refreshing the Phase 247 owner report only from that packet. The possible requirements and milestone audit updates are conditional on the canonical owner verdict changing. This phase must preserve `authorization_pending` and `gaps_found` when proof is absent.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs` | utility / verifier | request-response, evidence transform | same file (extend in place) | exact |
| `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs` | test | transform / contract checks | same file (extend in place) | exact |
| `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-247-RECONCILIATION.json` (proposed) | evidence record | batch / transform | `250-247-RECONCILIATION.json` schema emitted by verifier | role-match |
| `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-SUMMARY.md` (planned) | report | transform | generated Phase 247 verification report | role-match |
| `.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md` | owner verification report | transform | generated Phase 247 verification report in `verify-247-readiness.mjs` | exact |
| `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` and its test | validator / test | batch / transform | same validator and `validate-release-readiness.test.mjs` | exact |
| `.planning/REQUIREMENTS.md`, `.planning/v1.49-MILESTONE-AUDIT.md` (conditional) | traceability / generated audit | transform | `verify-v149-traceability.mjs` | role-match |

The Phase 251 output names follow the plans: `251-247-RECONCILIATION.json` and `251-EVIDENCE-SUMMARY.md`, while Phase 250 artifacts remain historical. The requirement and milestone files should only change if Phase 247's full acceptance evidence changes their canonical verdict.

## Pattern Assignments

### `verify-247-readiness.mjs` (utility / verifier, evidence transform)

**Analog:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs` (tracked; extend existing evaluator/capture boundary).

**Imports and repository paths** (lines 3-19):

```js
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');
const phase247 = path.join(repoRoot, '.planning/phases/247-release-candidate-and-repository-readiness');
const reconciliationPath = path.join(here, '250-247-RECONCILIATION.json');
```

Add a separate Phase 251 output destination instead of redirecting `reconciliationPath` onto the Phase 250 record. The existing writer also updates the Phase 247 report, so make output paths explicit before reuse.

**Tuple evaluation and fail-closed blockers** (lines 122-169):

```js
const proposalTuple = {
  candidateSha: proposal?.candidate_sha ?? null,
  reviewedBaseSha: proposal?.reviewed_base_sha ?? null,
  mainSha: proposal?.main_sha ?? null,
};
// ...derive readinessTuple and liveTuple with the same three source identities...
if (proposal?.authorization_status !== 'approved' || !authorization?.immutable || !sameTuple(authorization?.tuple, proposalTuple)) {
  blockers.push({ id: 'authorization_pending', message: 'No immutable approval proves the exact proposed candidate/base/main tuple.', identities: proposalTuple });
}
if (!sameTuple(readinessTuple, proposalTuple)) blockers.push({ id: 'readiness_tuple_mismatch', message: 'The saved readiness ledger is bound to a different candidate/base/main tuple.', identities: { proposal: proposalTuple, readiness: readinessTuple } });
```

The current `sameTuple` at lines 37-39 checks only candidate/base/main. Extend approval validation so its immutable historical record binds the CI run/attempt and receipt, readiness record, and dry-run receipt identities too; otherwise retain `authorization_pending`. Keep blockers as structured, deterministically sorted records.

**Preservation read-back** (lines 77-90):

```js
const commit = execFileSync('git', ['rev-parse', '--verify', `${reference.ref}^{commit}`], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
if (commit !== reference.commit_sha) return false;
const bytes = execFileSync('git', ['show', `${reference.ref}:${reference.record_path}`], { cwd: root, encoding: 'buffer', stdio: ['ignore', 'pipe', 'ignore'] });
if (sha256(bytes) !== reference.record_sha256) return false;
const record = JSON.parse(bytes.toString('utf8'));
return String(record.id) === String(dispositionId) && record.decision === decision;
```

Reuse this Git-ref and byte-digest proof for each applicable inherited-work disposition. A path/ref identity alone is not a successful preservation join.

**Capture and artifact identities** (lines 303-353):

```js
const evaluation = evaluateEvidence({ proposal, authorization: auth, readiness, dryRunReceipt, live, liveAfter, objects, remoteSourceObjects: { candidate: candidateRemote, readiness: readinessRemote }, exactHeadCiReceipt: exactHeadCi.receipt, authoritativeCi: exactHeadCi.authoritative, exactHeadCiDiagnostic: exactHeadCi.diagnostic });
const result = {
  schema_version: 1,
  repository: 'szTheory/sigra',
  captured_at: capturedAt,
  status: evaluation.status,
  source_capture: { /* live identities, source paths, hashes, and object availability */ },
  candidate_tuples: { proposal: evaluation.proposalTuple, saved_readiness: evaluation.readinessTuple, live_observation: evaluation.liveTuple, approved: auth?.tuple ?? null },
  evidence: evaluation.sourceEvidence,
  blockers: evaluation.blockers,
  requirement_verdicts: evaluation.requirementVerdicts,
};
```

Use the same source-bound packet shape for Phase 251, recording capture time and every input path/digest. Preserve historical snapshots as historical and do not combine evidence across candidate tuples.

**Writer and report** (lines 356-381):

```js
export function buildReport(reconciliation) {
  const jsonBytes = `${JSON.stringify(reconciliation, null, 2)}\n`;
  const digest = sha256(jsonBytes);
  // Render verdicts, blockers, and evidence references from the structured packet.
}

function writeCapture() {
  const reconciliation = captureEvidence();
  writeFileSync(reconciliationPath, `${JSON.stringify(reconciliation, null, 2)}\n`);
  writeFileSync(reportPath, buildReport(reconciliation));
}
```

Adapt this writer to create the new Phase 251 packet and summary, then point the Phase 247 owner report at the new packet only after its inputs are verified. Existing `--capture` currently overwrites the Phase 250 reconciliation plus Phase 247 report; do not run it unchanged.

### `verify-247-readiness.test.mjs` (test, transform / contract checks)

**Analog:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs` (tracked; extend focused contract tests).

The test file uses Node's built-in `node:test` and assertions, imports exported evaluator functions, and builds temporary Git repositories for preservation-reference checks. Follow its table-driven fixture style for missing/mismatched evidence and exact expected blocker IDs. Add regressions for approval binding to CI/readiness/dry-run digests, full PR number/head/base stability before and after capture, and non-overwriting Phase 251 output. Keep deterministic order checks; do not rely on live GitHub calls in unit tests.

### Phase 251 evidence packet and evidence summary (planned)

**Analog:** the packet builder and `buildReport`/`checkReport` pair in `verify-247-readiness.mjs` (lines 318-374), plus the existing `250-247-RECONCILIATION.json` schema.

The JSON should be the machine-readable source of truth, with schema version, repository, capture timestamp, exact source identities, artifact paths and SHA-256 digests, tuple join results, complete observed populations, dispositions, preservation read-back results, and blocker IDs. The markdown summary should render from that JSON and link to it with its digest. Do not treat an empty or unavailable API result as a complete population; distinguish read failure from an explicitly observed empty array.

### `247-VERIFICATION.md` (Phase 247 owner report)

**Analog:** `buildReport` and `checkReport` in `verify-247-readiness.mjs` (lines 356-374).

The owner report is generated from structured evidence. Preserve the owner phase and requirement IDs, report `gaps_found` while any acceptance item remains absent, and include the evidence packet path/hash and exact reasons. Do not say Phase 251 implements READY-01/02. The report checker currently validates digest, verdict rows, blockers, source identities, and absence of Phase 250 ownership; retain equivalent consistency checks for the Phase 251 packet reference.

### `validate-release-readiness.mjs` and `validate-release-readiness.test.mjs` (validator / test, batch transform)

**Analog:** `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` and its tracked test.

The existing validator defines allowed disposition and inherited path kinds at lines 7-8:

```js
const DISPOSITIONS = new Set(['release-blocking', 'release-relevant', 'separate-follow-up']);
const KINDS = new Set(['committed', 'dirty']);
```

At lines 43-113 it requires explicit arrays, validates unique/sorted commit and path identities, requires a reason/source/preservation location for each disposition, and joins recorded PR `number:head_sha:base` keys against the observed population. Extend these existing contracts if needed; do not create a parallel ledger/schema. Preserve full PR identity and explicit empty arrays. The tests use `node:test` fixture mutations and assert specific validation codes; follow that approach for changed PR head/base and incomplete population cases.

### `.planning/REQUIREMENTS.md` and `.planning/v1.49-MILESTONE-AUDIT.md` (conditional traceability/audit)

**Analog:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs` (tracked; 774 lines, targeted excerpts below).

The audit derives status from original owner reports, rejects claims by the wrong phase, and checks requirement checkbox alignment (lines 471-516). Its accepted Phase 250 exception contract explicitly requires READY rows to remain unsatisfied, unchecked, and without completion claims (lines 495-503). If Phase 247 becomes fully satisfied, update traceability only from that owner verdict and adapt exception handling without rewriting the Phase 250 amendment or implying Phase 251 ownership. Otherwise retain the current incomplete milestone state.

### Preservation ledger examples (evidence shape only)

**Analog:** `.planning/phases/249-publish-and-prove-sigra-1-6-0/249-PRESERVATION.json` (tracked). Its per-path records include exact source path/status, source HEAD, source SHA-256, a preservation ref, resolved object SHA, and read-back/unchanged checks (for example lines 17-52). Reuse the identity fields as a format reference, not its historical inventory or values. The live Phase 251 population must be recaptured.

## Shared Patterns

### READY-01 package and adopter source identity

The preflight and evaluator must keep the historical proposal candidate tuple (`0e773d3614a242e4fbcdd34c418ecb8a307703d6`, reviewed base `d135cbce343947499a0810736c500ef5f1cb5c32`, protected main `a494f3ee3878da93aab4f70712ffddeefd77a802`) separate from the published release identity (`v1.6.0` → `9e80cb78d6374b1ed4074d5fef6b613fee879dca` recorded by `249-RELEASE-RECEIPT.json`). The candidate source paths are `.release-please-manifest.json`, `release-please-config.json`, `mix.exs`, `CHANGELOG.md`, `README.md`, `guides/introduction/upgrading-to-v1.6.md`, and `test/example/priv/playwright/tests/organizations.spec.ts`; published-tag paths are `mix.exs`, `CHANGELOG.md`, `README.md`, `guides/introduction/upgrading-to-v1.6.md`, and `lib/sigra.ex`. Resolve every path at its exact immutable commit through both local Git objects and the trusted remote API. The v1.6 upgrade guide is absent from the active checkout but was verified at the exact candidate commit; a trusted exact-commit 404 is a recorded missing-item finding. A readable mismatch or missing item leaves READY-01 unsatisfied while a source-ready READY-02 inventory remains independently capturable.

The source-derived packet and report should expose the package/version/manifest/config/changelog/tag/HexDocs join and adopter-note checks: shipped behavior, compatibility, generated-host action or explicit no-action, `{:sigra, "~> 1.6.0"}`, `mix deps.update sigra`, dependency-tree/version verification, and tests. Do not treat separate candidate and published commits as one source tuple or infer an approval event from later authorization.

### Exact source identity

**Source:** `verify-247-readiness.mjs` lines 122-169, 297-353. Bind each proof to the candidate/base/main tuple and include artifact digests; compare live before/after identities. Do not allow a mixed tuple to satisfy READY-01.

### Fresh complete populations

**Source:** `validate-release-readiness.mjs` lines 43-113 and `verify-247-readiness.mjs` lines 54-75, 93-100. Require a full observed set, one unique disposition per identity, explicit empty arrays, and stable identities before/after capture. READY-02 remains blocked on API errors, capped results, or identity movement.

### Write-ahead preservation

Before any rewrite of a dirty `.planning/` artifact, preserve its exact path/status/bytes under a durable scoped ref, verify the ref and bytes can be read back, then re-read source status/hash. The verifier's `validPreservationReference` and Phase 249 ledger demonstrate the ref/digest join. This pattern applies to evidence sources the implementation may rewrite; the new Phase 251 output itself has no historical bytes to preserve.

### Owner and phase boundary

**Source:** `verify-v149-traceability.mjs` lines 480-516 and 495-503. READY-01/02 remain owned by Phase 247. Phase 250's exception is phase-only and cannot become a requirement pass. A missing historical approval must remain `authorization_pending`.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `251-EVIDENCE-SUMMARY.md` as a Phase 251-specific artifact | report | transform | No existing Phase 251 output exists; render from the Phase 251 packet using the Phase 247 generated-report contract. |

## Metadata

**Analog search scope:** `.planning/phases/247-release-candidate-and-repository-readiness/`, `.planning/phases/249-publish-and-prove-sigra-1-6-0/`, `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/`, and the Phase 251 directory.  
**Tracked-source gate:** All named source analogs were confirmed by `git ls-files`; no ignored runtime mirror paths are referenced.  
**Pattern extraction date:** 2026-10-11
