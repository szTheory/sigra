---
phase: 240-green-main-evidence-honest-pages-script
reviewed: 2026-09-18T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - .github/workflows/ci.yml
  - .github/workflows/green-04-evidence.yml
  - scripts/ci/capture-green-04-evidence.sh
  - scripts/ci/capture-green-04-evidence.test.sh
  - scripts/ci/ensure-github-pages-legacy-branch.sh
  - scripts/ci/ensure-github-pages-legacy-branch.test.sh
  - scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs
  - test/fixtures/prohibitions/p20-green-04-step-drift.yml
findings:
  critical: 2
  warning: 6
  info: 4
  total: 12
status: issues
---

# Phase 240: Code Review Report

**Reviewed:** 2026-09-18
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

The Pages script rewrite (SC-3) is sound: the status-line read is robust against empty
output, a malformed first line, a body containing the digits `403`, and a `204 No Content`
success with an empty body; every non-2xx except the one named PUT-403 exits 1; the
GET-side any-error→create hole is genuinely closed. Its self-test passes locally (10/10) and
is now wired into `fast_checks`. The `p20` parity guard was mutation-tested and is
non-vacuous in **both** directions (mutating `--test all`, `node-version`, and the `phx_new`
pin in the subject each turns it red; the empty-parse floor and the committed drift fixture
behave as documented). The three `|| true` build-trigger swallows in the Pages script are
exactly three, each commented per D-22, and no fourth swallow was introduced; the two other
`|| true` occurrences (`:55`, `:133`) are load-bearing (gh's rc cannot discriminate status,
so the status line must drive the branch) and correct.

The defects are concentrated in `capture-green-04-evidence.sh`, and they are the milestone's
own defect class. SC-1 is hardened against a selector that matches nothing
(`no_matrix_suffix`, `insufficient_legs`, `matrix_repeat_set_mismatch`,
`leg_without_conclusion`), but **SC-2 has no equivalent guard at all**: a job-name selector
that matches zero jobs, or a window containing zero runs, both produce a receipt that reads
"clean" and exit 0. Both were reproduced against a stub. Note: the committed
`240-GREEN-04-EVIDENCE.json` is *not* affected — its eight runs have non-null
`ci_gate_conclusion` and `generated_admin_smoke_conclusion`, so the shipped claim is real.
These are latent fail-open paths in the tool, not a falsification of this phase's evidence.

## Critical Issues

### CR-01: SC-2 job selectors fail open — a selector that matches zero jobs reports "no flake reds"

**File:** `scripts/ci/capture-green-04-evidence.sh:249-250` (and the consumer at `:312`)

**Issue:** `ci_gate_conclusion` and `generated_admin_smoke_conclusion` are computed as
`([$jobs[] | select(.name | test($re)) | .conclusion] | first)`, which yields `null` when the
anchored regex matches nothing. `flake_attributable_red_count` then counts only
`select(.generated_admin_smoke_conclusion == "failure")`, so `null` is silently excluded and
the count reads `0` — indistinguishable from a genuinely clean window.

Reproduced with a recording `gh` stub (two `main` runs whose smoke job concluded `failure`,
with only the job's `name:` changed to `Generated admin Playwright smoke v2`):

```
PROBE control (name matches):  {"run_count":2,"flake_attributable_red_count":2}
PROBE renamed (name matches 0):{"run_count":2,"flake_attributable_red_count":0,
                                "first_job_concl":null}   exit=0
```

Two real reds became "zero reds" with a zero exit and no diagnostic. `CI_JOB_NAME` is a
hardcoded constant (`:48`) pinned to a `ci.yml` job `name:` that this repo treats as
mutable prose (the evidence workflow's own header documents renaming hazards), so this is a
one-rename-away failure, not a hypothetical. The SC-1 half of the same script already treats
"the payload doesn't have the shape my selector assumes" as a rejected shape rather than an
empty result (`no_matrix_suffix`, `:194-196`); SC-2 has no analog.

**Fix:** assert per-run selector hits before tallying:

```bash
# after the merge loop, before emission
jq -e 'all(.[]; (.ci_gate_conclusion | type) == "string"
              and (.generated_admin_smoke_conclusion | type) == "string")' \
  "$SC2_RUNS_FILE" >/dev/null || fail "sc2_job_selector_matched_no_job"
```

(If a legitimately skipped/absent lane must be tolerated, tolerate it by name — e.g. accept
`null` only when the run's job list is provably missing that lane — never by letting `null`
fall through into a count that reads as good news.)

### CR-02: an empty `main` window produces a clean SC-2 receipt at exit 0, and nothing binds the window to the dispatch run

**File:** `scripts/ci/capture-green-04-evidence.sh:75-79`, `:229-231`, `:299-313`

**Issue:** `WINDOW_START`/`WINDOW_END` are validated only for ISO shape and ordering. If the
window contains no `main` runs, `MAIN_RUN_IDS` is empty, the merge loop never executes,
`SC2_RUNS_FILE` stays `[]`, and the script emits `run_count: 0`, all three
`ci_gate_conclusions` counters `0`, and `flake_attributable_red_count: 0` — then exits 0.
Reproduced:

```
PROBE empty window: exit=0
{"run_count":0,"ci_gate_conclusions":{"failure":0,"skipped":0,"success":0},
 "flake_attributable_red_count":0}
```

This directly contradicts the file's own header contract at `:6-10` — "a collector whose
window the caller steers lets whoever runs it choose the window that flatters the verdict —
that is evidence forgery wearing a green receipt … the `main` window bounds (themselves
bounded by the dispatch run)". Nothing in the code bounds the window by the dispatch run;
the caller picks both ends freely, and the degenerate choice (a one-second window) yields
the maximally flattering receipt. SC-1 enforces `MIN_LEGS`; SC-2 enforces no floor at all.

**Fix:** add both a floor and the documented binding:

```bash
MIN_MAIN_RUNS=1          # or the value SC-2 actually claims
RUN_STARTED_AT="$(gh api "repos/${REPO}/actions/runs/${RUN_ID}" --jq '.run_started_at')" \
  || fail "dispatch_run_unreadable"
[[ "$WINDOW_END" > "$RUN_STARTED_AT" || "$WINDOW_END" == "$RUN_STARTED_AT" ]] \
  || fail "main_window_not_bounded_by_dispatch_run"
...
RUN_COUNT="$(jq -r 'length' "$SC2_RUNS_FILE")"
(( RUN_COUNT >= MIN_MAIN_RUNS )) || fail "sc2_window_empty"
```

## Warnings

### WR-01: `verdict: "fail"` is emitted with exit status 0

**File:** `scripts/ci/capture-green-04-evidence.sh:219`, `:321`
**Issue:** `SC1_VERDICT` is `"fail"` whenever any leg concluded non-`success`, but the script
then writes the receipt and exits 0, printing `wrote … verdict=fail` on stdout. Every other
SC-1 invariant in this script is a hard `fail` call; the actual green/red verdict is the one
thing that isn't. Any future workflow or wrapper step that runs the collector goes green on
a red window — the pattern this milestone exists to remove.
**Fix:** either exit non-zero on `verdict != pass` after the receipt is written, or add an
explicit `--allow-red-window` opt-in so the lenient path is a deliberate, named choice.

### WR-02: SC-2 tallies can silently lose runs (no conclusion-completeness check)

**File:** `scripts/ci/capture-green-04-evidence.sh:307-312`
**Issue:** `ci_gate_conclusions` counts only `success`/`failure`/`skipped`. A run that is
still in progress (`conclusion: null`), `cancelled`, `timed_out`, or `action_required` is
counted in `run_count` but appears in none of the three buckets, so
`success + failure + skipped != run_count` is possible and unreported — a reader sees
"8 runs, 8 successes" only by coincidence. SC-1 rejects this class explicitly
(`leg_without_conclusion`, `:200-201`).
**Fix:** assert the reconciliation, e.g.
`jq -e '.sc2 | (.ci_gate_conclusions | add) == .run_count'`, or add an `other` bucket so an
unexpected conclusion is visible rather than absorbed.

### WR-03: the p20 parity guard stops at `steps:` while the job's environment is equally load-bearing

**File:** `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs:64-80`, `:113-163`;
`.github/workflows/green-04-evidence.yml:3-13`, `:71-97`
**Issue:** `stepList()` matches `/\n {4}steps:\n([\s\S]*)$/`, so everything above `steps:` is
outside the guard: `runs-on`, `timeout-minutes`, and the entire `services.postgres` block
(image `postgres:15`, health options, port mapping). The copy is byte-identical to
`ci.yml:1406-1420` today, but the file headers claim more than the guard delivers — "a
byte-faithful copy of the job", "the guard is what makes the copy provably a copy". A
`postgres:15` → `postgres:17` bump or a runner change in `ci.yml` would leave the evidence
lane silently diverged, which is the exact D-02 sibling-harness failure.
**Fix:** extend `parityIssue` with a job-header comparison (the slice from the job id to
`steps:`, normalized), allowing only the three documented exceptions (`name:`, the omitted
`needs:`, the added job-level `if:`); or narrow the header comments to say the guard covers
the step list only.

### WR-04: the Pages 200-arm never validates the extracted body, so a failed extraction falls through to a PUT

**File:** `scripts/ci/ensure-github-pages-legacy-branch.sh:57-62`, `:97-111`
**Issue:** On `200`, `pages_json` is produced by a `sed` range split. If that split yields
nothing (no header separator in the payload, a 200 with an empty body, a future `gh` output
shape change), `pages_json` is the empty string — and `jq -r '.build_type // empty'` on
empty input exits **0** with empty output (verified locally). `bt` and `branch` are then
empty, neither early-exit fires, and the script proceeds to **PUT a new Pages source
configuration** based on a config it never actually read. That is a silent fall-through into
a repository-state mutation, in the one script this phase rewrote to remove silent
fall-throughs. (Malformed-but-non-empty JSON is fine: `jq` exits non-zero and `set -e` kills
the script.)
**Fix:** gate the inspect path on a parsed body:

```bash
[[ -n "${pages_json}" ]] || { echo "…: GET /pages 200 with unparseable body" >&2; exit 1; }
echo "$pages_json" | jq -e 'type == "object"' >/dev/null \
  || { echo "…: GET /pages 200 body is not an object" >&2; exit 1; }
```

### WR-05: `2>/dev/null` discards gh's only error channel on the paths that now hard-fail

**File:** `scripts/ci/ensure-github-pages-legacy-branch.sh:55`, `:133`
**Issue:** Both `gh api -i` captures redirect stderr to `/dev/null`. For an HTTP error the
body is still on stdout, so this is harmless — but for a transport failure (DNS, TLS,
proxy, `gh` auth error) `gh` writes *only* to stderr and emits no status line. The new loud
arms then print `returned '<no status line>'` followed by an empty blob, discarding the one
message that explains why. The phase's stated goal is failing loudly; failing loudly with
the cause deleted halves the value.
**Fix:** capture stderr to a temp file (or merge it into a separate variable) and echo it on
the `*)` arms, e.g. `get_out="$(gh api -i … 2>"$err_file" || true)"` and
`cat "$err_file" >&2` before `exit 1`. Keep stderr out of `get_out` itself so the status-line
parse stays clean (D-17).

### WR-06: `capture-green-04-evidence.test.sh` has no CI caller while its sibling gained one in the same phase

**File:** `scripts/ci/capture-green-04-evidence.test.sh:16-18`; cf. `.github/workflows/ci.yml:262-267`
**Issue:** This phase wired `ensure-github-pages-legacy-branch.test.sh` into `fast_checks`
(correctly), but left the collector's 36-assertion hermetic self-test uncalled, justified by
"neither existing collector's test has a CI caller either" — an appeal to existing debt. The
collector holds every fail-closed assertion this phase depends on; it runs offline in ~3s
with no token and no network, so the whole stated reason for keeping guards off the PR
critical path does not apply. A future edit to the pagination or selector logic will not be
caught. (Note this test is also where CR-01/CR-02 coverage would naturally land.)
**Fix:** add one `fast_checks` step:
`run: bash scripts/ci/capture-green-04-evidence.test.sh`.

## Info

### IN-01: dead field in the p20 step parser

**File:** `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs:76`
**Issue:** `hasCondition` is computed for every step and never read by `parityIssue` or any
assertion. Inherited from the p15 copy the comment cites.
**Fix:** drop the field, or use it (a step-level `if:` appearing on only one side is drift
worth naming).

### IN-02: comments mis-name the job `name:` as the workflow `name:`

**File:** `scripts/ci/capture-green-04-evidence.sh:44-45`; `scripts/ci/capture-green-04-evidence.test.sh:11-12`
**Issue:** "this is the workflow's `name:` value, which the Actions API reports as a PREFIX" —
the value is the **job's** `name:` (`green-04-evidence.yml:53`). The workflow's `name:` is
`GREEN-04 evidence (n>=20 repeat)`. The code is right; the comment sends the next reader to
the wrong line.
**Fix:** s/workflow's/job's/ in both headers.

### IN-03: Pages test Case B is weaker than its siblings

**File:** `scripts/ci/ensure-github-pages-legacy-branch.test.sh:199-205`
**Issue:** Case B asserts exit 0 and exactly one POST-create, but unlike Cases A/E it does
not assert the `created.` stdout line, nor that zero PUTs were issued on the create path.
**Fix:** add `grep -q 'created\.' "$TMP/get_404.out"` and
`[[ "$(count_pages_calls get_404 PUT)" -eq 0 ]]`.

### IN-04: the only constraint on the SC-2 window is strict ordering

**File:** `scripts/ci/capture-green-04-evidence.sh:79`
**Issue:** `[[ "$WINDOW_START" < "$WINDOW_END" ]]` rejects a zero-width window but permits a
one-second one, which is functionally the same forgery (see CR-02). Listed separately only
because the fix belongs with CR-02's floor, not with the ordering check.
**Fix:** covered by CR-02.

## Checked and found clean (not findings)

- Status-line parsing (`head -n1 | awk '{print $2}'`) is correct for `HTTP/2.0 403 Forbidden`,
  empty output, and a body containing `403`; every unparsed case lands on the fail-closed
  `*)` arm. Verified by running the self-test (10/10 pass) on this machine.
- The header/body split (`sed -n '/^\r\{0,1\}$/,$p' | tail -n +2`) works under BSD sed as
  well as GNU sed — verified directly; no macOS/CI divergence.
- Exactly three `|| true` build-trigger swallows remain (`:81`, `:109`, `:156`), each with a
  D-22 comment; no fourth was introduced. The two `|| true` on the `gh api -i` captures are
  required (gh's rc cannot discriminate status) and are correctly paired with a status read.
- `p20` non-vacuity confirmed by mutation: altering `--test all`, `node-version`, or the
  `phx_new 1.8.8` pin in the subject each turns the guard red; the empty-parse floor and the
  committed drift fixture both behave as documented. The fixture's deliberate drift is not
  reported as a defect.
- `green-04-evidence.yml`: `permissions: contents: read` only, all four actions pinned to
  full SHAs, no untrusted context interpolated into any `run:` block, job-level
  `if: github.ref == 'refs/heads/main'` present. A dispatch on a non-`main` ref skips the job;
  the resulting zero-leg run cannot be laundered into evidence because the collector's
  `insufficient_legs` floor rejects it.
- Collector pagination core: `per_page=100`, `total_count` stability, `total_count`-vs-summed-
  length, proven terminal empty page, page contiguity, duplicate item ids, and an explicit
  `filter=latest` — all present and all exercised RED by the self-test (36/36 pass).

---

_Reviewed: 2026-09-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
