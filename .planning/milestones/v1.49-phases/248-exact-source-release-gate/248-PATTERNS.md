# Phase 248: Exact-Source Release Gate - Pattern Map

**Mapped:** 2026-10-07
**Files analyzed:** 12 likely new/modified files (inferred from CONTEXT.md and RESEARCH.md)
**Analogs found:** 12 / 12 (some new workflow roles are composite matches)

Phase 246/247 are incomplete inputs/dependencies; these assignments do not treat either as completed or verified. The candidate content check must consume Phase 247's source-backed readiness artifact only when that artifact exists and is verified. No app UI or runtime Elixir API work is in scope.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.github/workflows/release-please.yml` | workflow/config | request-response, batch | `.github/workflows/hex-publish.yml` | exact release-job flow |
| `.github/workflows/release-pr-automerge.yml` (likely new) | workflow/config | event-driven, request-response | `.github/workflows/ci.yml` `ci-gate`; external precedent noted in research | composite |
| `.github/workflows/release-run-observer.yml` (likely new) | workflow/config | event-driven | `.github/workflows/ci.yml` failure aggregator | role-match |
| `.github/workflows/hex-publish.yml` | workflow/config | request-response, batch | `.github/workflows/release-please.yml` publish job | exact |
| `scripts/ci/wait-for-ci-gate.sh` | utility | request-response | same file (current implementation) | exact |
| `scripts/ci/release-candidate-preflight.sh` (likely new) | utility | transform / batch | `scripts/ci/wait-for-ci-gate.sh` fail-closed CLI | role-match |
| `scripts/ci/release-exact-source.sh` (likely new) | utility | transform / request-response | `.github/workflows/hex-publish.yml` provenance shell | role-match |
| `scripts/ci/release-receipt.sh` (likely new) | utility | transform / file-I/O | `scripts/ci/release-post-publish-verify.sh` | role-match |
| `scripts/ci/release-observer.sh` (likely new) | utility | event-driven / request-response | `scripts/ci/notify-failure-issue.sh` plus run poller | composite |
| `scripts/ci/release-candidate-preflight.test.sh` (likely new) | test/fixture | transform | `scripts/ci/wait-for-ci-gate.test.sh` | exact |
| `scripts/ci/release-receipt.test.sh` (likely new) | test/fixture | file-I/O | `scripts/ci/wait-for-ci-gate.test.sh` | role-match |
| `test/sigra/planning/phase_248_release_gate_contract_test.exs` (likely new) | test | transform / request-response | `test/sigra/planning/phase_222_release_lane_hardening_test.exs` | exact |

The new filenames are likely boundaries, not locked names; RESEARCH.md A1 explicitly leaves the final split to planning. Add new fixtures alongside their helper test, or use inline temporary fixtures following the poller test, while preserving deterministic offline execution.

## Pattern Assignments

### `.github/workflows/release-please.yml` (workflow/config, batch)

**Analog:** `.github/workflows/hex-publish.yml`; tracked and current. This workflow already owns Release Please outputs, the SHA gate, package checks, Hex dry-run/publish, and failure reporting.

**Inputs/permissions/concurrency** (`.github/workflows/release-please.yml:11-37`):

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  actions: write
  contents: write
  issues: write
  pull-requests: write

concurrency:
  group: release-please-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Retain the existing triggers and pinned action style, but use job-level minimum permissions and per-run/release-safe concurrency. Do not keep a shared canceling group. `cancel-in-progress: false` alone can still replace a pending run; preserve each independent evaluation or make retries idempotent by release identity.

**Outputs and stage dependency** (`.github/workflows/release-please.yml:29-37,96-105,128-150`):

```yaml
outputs:
  release_created: ${{ steps.release.outputs.release_created }}
  tag_name: ${{ steps.release.outputs.tag_name }}
  version: ${{ steps.release.outputs.version }}
  sha: ${{ steps.release.outputs.sha }}
```

`gate-ci-green` depends on `release-please`; `publish-hex` depends on both jobs and checks out the tag. Preserve this staged DAG, adding a tag commit = checkout HEAD = Release Please SHA assertion before package setup. Keep version/manifest strings as secondary checks.

**Credential boundary** (`.github/workflows/release-please.yml:244-254`):

```yaml
- name: Dry run Hex publish
  env:
    HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
  run: mix hex.publish --dry-run --yes

- name: Publish to Hex
  env:
    HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
  run: mix hex.publish --yes
```

Use `HEX_DRY_RUN_API_KEY` only in the authenticated dry-run step; retain `HEX_API_KEY` only on final publish. Never promote dry-run authentication to evidence of write authorization.

**Receipt upload precedent** (`.github/workflows/release-please.yml:272-290`): post-publish verification writes JSON and an `if: always()` artifact upload retains it for 90 days. Extend this to a terminal stage receipt for normal success/failure; do not rely on `if: always()` to cover hard cancellation. Keep the issue notification supplementary and after the receipt.

### `.github/workflows/release-pr-automerge.yml` (workflow/config, event-driven)

**Analog:** `.github/workflows/ci.yml` required `ci-gate` at lines 1571-1673 for aggregating required checks; exact guarded merge precedent is the external `lattice_stripe` workflow referenced in CONTEXT, not a tracked file in this repository. No in-repo merge workflow analog was found.

**Required gate aggregation** (`.github/workflows/ci.yml:1571-1595,1638-1673`): the gate declares all required jobs in `needs`, runs with `if: always()`, and fails closed unless each result is `success` or an explicitly valid `skipped`. For candidate merge, additionally query/verify CI check identity on the captured PR head SHA; a synthetic PR merge SHA is insufficient.

Workflow code must run from the trusted default branch. Validate exactly one open candidate, expected branch/title/base, `autorelease: pending`, candidate-content preflight, and green `ci-gate` for exact current head. Re-read PR state/head immediately before `gh pr merge --squash --match-head-commit <sha>`; preserve branch protection, with no `--admin` or token fallback. Give `RELEASE_PLEASE_TOKEN` only to the privileged decision job and only required permissions.

### `.github/workflows/release-run-observer.yml` (workflow/config, event-driven)

**Analog:** `.github/workflows/ci.yml` failure aggregator around lines 1675 onward and `.github/workflows/release-please.yml:292-321`; tracked. Use the existing `workflow_run` semantics only for cancellation terminalization.

Observer code must be default-branch trusted and validate repository, source workflow ID/name, source run ID, and source SHA from GitHub API. Do not checkout or execute PR/source-run code and do not use unvalidated artifacts to decide source identity. Create a cancellation receipt keyed by source release run ID; the observer's own `GITHUB_SHA` is not the release SHA. Missing/malformed source metadata is a failed observation, never a pass.

### `.github/workflows/hex-publish.yml` (workflow/config, request-response)

**Analog:** `.github/workflows/release-please.yml:128-290`; tracked.

**Source-bound manual recovery** (`.github/workflows/hex-publish.yml:49-92`): validate a semantic version and accepted tag/SHA shape, fetch tags, resolve both refs to commits, and reject mismatch before checks. Keep its `dry_run: true` route as the recovery proof: it reaches authenticated dry-run and omits publish and post-publish checks. Use the new read-only secret for dry-run and write secret only for publish consistently with the primary release path.

### `scripts/ci/wait-for-ci-gate.sh` (utility, request-response)

**Analog:** same tracked script.

**CLI and fail-closed validation** (`scripts/ci/wait-for-ci-gate.sh:36-91`):

```bash
set -euo pipefail
...
fail() {
  echo "wait-for-ci-gate: FAIL: $*" >&2
  exit 1
}
...
[[ -n "$SHA" ]] || fail "..."
```

Keep explicit CLI/environment inputs, strict shell mode, a single diagnostic failure helper, no secret output, and hermetic fixture seams. Its current JSON output at lines 158-166 contains `sha`, `run_url`, `attempts`, and `verdict: PASS`; reconcile/extend it to the stable receipt contract instead of dropping fields consumers may already use. CI evidence must identify the exact run SHA and `ci-gate`, not just version/tag text.

### `scripts/ci/release-candidate-preflight.sh` (utility, transform/batch)

**Analog:** `scripts/ci/wait-for-ci-gate.sh:51-80,98-113` for parameter handling, normalized failure paths, and JSON shape checks. No dedicated changelog candidate checker exists.

Read the exact candidate checkout's changelog/version and source-backed adopter artifact. Reject `Unreleased` candidate notes, duplicate release entries, missing required adopter changes, wrong branch/title/base/label, multiple open candidates, and stale head. Keep GitHub context values passed through workflow `env`, not interpolated into shell source, following `scripts/ci/notify-failure-issue.sh:14-18` security convention. Phase 247 source-backed artifact is an input only when actually present and verified; do not assume Phase 247 is complete.

### `scripts/ci/release-exact-source.sh` (utility, transform/request-response)

**Analog:** `.github/workflows/hex-publish.yml:77-92` contains the current ref provenance shell. It fetches tags, resolves `input_ref^{commit}`, compares against the expected version tag, and exits before package setup on mismatch.

Extend the identity relation to all three values: resolved `tag^{commit}` = checked-out `git rev-parse HEAD` = Release Please `sha`. Emit a machine-readable identity result only on complete equality; mismatch must stop all package commands. Pass a single immutable ref/SHA to downstream stages.

### `scripts/ci/release-receipt.sh` (utility, file-I/O)

**Analog:** `scripts/ci/release-post-publish-verify.sh:69-101,104-155`; tracked.

**Evidence writer** (`scripts/ci/release-post-publish-verify.sh:86-101`):

```bash
write_evidence() {
  local status="$1"
  local reason="${2:-}"
  cat >"$EVIDENCE_FILE" <<EOF
{
  "status": "${status}",
  "reason": "${reason}",
  "package": "${PACKAGE}",
  "version": "${VERSION}",
  "tag": "${TAG}",
  "verified_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}
```

Use explicit output path and UTC timestamps, but serialize through `jq` (avoid hand-built JSON interpolation), validate required identifiers, and atomically write stable JSON. Include release run ID/URL, workflow/job URLs, version/tag/source SHA, gate run identity, verdict, attempts, start/end timestamps, stage failure reason, publish outcome, and source-run link for cancellation. Key idempotency by release run ID/release identity. Ensure a receipt exists for failures before invoking notifier; missing label or issue API failure cannot replace it.

### `scripts/ci/release-observer.sh` (utility, event-driven)

**Analog:** `scripts/ci/notify-failure-issue.sh:29-61` for strict required inputs and soft notifier semantics; `scripts/ci/wait-for-ci-gate.sh:98-108` for validating remote run payload before interpreting it.

The observer should use `gh api` to fetch the source run and fail closed unless repo, workflow, run ID, and source SHA match expected metadata. It must not infer success from an absent run/receipt or trust artifact-declared identity. If it writes a cancellation terminal record, link both source and observer run URLs. Keep notification optional and downstream of evidence persistence.

### `scripts/ci/release-candidate-preflight.test.sh` (test/fixture, transform)

**Analog:** `scripts/ci/wait-for-ci-gate.test.sh:39-131,133-299`; tracked.

The current self-test uses temporary files and a recording `gh` stub, sets test counters, executes the real CLI, and asserts both outputs and invocation counts. Reuse this deterministic offline structure. Cover candidate identity/content, zero/multiple candidate, duplicate/Unreleased/missing adopter notes, wrong CI SHA, stale-head race, and fail-closed malformed API payloads. Do not probe or merge a live candidate as part of fixture tests.

### `scripts/ci/release-receipt.test.sh` (test/fixture, file-I/O)

**Analog:** `scripts/ci/wait-for-ci-gate.test.sh:121-131,251-295` for fixture reset, isolated temp paths, JSON validation, and negative controls. Test receipt schema and timestamps for success, each stage failure, cancellation, malformed/missing identity, duplicate retry idempotency, and notification label failure. Assert no missing gate/source record can serialize as success.

### `test/sigra/planning/phase_248_release_gate_contract_test.exs` (test, transform/request-response)

**Analog:** `test/sigra/planning/phase_222_release_lane_hardening_test.exs:14-76`; tracked.

**Structural test style** (`test/sigra/planning/phase_222_release_lane_hardening_test.exs:18-21,64-76`):

```elixir
defp read!(rel) do
  root() |> Path.join(rel) |> File.read!()
end

test "... workflow contract ..." do
  release_please = read!(".github/workflows/release-please.yml")
  assert release_please =~ "..."
end
```

Use structural assertions for workflow dependencies, action SHA pins, exact-source gate before package steps, job permission boundaries, read/write Hex secret separation, release token location, non-cancelling/replacement-safe concurrency, and `workflow_run` source validation. Pair structural checks with helper fixture tests; do not claim that YAML inspection proves live branch protection or remote secret configuration.

## Shared Patterns

### Exact source identity

**Sources:** `.github/workflows/hex-publish.yml:77-92`; `.github/workflows/release-please.yml:147-150`; `scripts/ci/wait-for-ci-gate.sh:103-162`.

Carry `tag_name` and `sha` as one provenance pair; resolve annotated tag `^{commit}`, compare it with checkout HEAD and Release Please `sha`, and query the `ci-gate` run/check for that exact SHA before package work. Version strings are secondary. Gate timeout stays within the existing 120 × 30-second poll and 75-minute job ceilings.

### Trusted merge and token event semantics

**Sources:** `.github/workflows/ci.yml:1571-1673`; `.github/workflows/release-please.yml:85-94`.

Make merge decisions in default-branch workflow code, validate the candidate and CI run head, re-read head just before merge, and use match-head semantics while preserving branch protection. Use `RELEASE_PLEASE_TOKEN` for the authorized merge/event chain; never silently substitute `GITHUB_TOKEN`, whose resulting events may not trigger the normal downstream workflow chain. Keep the token out of CI/package jobs.

### Credentials and publish boundary

**Sources:** `.github/workflows/release-please.yml:244-254`; `.github/workflows/hex-publish.yml:177-187`.

Expose read-only `HEX_DRY_RUN_API_KEY` only to dry-run. Expose write-capable `HEX_API_KEY` only to final publish. The manual `dry_run: true` route must not reach the publish step.

### Receipts before notification; cancellation observer

**Sources:** `.github/workflows/release-please.yml:283-321`; `scripts/ci/release-post-publish-verify.sh:86-101`; `scripts/ci/notify-failure-issue.sh:20-61`.

Persist/link machine-readable success and failure receipts independently of labels/issues. The notification helper deliberately falls back when labels are missing, but it is supplemental. A separate trusted default-branch `workflow_run` observer is required for hard/manual cancellation; validate source run data and correlate to source run ID/SHA. Do not trust unvalidated artifacts or observer `GITHUB_SHA` as source identity.

### Deterministic contracts

**Sources:** `scripts/ci/wait-for-ci-gate.test.sh:39-131,251-295`; `test/sigra/planning/phase_222_release_lane_hardening_test.exs:14-76`; `scripts/ci/prohibitions/p04-no-release-lane-cancellation.test.mjs:13-62`.

Use hermetic fixture/CLI tests with stubbed `gh`, temporary JSON, and asserted calls; use ExUnit for workflow structure and Node tests for policy invariants when appropriate. Keep all contracts offline and deterministic. Check actionlint, secret placement, pinned actions, and replacement-safe concurrency structurally. Do not claim successful live merge, configured secret availability, or Phase 246/247 readiness from fixtures.

## No Analog Found

| File/role | Reason |
|---|---|
| Trusted Release Please auto-merge workflow | Repository has no in-tree release PR merge automation. Use the ci-gate aggregation and exact-head merge invariants described above; external lattice precedent is research only, not a tracked analog. |
| `workflow_run` cancellation observer | No current release observer covers hard cancellation; adapt trusted workflow/API validation patterns without copying an existing implementation. |

## Metadata

**Analog search scope:** `.github/workflows/`, `scripts/ci/`, `test/sigra/planning/`
**Files scanned:** 8 focused tracked analogs plus workflow gate and policy test references
**Pattern extraction date:** 2026-10-07
**Tracked-source gate:** All repository analog paths above were confirmed with `git ls-files`; no ignored mirror paths are cited.
