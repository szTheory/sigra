# Phase 249: Publish and Prove Sigra 1.6.0 - Pattern Map

**Mapped:** 2026-10-09
**Files analyzed:** 9 candidate paths/groups
**Analogs found:** 7 / 9

The shared checkout is explicitly an older, dirty branch (`phase-244-playwright-measurement`, HEAD `576c1e5`). All analogs below are tracked according to `git ls-files`, but they may be stale. Before editing, confirm these exact patterns and line ranges against the trusted current `main` source. Do not treat local snapshots or remote evidence values in the phase context as fresh proof.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.github/workflows/ci.yml` (ExDoc build plus generated-index check) | config/workflow | build-transform | `.github/workflows/ci.yml` lines 665-672 | exact seam; stale checkout |
| `doc/llms.txt` | generated artifact | transform | same generated artifact; no hand-authored analog | partial; regenerate from ExDoc |
| New docs-index compare helper and fixture tests (exact path TBD) | utility/test | transform | `scripts/ci/release-receipt.sh` plus `.test.sh` | role-match; stale checkout |
| `.github/workflows/release-please.yml` (trusted candidate refresh integration) | config/workflow | event-driven | `.github/workflows/release-pr-automerge.yml` lines 52-128 | role/data-flow match for candidate identity checks; stale checkout |
| `.github/workflows/release-please.yml` (receipt artifact seam) | config/workflow | batch/evidence | same file lines 445-528 | exact seam; stale checkout |
| `scripts/ci/release-post-publish-verify.sh` (extend live source proof) | utility | request-response | same script | exact role; stale checkout |
| Committed sanitized release receipt (stable path TBD) | model/evidence | transform | `scripts/ci/release-receipt.sh` schema projection; artifact producer in release workflow | role-match; stale checkout |
| Worktree/PR disposition ledger and validator (format/path TBD) | model/utility | batch | `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` | role/data-flow match; stale checkout |
| Tests for workflow permissions, candidate races, receipt identity, and ledger completeness (exact paths TBD) | test | transform/event-driven | `test/sigra/planning/phase_248_release_gate_contract_test.exs`, `scripts/ci/release-receipt.test.sh` | role-match; stale checkout |

## Pattern Assignments

### ExDoc drift gate: `.github/workflows/ci.yml`, generated `doc/llms.txt`, compare helper/tests

**Analog:** `.github/workflows/ci.yml` and its existing docs build seam.

**Current build seam** (`.github/workflows/ci.yml`, lines 665-672):

```yaml
      - name: Fetch library deps
        env:
          MIX_ENV: test
        run: mix deps.get
      # The sole alias owner exercises dep-off. This lane now owns only the one
      # docs build that is intentionally outside the contributor alias.
      - name: Check docs build cleanly
        run: mix docs --warnings-as-errors
```

Insert full-file generated-output equality immediately after this build at the current required CI docs seam, and ensure its enclosing job feeds `ci-gate`. The tracked index is generated output; do not hand-patch just the title. This checkout does not contain a focused index-comparison helper analog, so use the project’s script/test conventions after confirming current main.

### Trusted Release Please candidate refresh: workflow and helper (path TBD)

**Analog:** `.github/workflows/release-pr-automerge.yml`.

**Candidate identity and race guard** (lines 81-104, 107-124):

```yaml
          capture_candidate() {
            local suffix="$1"
            gh pr list --repo "$REPOSITORY" --state open --base main \
              --head release-please--branches--main \
              --json number,state,title,baseRefName,headRefName,headRefOid,headRepository,labels,url \
              > "$work_dir/pull-requests-${suffix}.json"
            local head_sha
            head_sha="$(jq -r '.[0].headRefOid // empty' "$work_dir/pull-requests-${suffix}.json")"
            [[ "$head_sha" =~ ^[0-9a-f]{40}$ ]] || {
              echo "release preflight: candidate head is missing or malformed" >&2
              return 1
            }
            # ... validate the candidate using the captured SHA ...
          }

          candidate="$(capture_candidate initial)"
          # ... make fresh API reads ...
          final_candidate="$(capture_candidate final)"
          [[ "$candidate" == "$final_candidate" ]] || {
            echo "release preflight: candidate or source CI state changed during validation" >&2
            exit 1
          }
```

Use this two-read, fail-closed candidate snapshot pattern for docs generation and writeback. The existing guarded merge also binds the mutation to the validated head (`.github/workflows/release-pr-automerge.yml`, lines 130-140):

```yaml
      - name: Squash merge the exact validated head
        env:
          GH_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}
          PR_NUMBER: ${{ steps.preflight.outputs.pr_number }}
          PR_HEAD_SHA: ${{ steps.preflight.outputs.head_sha }}
        run: |
          set -euo pipefail
          gh pr merge "$PR_NUMBER" --repo "$REPOSITORY" --squash \
            --match-head-commit "$PR_HEAD_SHA"
```

Keep the docs build unprivileged, send only the generated file to a narrowly scoped writer, and use an expected-base/non-force update. Preserve the current fresh-CI event chain and exact-head merge guard. The current source may have changed since this snapshot; recheck workflow triggers, token source, and action pins before planning.

### Sanitized release receipt and retained artifact

**Analog:** `scripts/ci/release-receipt.sh`; producer seam: `.github/workflows/release-please.yml`.

**Validation and secret exclusion** (`scripts/ci/release-receipt.sh`, lines 21-36):

```bash
[[ -n "$INPUT" && -f "$INPUT" ]] || fail "input JSON file is required"
[[ -n "$OUTPUT" ]] || fail "output path is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
jq -e 'type == "object"' "$INPUT" >/dev/null 2>&1 || fail "input must be a JSON object"

# Diagnostic text is deliberately an enum-like code rather than arbitrary logs.
# This prevents runner output or accidentally interpolated credentials from being
# persisted in the durable evidence artifact.
if ! jq -e '
  def no_credential_keys:
    [.. | objects | keys[]? | select(test("(token|secret|credential|api.?key)"; "i"))] | length == 0;
```

**Stable identity projection and atomic output** (`scripts/ci/release-receipt.sh`, lines 126-153):

```bash
jq -n --arg recorded_at "$RECORDED_AT" --slurpfile input "$INPUT" \
  --slurpfile previous "$PREVIOUS_FILE" '
  ($input[0]) as $r |
  ($previous[0] // {}) as $old |
  {
    schema_version: $r.schema_version,
    release_run_id: $r.release_run.id,
    release_run_attempt: $r.release_run.attempt,
    version: $r.source.version,
    tag: $r.source.tag,
    source_sha: $r.source.sha,
    gate: $r.gate,
    publish: $r.publish,
    terminal_verdict: $r.terminal_verdict,
    recorded_at: $recorded_at
  }
' > "$TEMP_OUTPUT" || fail "could not encode receipt JSON"
jq -e . "$TEMP_OUTPUT" >/dev/null || fail "encoded receipt is not valid JSON"
mv -f "$TEMP_OUTPUT" "$OUTPUT"
```

Extend the existing projection/schema and tests rather than inventing a second release identity model. Preserve separate fields for package-source CI, later protected-main CI, and the receipt commit/source. The producer currently uploads the validated JSON with 90-day retention (`.github/workflows/release-please.yml`, lines 521-528); derive the committed sanitized receipt from that retained artifact. The `release-receipt.sh` tests build fixture JSON and assert identity and failure behavior (`scripts/ci/release-receipt.test.sh`, lines 14-62); reuse this fixture-driven shell style.

### Live release proof

**Analog:** `scripts/ci/release-post-publish-verify.sh`.

**URLs and machine-readable evidence** (lines 80-101):

```bash
HEX_RELEASE_URL="https://hex.pm/api/packages/${PACKAGE}/releases/${VERSION}"
HEXDOCS_BASE_URL="https://hexdocs.pm/${PACKAGE}/${VERSION}"
SOURCE_LINK_NEEDLE="github.com/${REPOSITORY}/blob/${TAG}/"

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
  "hex_release_url": "${HEX_RELEASE_URL}",
  "hexdocs_base_url": "${HEXDOCS_BASE_URL}"
}
EOF
}
```

Current source-link check only finds the expected tag text in rendered HTML and rejects `main` (lines 127-148). Extend this boundary to fetch/follow the actual source destination and verify resolved tag/commit against the immutable source SHA. Retain bounded retry/fail diagnostics, and avoid claiming a live destination proof from rendered-link text alone.

### Worktree and PR disposition ledger

**Analog:** `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` (tracked) and its tracked JSON snapshot.

The validator uses enumerated disposition categories and inventories Git and GitHub state (`validate-release-readiness.mjs`, lines 7-9, 132-167):

```js
const DISPOSITIONS = new Set(['release-blocking', 'release-relevant', 'separate-follow-up']);
const KINDS = new Set(['committed', 'dirty']);

function observe(snapshot) {
  const repoRoot = runGit(['rev-parse', '--show-toplevel']);
  const branch = runGit(['branch', '--show-current']);
  const currentHead = runGit(['rev-parse', 'HEAD']);
  const remoteMain = runGh(['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha']);
  const rawStatus = parseStatus(runGit(['status', '--porcelain=v1', '-uall']));
  const pullRequests = JSON.parse(runGh(['pr', 'list', '--repo', repository, '--state', 'open', '--limit', '1000', '--json', 'number,headRefOid,baseRefName']))
    .map(row => ({ number: row.number, head_sha: row.headRefOid, base: row.baseRefName }))
    .sort((a, b) => a.number - b.number);
  return { repo_root: repoRoot, trusted_main_sha: remoteMain, branch, current_head_sha: currentHead,
    dirty_paths: rawStatus, pull_requests: pullRequests };
}
```

Reuse the deterministic inventory/validation approach, but model every current worktree and every open PR, recording durable preservation location/action for inherited changes. The Phase 247 path/snapshot logic is phase-specific and must not be copied as if it were a current inventory or general policy.

### Workflow contract tests

**Analog:** `test/sigra/planning/phase_248_release_gate_contract_test.exs`.

This ExUnit contract test reads workflow files directly and extracts named job bodies (lines 1-6, 45-52); the release artifact test asserts receipt ordering, input identities, upload action, and retention (lines 198-216). Add assertions for the new docs build-and-compare adjacency, credential isolation, candidate fixed-branch/SHA recheck, permitted changed path, non-force update, fresh CI event, and fail-closed race handling. Confirm current test placement and invocation on trusted main before using these exact helper conventions.

## Shared Patterns

### Trusted source identity and fail-closed validation

Use full 40-character commit identities, bind evidence to the source SHA that produced the package, and re-read mutable PR/run state immediately before writes. The merge guard uses `--match-head-commit`; preserve this exact-head constraint for automatic refresh/merge eligibility.

### Machine-readable evidence

Receipt and closeout data should be stable JSON/schema artifacts with explicit identities, enum-like failure/disposition values, and no credentials or arbitrary log dumps. Keep run ID and attempt, tag/version/SHA, CI run/head, Hex, docs, and source URL distinct.

### Error handling and privilege boundaries

Shell scripts use `set -euo pipefail`, explicit argument validation, stderr diagnostics, bounded external retries, and nonzero exits for missing/mismatched evidence. Build docs without write credentials; scope mutation credentials to a dedicated step/job and fail closed on branch/head/path/race mismatches.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| New docs-index comparison helper (path TBD) | utility | transform | No existing full generated-file equality helper was identified; adapt fixture/validation conventions from receipt helpers. |
| New trusted refresh writer (path TBD) | utility | event-driven | Existing exact-head checks are merge-only; no tracked docs refresh writer or bounded non-force candidate update analog found. |

## Metadata

**Analog search scope:** `.github/workflows/`, `scripts/ci/`, `test/sigra/planning/`, and Phase 247 planning evidence.
**Files scanned:** 9 primary candidates/analogs; 8 analog paths selected.
**Tracked-source gate:** Every named analog was confirmed by `git ls-files`; no ignored/runtime mirror paths are used.
**Pattern extraction date:** 2026-10-09.
**Freshness note:** Confirm all excerpts against trusted current `main`; this checkout contains inherited dirty changes and is not release-code source of truth.
