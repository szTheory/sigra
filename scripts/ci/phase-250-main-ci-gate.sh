#!/usr/bin/env bash
# Prove the exact protected-main CI run, including the separate admin-eval job.
set -euo pipefail

REPOSITORY="szTheory/sigra"
WORKFLOW_PATH=".github/workflows/ci.yml"
RECORD=""
while (($#)); do
  case "$1" in
    --record) [[ $# -ge 2 ]] || { echo "usage: $0 --record <diagnostic.json>" >&2; exit 2; }; RECORD="$2"; shift 2 ;;
    *) echo "phase-250-main-ci-gate: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$RECORD" && -f "$RECORD" ]] || { echo "phase-250-main-ci-gate: --record must name an existing diagnostic file" >&2; exit 2; }
for cmd in gh jq python3 rg; do command -v "$cmd" >/dev/null || { echo "phase-250-main-ci-gate: required command missing: $cmd" >&2; exit 1; }; done

RUN_ID="$(jq -er '.current_main_ci.run_id | select(type == "number")' "$RECORD")"
EXPECTED_ATTEMPT="$(jq -er '.current_main_ci.attempt | select(type == "number")' "$RECORD")"
EXPECTED_SHA="$(jq -er '.current_main_ci.head_sha | select(type == "string" and test("^[0-9a-f]{40}$"))' "$RECORD")"
[[ "$(jq -r '.current_main_ci.event' "$RECORD")" == push && "$(jq -r '.current_main_ci.branch' "$RECORD")" == main && "$(jq -r '.current_main_ci.workflow_path' "$RECORD")" == "$WORKFLOW_PATH" ]] || {
  echo "phase-250-main-ci-gate: recorded run is not a protected-main CI push" >&2; exit 1;
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/phase-250-main-ci.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
fail() {
  local message="$1" status="${2:-blocked}"
  local temp="${RECORD}.tmp.$$"
  jq --arg message "$message" --arg status "$status" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.current_main_ci += {verdict:$status, diagnostic:$message, observed_at:$at}' "$RECORD" > "$temp"
  jq -e . "$temp" >/dev/null && mv "$temp" "$RECORD"
  echo "phase-250-main-ci-gate: BLOCKED: $message" >&2
  exit 1
}

# Query quota before the one and only watcher. A 403/429 or low budget is a hard stop.
if ! gh api rate_limit >"$TMP_DIR/rate.json" 2>"$TMP_DIR/rate.err"; then
  fail "GitHub rate-limit preflight failed; no CI watch was started"
fi
CORE_REMAINING="$(jq -er '.resources.core.remaining | select(type == "number")' "$TMP_DIR/rate.json")" || fail "GitHub rate-limit response was malformed"
if (( CORE_REMAINING <= 250 )); then
  RESET="$(jq -r '.resources.core.reset // 0' "$TMP_DIR/rate.json")"
  fail "GitHub core API budget is $CORE_REMAINING (threshold 250); reset epoch $RESET. No CI watch was started"
fi

set +e
gh run watch "$RUN_ID" --repo "$REPOSITORY" --compact --interval 60 --exit-status 2>&1 | tee "$TMP_DIR/watch.log"
WATCH_STATUS=${PIPESTATUS[0]}
set -e
if rg -qi 'HTTP 403|HTTP 429|rate limit exceeded|secondary rate limit' "$TMP_DIR/watch.log"; then
  fail "GitHub rate limit was returned during the one CI watch; stop until the reported reset/retry time"
fi

# One run summary and one complete paginated jobs capture, after the watcher terminates.
if ! gh api "repos/${REPOSITORY}/actions/runs/${RUN_ID}" >"$TMP_DIR/run.json" 2>"$TMP_DIR/run.err"; then
  fail "could not retrieve the terminal run summary after the one watch"
fi
if ! gh api --paginate --slurp "repos/${REPOSITORY}/actions/runs/${RUN_ID}/jobs?per_page=100" >"$TMP_DIR/job-pages.json" 2>"$TMP_DIR/jobs.err"; then
  fail "could not retrieve all terminal job pages after the one watch"
fi
if ! jq -e 'type == "array" and length > 0 and all(.[]; (.jobs | type == "array"))' "$TMP_DIR/job-pages.json" >/dev/null; then
  fail "terminal job pagination returned a malformed or empty page set"
fi
jq '[.[].jobs[]]' "$TMP_DIR/job-pages.json" > "$TMP_DIR/jobs.json"
if ! gh api repos/${REPOSITORY}/commits/main >"$TMP_DIR/main.json" 2>"$TMP_DIR/main.err"; then
  fail "could not verify the protected main ref after the one watch"
fi

RUN_SHA="$(jq -r '.head_sha // ""' "$TMP_DIR/run.json")"
MAIN_SHA="$(jq -r '.sha // ""' "$TMP_DIR/main.json")"
RUN_ATTEMPT="$(jq -r '.run_attempt // 0' "$TMP_DIR/run.json")"
RUN_EVENT="$(jq -r '.event // ""' "$TMP_DIR/run.json")"
RUN_BRANCH="$(jq -r '.head_branch // ""' "$TMP_DIR/run.json")"
RUN_PATH="$(jq -r '.path // ""' "$TMP_DIR/run.json")"
RUN_STATUS="$(jq -r '.status // ""' "$TMP_DIR/run.json")"
RUN_CONCLUSION="$(jq -r '.conclusion // ""' "$TMP_DIR/run.json")"
[[ "$RUN_SHA" == "$EXPECTED_SHA" && "$MAIN_SHA" == "$EXPECTED_SHA" && "$RUN_ATTEMPT" == "$EXPECTED_ATTEMPT" \
  && "$RUN_EVENT" == push && "$RUN_BRANCH" == main && "$RUN_PATH" == "$WORKFLOW_PATH" \
  && "$RUN_STATUS" == completed && "$RUN_CONCLUSION" == success ]] || {
  # Fetch failed logs only for a terminal failed conclusion; store no raw log text.
  if [[ "$RUN_STATUS" == completed && "$RUN_CONCLUSION" != success ]]; then
    XDG_CACHE_HOME="$TMP_DIR/gh-cache" gh run view "$RUN_ID" --repo "$REPOSITORY" --log-failed >"$TMP_DIR/failure.log" 2>&1 || true
  fi
  if [[ -f "$TMP_DIR/failure.log" ]]; then
    python3 - "$TMP_DIR/failure.log" "$TMP_DIR/failure-evidence.json" <<'PY'
import json, re, sys
from pathlib import Path

raw = Path(sys.argv[1]).read_text(errors="replace")
raw = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", raw)
classes = []
if re.search(r"TimeoutError: page\.waitForURL: Timeout \d+ms exceeded", raw):
    classes.append("admin-eval registration redirect timed out waiting for navigation")
if "Account created successfully!" in raw and "element(s) not found" in raw:
    classes.append("admin-eval registration success alert was absent")
if not classes:
    classes.append("failed-job log retrieved; no known registration failure signature matched")
cases = sorted(set(re.findall(
    r"\d+\) \[(admin-eval(?:-mobile|-dark)?)\].*?render bundle: (board-mg-\d+)/(?:populated|zero|loading|error)",
    raw,
)))
Path(sys.argv[2]).write_text(json.dumps({"failure_classes": classes, "failed_render_cases": [
    {"project": project, "cell": cell} for project, cell in cases
]}, separators=(",", ":")), encoding="utf-8")
PY
  else
    printf '%s\n' '{"failure_classes":["terminal workflow failed; failed-job log unavailable"],"failed_render_cases":[]}' > "$TMP_DIR/failure-evidence.json"
  fi
  jq -n --arg expected_sha "$EXPECTED_SHA" --arg run_sha "$RUN_SHA" --arg main_sha "$MAIN_SHA" \
    --argjson expected_attempt "$EXPECTED_ATTEMPT" --argjson run_attempt "$RUN_ATTEMPT" \
    --arg event "$RUN_EVENT" --arg branch "$RUN_BRANCH" --arg path "$RUN_PATH" \
    --arg status "$RUN_STATUS" --arg conclusion "$RUN_CONCLUSION" \
    '{expected_sha:$expected_sha,run_sha:$run_sha,current_main_sha:$main_sha,expected_attempt:$expected_attempt,
      run_attempt:$run_attempt,event:$event,branch:$branch,workflow_path:$path,status:$status,conclusion:$conclusion}' > "$TMP_DIR/summary.json"
  BAD_JOBS="$(jq -c '[.[] | select(.conclusion != "success" and .conclusion != "skipped") | {id,name,conclusion,head_sha,run_attempt}]' "$TMP_DIR/jobs.json")"
  CI_JOB="$(jq -c '[.[] | select(.name == "ci-gate") | {id,name,conclusion,head_sha,run_attempt}]' "$TMP_DIR/jobs.json")"
  ADMIN_JOB="$(jq -c '[.[] | select(.name | startswith("Admin eval render + probe")) | {id,name,conclusion,head_sha,run_attempt}]' "$TMP_DIR/jobs.json")"
  FAILURE_EVIDENCE="$(cat "$TMP_DIR/failure-evidence.json")"
  local_summary="$(jq -c --argjson failed_jobs "$BAD_JOBS" --argjson ci_gate "$CI_JOB" --argjson admin_eval "$ADMIN_JOB" \
    --argjson failure_evidence "$FAILURE_EVIDENCE" \
    '. + {failed_jobs:$failed_jobs,ci_gate:$ci_gate,admin_eval:$admin_eval,failure_evidence:$failure_evidence}' "$TMP_DIR/summary.json")"
  local temp="${RECORD}.tmp.$$"
  jq --argjson summary "$local_summary" --arg url "$(jq -r '.html_url // ""' "$TMP_DIR/run.json")" \
    '.current_main_ci += {status:$summary.status, overall_conclusion:$summary.conclusion, url:$url,
      failed_jobs:$summary.failed_jobs, ci_gate:$summary.ci_gate, admin_eval:$summary.admin_eval,
      failure_classes:$summary.failure_evidence.failure_classes, failed_render_cases:$summary.failure_evidence.failed_render_cases,
      verdict:"failed", diagnostic:"terminal exact-main workflow did not pass"}' "$RECORD" > "$temp"
  jq -e . "$temp" >/dev/null && mv "$temp" "$RECORD"
  echo "phase-250-main-ci-gate: BLOCKED: run/ref identity or terminal workflow conclusion failed: $local_summary" >&2
  exit 1
}

if ! jq -e --arg sha "$EXPECTED_SHA" --argjson attempt "$EXPECTED_ATTEMPT" '
  all(.[]; .head_sha == $sha and .run_attempt == $attempt)
  and ([.[] | select(.name == "ci-gate" and .head_sha == $sha and .run_attempt == $attempt)] | length == 1)
  and ([.[] | select((.name | startswith("Admin eval render + probe")) and .head_sha == $sha and .run_attempt == $attempt)] | length == 1)
  and all(.[]; .conclusion == "success" or .conclusion == "skipped")
  and any(.[]; .name == "ci-gate" and .conclusion == "success")
  and any(.[]; (.name | startswith("Admin eval render + probe")) and .conclusion == "success")
' "$TMP_DIR/jobs.json" >/dev/null; then
  jq -c '[.[] | select(.conclusion != "success") | {id,name,conclusion,head_sha,run_attempt}]' "$TMP_DIR/jobs.json" > "$TMP_DIR/bad-jobs.json"
  if jq -e 'any(.[]; .conclusion == "skipped")' "$TMP_DIR/bad-jobs.json" >/dev/null; then
    SKIPPED="$(jq -c '[.[] | select(.conclusion == "skipped") | {id,name}]' "$TMP_DIR/bad-jobs.json")"
    fail "one or more jobs were skipped; their workflow conditions were not proven inapplicable: $SKIPPED" "failed"
  fi
  fail "required jobs failed or exact attempt/head identity did not match: $(cat "$TMP_DIR/bad-jobs.json")" "failed"
fi

# A skipped job is accepted only when its own workflow-level `if` expression proves
# it inapplicable for this push/main run or a dependency-result predicate is false.
if ! python3 - "$WORKFLOW_PATH" "$TMP_DIR/jobs.json" <<'PY'
import re, sys
import yaml

workflow_path, jobs_path = sys.argv[1:]
with open(workflow_path, encoding="utf-8") as stream:
    workflow = yaml.load(stream, Loader=yaml.BaseLoader)
with open(jobs_path, encoding="utf-8") as stream:
    jobs = __import__("json").load(stream)
declared = workflow.get("jobs", {})
display = {}
for key, spec in declared.items():
    label = spec.get("name", key) if isinstance(spec, dict) else key
    display[key] = (label, spec.get("if", "") if isinstance(spec, dict) else "")
results = {key: next((job.get("conclusion", "") for job in jobs if job.get("name") == label or job.get("name", "").startswith(label + " (")), "") for key, (label, _) in display.items()}
for job in jobs:
    if job.get("conclusion") != "skipped":
        continue
    key = next((key for key, (label, _) in display.items() if job.get("name") == label or job.get("name", "").startswith(label + " (")), None)
    if key is None:
        sys.exit(f"skipped job has no workflow definition: {job.get('name')}")
    condition = display[key][1]
    # Only accept explicit, mechanically checkable false clauses; unknown expressions fail closed.
    event_false = re.search(r"github\.event_name\s*==\s*['\"]([^'\"]+)['\"]", condition)
    if event_false and event_false.group(1) != "push" and "||" not in condition:
        continue
    if re.search(r"github\.event_name\s*!=\s*['\"]push['\"]", condition) and "||" not in condition:
        continue
    dependency_false = False
    for dep, expected in re.findall(r"needs\.([A-Za-z0-9_-]+)\.result\s*==\s*['\"]([^'\"]+)['\"]", condition):
        if results.get(dep) and results[dep] != expected and "&&" in condition:
            dependency_false = True
    if dependency_false:
        continue
    sys.exit(f"skipped job condition is not proven inapplicable for push/main: {job.get('name')}: {condition}")
PY
then
  fail "a skipped job is not proven inapplicable by its declared workflow condition" "failed"
fi

JOB_SUMMARY="$(jq -c '[.[] | {id,name,conclusion,head_sha,run_attempt}]' "$TMP_DIR/jobs.json")"
TEMP_RECORD="${RECORD}.tmp.$$"
jq --argjson jobs "$JOB_SUMMARY" --arg url "$(jq -r '.html_url // ""' "$TMP_DIR/run.json")" \
  --arg admin_job_id "$(jq -r '.[] | select(.name | startswith("Admin eval render + probe")) | .id' "$TMP_DIR/jobs.json")" \
  --arg ci_job_id "$(jq -r '.[] | select(.name == "ci-gate") | .id' "$TMP_DIR/jobs.json")" \
  '.current_main_ci += {status:"completed", overall_conclusion:"success", url:$url, admin_eval_job_id:($admin_job_id|tonumber),
    ci_gate_job_id:($ci_job_id|tonumber), required_jobs:$jobs, verdict:"passed", diagnostic:null}' "$RECORD" > "$TEMP_RECORD"
jq -e . "$TEMP_RECORD" >/dev/null && mv "$TEMP_RECORD" "$RECORD"
echo "phase-250-main-ci-gate: PASS run=$RUN_ID attempt=$EXPECTED_ATTEMPT sha=$EXPECTED_SHA (overall workflow, admin eval, ci-gate, and applicable jobs succeeded)"
