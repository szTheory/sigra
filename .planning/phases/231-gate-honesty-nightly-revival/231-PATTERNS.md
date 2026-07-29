# Phase 231: Gate Honesty + Nightly Revival — Pattern Map

**Mapped:** 2026-07-29
**Files analyzed:** 13 (4 new, 9 modified)
**Analogs found:** 13 / 13

> **Relationship to RESEARCH.md.** RESEARCH.md § "House Patterns The Plan Must Replicate"
> (`:402-598`) already quotes the guard header shape, the manifest `awk` idiom, the `grep -c` caveat,
> both `gh`-stub heredocs, and the `nightly_probe` probe-input pattern. **This file does not repeat
> those.** It closes the gaps RESEARCH left: the *full* shipped verdict script (arg parse → verdict
> loop → dual-format output → exit code), the *full* shipped self-test skeleton (case table,
> `run_*_rc` helper pair, results footer), and the exact YAML blocks each modified file must be
> edited into.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|
| **NEW** `scripts/ci/honest-skip-verdict.sh` | CI guard script | file-I/O → transform → verdict | `scripts/ci/ci-demotion-observer.sh` | exact |
| **NEW** `scripts/ci/honest-skip-verdict.test.sh` | hermetic self-test | fixture-I/O → assert | `scripts/ci/ci-demotion-observer.test.sh` | exact |
| **NEW** `scripts/ci/wait-for-ci-gate.sh` | CI poll script | request-response (poll) | `release-please.yml:111-169` (loop to extract) + `scripts/ci/ci-run-metrics.sh` (`gh` shape) | role-match |
| **NEW** `scripts/ci/wait-for-ci-gate.test.sh` | hermetic self-test | `gh`-stub → assert | `scripts/ci/ci-demotion-observer.test.sh` (recording stub) | exact |
| `scripts/ci/prohibitions/p05-…test.mjs` | prohibition test | static-analysis assert | itself (invert in place) | self |
| `scripts/ci/prohibitions/p10-…test.mjs` | prohibition test | TSV+YAML parity assert | itself (extend in place) | self |
| `scripts/ci/notify-failure-issue.sh` | CI action script | request-response (`gh`) | itself | self |
| `scripts/ci/notify-failure-issue.test.sh` | hermetic self-test | `gh`-stub → assert | itself + `ci-demotion-observer.test.sh` env-scripted stub | exact |
| `.github/workflows/ci.yml` `fast_checks` | workflow wiring | config | `ci.yml:335-343` (Demotion observer self-test step) | exact |
| `.github/workflows/ci.yml` `ci-gate` | workflow job | config + shell verdict | `ci.yml:1805-1840` (existing step) | self |
| `.github/workflows/ci.yml` `admin_eval_render` / `generated_admin_playwright_smoke` | workflow job | config | `ci.yml:2506-2519`, `:1671-1675` | self |
| `.github/workflows/playwright-github-pages.yml` | workflow job | config | `ci.yml:2498-2519` (non-`docs_only` seeds block) | exact |
| `.github/workflows/release-please.yml` `gate-ci-green` | workflow job | config | `ci.yml:2543-2551` (script-invoking step) | role-match |
| `.github/workflows/ci-observe.yml:130-136` | workflow shell | config | n/a — pure deletion | n/a |
| `.github/ci-skip-manifest.tsv`, `MAINTAINING.md` | data / docs | — | rows/lines quoted below | self |

---

## Pattern Assignments — NEW FILES

### `scripts/ci/honest-skip-verdict.sh` (CI guard, TSV → verdict)

**Analog:** `scripts/ci/ci-demotion-observer.sh` (235 lines — read it whole; it is the same program
with a different predicate). RESEARCH quotes its header + arg-parse + manifest `awk`. The four
structures RESEARCH did **not** quote, all of which must be copied:

**1. Verdict loop shape** (`ci-demotion-observer.sh:141-191`) — `while IFS=$'\t' read` over the awk
output, one `VERDICT`/`REASON` pair per row, accumulated into a `jq` array, `EXIT_CODE` latched:

```bash
VERDICTS="[]"
EXIT_CODE=0

while IFS=$'\t' read -r kind id parent_id display_name; do
  [[ -n "$kind" ]] || continue
  ...
    if [[ "$STATUS" != "completed" ]]; then
      VERDICT="FAIL"; REASON="status is '${STATUS:-<empty>}', not 'completed' -- ..."
    elif [[ -z "$CONCL" ]]; then
      VERDICT="FAIL"; REASON="empty conclusion -- never treat an absent conclusion as 'not skipped'"
    elif [[ "$CONCL" == "skipped" ]]; then
      VERDICT="FAIL"; REASON="skipped on a non-pull_request run -- the demotion rotted; ..."
    ...
    else
      VERDICT="PASS"; REASON="executed (${CONCL})"
    fi
  fi

  [[ "$VERDICT" == "PASS" ]] || EXIT_CODE=1

  VERDICTS="$(echo "$VERDICTS" | jq \
    --arg id "$id" --arg kind "$kind" --arg loc "$LOCATION" --arg name "$display_name" \
    --arg status "$STATUS" --arg concl "$CONCL" --argjson dur "${DUR:-0}" \
    --arg verdict "$VERDICT" --arg reason "$REASON" \
    '. + [{id: $id, kind: $kind, location: $loc, display_name: $name, status: $status,
           conclusion: $concl, duration_seconds: $dur, verdict: $verdict, reason: $reason}]')"
done <<< "$ASSERT_ROWS"
```

**2. Payload acquisition — `--from-json` OR one `gh` round-trip, plus a shape assertion**
(`:106-120`). The shape assertion is load-bearing: it is what makes test R (feeding the script's
own output back in) fail closed rather than render an empty receipt.

```bash
if [[ -n "$FROM_JSON" ]]; then
  [[ -f "$FROM_JSON" ]] || fail "--from-json payload not found at ${FROM_JSON}"
  RUN_JSON="$(cat "$FROM_JSON")"
else
  [[ -n "$RUN_ID" ]] || fail "no run id: pass --run <id> or set GITHUB_RUN_ID"
  command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH"
  RUN_JSON="$(gh run view "$RUN_ID" --repo "$REPO" --json jobs,event,createdAt,updatedAt,databaseId)" \
    || fail "gh run view failed for run ${RUN_ID}"
fi

echo "$RUN_JSON" | jq -e 'type == "object" and has("jobs")' >/dev/null 2>&1 \
  || fail "run payload is not an object carrying a .jobs array"

JOB_COUNT="$(echo "$RUN_JSON" | jq '.jobs | length')"
[[ "$JOB_COUNT" -gt 0 ]] || fail "run payload has an empty job list -- fail-closed, never 'nothing to check so pass'"
```

**3. Dual-format tail** (`:206-235`) — `json` for machine consumption, `table` for the job log, and
the FAIL reasons re-printed after the table so the ci-gate log names the lane (SC-3 requires the
rot-probe verdict to **name the lane**):

```bash
case "$FORMAT" in
  json)
    jq -n --arg run "$RUN_DBID" --arg event "$RUN_EVENT" --argjson wall "${WALL:-0}" \
      --argjson constructs "$VERDICTS" ... \
      '{run_id: $run, event: $event, ..., verdict: (if $exit_code == 0 then "PASS" else "FAIL" end)}'
    ;;
  table)
    printf 'Demotion receipt -- run %s (event: %s, wall-clock %dm%02ds)\n\n' ...
    {
      printf 'construct\tlocation\tconclusion\tduration\tverdict\n'
      echo "$VERDICTS" | jq -r '.[] | "\(.id)\t\(.location)\t\(.conclusion // "-")\t\(.duration_seconds)s\t\(.verdict)"'
    } | column -t -s $'\t'
    echo
    echo "$VERDICTS" | jq -r '.[] | select(.verdict == "FAIL") | "  FAIL \(.id): \(.reason)"'
    if [[ "$EXIT_CODE" -eq 0 ]]; then
      echo "  every demoted construct executed on this lane."
    fi
    ;;
esac

exit "$EXIT_CODE"
```

**4. Cross-row resolution helper** (`:92-101`) — the pattern for looking a value up in a *second*
manifest row and hard-failing when it is unresolvable. GATE-03 needs the same shape to resolve
each `ci-gate.needs` lane id → its `display_name` / `gate` column:

```bash
parent_display_name() {
  local parent_id="$1" out
  out="$(awk -F'\t' -v pid="$parent_id" '
    /^#/ { next }
    $1 == "tier" { next }
    $2 == "job" && $3 == pid { print $5; exit }
  ' "$MANIFEST")"
  [[ -n "$out" ]] || fail "manifest has a step row whose parent_job_id '${parent_id}' has no matching kind=job row -- cannot resolve the parent job's display name"
  printf '%s' "$out"
}
```

**What must DIFFER from the analog:**

| Analog behavior | GATE-03 behavior |
|---|---|
| filters `$8 == "assert"` (tier B only) | must filter on the **nine `ci-gate.needs` ids** (`ci.yml:1793-1802`) — a fixed list in the script, cross-checked against the manifest so a `needs:` edit that skips a lane cannot slip past |
| `skipped` is always FAIL | `skipped` is **PASS only if** the row's legitimacy holds for the event: D-03 → on `pull_request`, `{upgrade_smoke (any), library_tests_dep_off (docs-only only)}`; on any non-PR event, **no** skip is legitimate |
| non-vacuity floor `>= 2` (the two tier-B rows) | floor `>= 9` (the `ci-gate.needs` set), same literal message `-- the parse broke, this is not a pass` |
| needs a run payload from `gh` | reads `needs.*.result` values from the **environment**, exactly like the existing ci-gate step's `env:` block (`ci.yml:1806-1815`) — no `gh` round-trip at all, so `--from-json` becomes "read lane results from a file/env" and the self-test is trivially hermetic |
| no probe input | `--force-rot-probe` (or an env flag) injects a synthetic rotted-skip row so SC-3's fail direction is reproducible forever (RESEARCH `:594`) |

**Also copy verbatim:** the `fail()` helper (`:63-66`), the `--format` validation (`:68-70`), the
`[[ -f "$MANIFEST" ]] || fail` existence check (`:72`), and the `exit 2` on unknown arg (`:59`).

---

### `scripts/ci/honest-skip-verdict.test.sh` (hermetic self-test)

**Analog:** `scripts/ci/ci-demotion-observer.test.sh` (397 lines, 19 cases A–S). RESEARCH quotes only
the stub + `gh_call_count`. Copy these four un-quoted structures:

**1. Preamble: locate script + real manifest, hard-fail at exit 2 if either is missing** (`:49-60`):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/ci-demotion-observer.sh"
REAL_MANIFEST="$(cd "${SCRIPT_DIR}/../.." && pwd)/.github/ci-skip-manifest.tsv"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi
if [[ ! -f "$REAL_MANIFEST" ]]; then
  echo "FATAL: manifest not found at ${REAL_MANIFEST}" >&2
  exit 2
fi
```

**2. Counter + `trap cleanup EXIT` on a `mktemp -d`** (`:62-79`):

```bash
PASS=0
FAIL=0
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then rm -rf "$TMPDIR_ROOT"; fi
}
trap cleanup EXIT

TMPDIR_ROOT="$(mktemp -d)"
```

**3. The paired invoker — output-capturing AND rc-capturing** (`:124-139`). Two functions, because
the output helper swallows the status with `|| true` and would otherwise hide every rc:

```bash
run_observer() {
  local payload="$1"; shift
  printf '%s' "$payload" > "$PAYLOAD_FILE"
  : > "$GH_STUB_LOG"
  PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --manifest "$REAL_MANIFEST" "$@" 2>&1 || true
}
run_observer_rc() {
  local payload="$1"; shift
  printf '%s' "$payload" > "$PAYLOAD_FILE"
  : > "$GH_STUB_LOG"
  set +e
  PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --manifest "$REAL_MANIFEST" "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  echo "$rc"
}
```

**4. The both-directions case body + the two fixture-manifest idioms.** Every case is
`mutate fixture → assert rc AND assert the reason text`, never rc alone:

```bash
# ---- C: admin_eval_render skipped -> exit 1 ---------------------------------
echo "Test C: admin_eval_render skipped -> exit 1"
P_C="$(jq --arg n "$EVAL_NAME" '(.jobs[] | select(.name == $n)) |= (.conclusion = "skipped" | .completedAt = .startedAt)' <<<"$BASE_PAYLOAD")"
RC_C="$(run_observer_rc "$P_C")"; OUT_C="$(run_observer "$P_C")"
if [[ "$RC_C" -eq 1 ]] && grep -q "FAIL admin_eval_render" <<<"$OUT_C" && grep -q "rotted" <<<"$OUT_C"; then
  pass "C: exit 1 and the reason names the rotted demotion"
else
  fail "C: rc=${RC_C}, output: ${OUT_C}"
fi
```

Fixture manifest written into the temp dir with `printf '...\t...\n'` (`:308-313`) — GATE-03's
non-vacuity case (`O`) and orphan case (`P`) both use this:

```bash
EMPTY_MANIFEST="${TMPDIR_ROOT}/empty-manifest.tsv"
{
  printf '# a manifest whose assert rows have all been removed\n'
  printf 'tier\tkind\tid\tparent_job_id\tdisplay_name\tgate_level\tgate\tobserver\n'
  printf 'A\tjob\tinstall_matrix\t-\tInstall matrix (flag combinations)\tjob\tx\tignore\n'
} > "$EMPTY_MANIFEST"
```

**The positive control (case Q, `:344-353`) is mandatory** — it proves the earlier cases ran against
a realistic set, not an empty one. GATE-03's equivalent: the shipped manifest yields all nine
`ci-gate.needs` ids.

```bash
SHIPPED_ASSERTS="$(awk -F'\t' '/^#/{next} $1=="tier"{next} $8=="assert"{print $3}' "$REAL_MANIFEST")"
if grep -qx "admin_eval_render" <<<"$SHIPPED_ASSERTS" \
   && grep -qx "design_gallery_snapshots" <<<"$SHIPPED_ASSERTS" \
   && [[ "$(grep -c . <<<"$SHIPPED_ASSERTS")" -eq 2 ]]; then
```

**Static workflow-parity case (S, `:376-390`)** — the shape for asserting the *shipped workflow*
wires the script correctly, with its own non-vacuity branch. GATE-03 needs the analog: `ci.yml`'s
ci-gate job actually invokes `honest-skip-verdict.sh`.

```bash
OBSERVE_WF="$(cd "${SCRIPT_DIR}/../.." && pwd)/.github/workflows/ci-observe.yml"
FROM_JSON_ARGS="$(grep -oE '\-\-from-json[[:space:]]+[^[:space:]]+' "$OBSERVE_WF" | awk '{print $2}')"
if [[ -z "$FROM_JSON_ARGS" ]]; then
  fail "S: no --from-json invocation found in ${OBSERVE_WF} -- the parse broke, this is not a pass"
elif grep -q 'demotion-observation.json' <<<"$FROM_JSON_ARGS"; then
  fail "S: ci-observe.yml feeds the observer's own output back into --from-json: ${FROM_JSON_ARGS}"
else
  pass "S: every --from-json argument is a run payload ($(tr '\n' ' ' <<<"$FROM_JSON_ARGS"))"
fi
```

**Footer** (`:392-397`) — copy exactly; `fast_checks` reads the exit code, humans read the line:

```bash
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "ci-demotion-observer.test: FAIL"
  exit 1
fi
echo "ci-demotion-observer.test: PASS"
```

---

### `scripts/ci/wait-for-ci-gate.sh` (poll loop, extracted)

**Analog A — the loop to extract, verbatim** from `release-please.yml:111-169`. This is the *only*
poll loop in the repo; it moves into the script essentially unchanged:

```bash
          set -euo pipefail

          sha="${RELEASE_SHA}"
          if [ -z "$sha" ]; then
            sha="$(gh api "repos/${REPOSITORY}/commits/${TAG_NAME}" --jq '.sha')"
          fi

          max_attempts=60          # <-- D-20: becomes 120
          wait_seconds=30
          last_run_url=""
          ci_dispatched=false

          for attempt in $(seq 1 "$max_attempts"); do
            runs_json="$(gh run list \
              --repo "$REPOSITORY" \
              --workflow ci.yml \
              --commit "$sha" \
              --limit 20 \
              --json databaseId,status,conclusion,url,createdAt)"

            run_count="$(jq 'length' <<<"$runs_json")"
            if [ "$run_count" -eq 0 ]; then
              echo "No ci.yml run yet for ${sha} (${attempt}/${max_attempts})."
              if [ "$attempt" -eq 3 ] && [ "$ci_dispatched" = false ]; then
                gh workflow run ci.yml --ref "$TAG_NAME" --repo "$REPOSITORY"
                ci_dispatched=true
                echo "Dispatched ci.yml on tag ${TAG_NAME} for release SHA ${sha}."
              fi
              sleep "$wait_seconds"
              continue
            fi

            last_run_url="$(jq -r 'sort_by(.createdAt) | reverse | .[0].url' <<<"$runs_json")"
            incomplete="$(jq -r '[.[] | select(.status != "completed")] | length' <<<"$runs_json")"
            if [ "$incomplete" -gt 0 ]; then
              echo "ci.yml still running for ${sha} (${attempt}/${max_attempts}): ${last_run_url}"
              sleep "$wait_seconds"
              continue
            fi

            for run_id in $(jq -r 'sort_by(.createdAt) | reverse | .[].databaseId' <<<"$runs_json"); do
              ci_gate="$(gh run view "$run_id" \
                --repo "$REPOSITORY" \
                --json jobs \
                --jq '.jobs[] | select(.name == "ci-gate") | .conclusion' 2>/dev/null || true)"
              if [ "$ci_gate" = "success" ]; then
                run_url="$(gh run view "$run_id" --repo "$REPOSITORY" --json url --jq '.url')"
                echo "ci-gate succeeded on release SHA ${sha}: ${run_url}"
                exit 0
              fi
            done

            echo "No successful ci-gate yet for ${sha} (${attempt}/${max_attempts}); waiting for a fresh run."
            sleep "$wait_seconds"
          done

          echo "Timed out waiting for ci-gate on SHA ${sha}. Last run: ${last_run_url:-none}"
          exit 1
```

**Analog B — the bare-`gh`-via-PATH convention**, `scripts/ci/ci-run-metrics.sh:44-45, 70, 87-88, 95, 130`:

```bash
# Security: never echoes GH_TOKEN or any secret. Reads only public `gh run list` /
# `gh run view` run metadata. `gh` is invoked bare (resolved via PATH) so the self-test can …
    *) echo "ci-run-metrics: FAIL: unknown arg: $1" >&2; exit 2;;
if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI not found on PATH"
JOBS_JSON="$(gh run view "$RUN_ID" --repo "$REPO" --json jobs --jq '.jobs')" || fail "gh run view failed for run ${RUN_ID}"
RUNS_JSON="$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit "$LIMIT" --json databaseId,event,createdAt,updatedAt,conclusion)" || fail "gh run list failed"
```

**What must DIFFER:** `sh`-isms (`[ ]`, `$(seq …)`) become the house `[[ ]]`; the inlined
`${REPOSITORY}` / `${TAG_NAME}` / `${RELEASE_SHA}` env reads become `--repo` / `--tag` / `--sha`
flags with env fallbacks; add `--max-attempts` (default **120**, D-20) and `--wait-seconds`
(default 30) so the self-test can drive the loop to exhaustion in ~0s; add `--workflow` (default
`ci.yml`). Keep `exit 2` on unknown arg. **D-21's live invocation** requires the script to accept a
plain push-to-`main` SHA with no tag, so the `gh api …/commits/${TAG_NAME}` fallback must be
skipped when `--sha` is given.

---

### `scripts/ci/wait-for-ci-gate.test.sh` (hermetic self-test, shadows `gh`)

**Analog:** `scripts/ci/ci-demotion-observer.test.sh:110-147` — the **unquoted** heredoc form, which
is the one to copy here because this stub must dispatch on argv *and* vary its response per attempt
(`run list` vs `run view`):

```bash
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"; mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
PAYLOAD_FILE="${TMPDIR_ROOT}/payload.json"
: > "$GH_STUB_LOG"

cat >"${STUB_BIN_DIR}/gh" <<STUB
#!/usr/bin/env bash
# Recording stub for \`gh\` (test-only). Logs argv, returns the scripted payload.
set -euo pipefail
echo "\$*" >> "${GH_STUB_LOG}"
if [[ -n "\${GH_STUB_FAIL:-}" ]]; then
  echo "gh: simulated failure" >&2
  exit 1
fi
cat "${PAYLOAD_FILE}"
STUB
chmod +x "${STUB_BIN_DIR}/gh"
```

…combined with `notify-failure-issue.test.sh:50-58`'s **argv dispatch** (quoted-heredoc form) so
`run list` and `run view` return different fixtures:

```bash
if [[ "${1:-}" == "issue" && "${2:-}" == "list" ]]; then
  echo "${GH_STUB_ISSUE_NUMBER:-}"
  exit 0
fi
```

Invocation is always `PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" …` (`ci-demotion-observer.test.sh:128`)
and call counting always via the `|| true` idiom (`:143-147`, and the SC2 comment above it).

**Required cases:** no run yet → dispatch fires on attempt 3, exactly once; run incomplete → keeps
polling; `ci-gate` success → exit 0 with the run URL echoed; `ci-gate` failure on all runs →
exhausts attempts, exit 1, `Timed out waiting for ci-gate` in output; `--max-attempts 2
--wait-seconds 0` completes instantly (proves the flags are wired, and keeps `fast_checks` fast);
unknown flag → exit 2, **zero** `gh` calls.

---

## Pattern Assignments — MODIFIED FILES

### `scripts/ci/prohibitions/p05-admin-eval-red-not-abandoned.test.mjs` — INVERT

The block to invert is `:46-55`. Today it asserts `continue-on-error: true` is **present**:

```javascript
test('the unread red is retained and visible, not masked away', () => {
  assert.match(
    block,
    /^ {4}continue-on-error:\s*true\s*$/m,
    '`continue-on-error: true` was removed from admin_eval_render. Phase 230 retains it ' +
      'DELIBERATELY (D-11): …  Removing it is Phase 231 GATE-04\'s job, together with the fix.',
  );
});
```

**Change:** `assert.match` → `assert.doesNotMatch` on the **job-level** regex `/^ {4}continue-on-error/m`
(4-space indent = job level). **Do not** broaden it — D-13 keeps the **step**-level
`continue-on-error: true` at `ci.yml:2548`, which sits at 8-space indent and must survive. Add a
companion positive assertion that the step-level flag is still present, otherwise a future edit
deleting it (and losing the artifact upload) goes unnoticed.

Its file header (`:10-14`) explicitly authorizes this inversion and must be rewritten in the same
commit. The `:57-77` GATE-04-still-open test also inverts: once GATE-04 is Complete, the
`!/\bComplete\b/.test(row)` assertion reds — the header (`:73-75`) says so and says to retire it
"deliberately, in Phase 231, not silently."

The two tests to leave alone: `:27-34` (lane still exists) and `:36-44` (still non-PR demoted).

### `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` — extend

Tier-A floor to change (`:34-41`):

```javascript
test('the manifest parses to a populated, tiered enumeration', () => {
  assert.ok(rows.length >= 12, `manifest parsed ${rows.length} rows; expected at least 12.`);
  const counts = { A: 0, B: 0, C: 0 };
  for (const r of rows) counts[r.tier] = (counts[r.tier] ?? 0) + 1;
  assert.ok(counts.A >= 9, `tier A has ${counts.A} rows, expected >= 9 — the parse broke.`);
```

D-06 deletes `generated_admin_playwright_smoke`'s `if:` → its tier-A row disappears → `counts.A`
drops to 8 → **`>= 9` reds**. Lower to `>= 8` and `rows.length >= 11` in the same commit.

New `gate`-column assertion — model it on the shipped `display_name` test (`:72-84`), which is the
only existing test that compares a manifest *cell* against `ci.yml` text:

```javascript
test('display_name matches the construct name ci.yml actually declares', () => {
  for (const r of rows) {
    const needle = r.kind === 'job'
      ? new RegExp(`^ {4}name: ${r.displayName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`, 'm')
      : new RegExp(`name: ${r.displayName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`, 'm');
    assert.ok(needle.test(ci), `manifest row \`${r.id}\` records display_name "${r.displayName}", which ci.yml does not declare. …`);
  }
});
```

The `gate` version compares `normalizeExpr(r.gate)` against the `normalizeExpr`'d `if:` extracted
from the job block — reuse the extractor already in this file at `:90`:

```javascript
const ifs = [...block.matchAll(/^ {4}if:[ \t]*(.+)$/gm)].map((m) => normalizeExpr(m[1]));
```

Note the existing anti-vacuity doctrine in the header (`:16-21`): both `if:` syntaxes must be
normalized, and every new assertion needs a floor so an extractor matching nothing fails loudly.
The negative control (`:102-110`) is the falsifiability pattern to imitate for any new assertion.

### `scripts/ci/notify-failure-issue.sh` — label self-heal (D-22)

The whole file is 34 lines; the block to edit is `:26-33`:

```bash
existing="$(gh issue list --label "$LABEL" --state open --json number --jq '.[0].number' || true)"

if [[ -n "$existing" ]]; then
  echo "notify-failure-issue: found open issue #${existing} for label '${LABEL}'; appending occurrence comment"
  gh issue comment "$existing" --body "$BODY"
else
  echo "notify-failure-issue: no open issue for label '${LABEL}'; creating"
  gh issue create --label "$LABEL" --title "$TITLE" --body "$BODY"
fi
```

The `gh label list` / `gh label create` self-heal goes **inside the `else` branch only** — case F in
RESEARCH `:549` requires the comment path to make **zero** label calls. Soft-fail the create
(`|| echo "…"`) so a permission-denied label create still lets the issue open (case G).

### `scripts/ci/notify-failure-issue.test.sh` — stub extension (⚠ same commit)

Quoted-heredoc stub at `:45-60`, whose **fallthrough is `exit 1`**:

```bash
cat >"${STUB_BIN_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${GH_STUB_LOG}"
if [[ "${1:-}" == "issue" && "${2:-}" == "list" ]]; then
  echo "${GH_STUB_ISSUE_NUMBER:-}"
  exit 0
fi
if [[ "${1:-}" == "issue" && ( "${2:-}" == "create" || "${2:-}" == "comment" ) ]]; then
  exit 0
fi
echo "gh stub: unexpected invocation: $*" >&2
exit 1
STUB
```

Add `label` branches before the fallthrough or **A/B/C all break**. New cases follow A/B/C's exact
shape (`:62-82`) — `: > "$GH_STUB_LOG"`, `set +e` around the invocation, then `grep -c '^…' || true`:

```bash
: > "$GH_STUB_LOG"
set +e
PATH="${STUB_BIN_DIR}:${PATH}" \
  GH_STUB_LOG="$GH_STUB_LOG" \
  GH_STUB_ISSUE_NUMBER="" \
  LABEL="release-lane-rot" TITLE="Red main" BODY="run url" GH_TOKEN="stub-token" \
  bash "$SCRIPT" >/dev/null 2>&1
EXIT_A=$?
set -e

CREATE_COUNT_A=$(grep -c '^issue create' "$GH_STUB_LOG" || true)
COMMENT_COUNT_A=$(grep -c '^issue comment' "$GH_STUB_LOG" || true)
```

New counters: `grep -c '^label create'`, `grep -c '^label list'`. Update the case docstring at
`:8-13` — it enumerates A/B/C and is the file's own index.

### `.github/workflows/ci.yml` `fast_checks` — new self-test step

Insert after `ci.yml:335-343`, which is the closest analog (a hermetic `gh`-stubbed self-test with
a comment stating what it does **and does not** cover):

```yaml
      - name: Demotion observer self-test
        # Phase 230 closeout: the observer behind .github/workflows/ci-observe.yml's
        # demotion receipt -- the standing, permanent form of the AFTER-PUSH evidence
        # item. Its load-bearing case is the fail-OPEN hole: an unfinished construct
        # serializes `completedAt: "0001-01-01T00:00:00Z"` and `conclusion: ""`, which a
        # duration check clamps to 0s (indistinguishable from a skip) and a
        # `conclusion != 'skipped'` check waves through. Hermetic: a PATH-shadowed
        # recording `gh`, no network, no GH_TOKEN.
        run: bash scripts/ci/ci-demotion-observer.test.sh
```

And the guard-plus-self-test two-step, when both belong in `fast_checks` (`:332-334`):

```yaml
        run: bash scripts/ci/playwright-cache-key-guard.sh
      - name: Playwright cache key guard self-test
        run: bash scripts/ci/playwright-cache-key-guard.test.sh
```

For GATE-03 only the `.test.sh` goes here (D-02); the guard itself runs in `ci-gate`.
`wait-for-ci-gate.test.sh` also goes here as a self-test-only step.

### `.github/workflows/ci.yml` `ci-gate` — GATE-03 enforcement site

The existing step to edit into (`ci.yml:1805-1840`). Note the `env:`-mapped `needs.*.result` block —
the verdict script's inputs come from here, not from `gh`:

```yaml
    steps:
      - name: Verify required release CI lanes
        env:
          INSTALL_GOLDEN_CONTRACT: ${{ needs.install_golden_contract.result }}
          …
          FAST_CHECKS: ${{ needs.fast_checks.result }}
        run: |
          set -euo pipefail
          failed=0
          for lane in \
            INSTALL_GOLDEN_CONTRACT \
            … \
            FAST_CHECKS
          do
            result="${!lane}"
            if [[ "$result" != "success" && "$result" != "skipped" ]]; then
              echo "Required release lane $lane: $result"
              failed=1
            fi
          done
```

`"$result" != "skipped"` at `:1831` is the defect. **Constraint RESEARCH flags (`:606-608`):
`changes` is NOT in `ci-gate.needs`**, so `needs.changes.outputs.docs_only` is empty here — either
add `changes` to `needs:` or pass `docs_only` through another route before the docs-only legitimacy
rule can be evaluated. Add a second step (Claude's Discretion, D) invoking the verdict script with
the same `env:` mapping plus `GITHUB_EVENT_NAME`.

### `.github/workflows/ci.yml` `generated_admin_playwright_smoke` — D-06 deletion

Delete `:1672-1674` (comment **and** clause); keep `:1671` and `:1675`:

```yaml
    timeout-minutes: 15
    # GATE-02 / D-08: temporary integration-scoped relaxation — runs on PR #63's head branch
    # (ship/v1.42-ci-gate-remediation) to prove generated-host parity in CI; remove after merge.
    if: github.event_name != 'pull_request' || github.head_ref == 'ship/v1.42-ci-gate-remediation'
    needs: release_ref_guard
```

Three same-commit companion edits (D-10):
- `.github/ci-skip-manifest.tsv:65` — delete the row (it records the stale gate string verbatim):
  `A	job	generated_admin_playwright_smoke	-	Generated admin Playwright smoke	job	github.event_name != 'pull_request' || github.head_ref == 'ship/v1.42-ci-gate-remediation'	ignore`
- `MAINTAINING.md:137` — remove from the nightly-only cadence list:
  `- \`generated_admin_playwright_smoke\` (generated-host admin behavior; see its \`timeout-minutes:\` for the current ceiling)`
- `MAINTAINING.md:270-276` — retire residual **2** (`:274`), leaving residual 1 (`upgrade_smoke`) and rewriting the "Two coverage areas" lead-in at `:270`.

### `.github/workflows/ci.yml` `admin_eval_render` — D-11 sites

Job-level flag to delete (`:2446-2450`) — the comment block goes with it:

```yaml
    # Advisory evidence lane — deliberately NOT in ci-gate.needs. continue-on-error
    # so a harness failure (or its own dev-boot flake) can never redden the
    # default-branch run; evidence bundles still upload as artifacts. The real
    # merge signal is ci-gate + the committed-ledger guards in fast_checks.
    continue-on-error: true
```

Browser install to widen (`:2517-2519`) — the step **name** asserts the bug and must change too:

```yaml
      - name: Install Playwright browsers (chromium only — admin-eval uses chromium)
        working-directory: test/example/priv/playwright
        run: npx playwright install --with-deps chromium
```

Copy the correct form from `playwright-github-pages.yml:92-94`:

```yaml
      - name: Install Playwright browsers
        working-directory: test/example/priv/playwright
        run: npx playwright install --with-deps chromium webkit
```

**Keep untouched** (D-13) — the step-level flag and the re-fail pair at `:2543-2565`:

```yaml
        id: admin_eval_harness
        continue-on-error: true
        …
      - name: Fail the job if harness did not PASS
        # Re-fail after artifact upload so investigators can download partial bundles.
        if: steps.admin_eval_harness.outcome == 'failure'
```

### `.github/workflows/playwright-github-pages.yml` — D-17 seeds prelude

Current gap, `:81-95` — `Setup example dev DB` runs straight into `Install Playwright deps`:

```yaml
      - name: Setup example dev DB
        working-directory: test/example
        env:
          MIX_ENV: dev
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
        run: mix ecto.create && mix ecto.migrate
      - name: Install Playwright deps
        working-directory: test/example/priv/playwright
        run: npm ci
```

Copy the seeds step from `ci.yml:2506-2513` — the **`admin_eval_render`** copy, deliberately, because
it carries **no `if: docs_only`** guard (this workflow has no `changes` job, so the `ci.yml:1288-1296`
copy's `if:` would silently evaluate empty). Verbatim, with its surrounding steps for placement:

```yaml
      - name: Setup example dev DB
        working-directory: test/example
        env:
          MIX_ENV: dev
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
        run: mix ecto.create && mix ecto.migrate
      - name: Run demo seeds
        working-directory: test/example
        env:
          MIX_ENV: dev
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
        run: mix run priv/repo/seeds.exs
      - name: Install Playwright deps
        working-directory: test/example/priv/playwright
        run: npm ci
```

For contrast, the `docs_only`-guarded variant at `ci.yml:1288-1296` — **do not** copy this one here:

```yaml
      - name: Run demo seeds
        if: needs.changes.outputs.docs_only != 'true'
        working-directory: test/example
        env:
          MIX_ENV: dev
          …
        run: mix run priv/repo/seeds.exs
```

Note this workflow's app boots on the default **4000** (`:103`, `:107`), not 4011 — the seeds step
itself is port-agnostic, so it copies unchanged.

### `.github/workflows/release-please.yml` `gate-ci-green` — D-20/D-21

Job header to edit (`:96-104`) — carries **no** `timeout-minutes`, so it inherits 360:

```yaml
  gate-ci-green:
    name: Verify CI is green on release SHA
    runs-on: ubuntu-latest
    needs: release-please
    if: ${{ needs.release-please.outputs.release_created == 'true' }}
    permissions:
      actions: write
      contents: read
    steps:
      - name: Wait for ci-gate on release SHA
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPOSITORY: ${{ github.repository }}
          TAG_NAME: ${{ needs.release-please.outputs.tag_name }}
          RELEASE_SHA: ${{ needs.release-please.outputs.sha }}
        run: |
```

Add `timeout-minutes:` beside `runs-on:` (matching `ci-gate`'s own placement at `ci.yml:1791-1792`,
`runs-on` then `timeout-minutes`), comfortably above the 60-minute polling ceiling. Replace the
58-line `run: |` block with a script invocation — closest analog `ci.yml:2543-2551`, where env stays
in the step and the body is one `bash scripts/ci/…` line:

```yaml
      - name: Run admin-eval harness (render matrix + derivative guards)
        id: admin_eval_harness
        continue-on-error: true
        env:
          SIGRA_EXAMPLE_URL: "http://localhost:4011"
        run: bash scripts/ci/admin-eval-harness.sh
```

**Do not remove** `permissions: actions: write` — the loop dispatches `gh workflow run ci.yml`
(`:136`) on attempt 3, which needs it. The `notify-release-failure` consumer at `:344-379` (the
unexercised half, D-23) stays as-is.

### `.github/workflows/ci-observe.yml` — D-19 deletion

Pure deletion of `:130-136`; leave `exit 1` at `:137` as the sole terminal branch:

```bash
          # REMOVAL CONDITION: Phase 231 GATE-01. When a scheduled run concludes green (or
          # every remaining red is a filed, diagnosed defect), delete this branch so the
          # schedule lane fails like the push lane does.
          if [ "$RUN_EVENT" = "schedule" ]; then
            echo "::warning::Demotion receipt FAILED on the scheduled lane. Not failing this job: the nightly baseline is 0 pass / 9 fail, so an extra red is unreadable. Remove this leniency when Phase 231 GATE-01 lands."
            exit 0
          fi
          exit 1
```

Companion edit: `MAINTAINING.md:255-262` records the same commitment and must be updated in the
same commit.

---

## Shared Patterns

### Guard script skeleton
**Source:** `scripts/ci/ci-demotion-observer.sh` — header contract block, `set -euo pipefail`,
`ROOT=` resolution, `while [[ $# -gt 0 ]]` arg parse with `exit 2` fallthrough, `fail()`, non-vacuity
floor with the literal `-- the parse broke, this is not a pass`, dual `--format table|json` tail,
`exit "$EXIT_CODE"`.
**Apply to:** `honest-skip-verdict.sh`, `wait-for-ci-gate.sh`.

### Hermetic self-test skeleton
**Source:** `scripts/ci/ci-demotion-observer.test.sh` — case-table docstring, `exit 2` on a missing
subject, `PASS`/`FAIL` counters, `trap cleanup EXIT` on `mktemp -d`, PATH-shadowed recording `gh`,
paired output/rc invokers, `grep -c . … || true`, a positive control against the shipped artifact,
a static workflow-wiring case with its own non-vacuity branch, `Results: N passed, M failed` footer.
**Apply to:** both new `.test.sh` files, and the extension of `notify-failure-issue.test.sh`.

### Fail-closed verdict doctrine
**Source:** `ci-demotion-observer.sh:126-137` (the tri-state comment block) and `:116-120`.
Every unknown/empty/unfinished state is FAIL, never "nothing to check so pass"; the payload's
*shape* is asserted before its contents.
**Apply to:** `honest-skip-verdict.sh` (the whole point of GATE-03), `wait-for-ci-gate.sh`.

### `fast_checks` step comment convention
**Source:** `ci.yml:335-343`, `:306-322`. Every step carries `Phase NNN (REQ / D-NN):` plus an
explicit statement of what it does **not** cover.
**Apply to:** both new `fast_checks` steps.

### Bare `gh` via PATH
**Source:** `ci-demotion-observer.sh:37-39`, `ci-run-metrics.sh:44-45`. Never `/usr/bin/gh`, never a
wrapper — the self-test shadows it. Always paired with `command -v gh >/dev/null 2>&1 || fail`.
**Apply to:** `wait-for-ci-gate.sh`, `notify-failure-issue.sh`'s new `label` calls.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `test/example/priv/playwright/lib/eval/probes.ts:380` | probe utility | transform | A one-line `SVGAnimatedString` fix. `probes.ts:176` and `:237` use `className` for truthiness only and are **not** the pattern to copy — D-12 says explicitly not to "fix" them. |
| `test/example/priv/playwright/tests/admin-generated.spec.ts:169-176` | spec | assert | The 320px flake is a diagnosis task (D-09), not a code-shape task. No analog applies; relaxing the assertion is forbidden. |
| `ci.yml` `force_rot_probe` input | workflow config | event-driven | RESEARCH `:552-594` already quotes `force_fail_probe` in full **and** states the required divergence (verdict-script-level flag, not a new job). Nothing further to extract. |

---

## Metadata

**Analog search scope:** `scripts/ci/`, `scripts/ci/prohibitions/`, `.github/workflows/`,
`.github/ci-skip-manifest.tsv`, `MAINTAINING.md`
**Files scanned:** 62 `scripts/ci/*.sh`, 13 prohibition `.mjs`, 4 workflows
**Pattern extraction date:** 2026-07-29
