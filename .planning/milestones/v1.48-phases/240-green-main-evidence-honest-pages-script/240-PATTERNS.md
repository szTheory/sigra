# Phase 240: Green-Main Evidence + Honest Pages Script - Pattern Map

**Mapped:** 2026-09-18
**Files analyzed:** 11 (7 new, 4 modified)
**Analogs found:** 10 / 11 (the only file with no analog is the todo-closure *move*, which is a
file operation, not a code pattern)

All line citations below were read this session from the working tree at `main` (`0711901d`).

## File Classification

| New/Modified File | New? | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|------|-----------|----------------|---------------|
| `.github/workflows/green-04-evidence.yml` | new | config (CI workflow) | batch / event-driven (dispatch) | `.github/workflows/generated-app-login-runtime-proof.yml` (shape) + `.github/workflows/ci.yml:1401-1533` (body) + `.github/workflows/fast-01-remeasurement-evidence.yml:10-18` (evidence-job keys) | exact (composite of 3) |
| `scripts/ci/capture-green-04-evidence.sh` | new | service (API collector) | request-response → transform → file-I/O | `scripts/ci/capture-terminal-ratification-evidence.sh` (pagination core, jobs endpoint) + `scripts/ci/capture-fast-01-remeasurement.sh` (canonical-JSON emission) | exact (dual provenance) |
| `scripts/ci/capture-green-04-evidence.test.sh` | new | test (hermetic stub harness) | request-response (stubbed) | `scripts/ci/capture-terminal-ratification-evidence.test.sh` | exact |
| `scripts/ci/ensure-github-pages-legacy-branch.test.sh` | new | test (hermetic stub harness) | request-response (stubbed) | `scripts/ci/notify-failure-issue.test.sh` (non-collector script + recording `gh` stub + per-case PASS/FAIL tally) — secondary: `capture-terminal-ratification-evidence.test.sh:88-121` (expected-failure idiom) | exact |
| `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` | new | test (offline structural guard) | transform (parse + compare) | `scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs` | exact (near-structural twin) |
| `test/fixtures/prohibitions/p20-green-04-step-drift.yml` | new | test fixture (known-bad) | n/a | `test/fixtures/prohibitions/p06-fast-checks-docs-gated.yml` | exact |
| `.planning/phases/240-.../240-EVIDENCE.md` | new | doc (evidence ledger, p12 slot grammar) | n/a | `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md` | exact (with one mandatory deviation — see below) |
| `scripts/ci/ensure-github-pages-legacy-branch.sh` | modified | utility (shell, REST client) | request-response | itself (`:43-51` is already the loud/branching idiom); status-line discipline has **no in-repo analog** — see "No Analog Found" | partial |
| `.github/workflows/ci.yml` (one `fast_checks` step) | modified | config | n/a | `ci.yml:257-261` (`Notify-failure-issue self-test`) | exact |
| `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md` | modified+moved | doc | n/a | `.planning/todos/completed/2026-07-29-github-pages-...md` (its own tail carries a resolution/evidence append) | role-match |
| `.planning/todos/completed/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` | modified | doc | n/a | same file's existing structure (`:1-17` frontmatter, terminal `## Required owner action`) | exact |

---

## Pattern Assignments

### `.github/workflows/green-04-evidence.yml` (config, dispatch-only matrix evidence workflow)

**Analogs (three, each supplying a different layer):**

**1. Workflow skeleton — `.github/workflows/fast-01-remeasurement-evidence.yml:1-19`** (verbatim):

```yaml
name: FAST-01 fresh-window evidence

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  capture:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: read
      actions: read
      id-token: write
      attestations: write
    steps:
```

Note: `if: github.ref == 'refs/heads/main'` sits at **job** level (`:11`), which is the shape D-01
names. The elevated `permissions` block (`:14-18`) belongs to an *attesting* job; the GREEN-04
evidence job runs Playwright, not attestation, so it should keep only `contents: read`
(workflow-level, `:6-7`) per RESEARCH §Security V4.

**2. Precedent for a duplicated generated-host dispatch job — `generated-app-login-runtime-proof.yml:9-33`** (verbatim):

```yaml
jobs:
  generated_app_login_runtime_proof:
    name: Generated app-login runtime proof
    runs-on: ubuntu-latest
    timeout-minutes: 30
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - uses: erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124
        with:
          version-file: .tool-versions
          version-type: strict
```

This file declares **no `concurrency:` block** (verified: absent from both dispatch evidence
workflows) — matching D-01/RESEARCH §1's "omit entirely".

**3. Job body to copy — `ci.yml:1401-1533`.** The `services.postgres` block (`:1422-1430`) is
byte-identical to the one above. The 11 steps, with the four load-bearing `run:` lines:

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
      - uses: erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124  # v1.24.1
        with:
          version-file: .tool-versions
          version-type: strict
      - uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020  # v7.0.0
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: 'test/example/priv/playwright/package-lock.json'
      - name: Install Hex + Rebar
        run: |
          mix local.hex --force
          mix local.rebar --force
      - name: Install phx_new archive
        run: mix archive.install --force hex phx_new 1.8.8
      - name: Install Playwright deps
        working-directory: test/example/priv/playwright
        run: npm ci
      - name: Install Playwright browsers
        working-directory: test/example/priv/playwright
        run: npx playwright install --with-deps chromium webkit
      - name: Run generated admin acceptance smoke
        env:
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
          GITHUB_WORKSPACE: ${{ github.workspace }}
        run: scripts/ci/admin-acceptance-smoke.sh --test all
```

**Artifact-upload pattern to copy with the one mandatory deviation** (`ci.yml:1496-1513`):

```yaml
      - name: Upload generated admin review bundle (main, 14d retention)
        if: always() && github.ref == 'refs/heads/main'
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
        with:
          name: generated-admin-report
          path: |
            test/example/priv/playwright/playwright-report/
            test/example/priv/playwright/artifacts/admin-checkpoints/
          retention-days: 14
```

Deviation (RESEARCH §1 / Pitfall 1): `name:` must become
`generated-admin-report-${{ matrix.repeat }}` on `:1500` and `:1509`, and
`generated-admin-failure-diagnostics-${{ matrix.repeat }}` on `:1523` and `:1530`.

**Must NOT copy:** `needs: release_ref_guard` (`ci.yml:1421`) — unresolvable in the new workflow;
and the job `name:` `Generated admin Playwright smoke` (`:1402`) — use a distinct name so the
collector's `.name ==` selector (D-08) can never ingest a real `ci.yml` job.

**Matrix keys (no in-repo analog for a `repeat` matrix; nearest matrix precedent is
`ci.yml:559-565`'s shard matrix and its documented job-name-suffixing hazard):**

```yaml
    strategy:
      fail-fast: false
      max-parallel: 5
      matrix:
        repeat: [1, 2, 3, ..., 20]
```

---

### `scripts/ci/capture-green-04-evidence.sh` (service, API collector)

**Primary analog:** `scripts/ci/capture-terminal-ratification-evidence.sh` (jobs-endpoint half).
**Secondary analog:** `scripts/ci/capture-fast-01-remeasurement.sh` (canonical-output half).

**Header + fixed-parameter pattern** (`capture-terminal-ratification-evidence.sh:1-16`):

```bash
#!/usr/bin/env bash
# Capture the fixed Phase 235 historical Actions population as an attestation subject.
# This command deliberately has no caller-configurable repository, workflow, or window.
set -euo pipefail

REPO="szTheory/sigra"
WORKFLOW="ci.yml"
CUTOFF="2026-08-01T02:06:30Z"
ENDPOINT="2026-08-02T18:07:04Z"
MAX_PAGES=10000
```

**Arg surface + fail-closed preflight + temp-output discipline** (`:18-46`):

```bash
if [[ $# -ne 1 ]]; then
  echo "capture-terminal-ratification-evidence: FAIL: expected OUTPUT_PATH" >&2
  exit 2
fi
OUTPUT="$1"
TMPDIR_CAPTURE="$(mktemp -d)"
output_tmp=""
cleanup() {
  rm -rf "$TMPDIR_CAPTURE"
  if [[ -n "$output_tmp" ]]; then
    rm -f "$output_tmp"
  fi
}
trap cleanup ERR INT TERM EXIT

fail() { echo "capture-terminal-ratification-evidence: FAIL: $*" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH"
command -v jq >/dev/null 2>&1 || fail "jq not found on PATH"

# Exactly one preflight. Collection is finite REST retrieval, not workflow polling.
REMAINING="$(gh api rate_limit --jq '.resources.core.remaining')" || fail "rate_limit_preflight_failed"
[[ "$REMAINING" =~ ^[0-9]+$ ]] || fail "rate_limit_preflight_malformed"
(( REMAINING > 250 )) || fail "rate_limit_remaining_at_or_below_250"

# Never take ownership of the caller's receipt path until a complete, validated
# replacement exists. A failed refresh must preserve any retained evidence.
output_dir="$(dirname -- "$OUTPUT")"
[[ -d "$output_dir" ]] || fail "output_directory_missing"
output_tmp="$(mktemp "$output_dir/.terminal-ratification.XXXXXX")" || fail "output_temporary_file_failed"
```

**THE pagination core — copy verbatim** (`:48-92`). This is the whole of D-11 already implemented,
generic over endpoint and item key:

```bash
request_page() {
  local endpoint="$1" page="$2" out="$3"
  if ! gh api "${endpoint}&per_page=100&page=${page}" >"$out"; then
    # gh prints HTTP detail itself; do not retry 403/429 or any other API failure.
    fail "github_api_request_failed_page_${page}"
  fi
}

validate_manifest() {
  local manifest="$1" item_key="$2" label="$3"
  jq -s -e --arg key "$item_key" '
    if type != "array" or length == 0 then error("absent_terminal_empty_page") else . end
    | . as $pages
    | if all(.[]; (.page|type) == "number" and ((.page|floor) == .page) and .page > 0 and (.body|type) == "object") then . else error("malformed_envelope") end
    | if ([.[].page] | sort) == [range(1; length + 1)] then . else error("non_contiguous_or_duplicate_page") end
    | if ([.[].body.total_count] | all(type == "number" and (floor == .) and . >= 0)) then . else error("malformed_total_count") end
    | if ([.[].body.total_count] | unique | length) == 1 then . else error("total_count_changed") end
    | if (.[-1].body[$key] | type) == "array" and (.[-1].body[$key] | length) == 0 then . else error("absent_terminal_empty_page") end
    | if ([.[0:-1][].body[$key] | length] | add // 0) == .[0].body.total_count then . else error("total_count_disagreement") end
    | if all(.[0:-1][]; (.body[$key] | type) == "array" and length > 0) then . else error("nonterminal_empty_page") end
    | ([.[].body[$key][]?.id] | if all(type == "number" or type == "string") then . else error("malformed_item_identity") end) as $ids
    | if ($ids | length) == ($ids | unique | length) then . else error("duplicate_item_id") end
  ' "$manifest" >/dev/null || fail "${label}_manifest_invalid"
}

collect_pages() {
  local endpoint="$1" item_key="$2" label="$3" manifest="$4"
  local page=1 response total minimum_pages items
  : >"$manifest"
  while :; do
    response="$TMPDIR_CAPTURE/${label}-${page}.json"
    request_page "$endpoint" "$page" "$response"
    jq -e --argjson page "$page" '{page: $page, body: .}' "$response" >>"$manifest" || fail "${label}_malformed_response"
    total="$(jq -r '.total_count' "$response")"
    [[ "$total" =~ ^[0-9]+$ ]] || fail "${label}_malformed_total_count"
    minimum_pages=$(( (total + 99) / 100 + 1 ))
    (( minimum_pages <= MAX_PAGES )) || fail "pagination_bound_reached"
    items="$(jq --arg key "$item_key" '.[$key] | if type == "array" then length else -1 end' "$response")"
    (( items >= 0 )) || fail "${label}_malformed_items"
    if (( items == 0 )); then break; fi
    (( page < MAX_PAGES )) || fail "pagination_bound_reached"
    page=$((page + 1))
  done
  validate_manifest "$manifest" "$item_key" "$label"
}
```

**The `/jobs` call site to model on** (`:126-136`) — note the `?` suffix so `request_page`'s `&`
concatenation is well-formed, and the per-job identity/chronology assertion including the
skipped-job nullability exemption:

```bash
for run_id in "${MEASUREMENT_RUN_IDS[@]}"; do
  manifest="$TMPDIR_CAPTURE/jobs-${run_id}.manifest.jsonl"
  collect_pages "repos/${REPO}/actions/runs/${run_id}/jobs?" jobs "jobs-${run_id}" "$manifest"
  jq -s -e '
    [.[].body.jobs[]]
    | all(.[]; . as $job | ($job.id|type) == "number" and ($job.name|type) == "string" and ($job.name|length) > 0 and ($job.conclusion|type) == "string" and ($job.conclusion|length) > 0 and (if $job.conclusion == "skipped" then (($job.started_at|type) == "string" or $job.started_at == null) and (($job.completed_at|type) == "string" or $job.completed_at == null) else ($job.started_at|type) == "string" and ($job.completed_at|type) == "string" and $job.completed_at >= $job.started_at end))
  ' "$manifest" >/dev/null || fail "job_chronology_or_identity_invalid_run_${run_id}"
  jobs_next="$TMPDIR_CAPTURE/jobs-${run_id}.json"
  jq --arg id "$run_id" --slurpfile pages "$manifest" '. + [{run_id: ($id|tonumber), pages: $pages}]' "$JOB_MANIFESTS_FILE" >"$jobs_next" || fail "job_manifest_append_failed"
  mv "$jobs_next" "$JOB_MANIFESTS_FILE"
done
```

D-11 requires `filter=` to be explicit; this call site does **not** pass it, so the new script
must use `repos/${REPO}/actions/runs/${run_id}/jobs?filter=latest` (still ending in a parameter so
`&per_page=100` appends correctly).

**Canonical-output emission** — two idioms, pick per field shape.
From `capture-terminal-ratification-evidence.sh:138-153` (schema + `--slurpfile` + `mv -f`):

```bash
jq -S -n --arg repository "$REPO" --arg workflow "$WORKFLOW" --slurpfile run_pages "$RUNS_MANIFEST" --slurpfile jobs "$JOB_MANIFESTS_FILE" '
  {schema_version: "sigra.terminal-ratification-receipt/v1", repository: $repository, ...}
' >"$output_tmp" || fail "canonical_output_failed"

test -s "$output_tmp" || fail "empty_canonical_output"
mv -f -- "$output_tmp" "$OUTPUT" || fail "canonical_output_replace_failed"
output_tmp=""
```

From `capture-fast-01-remeasurement.sh:84-92` (row projection + population floor + verdict field):

```bash
jq -S -n --arg endpoint "$ENDPOINT" --arg cutoff "$CUTOFF" --arg sha "$CUTOFF_SHA" --slurpfile pages "$MANIFEST" '
  ([ $pages[].body.workflow_runs[]? | select(.event == "pull_request") ] | map({run_id:.id,wall_seconds:(...),conclusion:.conclusion,url:.html_url})) as $runs
  | if ($runs|length) < 10 then error("insufficient_population") else . end
  | {schema_version:"sigra.fast-01-remeasurement/v1", ..., verdict:(if $p50 < 720 then "pass" else "miss" end), status:"measured"}
' >"$OUTTMP" || fail "canonical_protected_output_failed"
mv -f "$OUTTMP" "$OUTPUT"
```

**Clean-tree / final-HEAD assertion (D-13):** no existing collector does this. The nearest
in-repo precedent for a git-side protected-constant assertion is
`capture-fast-01-remeasurement.sh:25-29`:

```bash
git merge-base --is-ancestor "$CUTOFF_SHA" origin/main || fail "cutoff_not_on_origin_main"
# Compare the instant, not Git's equivalent ISO-8601 spelling (`Z` vs `+00:00` differs ...).
[[ "$(git show -s --format=%ct "$CUTOFF_SHA")" == "$CUTOFF_EPOCH" ]] || fail "cutoff_timestamp_mismatch"
git show --format= --name-only "$CUTOFF_SHA" | grep -qx '.github/workflows/ci.yml' || fail "cutoff_not_topology_affecting"
```

Follow that *style* (git command, `||` fail token) for the new
`dirty_tree` / `evidence_run_head_sha_is_not_final_committed_head` assertions.

**Do NOT extend `capture-fast-01-remeasurement.sh`** — `:5-11` are protected constants pinned by
`test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs`, and its own self-test
greps them literally (`capture-fast-01-remeasurement.test.sh:10-11`).

---

### `scripts/ci/capture-green-04-evidence.test.sh` (test, hermetic stub harness)

**Analog:** `scripts/ci/capture-terminal-ratification-evidence.test.sh` (read in full).

**Stub construction + happy path** (`:1-18`, `:69-71`):

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$ROOT/scripts/ci/capture-terminal-ratification-evidence.sh"
WORKFLOW="$ROOT/.github/workflows/terminal-ratification-evidence.yml"

test -x "$COLLECTOR"
test -s "$WORKFLOW"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
if [[ "$1" == api && "$2" == rate_limit ]]; then echo 251; exit 0; fi
if [[ "${FAKE_MODE:-ok}" == api_failure ]]; then
  echo "synthetic API failure" >&2
  exit 1
fi
PAGE="$(printf '%s' "$*" | sed -n 's/.*page=\([0-9][0-9]*\).*/\1/p')"
...
EOF
chmod +x "$TMP/bin/gh"

FAKE_GH_LOG="$TMP/calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/receipt.json"
```

**Expected-failure idiom — assert the *reason*, not just non-zero** (`:88-94`, `:96-103`):

```bash
set +e
FAKE_MODE=inverted_run FAKE_GH_LOG="$TMP/inverted-calls" PATH="$TMP/bin:$PATH" "$COLLECTOR" "$TMP/inverted.json" 2>"$TMP/inverted.err"
RC=$?
set -e
test "$RC" -ne 0
grep -q 'run_chronology_or_identity_invalid' "$TMP/inverted.err"
test ! -e "$TMP/inverted.json"

printf '%s' 'retained receipt bytes' >"$TMP/existing-receipt.json"
set +e
FAKE_MODE=api_failure ... "$COLLECTOR" "$TMP/existing-receipt.json" 2>"$TMP/api-failure.err"
RC=$?
set -e
test "$RC" -ne 0
grep -q 'github_api_request_failed_page_1' "$TMP/api-failure.err"
test "$(<"$TMP/existing-receipt.json")" = 'retained receipt bytes'
```

**Negative assertions from the call log** (`:83-85`, `:105-114`) — the mechanism that proves a call
was *never* made:

```bash
test "$(grep -c '/jobs?' "$TMP/calls")" -eq 46
test "$(grep -c '/jobs?.*&page=1$' "$TMP/calls")" -eq 23
...
  test "$(grep -c '/jobs?' "$TMP/${mode}-calls" || true)" -eq 0
```

**Terminal PASS line** — from `capture-fast-01-remeasurement.test.sh:99`:

```bash
echo "capture-fast-01-remeasurement.test: PASS"
```

Also copy that file's `fail()` helper and executable precondition (`:8-9`) and its adversarial
argument-surface case (`:86-90`), which proves the collector refuses caller-chosen windows.

---

### `scripts/ci/ensure-github-pages-legacy-branch.test.sh` (test, fake-`gh` stub harness)

**Primary analog:** `scripts/ci/notify-failure-issue.test.sh` — the closest structural match,
because it self-tests a *non-collector* `gh`-calling script and enumerates its cases in the header.

**Header case enumeration** (`:1-24`):

```bash
#!/usr/bin/env bash
# Self-test for notify-failure-issue.sh (Phase 222 Plan 02 / D-07).
#
# Hermetic: no real `gh` CLI or network call. A recording stub `gh` is placed
# first on PATH; it logs every invocation's argv and returns a scripted
# response so each case can assert exactly what the script under test called.
#
# Test cases (mirrors the plan's <behavior> block):
#   A: no open issue -> `gh issue create` exactly once, never `gh issue comment`.
#   ...
set -euo pipefail
```

**PASS/FAIL tally + cleanup + recording stub** (`:26-70`):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/notify-failure-issue.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi

PASS=0
FAIL=0
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() { if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then rm -rf "$TMPDIR_ROOT"; fi }
trap cleanup EXIT

TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"
mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
: > "$GH_STUB_LOG"

cat >"${STUB_BIN_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
# Recording stub for `gh` (test-only). Logs argv, returns a scripted response.
set -euo pipefail
echo "$*" >> "${GH_STUB_LOG}"
if [[ "${1:-}" == "issue" && "${2:-}" == "list" ]]; then
  echo "${GH_STUB_ISSUE_NUMBER:-}"
  exit 0
fi
...
STUB
```

**Secondary analog for the `FAKE_MODE` selector and expected-failure blocks:**
`capture-terminal-ratification-evidence.test.sh:20-23` (`${FAKE_MODE:-ok}` default) and `:88-104`
(quoted above). The nine stub modes RESEARCH §5 enumerates map onto `FAKE_MODE`.

**No analog exists for emitting a four-channel `gh api -i` response from a stub.** RESEARCH §5
supplies the verbatim payload (status line as stdout line 1 in `HTTP/2.0` form, headers, blank
line, JSON body on stdout with no trailing newline, `gh: <msg> (HTTP 403)` on stderr, `exit 1`);
treat that block as the source of truth rather than looking for an in-repo precedent.

---

### `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` (test, offline structural guard)

**Analog:** `scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs` — a
near-exact structural twin (extracts a step list from a workflow job and checks an invariant via a
pure checker function).

**Header comment contract** (`p15:1-31`) — the house shape is: prohibition restated in `MUST
NOT` form, the concrete incident that motivated it, `Subject:` line naming the
`GSD_PROHIB_SUBJECT`-substitutable path, "what silently breaks if this guard is deleted", and why
comments are stripped:

```js
// P15 (231-10-PLAN.md) — mechanical enforcement.
//
//   MUST NOT let the Playwright GitHub Pages publisher boot the example app without first
//   seeding it. D-17: ...
//
// Subject: .github/workflows/playwright-github-pages.yml (via GSD_PROHIB_SUBJECT).
//
// What this guard proves: ...
// What silently breaks if this guard is deleted: ...
//
// Comments are stripped before parsing (`stripYamlComments`) for the same reason `p06`
// explains: ...

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, jobBlock, stripYamlComments } from './_lib.mjs';

const SUBJECT = '.github/workflows/playwright-github-pages.yml';
```

`p19-tag-namespace-ruleset.test.mjs:14-21` supplies the offline-by-design paragraph to mirror:

```js
// STRUCTURAL AND OFFLINE BY DESIGN, mirroring p12 (`p12-run-id-provenance.test.mjs:1-20`). This
// guard does NOT call the GitHub API, use a token, or touch the network. Two reasons: (1) doing
// so would put `gh`, a token, and a transient 5xx on the pull_request critical path, and a red PR
// for a reason unrelated to the diff is exactly the tax this milestone exists to remove; ...
```

**`stepList()` — copy verbatim** (`p15:40-56`):

```js
function stepList(jobBlockText) {
  const m = jobBlockText.match(/\n {4}steps:\n([\s\S]*)$/);
  if (!m) return [];
  const body = m[1];
  return body
    .split(/(?=^ {6}- )/m)
    .filter((s) => s.trim() !== '')
    .map((block) => {
      const nameMatch = block.match(/^ {6}- name:\s*(.+)$/m);
      const usesMatch = block.match(/^ {6}- uses:\s*(.+)$/m);
      return {
        name: nameMatch ? nameMatch[1].trim() : (usesMatch ? `uses:${usesMatch[1].trim()}` : '(unnamed)'),
        hasCondition: /^ {8}if:/m.test(block),
        text: block,
      };
    });
}
```

**Pure-checker shape with a parse-broke guard clause** (`p15:64-72`):

```js
function seedsOrderingIssue(steps) {
  if (steps.length === 0) {
    return 'the parse broke, this is not a pass — zero steps extracted from the publish job';
  }
  const dbIndex = steps.findIndex((s) => s.name === 'Setup example dev DB');
  ...
}
```

**Subject read + non-vacuity floor test + behavior test** (`p15:99-118`):

```js
const ci = stripYamlComments(readSubject(SUBJECT));
const publishBlock = jobBlock(ci, 'publish');

test('the parse locates the publish job and its step list is non-empty', () => {
  assert.ok(publishBlock, 'job `publish` not found in playwright-github-pages.yml — the parse broke, this is not a pass');
  const steps = stepList(publishBlock);
  assert.ok(steps.length > 0, 'the parse broke, this is not a pass — zero steps extracted from the publish job');
});

test('a demo-seeds step exists, unconditional, strictly between DB setup and app boot', () => {
  const steps = stepList(publishBlock);
  const issue = seedsOrderingIssue(steps);
  assert.equal(issue, null, issue ?? '');
});
```

**Negative-control test shape** (`p15:120-139`) — note p15 inlines its bad fixture as a template
literal; p20 must instead read a **committed** fixture under `test/fixtures/prohibitions/` per
ROADMAP standing constraint 6, using `readRepoFile` (`_lib.mjs:80-84`):

```js
test('negative control: a fixture omitting the seeds step fails the guard', () => {
  const fixture = `  publish:
    name: Publish Playwright site
    steps:
      - uses: actions/checkout@abc
      ...
`;
  const issue = seedsOrderingIssue(stepList(fixture));
  assert.match(
    issue ?? '',
    /no step invokes priv\/repo\/seeds\.exs/,
    'a fixture with no seeds step must fail the guard — a guard that only passes on the real ' +
      'file is not falsifiable',
  );
});
```

**Helpers available from `_lib.mjs` (all verified present):** `subjectPath`/`readSubject`
(`:33-78`, honours `GSD_PROHIB_SUBJECT` and archive-aware paths), `readRepoFile` (`:80-84`, for
reading `ci.yml` as the *reference* rather than the subject), `jobBlocks` (`:93-113`),
`stripYamlComments` (`:128-146`), `jobBlock` (`:179-182`).

**Guard id:** `p20` is correct. `ls scripts/ci/prohibitions/` returns `p01`–`p17` and `p19`
(no `p18`); fixtures dir holds `p01`–`p13`, `p17`, `p19`.

---

### `test/fixtures/prohibitions/p20-green-04-step-drift.yml` (test fixture, known-bad)

**Analog:** `test/fixtures/prohibitions/p06-fast-checks-docs-gated.yml` (full file read).

**Fixture prose-header pattern** (`p06:1-11`) — a fixture must be *structurally valid* so the
guard's non-vacuity floor passes and the red comes from the clause under test:

```yaml
name: CI
# KNOWN-BAD fixture for P6 (230-05). Structurally a valid ci.yml: it declares all three
# lanes the guard names, so the guard's non-vacuity test PASSES and the red comes from the
# clause under test rather than from an empty parse.
#
# The defect: `fast_checks` carries a docs_only gate, and `library_tests_shard` depends on
# `changes`. Either alone removes coverage in exactly the dimension a docs-only PR touches.
on:
  pull_request:
    branches: [main]

jobs:
```

`p04-concurrency-groups-main-pushes.yml:1-5` is the same shape for a workflow-level defect. For
p20 the defect is a dropped `Install Playwright browsers` step (RESEARCH §6).

---

### `.planning/phases/240-.../240-EVIDENCE.md` (doc, p12 slot-grammar ledger)

**Analog:** `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md`.

**Summary table + anchored slot links** (`236-EVIDENCE.md:1-9`):

```markdown
# Phase 236 Evidence Ledger

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-FLAKE-RED](#before-flake-red) | Deliberately manufactured RED of ... | Real GitHub Actions CI run `35004420339` (`gh run view` / `gh api .../logs`) ... | captured (run `35004420339`) |
| [AFTER-FIX-GREEN](#after-fix-green) | Five sequential `pull_request` CI runs ... | `gh run list --workflow CI --branch ...` + `gh run view <id> --json jobs` ... | captured (runs `35029916498`, `35030710957`, `35031404780`, `35032086557`, `35034938082`) |

---
```

**Captured-slot body** (`:11-34`) — `Status:` line, then a fenced block naming the producing
command (p12 requires it to match `ci-run-metrics.sh` or `/\bgh (run|pr|api)\b/`), then the run id
repeated in prose/output so it occurs ≥2× in the slot:

```markdown
## BEFORE-FLAKE-RED

Status: captured (run `35004420339`)

### Primary evidence: real, unprompted CI failure (run `35004420339`)

Producing commands:

```bash
gh run list --workflow=ci.yml --limit 50 --json databaseId,conclusion,headBranch,createdAt,event
gh run view 35004420339 --json jobs -q '.jobs[] | select(.name=="Generated admin Playwright smoke")'
gh api repos/szTheory/sigra/actions/jobs/104500542292/logs
```
```

**Guard-RED-observed slot** (`236-EVIDENCE.md`, `## AFTER-P17-GUARD-OBSERVED`) — the exact shape
for p20's standing-constraint-6 record (RED half with `GSD_PROHIB_SUBJECT`, GREEN half, shared-glob
regression check, each with its exit code and TAP summary):

```markdown
### RED half — committed known-bad fixture substituted as the subject

```bash
GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts node --test --test-reporter=tap scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs
```

Exit code: `1`.
...
TAP summary: `# tests 5`, `# pass 4`, `# fail 1`.

### Shared glob unaffected

```bash
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
```
```

**MANDATORY DEVIATION from this analog:** that slot's `Status: captured` (bare, no parenthetical)
**fails** p12's grammar regex (`p12:44-49`, `/^(captured \((run|runs) [\s\S]+\)|pending \(.+\))$/`).
It passes today only because p12 is hardcoded to the *230* ledger (`p12:26`). Every 240 slot must
use `captured (run <id>)` / `captured (runs <id>, <id>)` / `pending (<...obligation...>)`.

**Grammar contract enforced by `_lib.mjs:254-294`** (read verbatim):

```js
export const SLOT_HEADING_RE = /^##\s+((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$/;
...
    s.statusRaw = st ? st[1].trim() : null;
    s.captured = Boolean(s.statusRaw && s.statusRaw.startsWith('captured'));
    s.pending = Boolean(s.statusRaw && s.statusRaw.startsWith('pending'));
    s.runIds = [...s.text.matchAll(/\b(\d{8,12})\b/g)].map((m) => m[1]);
    s.fenced = [...s.text.matchAll(/```[\s\S]*?```/g)].map((m) => m[0]);
```

Floors (`p12:29-35`, `:53-58`): `slots.length >= 4` and `captured.length >= 3`.

---

### `scripts/ci/ensure-github-pages-legacy-branch.sh` (modified; utility, REST client)

**Best in-file analog for the loud/branching posture is the script's own `:43-51`**, which already
inspects and exits with an explanatory echo rather than swallowing:

```bash
if [[ "$bt" == "workflow" ]]; then
  echo "ensure-github-pages-legacy-branch: build_type=workflow; not changing."
  exit 0
fi

if [[ "$branch" == "gh-pages" && "$path" == "/" ]]; then
  echo "ensure-github-pages-legacy-branch: already gh-pages /"
  gh api "repos/${REPO}/pages/builds" --method POST >/dev/null 2>&1 || true
  exit 0
fi
```

**The two sites to rewrite, verbatim as they stand today:**

Site 1 — `:18` (any-error → create, D-15):

```bash
if ! pages_json=$(gh api "repos/${REPO}/pages" 2>/dev/null); then
  echo "ensure-github-pages-legacy-branch: no Pages site yet; creating legacy gh-pages / ..."
```

Site 2 — `:66-73` (merged `2>&1` blob + unanchored `403` grep, D-17):

```bash
if ! put_out=$(gh api "repos/${REPO}/pages" --method PUT --input "${put_body}" 2>&1); then
  if echo "${put_out}" | grep -qE '403|Resource not accessible by integration'; then
    echo "ensure-github-pages-legacy-branch: Pages API PUT returned 403 (default GITHUB_TOKEN often cannot change Pages source). gh-pages push already ran; set repo Pages → branch gh-pages / manually if needed." >&2
    exit 0
  fi
  echo "${put_out}" >&2
  exit 1
fi
```

**The three `|| true` build-trigger swallows to LEAVE ALONE (D-22)** are at **`:30`, `:50`, `:75`**
— confirmed by reading the file; CONTEXT D-22's `:31`/`:52` citations are one line late. The
no-token early exit to keep is `:13-16`:

```bash
if [[ -z "${GH_TOKEN}" ]]; then
  echo "ensure-github-pages-legacy-branch: no GH_TOKEN/GITHUB_TOKEN; skip."
  exit 0
fi
```

**Sole caller** — `playwright-github-pages.yml:206-211` (read; a loud `exit 1` reddens only this
step, and this job is not in `ci-gate.needs`):

```yaml
      - name: Point GitHub Pages at gh-pages (REST API)
        # gh_pages_push is always present; outcome is skipped when not on main or no site.
        if: steps.gh_pages_push.outcome == 'success'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: bash "$GITHUB_WORKSPACE/scripts/ci/ensure-github-pages-legacy-branch.sh"
```

**No in-repo analog exists for a `gh api -i` status-line read.** `grep -rn 'gh api -i' scripts/`
returns nothing. Use RESEARCH §4's proposed `case` blocks as the source of truth rather than
searching for a precedent that does not exist.

---

### `.github/workflows/ci.yml` — one `fast_checks` step (modified; config)

**Analog:** `ci.yml:257-261` — the closest match, because it wires a hermetic `gh`-stubbing shell
self-test:

```yaml
      - name: Notify-failure-issue self-test
        # Phase 222 Plan 02 (HARD-01/HARD-02/D-07): hermetic proof that the shared
        # tracking-issue notifier is idempotent (create-once / comment-once) and
        # fail-closed on missing LABEL/TITLE/BODY. No real `gh` CLI or network call.
        run: bash scripts/ci/notify-failure-issue.test.sh
```

Siblings with the same three-line shape: `:240-243`, `:248-251`, `:252-256`, `:267-270`,
`:394-400`. 19 such steps exist. The prohibition-guard glob that picks up p20 with **zero**
workflow edits is `ci.yml:383-393`:

```yaml
      - name: Phase 230 prohibition guards
        # ... A bare directory arg is NOT valid here (node 22 resolves it as a module); the
        # shell glob is load-bearing.
        run: node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
```

**Do not touch `ci-gate.needs`** (`ci.yml:1547-1557`, exactly ten entries; the comment at
`:1543-1546` warns that `honest-skip-verdict.sh`'s extractor requires bare `      - id` lines with
no comments or blanks inside the list).

---

### `.planning/todos/*` (modified; docs)

**Frontmatter shape both files share** (`2026-07-30-...:1-22`):

```yaml
---
created: 2026-07-30T00:00:00.000Z
status: pending
title: "..."
area: admin-ui
files:

  - test/example/priv/playwright/tests/admin-generated.spec.ts
  - lib/sigra/admin/live/audit_live.ex

severity: medium
source: >-
  ...
owner: unassigned (repo maintainer to triage)
audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
resolves_phase: 236
---
```

D-26's sharp edge is verified: `files:` names `lib/sigra/admin/live/audit_live.ex`, which does not
exist, and the body (`:26`, `:65`) cites `admin-generated.spec.ts:454-458` plus an "Apply filters"
button. Closure prose must cite `lib/sigra/admin/live/audit_index_live.ex` and
`admin-generated.spec.ts:459`.

**Evidence-append pattern** — `2026-07-29-github-pages-...md` (tail, read) already models appending
a live observation with a fenced verbatim log excerpt and a terminal owner-action list:

```markdown
The step log identifies the operative cause precisely:

```text
ensure-github-pages-legacy-branch: updating Pages source -> gh-pages / (was: main /)
ensure-github-pages-legacy-branch: Pages API PUT returned 403 (default GITHUB_TOKEN often cannot change Pages source). ...
```

## Required owner action

1. In repository Settings → Pages → Build and deployment, select branch `gh-pages` and path `/`.
2. Confirm `gh api repos/szTheory/sigra/pages --jq '.source'` returns
   `{"branch":"gh-pages","path":"/"}`.
```

That file's frontmatter still reads `status: pending` at `:3` despite living under `completed/`
(verified) — D-25's "verify + append" should also flip that field.

**No analog for a standardized `## Resolution` section:** `grep -lE '^## (Resolution|Resolved|Closure)' .planning/todos/completed/*.md`
matches ~10 files, but the two sampled hits are phase-rollup todos whose headings are unrelated
sections, not a closure convention. There is **no repo-wide closure-section template** — the
honest pattern is "append a dated evidence section in the file's existing voice, then move".

---

## Shared Patterns

### Fail-closed shell posture (all new/modified `scripts/ci/` files)
**Source:** `capture-terminal-ratification-evidence.sh:4`, `:33-35`; `ensure-github-pages-legacy-branch.sh:9`
**Apply to:** `capture-green-04-evidence.sh`, `ensure-github-pages-legacy-branch.sh`

```bash
set -euo pipefail
fail() { echo "<script-name>: FAIL: $*" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH"
command -v jq >/dev/null 2>&1 || fail "jq not found on PATH"
```

Every failure exits with a **named token** (`total_count_disagreement`, `dirty_tree`,
`rate_limit_remaining_at_or_below_250`) so the sibling `.test.sh` can `grep -q` the reason rather
than only asserting non-zero.

### Fake-`gh`-on-PATH stub (both new `.test.sh` files)
**Source:** `capture-terminal-ratification-evidence.test.sh:13-18`, `:71`; `notify-failure-issue.test.sh:49-59`
**Apply to:** `ensure-github-pages-legacy-branch.test.sh`, `capture-green-04-evidence.test.sh`

```bash
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
... dispatch on "$*" and "${FAKE_MODE:-ok}" ...
EOF
chmod +x "$TMP/bin/gh"

FAKE_MODE=put_403 FAKE_GH_LOG="$TMP/calls" PATH="$TMP/bin:$PATH" bash "$SCRIPT" >"$TMP/out" 2>"$TMP/err"
```

`PATH` is prepended **per invocation**, never exported globally. The call log is what makes
negative assertions ("the create POST was never issued") possible.

### Offline prohibition guard (p20)
**Source:** `p12-run-id-provenance.test.mjs:9-20`, `p19-tag-namespace-ruleset.test.mjs:14-21`, `p15:99-139`
**Apply to:** `p20-green-04-evidence-step-parity.test.mjs`

Guards import only `node:test` + `node:assert/strict` + `./_lib.mjs`. No YAML dependency, no
`gh`, no token, no network. Every guard carries: (1) a non-vacuity floor test that fails when the
parse yields nothing, (2) the behavior test, (3) a negative control against a committed known-bad
fixture. The literal message idiom for a broken parse is
`'the parse broke, this is not a pass'` (`p15:66`, `:110`).

### Comment stripping before any content assertion
**Source:** `_lib.mjs:115-146`; motivation restated in `p15:23-27`
**Apply to:** `p20-...test.mjs` (both the subject and the `ci.yml` reference read)

```js
const ci = stripYamlComments(readSubject(SUBJECT));
```

`ci.yml:1401-1533` is ~40% comments; a raw-text step-name match would misattribute prose
(e.g. `:1460-1464` names `--test all` inside a comment) to the wrong step.

### `GSD_PROHIB_SUBJECT` fail-first injection
**Source:** `_lib.mjs:33-38`, `:70-78`
**Apply to:** p20 (RED demonstration) and the p12 run against `240-EVIDENCE.md`

```bash
GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p20-green-04-step-drift.yml \
  node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs
GSD_PROHIB_SUBJECT=.planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md \
  node --test --test-reporter=tap scripts/ci/prohibitions/p12-run-id-provenance.test.mjs
```

A missing subject **throws** rather than passing (`_lib.mjs:72-76`: "a missing subject is a broken
run, never an absent violation").

### Pinned action SHAs (new workflow)
**Source:** `ci.yml:1432`, `:1433`, `:1437`, `:1498`
**Apply to:** `green-04-evidence.yml`

Copy the exact pins, never a tag: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`,
`erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124`,
`actions/setup-node@820762786026740c76f36085b0efc47a31fe5020`,
`actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`. The two existing dispatch
evidence workflows use the identical checkout/setup-beam/upload-artifact SHAs
(`fast-01-remeasurement-evidence.yml:20`, `:38`; `generated-app-login-runtime-proof.yml:24`, `:25`, `:91`).

---

## No Analog Found

| File / concern | Role | Data Flow | Reason |
|---|---|---|---|
| `gh api -i` status-line read (inside `ensure-github-pages-legacy-branch.sh`) | utility | request-response | `grep -rn 'gh api -i' scripts/` returns nothing — no script in the repo reads an HTTP status line. Use RESEARCH §4's `case` blocks (derived from live `gh` 2.95.0 probes) as the source of truth. |
| A stub that emits a full HTTP response envelope (status line + headers + body + stderr + rc) | test | request-response | Both existing fake-`gh` stubs emit bare JSON on stdout only. The four-channel payload is specified verbatim in RESEARCH §5 and has no in-repo precedent. |
| `strategy.matrix.repeat` for N-fold repetition | config | batch | The only matrix in `ci.yml` is the shard matrix (`:559-565`), used for partitioning, not repetition — and its comment documents the job-name-suffix hazard that D-06 cites. No repeat-matrix precedent exists. |
| Collector clean-tree / HEAD-equality assertion (D-13) | service | transform | No `capture-*.sh` asserts against the working tree. Nearest stylistic precedent is `capture-fast-01-remeasurement.sh:25-29`'s git-side constant assertions. |
| Standardized todo `## Resolution` closure section | doc | n/a | No repo-wide convention; completed todos append evidence in their own voice (see `2026-07-29-github-pages-...md` tail). |
| A `capture-*.test.sh` wired into CI | config | n/a | Verified: neither `capture-fast-01-remeasurement.test.sh` nor `capture-terminal-ratification-evidence.test.sh` is invoked by any workflow or by `mix ci`. If `capture-green-04-evidence.test.sh` ships unwired, that follows precedent — but say so explicitly (RESEARCH §5). |

---

## Metadata

**Analog search scope:** `.github/workflows/`, `scripts/ci/`, `scripts/ci/prohibitions/`,
`test/fixtures/prohibitions/`, `.planning/todos/{pending,completed}/`,
`.planning/phases/236-*/`

**Files read this session (in full unless a range is given):**
`.github/workflows/fast-01-remeasurement-evidence.yml`,
`.github/workflows/generated-app-login-runtime-proof.yml`,
`.github/workflows/ci.yml` (`240-275`, `380-402`, `1401-1533`, `1534-1565`),
`.github/workflows/playwright-github-pages.yml` (`190-211`),
`scripts/ci/capture-terminal-ratification-evidence.sh`,
`scripts/ci/capture-terminal-ratification-evidence.test.sh`,
`scripts/ci/capture-fast-01-remeasurement.sh` (`1-92`),
`scripts/ci/capture-fast-01-remeasurement.test.sh` (`1-99`),
`scripts/ci/ensure-github-pages-legacy-branch.sh`,
`scripts/ci/notify-failure-issue.test.sh` (`1-70`),
`scripts/ci/prohibitions/_lib.mjs` (`25-200`, `250-300`),
`scripts/ci/prohibitions/p12-run-id-provenance.test.mjs`,
`scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs`,
`scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` (`1-70`),
`test/fixtures/prohibitions/p06-fast-checks-docs-gated.yml`,
`test/fixtures/prohibitions/p04-concurrency-groups-main-pushes.yml` (`1-30`),
`.planning/phases/236-*/236-EVIDENCE.md` (`1-90` + the `AFTER-P17-GUARD-OBSERVED` slot),
both owning todos.

**Pattern extraction date:** 2026-09-18
