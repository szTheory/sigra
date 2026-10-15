#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
INVOKED_FROM="$PWD"
PHASE_DIR="$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
FIXTURE="$PHASE_DIR/253-RECOVERY-CANARY-WORKFLOW.yml"
RECOVERY_FREEZE="$PHASE_DIR/253-RECOVERY-CANARY-FREEZE.json"
EVIDENCE="$PHASE_DIR/253-RECOVERY-CANARY-EVIDENCE.json"
REQUESTS="$PHASE_DIR/253-RECOVERY-CANARY-HTTP-LEDGER-v2.json"
REQUEST_PRESERVED_REF=""
REQUEST_PRESERVED_SHA=""
REQUEST_PRESERVED_STATUS=""
RATE_SOURCE="$PHASE_DIR/253-RECOVERY-CANARY-PREFLIGHT-rate.json"
RULES_SOURCE="$PHASE_DIR/253-RECOVERY-CANARY-PREFLIGHT-effective-rules.json"
WORKFLOW_SOURCE="$PHASE_DIR/253-RECOVERY-CANARY-PREFLIGHT-registered-workflow.json"
REPO="szTheory/sigra"
WORKFLOW_ID="259268962"
MAX_REQUESTS=117
MAX_JOBS=45
MAX_MINUTES=60
POLL_INTERVAL=60
SCENARIO=""
ALL_REMAINING=false
CHECK_ONLY=false
FREEZE_TO_CHECK=""
CANARY_STARTED_EPOCH=0
PREFLIGHT_ONLY=false
PUBLISH_REF_ONLY=false
TRANSPORT_PROBE=false
HTTP_ALLOCATION=""
HTTP_LEDGER=""
HTTP_REQUEST=""
HTTP_OUTPUT=""
HTTP_BODY_OUTPUT=""
LIVE_ALLOCATION=""
PUBLISHER="$ROOT/scripts/ci/ci-git-publication.py"
REVISION_FREEZE=""
ACTION_APPROVAL=""
PUBLISH_ONLY=false
EVIDENCE_SET=false
REQUESTS_SET=false
PUBLICATION_RECEIPT=""

preserve_path() {
  local path="$1" scope="$2" status_before sha_before blob ref status_after sha_after
  [[ -f "$path" ]] || { PRESERVED_REF=""; PRESERVED_SHA=""; PRESERVED_STATUS=""; return 0; }
  status_before="$(git status --porcelain=v1 -- "$path" | tr -d '\n')"
  sha_before="$(shasum -a 256 "$path" | awk '{print $1}')"
  blob="$(git hash-object -w "$path")"
  ref="refs/gsd/phase253-12-canary-$scope/$sha_before"
  if git show-ref --verify --quiet "$ref"; then
    [[ "$(git rev-parse "$ref")" == "$blob" ]] || { echo "cannot preserve $path: content-addressed ref conflicts: $ref" >&2; exit 1; }
  else
    git update-ref "$ref" "$blob" || { echo "cannot preserve $path at $ref" >&2; exit 1; }
  fi
  [[ "$(git show "$ref" | shasum -a 256 | awk '{print $1}')" == "$sha_before" ]] || { echo "cannot preserve $path: exact-byte read-back failed" >&2; exit 1; }
  status_after="$(git status --porcelain=v1 -- "$path" | tr -d '\n')"
  sha_after="$(shasum -a 256 "$path" | awk '{print $1}')"
  [[ "$status_before" == "$status_after" && "$sha_before" == "$sha_after" ]] || { echo "cannot preserve $path: source changed during preservation" >&2; exit 1; }
  PRESERVED_REF="$ref"
  PRESERVED_SHA="$sha_before"
  PRESERVED_STATUS="$status_before"
}

assert_downstream_filters() {
  # Every workflow that filters on workflow names must exist and must not capture the canary name.
  local path
  for path in .github/workflows/ci-observe.yml .github/workflows/release-pr-automerge.yml .github/workflows/release-run-observer.yml; do
    [[ -f "$ROOT/$path" ]] || fail "downstream workflow is missing, so the name filter cannot be checked: $path"
    if grep -Fq 'Phase 253 Gate Canary' "$ROOT/$path"; then fail "fixture name matches a downstream workflow filter: $path"; fi
  done
}

usage() {
  cat <<'EOF'
Usage: ci-gate-canary.sh (--scenario NAME | --remaining-scenarios) [--evidence PATH] [--requests PATH]
       ci-gate-canary.sh --check-only [--recovery-freeze PATH]
       ci-gate-canary.sh --preflight-only [--recovery-freeze PATH]
       ci-gate-canary.sh --publish-ref-only [--recovery-freeze PATH]
       ci-gate-canary.sh --check-only --revision-freeze PATH
       ci-gate-canary.sh (--publish-only | --preflight-only | --publish-ref-only | --scenario NAME | --remaining-scenarios)
                         --revision-freeze PATH --action-approval FILE --http-allocation PATH
                         [--requests LEDGER] [--evidence PATH] [--publication-receipt PATH]
       ci-gate-canary.sh --transport-probe --allocation PATH --ledger PATH --request PATH --output PATH
       ci-gate-canary.sh --http-allocation PATH [--requests NEW-LEDGER]

Scenarios: full-pass, docs-only, actual-failure, missing-seam,
           unexpected-skip, cancelled
Runs only the sealed Phase 253 Gate Canary on a unique refs/heads/gsd/253-* branch.
--check-only validates local contracts and performs no GitHub request or mutation.
Every live mode needs a committed approval bound to the canary section of the reviewed revision freeze.
EOF
}

fail() {
  printf 'ci-gate-canary: FAIL: %s\n' "$*" >&2
  if [[ "$CHECK_ONLY" != true && "$TRANSPORT_PROBE" != true && -n "$LIVE_ALLOCATION" && -f "$EVIDENCE" ]] && \
     jq -e '.schema_version=="sigra.phase253.hosted-replan-evidence/v2" and .status != "halted"' "$EVIDENCE" >/dev/null 2>&1; then
    local failure_tmp="${EVIDENCE}.tmp"
    preserve_path "$EVIDENCE" evidence
    jq --arg message "$*" --arg ref "$PRESERVED_REF" --arg sha "$PRESERVED_SHA" --arg status "$PRESERVED_STATUS" \
      --arg evidence_path "${EVIDENCE#${ROOT}/}" --arg request_path "${REQUESTS#${ROOT}/}" \
      --arg request_ref "$REQUEST_PRESERVED_REF" --arg request_sha "$REQUEST_PRESERVED_SHA" --arg request_status "$REQUEST_PRESERVED_STATUS" \
      '(.diagnostics //= []) | .status="halted" | .diagnostics += [{kind:"canary-stop",message:$message}] | .preserved_revisions += [{path:$evidence_path,ref:$ref,sha256:$sha,status:$status},{path:$request_path,ref:$request_ref,sha256:$request_sha,status:$request_status}]' \
      "$EVIDENCE" > "$failure_tmp" 2>/dev/null && mv "$failure_tmp" "$EVIDENCE"
  fi
  exit 1
}

TRANSPORT_LEDGER="$REQUESTS"
MAX_INPUT_KEYS=10
MAX_INPUT_CHARS=65535
MAX_ARTIFACT_COMPRESSED=$((2 * 1024 * 1024))
MAX_ARTIFACT_EXTRACTED=$((4 * 1024 * 1024))

while (($#)); do
  case "$1" in
    --scenario) (($# >= 2)) || fail '--scenario requires a value'; SCENARIO="$2"; shift 2 ;;
    --remaining-scenarios) ALL_REMAINING=true; shift ;;
    --evidence) (($# >= 2)) || fail '--evidence requires a path'; EVIDENCE="$2"; EVIDENCE_SET=true; shift 2 ;;
    --requests) (($# >= 2)) || fail '--requests requires a path'; REQUESTS="$2"; REQUESTS_SET=true; shift 2 ;;
    --revision-freeze) (($# >= 2)) || fail '--revision-freeze requires a path'; REVISION_FREEZE="$2"; shift 2 ;;
    --action-approval) (($# >= 2)) || fail '--action-approval requires a path'; ACTION_APPROVAL="$2"; shift 2 ;;
    --publication-receipt) (($# >= 2)) || fail '--publication-receipt requires a path'; PUBLICATION_RECEIPT="$2"; shift 2 ;;
    --publish-only) PUBLISH_ONLY=true; shift ;;
    --rerun|--retry-infrastructure|--rerun-failed)
      fail "$1 is refused: reruns are expired for this window (no implemented rerun route; an infrastructure fault halts)" ;;
    --http-allocation) (($# >= 2)) || fail '--http-allocation requires a path'; LIVE_ALLOCATION="$2"; shift 2 ;;
    --publish-ref-only) PUBLISH_REF_ONLY=true; shift ;;
    --check-only) CHECK_ONLY=true; shift ;;
    --recovery-freeze) (($# >= 2)) || fail '--recovery-freeze requires a path'; FREEZE_TO_CHECK="$2"; shift 2 ;;
    --preflight-only) PREFLIGHT_ONLY=true; shift ;;
    --transport-probe) TRANSPORT_PROBE=true; shift ;;
    --allocation) (($# >= 2)) || fail '--allocation requires a value'; HTTP_ALLOCATION="$2"; shift 2 ;;
    --ledger) (($# >= 2)) || fail '--ledger requires a value'; HTTP_LEDGER="$2"; shift 2 ;;
    --request) (($# >= 2)) || fail '--request requires a value'; HTTP_REQUEST="$2"; shift 2 ;;
    --output) (($# >= 2)) || fail '--output requires a value'; HTTP_OUTPUT="$2"; shift 2 ;;
    --body-output) (($# >= 2)) || fail '--body-output requires a value'; HTTP_BODY_OUTPUT="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

if [[ "$TRANSPORT_PROBE" == true ]]; then
  [[ -n "$HTTP_ALLOCATION" && -n "$HTTP_LEDGER" && -n "$HTTP_REQUEST" && -n "$HTTP_OUTPUT" ]] || {
    echo 'ci-gate-canary: transport probe requires allocation, ledger, request and output paths' >&2
    exit 2
  }
  args=(--allocation "$HTTP_ALLOCATION" --ledger "$HTTP_LEDGER" --request "$HTTP_REQUEST" --output "$HTTP_OUTPUT")
  [[ -z "$HTTP_BODY_OUTPUT" ]] || args+=(--body-output "$HTTP_BODY_OUTPUT")
  exec python3 "$ROOT/scripts/ci/ci-hosted-transport.py" "${args[@]}"
fi

# One private (mode 700) per-run directory holds every temporary request/receipt/response file.
# BSD mktemp only substitutes trailing X characters, so no template below carries a suffix.
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/253-canary.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ "$CHECK_ONLY" == true && -n "$REVISION_FREEZE" ]]; then
  [[ -f "$REVISION_FREEZE" ]] || fail "revision freeze missing: $REVISION_FREEZE"
  FIXTURE_REL="$(jq -r '.bound_documents.fixture_workflow.path // empty' "$REVISION_FREEZE")"
  [[ -n "$FIXTURE_REL" && "$FIXTURE_REL" != /* && "$FIXTURE_REL" != *..* ]] || fail 'revision freeze has no safe bound fixture workflow path'
  FIXTURE="$ROOT/$FIXTURE_REL"
  [[ -f "$FIXTURE" ]] || fail "fixture workflow missing: $FIXTURE"
  [[ -f "$ROOT/scripts/ci/ci-browser-records.mjs" && -f "$ROOT/scripts/ci/honest-skip-verdict.sh" ]] || fail 'candidate shared gate helpers missing'
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --help >/dev/null
  grep -Fq 'name: Phase 253 Gate Canary' "$FIXTURE" || fail 'fixture workflow name changed'
  grep -Fq 'workflow_dispatch:' "$FIXTURE" || fail 'fixture is not manually dispatchable'
  ! grep -Eq '^  (push|pull_request|schedule|workflow_run):' "$FIXTURE" || fail 'fixture has an unapproved trigger'
  assert_downstream_filters
  python3 - "$FIXTURE" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding='utf-8')
if len(re.findall(r'^name: Phase 253 Gate Canary$', text, re.M)) != 1 or re.search(r'^  (push|pull_request|schedule|workflow_run):', text, re.M):
    raise SystemExit('fixture has an unapproved trigger or name')
try:
    import yaml
    parsed = yaml.safe_load(text)
except Exception as error:
    raise SystemExit(f'fixture YAML is invalid: {error}')
triggers = parsed.get('on', parsed.get(True))
jobs = parsed.get('jobs', {})
if not isinstance(triggers, dict) or list(triggers) != ['workflow_dispatch'] or parsed.get('permissions') != {"contents": "read"}:
    raise SystemExit('fixture must be dispatch-only with read-only top-level permissions')
if set(jobs) != {'producers', 'verdict', 'verifier'} or jobs['producers'].get('strategy', {}).get('matrix', {}).get('seam') != ['non_admin_smoke', 'admin_behavior', 'admin_checkpoints', 'design_gallery', 'demo_showcase']:
    raise SystemExit('fixture does not contain the five frozen tiny producers, verdict and verifier')
if jobs['verifier'].get('permissions') != {"contents": "read", "actions": "read"}:
    raise SystemExit('independent verifier permissions exceed read-only scope')
PY
  python3 "$PUBLISHER" --check-freeze "$REVISION_FREEZE" --repo-root "$ROOT" >/dev/null || fail 'revision freeze failed the policy check (expired reruns, native_target, bounds, source)'
  echo 'ci-gate-canary: local fixture contract passed'
  exit 0
fi

if [[ "$CHECK_ONLY" == true ]]; then
  [[ -f "$FIXTURE" ]] || fail "fixture workflow missing: $FIXTURE"
  [[ -n "$FREEZE_TO_CHECK" && -f "$FREEZE_TO_CHECK" ]] || fail 'a recovery freeze file is required for check-only'
  [[ -f "$ROOT/scripts/ci/ci-browser-records.mjs" && -f "$ROOT/scripts/ci/honest-skip-verdict.sh" ]] || fail 'candidate shared gate helpers missing'
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --help >/dev/null
  grep -Fq 'name: Phase 253 Gate Canary' "$FIXTURE" || fail 'fixture workflow name changed'
  grep -Fq 'workflow_dispatch:' "$FIXTURE" || fail 'fixture is not manually dispatchable'
  ! grep -Eq '^  (push|pull_request|schedule|workflow_run):' "$FIXTURE" || fail 'fixture has an unapproved trigger'
  assert_downstream_filters
  python3 - "$ROOT" "$FIXTURE" "$FREEZE_TO_CHECK" <<'PY'
import hashlib, json, re, subprocess, sys
from pathlib import Path
root, workflow, freeze_path = map(Path, sys.argv[1:])
freeze=json.loads(freeze_path.read_text(encoding='utf-8'))
expected_scenarios={"full-pass":"success","docs-only":"success","actual-failure":"failure",
                    "missing-seam":"failure","unexpected-skip":"failure","cancelled":"cancelled"}
if freeze.get("schema_version") != "sigra.recovery-canary-freeze/v1": raise SystemExit('freeze schema mismatch')
identity=freeze.get("identity", {})
candidate=identity.get("candidate_helper_commit", "")
fixture=identity.get("fixture_workflow_commit", "")
blob=identity.get("fixture_workflow_blob", "")
ref=identity.get("fixture_ref", "")
if not re.fullmatch(r"[0-9a-f]{40}", candidate): raise SystemExit('candidate helper commit is invalid')
if not re.fullmatch(r"[0-9a-f]{40}", fixture) or not re.fullmatch(r"[0-9a-f]{40}", blob): raise SystemExit('fixture commit or blob is invalid')
if not ref.startswith('refs/heads/gsd/253-replan-') or '20261013T044113Z-67104' in ref: raise SystemExit('fixture ref is reused or outside the new replan namespace')
actual_ref=subprocess.run(['git','rev-parse','--verify',ref],cwd=root,text=True,capture_output=True)
if actual_ref.returncode or actual_ref.stdout.strip()!=fixture: raise SystemExit('create-only fixture ref does not resolve to frozen commit')
if subprocess.run(['git','merge-base','--is-ancestor',candidate,'HEAD'],cwd=root).returncode: raise SystemExit('candidate helper commit is not in the current history')
if subprocess.run(['git','merge-base','--is-ancestor',candidate,fixture],cwd=root).returncode: raise SystemExit('fixture commit is not based on the candidate helper commit')
actual_blob=subprocess.run(['git','rev-parse',f'{fixture}:.github/workflows/ci.yml'],cwd=root,text=True,capture_output=True)
if actual_blob.returncode or actual_blob.stdout.strip()!=blob: raise SystemExit('fixture blob does not match frozen workflow content')
if identity.get("old_failed_run_id") != "38347679431" or identity.get("old_failed_fixture_ref") == ref or identity.get("old_failed_fixture_blob") == blob: raise SystemExit('old failed run/ref/blob was reused or lost')
scenarios=freeze.get('scenarios')
if not isinstance(scenarios,dict) or {item.get('name'):item.get('expected_outcome') for item in scenarios.get('cases',[])} != expected_scenarios: raise SystemExit('six frozen scenario names/outcomes changed')
bounds=freeze.get('bounds',{})
if bounds != {"max_requests":120,"max_actual_tiny_jobs":45,"max_minutes":60,"max_infrastructure_retries":1,"max_dispatch_input_keys":10,"max_dispatch_input_chars":65535,"max_artifact_compressed_bytes":2097152,"max_artifact_extracted_bytes":4194304}: raise SystemExit('finite canary bounds are missing or changed')
if scenarios.get('count') != 6 or scenarios.get('optional_infrastructure_retry') != 1: raise SystemExit('scenario count or retry policy is invalid')
if freeze.get('required_checks') != ["Library tests","Example unit smoke (ExUnit + ConnTest)","Install smoke (fresh phx.new + sigra.install)","Example HTTP smoke (boot + curl critical routes)","Example Playwright smoke (full lifecycle)"]: raise SystemExit('required check names differ from the five-name contract')
if freeze.get('workflow',{}).get('permissions') != {"contents":"read"} or freeze['workflow'].get('trigger') != ['workflow_dispatch']: raise SystemExit('fixture permissions or trigger are not read-only dispatch-only')
if freeze.get('workflow',{}).get('jobs') != {"tiny_producers":5,"verdict":1,"independent_verifier":1,"observer_trigger":False}: raise SystemExit('fixture workflow job topology or observer trigger changed')
if freeze.get('historical',{}).get('previous_accounted_or_reserved_requests') != 20 or freeze['historical'].get('previous_exact_http_count_proven') is not False: raise SystemExit('historical 20-call ledger was misrepresented as exact')
source_hashes=freeze.get('source_sha256',{})
for name, digest in source_hashes.items():
    path=root/name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest: raise SystemExit(f'source hash mismatch: {name}')
if set(source_hashes) != {"scripts/ci/ci-gate-canary.sh","scripts/ci/ci-gate-canary.test.sh","scripts/ci/ci-hosted-gate-verify.py","scripts/ci/ci-hosted-gate-verify.test.py","scripts/ci/ci-hosted-transport.py"}: raise SystemExit('freeze source hash set is incomplete or unexpected')
text=workflow.read_text(encoding='utf-8')
if len(re.findall(r'^name: Phase 253 Gate Canary$',text,re.M))!=1 or re.search(r'^  (push|pull_request|schedule|workflow_run):',text,re.M): raise SystemExit('fixture has an unapproved trigger or name')
try:
    import yaml
    parsed=yaml.safe_load(text)
except Exception as error:
    raise SystemExit(f'fixture YAML is invalid: {error}')
triggers=parsed.get('on',parsed.get(True))
jobs=parsed.get('jobs',{})
if not isinstance(triggers,dict) or list(triggers)!=['workflow_dispatch'] or parsed.get('permissions')!={"contents":"read"}: raise SystemExit('fixture must be dispatch-only with read-only top-level permissions')
if set(jobs)!={'producers','verdict','verifier'} or jobs['producers'].get('strategy',{}).get('matrix',{}).get('seam')!=['non_admin_smoke','admin_behavior','admin_checkpoints','design_gallery','demo_showcase']: raise SystemExit('fixture does not contain the five frozen tiny producers, verdict and verifier')
if jobs['verifier'].get('permissions')!={"contents":"read","actions":"read"}: raise SystemExit('independent verifier permissions exceed read-only scope')
PY
  echo 'ci-gate-canary: local fixture contract passed'
  exit 0
fi


if [[ -n "$REVISION_FREEZE" ]]; then
  # Relative operator-supplied paths are anchored where the script was invoked, before it changes directory.
  for _path_var in REVISION_FREEZE ACTION_APPROVAL LIVE_ALLOCATION PUBLICATION_RECEIPT EVIDENCE REQUESTS; do
    case "$_path_var" in
      EVIDENCE) [[ "$EVIDENCE_SET" == true ]] || continue ;;
      REQUESTS) [[ "$REQUESTS_SET" == true ]] || continue ;;
    esac
    if [[ -n "${!_path_var}" && "${!_path_var}" != /* ]]; then printf -v "$_path_var" '%s/%s' "$INVOKED_FROM" "${!_path_var}"; fi
  done
  # The committed canary section approval is checked before any evidence file, ledger or request exists.
  [[ -f "$REVISION_FREEZE" ]] || fail "live mode requires the reviewed --revision-freeze: $REVISION_FREEZE is missing"
  cd "$ROOT"
  [[ "$(git rev-parse --show-toplevel)" == "$ROOT" ]] || fail 'checkout root changed'
  APPROVAL_RECORD="$(python3 "$PUBLISHER" --check-approval --action-approval "$ACTION_APPROVAL" --freeze "$REVISION_FREEZE" --section canary --repo-root "$ROOT")" \
    || fail 'a committed canary section approval bound to the freeze is required before any request'
  bash "$SELF" --check-only --revision-freeze "$REVISION_FREEZE" >/dev/null || fail 'revision freeze failed local check-only validation'
  FROZEN_CANDIDATE_SHA="$(jq -r '.identity.candidate_helper_commit' "$REVISION_FREEZE")"
  FROZEN_FIXTURE_REF="$(jq -r '.identity.fixture_ref' "$REVISION_FREEZE")"
  FROZEN_FIXTURE_SHA="$(jq -r '.identity.fixture_workflow_commit' "$REVISION_FREEZE")"
  FROZEN_FIXTURE_BLOB="$(jq -r '.identity.fixture_workflow_blob' "$REVISION_FREEZE")"
  # D-12 (253-100 decision server-parent-identity): native check sources are read from the frozen server parent.
  FROZEN_SERVER_PARENT_SHA="$(jq -r '.identity.server_parent_sha // empty' "$REVISION_FREEZE")"
  FIXTURE="$ROOT/$(jq -r '.bound_documents.fixture_workflow.path' "$REVISION_FREEZE")"
  [[ "$EVIDENCE_SET" == true ]] || EVIDENCE="$PHASE_DIR/253-LOAD-RECOVERY-CANARY-EVIDENCE.json"
  [[ "$REQUESTS_SET" == true ]] || REQUESTS="$PHASE_DIR/253-LOAD-RECOVERY-CANARY-REQUESTS.json"
  [[ -n "$PUBLICATION_RECEIPT" ]] || PUBLICATION_RECEIPT="$PHASE_DIR/253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT.json"
  TRANSPORT_LEDGER="$REQUESTS"
else
  [[ -n "$FREEZE_TO_CHECK" && -f "$FREEZE_TO_CHECK" ]] || fail 'hosted execution requires the separately reviewed recovery freeze'
  bash "$SELF" --check-only --recovery-freeze "$FREEZE_TO_CHECK" >/dev/null || fail 'recovery freeze failed local check-only validation'
  FROZEN_CANDIDATE_SHA="$(jq -r '.identity.candidate_helper_commit' "$FREEZE_TO_CHECK")"
  FROZEN_FIXTURE_REF="$(jq -r '.identity.fixture_ref' "$FREEZE_TO_CHECK")"
  FROZEN_FIXTURE_SHA="$(jq -r '.identity.fixture_workflow_commit' "$FREEZE_TO_CHECK")"
  FROZEN_FIXTURE_BLOB="$(jq -r '.identity.fixture_workflow_blob' "$FREEZE_TO_CHECK")"
  FROZEN_SERVER_PARENT_SHA="$(jq -r '.identity.server_parent_sha // empty' "$FREEZE_TO_CHECK")"
fi

cd "$ROOT"
normalize_repo_path() {
  local value="$1" resolved
  if [[ "$value" == /* ]]; then
    resolved="$(cd "$(dirname "$value")" && pwd -P)/$(basename "$value")"
  else
    resolved="$ROOT/$value"
  fi
  [[ "$resolved" == "$ROOT/"* ]] || fail "evidence path must stay inside the repository: $value"
  printf '%s\n' "$resolved"
}
EVIDENCE="$(normalize_repo_path "$EVIDENCE")"
REQUESTS="$(normalize_repo_path "$REQUESTS")"
[[ "$ALL_REMAINING" == true || -n "$SCENARIO" || "$PREFLIGHT_ONLY" == true || "$PUBLISH_REF_ONLY" == true || "$PUBLISH_ONLY" == true ]] || { usage >&2; exit 2; }
[[ "$PUBLISH_ONLY" == false || ( "$ALL_REMAINING" == false && -z "$SCENARIO" && "$PREFLIGHT_ONLY" == false && "$PUBLISH_REF_ONLY" == false ) ]] || fail 'publish-only mode cannot include another execution mode'
[[ "$ALL_REMAINING" == false || -z "$SCENARIO" ]] || fail 'choose one scenario mode'
[[ "$PREFLIGHT_ONLY" == false || ( "$ALL_REMAINING" == false && -z "$SCENARIO" ) ]] || fail 'preflight-only mode cannot include a scenario'
[[ "$PUBLISH_REF_ONLY" == false || ( "$ALL_REMAINING" == false && -z "$SCENARIO" && "$PREFLIGHT_ONLY" == false ) ]] || fail 'publish-ref-only mode cannot include another execution mode'
valid_scenario() { case "$1" in full-pass|docs-only|actual-failure|missing-seam|unexpected-skip|cancelled) return 0;; *) return 1;; esac; }
if [[ "$PREFLIGHT_ONLY" == false && "$PUBLISH_REF_ONLY" == false && "$ALL_REMAINING" == false && "$PUBLISH_ONLY" == false ]]; then valid_scenario "$SCENARIO" || fail "unknown scenario: $SCENARIO"; fi

[[ "$(git rev-parse --show-toplevel)" == "$ROOT" ]] || fail 'checkout root changed'
[[ -f "$FIXTURE" ]] || fail 'frozen fixture is missing'
[[ -f "$PHASE_DIR/253-PREHOST-REVIEW.md" ]] || fail 'pre-host review report is missing'
if grep -En '^### CR-.*(ci-browser-records|honest-skip-verdict|ci-gate)' "$PHASE_DIR/253-PREHOST-REVIEW.md"; then
  fail 'pre-host review found a blocking issue in a canary gate helper'
fi
assert_downstream_filters

# Never let a rerun discard deterministic diagnostics or reuse a halted freeze.
# This guard precedes every gh invocation, including local token lookup.
if [[ -f "$EVIDENCE" ]] && jq -e '.status == "halted" or ((.diagnostics // {}) | length > 0)' "$EVIDENCE" >/dev/null; then
  fail 'halted evidence requires a separately authorized new freeze; existing diagnostics cannot be retried'
fi
[[ -n "$REVISION_FREEZE" ]] || fail 'recovery freezes are retired for live execution: use --revision-freeze with a committed canary section approval'
[[ -n "$LIVE_ALLOCATION" && -f "$LIVE_ALLOCATION" ]] || fail 'a new frozen HTTP allocation is required before hosted work'
if [[ "$PUBLISH_ONLY" == true ]]; then
  MANIFEST_REL="$(jq -r '.bound_documents.publication_manifest.path' "$REVISION_FREEZE")"
  WINDOW_START="$(date +%s)"
  if [[ -f "$EVIDENCE" ]]; then
    jq -e --argjson approval "$APPROVAL_RECORD" '.action_approval.section_sha256 == $approval.section_sha256' "$EVIDENCE" >/dev/null \
      || fail 'existing evidence is bound to a different approval'
  else
    jq -n --argjson approval "$APPROVAL_RECORD" --argjson window "$WINDOW_START" --slurpfile freeze "$REVISION_FREEZE" \
      '$freeze[0].identity as $id | {schema_version:"sigra.phase253.hosted-replan-evidence/v2",repository:"szTheory/sigra",
        action_approval:($approval + {window_wall_start_epoch:$window}),
        expected:{candidate_sha:$id.candidate_helper_commit,fixture_ref:$id.fixture_ref,fixture_ref_state:"pending-publication",
          workflow_id:259268962,workflow_path:".github/workflows/ci.yml",workflow_name:"Phase 253 Gate Canary",
          workflow_sha:$id.fixture_workflow_commit,workflow_blob:$id.fixture_workflow_blob,
          check_source_sha:$id.server_parent_sha,check_source_role:"server_parent"},
        preflight:{},budget:{accounted_max_requests:120,new_measured_max_requests:117,max_requests:117,request_count:0,max_jobs:45,
          actual_jobs:0,max_minutes:60,started_epoch:$window,elapsed_seconds:0},
        transport_ledger:null,transport_receipts:[],dispatch_inputs:{},dispatch_input_metrics:[],preserved_revisions:[],
        scenarios:{},separate_verifier:{status:"pending"}}' > "$EVIDENCE.tmp" && mv "$EVIDENCE.tmp" "$EVIDENCE"
  fi
  RECORDED_WINDOW="$(jq -r '.action_approval.window_wall_start_epoch' "$EVIDENCE")"
  [[ "$RECORDED_WINDOW" =~ ^[0-9]+$ ]] || fail 'the evidence has no recorded wall-clock window start'
  python3 "$PUBLISHER" --publish --manifest "$ROOT/$MANIFEST_REL" --allocation "$LIVE_ALLOCATION" --ledger "$REQUESTS" \
    --receipt "$PUBLICATION_RECEIPT" --freeze "$REVISION_FREEZE" --action-approval "$ACTION_APPROVAL" --repo-root "$ROOT" \
    --window-wall-start-epoch "$RECORDED_WINDOW" \
    || fail 'counted object/ref publication failed'
  # Only a live allocation can prove a live publication: a hermetic receipt never marks the fixture ref verified.
  if jq -e '.mode == "live"' "$LIVE_ALLOCATION" >/dev/null; then
    python3 "$PUBLISHER" --verify-publication "$PUBLICATION_RECEIPT" --require-live-origin >/dev/null \
      || fail 'publication receipt failed live-origin verification'
    REF_STATE=verified
  else
    python3 "$PUBLISHER" --verify-publication "$PUBLICATION_RECEIPT" >/dev/null || fail 'publication receipt failed verification'
    REF_STATE=hermetic-unverified
  fi
  jq --slurpfile receipt "$PUBLICATION_RECEIPT" --arg path "${PUBLICATION_RECEIPT#${ROOT}/}" --arg ref_state "$REF_STATE" \
    --arg digest "$(shasum -a 256 "$PUBLICATION_RECEIPT" | awk '{print $1}')" --slurpfile ledger "$REQUESTS" \
    '.expected.fixture_ref_state=$ref_state | .budget.request_count=($ledger[0].transactions|length)
     | .publication={receipt_path:$path,receipt_sha256:$digest,status:$receipt[0].status,origin:$receipt[0].origin,
                     request_count:$receipt[0].request_count,candidate_ref:$receipt[0].candidate_ref,fixture_ref:$receipt[0].fixture_ref}' \
    "$EVIDENCE" > "$EVIDENCE.tmp" && mv "$EVIDENCE.tmp" "$EVIDENCE"
  echo "ci-gate-canary: counted publication verified (requests=$(jq -r '.transactions|length' "$REQUESTS")/117; no workflow dispatch)"
  exit 0
fi
if [[ -f "$EVIDENCE" ]] && ! jq -e '.schema_version=="sigra.phase253.hosted-replan-evidence/v2"' "$EVIDENCE" >/dev/null 2>&1; then
  fail 'the existing evidence is historical v1/v2 disclosure; new acceptance needs a separate measured-v2 evidence path and allocation'
fi
startup_request="$(mktemp "$WORK_DIR/startup-request.XXXXXX")"
jq -n '{method:"GET",route_id:"rate_limit"}' > "$startup_request"
python3 "$ROOT/scripts/ci/ci-hosted-transport.py" --check-only --allocation "$LIVE_ALLOCATION" \
  --ledger "$REQUESTS" --request "$startup_request" --output /dev/null || fail 'frozen HTTP allocation failed local transport validation'
rm -f "$startup_request"
if [[ -f "$EVIDENCE" ]]; then
  [[ -f "$REQUESTS" ]] || fail 'recovery request ledger is missing for existing evidence'
  REQUEST_COUNT="$(jq -r '.transactions | length' "$REQUESTS")"
  CANARY_STARTED_EPOCH="$(jq -r '.budget.started_epoch // 0' "$EVIDENCE")"
  FIXTURE_REF="$(jq -r '.expected.fixture_ref // empty' "$EVIDENCE")"
  CANDIDATE_SHA="$(jq -r '.expected.candidate_sha // empty' "$EVIDENCE")"
  FIXTURE_SHA="$(jq -r '.expected.workflow_sha // empty' "$EVIDENCE")"
  FIXTURE_BLOB="$(jq -r '.expected.workflow_blob // empty' "$EVIDENCE")"
  CHECK_SOURCE_SHA="$(jq -r '.expected.check_source_sha // empty' "$EVIDENCE")"
else
  [[ ! -e "$REQUESTS" ]] || fail 'request ledger exists without its matching recovery evidence'
  REQUEST_COUNT=0
  FIXTURE_REF=""
  CANDIDATE_SHA=""
  FIXTURE_SHA=""
  FIXTURE_BLOB=""
  CHECK_SOURCE_SHA=""
fi
if [[ -n "$FIXTURE_REF" && ( "$FIXTURE_REF" != "$FROZEN_FIXTURE_REF" || "$CANDIDATE_SHA" != "$FROZEN_CANDIDATE_SHA" || "$FIXTURE_SHA" != "$FROZEN_FIXTURE_SHA" || "$FIXTURE_BLOB" != "$FROZEN_FIXTURE_BLOB" || "$CHECK_SOURCE_SHA" != "$FROZEN_SERVER_PARENT_SHA" ) ]]; then
  fail 'existing execution evidence does not match this new recovery freeze'
fi
CANDIDATE_SHA="$FROZEN_CANDIDATE_SHA"
FIXTURE_REF="$FROZEN_FIXTURE_REF"
FIXTURE_SHA="$FROZEN_FIXTURE_SHA"
FIXTURE_BLOB="$FROZEN_FIXTURE_BLOB"
CHECK_SOURCE_SHA="$FROZEN_SERVER_PARENT_SHA"
[[ "$REQUEST_COUNT" =~ ^[0-9]+$ ]] || fail 'frozen request ledger is malformed'

check_budget() {
  local reserve="${1:-0}"
  (( REQUEST_COUNT + reserve <= MAX_REQUESTS )) || fail "GitHub request budget exhausted: used=$REQUEST_COUNT reserve=$reserve max=$MAX_REQUESTS"
  if (( CANARY_STARTED_EPOCH > 0 )); then
    (( $(date +%s) - CANARY_STARTED_EPOCH < MAX_MINUTES * 60 )) || fail "hosted canary exceeded its fixed ${MAX_MINUTES}-minute clock"
  fi
}

REQUEST_LEDGER="$REQUESTS"

preserve_evidence() {
  preserve_path "$EVIDENCE" evidence
  PRIOR_EVIDENCE_STATUS="$PRESERVED_STATUS"
  PRIOR_EVIDENCE_SHA="$PRESERVED_SHA"
  PRIOR_EVIDENCE_REF="$PRESERVED_REF"
}

publish_fixture_ref() {
  local ref_endpoint="git/ref/heads/$FIXTURE_BRANCH" remote_ref state remote_response
  remote_ref="$(mktemp "$WORK_DIR/remote-ref.XXXXXX")"
  if api_get "$ref_endpoint" "$remote_ref" true; then
    jq -e --arg ref "$FIXTURE_REF" --arg sha "$FIXTURE_SHA" '.ref==$ref and .object.sha==$sha' "$remote_ref" >/dev/null || fail 'remote fixture ref exists with a different identity; refusing to update it'
    state='present-exact'
  else
    remote_response="$(mktemp "$WORK_DIR/create-ref-response.XXXXXX")"
    api_post_create_ref "$FIXTURE_BRANCH" "$FIXTURE_SHA" "$remote_response"
    jq -e --arg ref "$FIXTURE_REF" --arg sha "$FIXTURE_SHA" '.ref==$ref and .object.sha==$sha' "$remote_response" >/dev/null || fail 'created fixture ref response did not match the sealed commit'
    api_get "$ref_endpoint" "$remote_ref"
    jq -e --arg ref "$FIXTURE_REF" --arg sha "$FIXTURE_SHA" '.ref==$ref and .object.sha==$sha' "$remote_ref" >/dev/null || fail 'remote fixture ref did not read back the exact sealed commit'
    state='created-and-read-back'
  fi
  preserve_evidence
  jq --arg ref "$FIXTURE_REF" --arg sha "$FIXTURE_SHA" --arg blob "$FIXTURE_BLOB" --arg state "$state" \
    --arg evidence_path "${EVIDENCE#${ROOT}/}" --arg prior_ref "$PRIOR_EVIDENCE_REF" --arg prior_sha "$PRIOR_EVIDENCE_SHA" --arg prior_status "$PRIOR_EVIDENCE_STATUS" \
    '.expected.remote_fixture_ref_state=$state | .expected.remote_fixture_ref=$ref | .expected.remote_fixture_sha=$sha | .expected.remote_workflow_blob=$blob | .preserved_revisions += [{path:$evidence_path,ref:$prior_ref,sha256:$prior_sha,status:$prior_status}]' \
    "$EVIDENCE" > "${EVIDENCE}.tmp" && mv "${EVIDENCE}.tmp" "$EVIDENCE"
  record_budget
}

watch_run() {
  local run_id="$1" description="$2" rate_file core_left started run_target status conclusion lock_dir
  rate_file="$(mktemp "$WORK_DIR/watch-rate.XXXXXX")"
  CATEGORY_OVERRIDE=pre_watch_rate api_get rate_limit "$rate_file"
  core_left="$(jq -r '.resources.core.remaining // 0' "$rate_file")"
  (( core_left > 250 )) || fail "GitHub core API budget is at or below 250 before watch (remaining=$core_left)"
  lock_dir="${TMPDIR:-/tmp}/253-canary-poll-$run_id.lock"
  mkdir "$lock_dir" 2>/dev/null || fail "another poller already owns run $run_id"
  started="$SECONDS"
  run_target="$(mktemp "$WORK_DIR/terminal-run.XXXXXX")"
  while :; do
    check_budget 0
    (( SECONDS - started < MAX_MINUTES * 60 )) || fail "60-minute canary ceiling reached while polling run $run_id"
    api_get "actions/runs/$run_id" "$run_target"
    status="$(jq -r '.status // empty' "$run_target")"
    conclusion="$(jq -r '.conclusion // empty' "$run_target")"
    if [[ "$status" == completed && -n "$conclusion" ]]; then
      cp "$run_target" "$TERMINAL_RUN_JSON"
      rmdir "$lock_dir"
      return 0
    fi
    sleep "$POLL_INTERVAL"
  done
}

validate_dispatch_inputs() {
  python3 - "$TRANSPORT_MODULE" "$1" <<'PY'
import importlib.util, json, sys
spec=importlib.util.spec_from_file_location("ci_hosted_transport",sys.argv[1])
module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
inputs=json.loads(sys.argv[2])
module.serialize_dispatch_inputs(inputs)
PY
}

TRANSPORT_MODULE="$ROOT/scripts/ci/ci-hosted-transport.py"
REQUEST_LEDGER="$REQUESTS"
HTTP_RECEIPT_DIR="$(mktemp -d "$WORK_DIR/http-receipts.XXXXXX")"

# Every request is predebited against its frozen category (253-LOAD-RECOVERY-BUDGETS.md hosted-canary table).
request_category() {
  case "$1" in
    rate_limit) printf '%s\n' "${CATEGORY_OVERRIDE:-preflight}" ;;
    rules_main|branch_protection|check_runs|workflow) printf 'preflight\n' ;;
    create_ref|get_ref) printf 'publication\n' ;;
    dispatch) printf 'dispatch\n' ;;
    workflow_runs) printf 'run_discovery\n' ;;
    run) printf 'terminal_polls\n' ;;
    run_jobs) printf 'attempt_jobs\n' ;;
    run_artifacts) printf 'artifact_metadata\n' ;;
    artifact_zip) printf 'artifact_downloads\n' ;;
    run_logs) printf 'failure_logs\n' ;;
    cancel_run) printf 'cancellation\n' ;;
    *) fail "route has no frozen request category: $1" ;;
  esac
}

transport_call() {
  route="$1"; method="$2"; target="$3"; params="$4"; query="$5"; body="$6"; mode="$7"
  request_file="$(mktemp "$WORK_DIR/http-request.XXXXXX")"
  receipt_file="$(mktemp "$WORK_DIR/http-receipt.XXXXXX")"
  category="$(request_category "$route")"
  jq -n --arg route "$route" --arg method "$method" --arg category "$category" --argjson params "$params" --argjson query "$query" --argjson body "$body" \
    '{route_id:$route,method:$method,category:$category,params:$params,query:$query,page_ordinal:1,hop_ordinal:0,body:(if $body==null then null else $body end)}' > "$request_file"
  rc=0
  if [[ "$mode" == pages ]]; then extra=--fetch-pages; elif [[ "$mode" == download ]]; then extra=--follow-download; else extra=; fi
  python3 "$TRANSPORT_MODULE" --allocation "$LIVE_ALLOCATION" --ledger "$REQUEST_LEDGER" \
    --request "$request_file" --output "$receipt_file" --body-output "$target" $extra || rc="$?"
  if [[ -f "$REQUEST_LEDGER" ]]; then REQUEST_COUNT="$(jq '.transactions | length' "$REQUEST_LEDGER")"; fi
  if [[ -f "$receipt_file" ]]; then
    LAST_REQUEST_SEQUENCE="$(jq -r '.sequence // (.receipts[-1].sequence // 0)' "$receipt_file")"
    LAST_REQUEST_STATUS="$(jq -r '.actual_status // .receipts[-1].actual_status // empty' "$receipt_file")"
    LAST_INPUT_KEY_COUNT="$(jq -r '.input_key_count // .receipts[-1].input_key_count // empty' "$receipt_file")"
    LAST_INPUT_UNICODE_SCALARS="$(jq -r '.input_unicode_scalars // .receipts[-1].input_unicode_scalars // empty' "$receipt_file")"
    LAST_INPUT_UTF8_BYTES="$(jq -r '.input_utf8_bytes // .receipts[-1].input_utf8_bytes // empty' "$receipt_file")"
    LAST_INPUT_SHA256="$(jq -r '.input_sha256 // .receipts[-1].input_sha256 // empty' "$receipt_file")"
    if [[ -f "$EVIDENCE" ]]; then
      jq --slurpfile new_receipts "$receipt_file" \
        '.transport_receipts += (if ($new_receipts[0].receipts|type)=="array" then $new_receipts[0].receipts else [$new_receipts[0]] end)' \
        "$EVIDENCE" > "$EVIDENCE.tmp" && mv "$EVIDENCE.tmp" "$EVIDENCE"
    fi
  fi
  record_budget
  rm -f "$request_file" "$receipt_file"
  return "$rc"
}

record_budget() {
  [[ -f "$EVIDENCE" && -f "$REQUEST_LEDGER" ]] || return 0
  temp="$EVIDENCE.tmp"
  elapsed=0
  if (( CANARY_STARTED_EPOCH > 0 )); then elapsed="$(($(date +%s) - CANARY_STARTED_EPOCH))"; fi
  preserve_evidence
  jq --slurpfile ledger "$REQUEST_LEDGER" --argjson count "$REQUEST_COUNT" --argjson elapsed "$elapsed" \
    '.budget.request_count=$count | .budget.elapsed_seconds=$elapsed | .transport_ledger=$ledger[0] | .origin={kind:"measured-v2",window_id:$ledger[0].window_id,source_sha256:$ledger[0].source_sha256,channel:"github-api"}' \
    "$EVIDENCE" > "$temp" && mv "$temp" "$EVIDENCE"
}

api_get() {
  endpoint="$1"; target="$2"; allow_missing=false; [[ "$#" -lt 3 ]] || allow_missing="$3"; route=""; params='{}'; query='{}'; mode=one
  if [[ "$endpoint" == rate_limit ]]; then route=rate_limit
  elif [[ "$endpoint" == 'rules/branches/main?per_page=100' ]]; then route=rules_main; query='{"per_page":100}'; mode=pages
  elif [[ "$endpoint" == branches/main/protection ]]; then route=branch_protection
  elif [[ "$endpoint" =~ ^commits/([a-f0-9]{40})/check-runs\?per_page=100$ ]]; then route=check_runs; params="$(jq -cn --arg sha "${BASH_REMATCH[1]}" '{commit_sha:$sha}')"; query='{"per_page":100}'; mode=pages
  elif [[ "$endpoint" =~ ^actions/workflows/([0-9]+)$ ]]; then route=workflow; params="$(jq -cn --argjson id "${BASH_REMATCH[1]}" '{workflow_id:$id}')"
  elif [[ "$endpoint" =~ ^actions/workflows/([0-9]+)/runs\?event=workflow_dispatch\&branch=([^&]+)\&per_page=100$ ]]; then
    route=workflow_runs; params="$(jq -cn --argjson id "${BASH_REMATCH[1]}" '{workflow_id:$id}')"
    query="$(jq -cn --arg branch "${BASH_REMATCH[2]}" '{event:"workflow_dispatch",branch:$branch,per_page:100}')"; mode=pages
  elif [[ "$endpoint" =~ ^actions/runs/([0-9]+)/jobs\?per_page=100$ ]]; then route=run_jobs; params="$(jq -cn --argjson id "${BASH_REMATCH[1]}" '{run_id:$id}')"; query='{"per_page":100}'; mode=pages
  elif [[ "$endpoint" =~ ^actions/runs/([0-9]+)/artifacts\?per_page=100$ ]]; then route=run_artifacts; params="$(jq -cn --argjson id "${BASH_REMATCH[1]}" '{run_id:$id}')"; query='{"per_page":100}'; mode=pages
  elif [[ "$endpoint" =~ ^actions/runs/([0-9]+)$ ]]; then route=run; params="$(jq -cn --argjson id "${BASH_REMATCH[1]}" '{run_id:$id}')"
  elif [[ "$endpoint" =~ ^git/ref/heads/(.+)$ ]]; then route=get_ref; params="$(jq -cn --arg branch "${BASH_REMATCH[1]}" '{branch:$branch}')"
  else fail "no typed HTTP route for endpoint: $endpoint"; fi
  transport_call "$route" GET "$target" "$params" "$query" null "$mode" || return $?
  [[ "$LAST_REQUEST_STATUS" != 404 || "$allow_missing" == true ]] || return 1
  [[ -n "$LAST_REQUEST_STATUS" ]] || fail "missing measured status for route $route"
  jq -e . "$target" >/dev/null || fail "invalid JSON for route $route"
}

require_listed() {
  local want="$1"
  jq -e --argjson want "$want" '
    def subset($small; $big):
      if ($small | type) == "object"
      then ($big | type) == "object" and ($small | to_entries | all(. as $kv | $big[$kv.key] != null and subset($kv.value; $big[$kv.key])))
      else $small == $big end;
    .outward_actions.canary.actions
    | any(.[]; subset($want; .)
               and (($want.inputs == null) or ((.inputs // {}) | del(.matrix_evidence)) == ($want.inputs | del(.matrix_evidence))))' "$REVISION_FREEZE" >/dev/null \
    || fail "action is outside the approved canary section: $want"
}

api_post_create_ref() {
  branch="$1"; sha="$2"; target="$3"; body="$(jq -cn --arg ref "refs/heads/$branch" --arg sha "$sha" '{ref:$ref,sha:$sha}')"
  require_listed "$(jq -cn --arg ref "refs/heads/$branch" --arg sha "$sha" '{action:"create_ref",ref:$ref,sha:$sha}')"
  transport_call create_ref POST "$target" '{}' '{}' "$body" one
  [[ "$LAST_REQUEST_STATUS" == 201 ]] || fail "create-ref returned HTTP $LAST_REQUEST_STATUS"
}

api_post_dispatch() {
  inputs="$1"; branch="$(printf '%s' "$FIXTURE_REF" | sed 's#^refs/heads/##')"
  require_listed "$(jq -cn --arg ref "$branch" --argjson inputs "$inputs" '{action:"workflow_dispatch",ref:$ref,inputs:($inputs|del(.matrix_evidence))}')"
  body="$(jq -cn --arg ref "$branch" --argjson inputs "$inputs" '{ref:$ref,inputs:$inputs}')"
  transport_call dispatch POST /dev/null '{}' '{}' "$body" one
  [[ "$LAST_REQUEST_STATUS" == 202 || "$LAST_REQUEST_STATUS" == 204 ]] || fail "dispatch returned HTTP $LAST_REQUEST_STATUS"
  [[ "$LAST_INPUT_KEY_COUNT" == "$(jq -r 'keys|length' <<<"$inputs")" ]] || fail 'transmitted dispatch input count differs from serializer'
  [[ "$LAST_INPUT_UNICODE_SCALARS" =~ ^[0-9]+$ && "$LAST_INPUT_UTF8_BYTES" =~ ^[0-9]+$ && "$LAST_INPUT_SHA256" =~ ^[a-f0-9]{64}$ ]] || fail 'transport did not retain exact dispatch input byte metrics'
  preserve_evidence
  jq --argjson inputs "$inputs" --argjson sequence "$LAST_REQUEST_SEQUENCE" \
    --argjson scalars "$LAST_INPUT_UNICODE_SCALARS" --argjson bytes "$LAST_INPUT_UTF8_BYTES" --arg digest "$LAST_INPUT_SHA256" \
    '.dispatch_inputs=$inputs | .dispatch_input_metrics += [{sequence:$sequence,key_count:($inputs|keys|length),unicode_scalars:$scalars,utf8_bytes:$bytes,sha256:$digest}]' \
    "$EVIDENCE" > "$EVIDENCE.tmp" && mv "$EVIDENCE.tmp" "$EVIDENCE"
}

download_no_follow() {
  url="$1"; target="$2"
  if [[ "$url" =~ ^https://api.github.com/repos/szTheory/sigra/actions/runs/([0-9]+)/logs$ ]]; then
    transport_call run_logs GET "$target" "$(jq -cn --argjson id "${BASH_REMATCH[1]}" '{run_id:$id}')" '{}' null download
  elif [[ "$url" =~ ^https://api.github.com/repos/szTheory/sigra/actions/artifacts/([0-9]+)/zip$ ]]; then
    transport_call artifact_zip GET "$target" "$(jq -cn --argjson id "${BASH_REMATCH[1]}" '{artifact_id:$id}')" '{}' null download
  else fail 'download URL did not match an approved typed route'; fi
  [[ "$LAST_REQUEST_STATUS" == 200 ]]
}

store_preflight() {
  local source="$1" destination="$2" label="$3" prior_ref prior_sha prior_status
  if [[ -e "$destination" ]]; then
    preserve_path "$destination" "preflight-$label"
    prior_ref="$PRESERVED_REF"
    prior_sha="$PRESERVED_SHA"
    prior_status="$PRESERVED_STATUS"
    preserve_evidence
    jq --arg path "$destination" --arg ref "$prior_ref" --arg sha "$prior_sha" --arg status "$prior_status" \
      --arg evidence_ref "$PRIOR_EVIDENCE_REF" --arg evidence_sha "$PRIOR_EVIDENCE_SHA" --arg evidence_status "$PRIOR_EVIDENCE_STATUS" \
      --arg evidence_path "${EVIDENCE#${ROOT}/}" \
      '.preserved_revisions += [{path:$path,ref:$ref,sha256:$sha,status:$status},{path:$evidence_path,ref:$evidence_ref,sha256:$evidence_sha,status:$evidence_status}]' \
      "$EVIDENCE" > "${EVIDENCE}.tmp" && mv "${EVIDENCE}.tmp" "$EVIDENCE"
  fi
  cp "$source" "$destination"
  cmp -s "$source" "$destination" || fail "fresh $label preflight did not read back exactly"
}

if [[ ! -e "$EVIDENCE" ]]; then
  CANARY_STARTED_EPOCH="$(date +%s)"
  jq -n --arg candidate "$CANDIDATE_SHA" --arg fixture_ref "$FIXTURE_REF" --arg fixture_sha "$FIXTURE_SHA" --arg blob "$FIXTURE_BLOB" \
    --arg check_source "$CHECK_SOURCE_SHA" --argjson started_epoch "$CANARY_STARTED_EPOCH" --argjson approval "$APPROVAL_RECORD" \
    '{schema_version:"sigra.phase253.hosted-replan-evidence/v2",repository:"szTheory/sigra",action_approval:($approval + {window_wall_start_epoch:$started_epoch}),expected:{candidate_sha:$candidate,fixture_ref:$fixture_ref,fixture_ref_state:"verified",workflow_id:259268962,workflow_path:".github/workflows/ci.yml",workflow_name:"Phase 253 Gate Canary",workflow_sha:$fixture_sha,workflow_blob:$blob,check_source_sha:$check_source,check_source_role:"server_parent"},preflight:{},budget:{accounted_max_requests:120,new_measured_max_requests:117,max_requests:117,request_count:0,max_jobs:45,actual_jobs:0,max_minutes:60,elapsed_seconds:0},transport_ledger:null,transport_receipts:[],dispatch_inputs:{},dispatch_input_metrics:[],preserved_revisions:[],scenarios:{},separate_verifier:{status:"pending"}}' > "$EVIDENCE"
else
  jq -e --argjson approval "$APPROVAL_RECORD" '.action_approval.section_sha256 == $approval.section_sha256' "$EVIDENCE" >/dev/null \
    || fail 'existing evidence is bound to a different approval'
  CANARY_STARTED_EPOCH="$(jq -r '.budget.started_epoch // 0' "$EVIDENCE")"
fi
if [[ -f "$REQUEST_LEDGER" ]]; then REQUEST_COUNT="$(jq -r '.transactions | length' "$REQUEST_LEDGER")"; else REQUEST_COUNT=0; fi
if (( CANARY_STARTED_EPOCH == 0 )); then CANARY_STARTED_EPOCH="$(date +%s)"; fi
record_budget

# Fresh read-only preflights share the immutable 117-new-request budget with all
# dispatches, polling, cancellation, artifact downloads, and failure logs.
RATE_RESPONSE="$(mktemp "$WORK_DIR/recovery-rate.XXXXXX")"
RULES_RESPONSE="$(mktemp "$WORK_DIR/recovery-rules.XXXXXX")"
WORKFLOW_RESPONSE="$(mktemp "$WORK_DIR/recovery-workflow.XXXXXX")"
LEGACY_RESPONSE="$(mktemp "$WORK_DIR/recovery-legacy-protection.XXXXXX")"
CHECK_RUNS_RESPONSE="$(mktemp "$WORK_DIR/recovery-check-runs.XXXXXX")"
# D-12 decision server-parent-identity: the candidate is created inside the window and no workflow runs on gsd/* refs,
# so native check sources come from the frozen server parent (identity only; success stays a PR-head rule).
[[ "$CHECK_SOURCE_SHA" =~ ^[a-f0-9]{40}$ ]] || fail 'frozen server-parent check source is missing or malformed'
api_get rate_limit "$RATE_RESPONSE"
CORE_LEFT="$(jq -r '.resources.core.remaining // 0' "$RATE_RESPONSE")"
(( CORE_LEFT > 250 )) || fail "GitHub core API budget is at or below 250 (remaining=$CORE_LEFT)"
# Ruleset listings contain names and IDs, not the active rules for main.
api_get 'rules/branches/main?per_page=100' "$RULES_RESPONSE"
api_get 'branches/main/protection' "$LEGACY_RESPONSE" true
api_get "commits/$CHECK_SOURCE_SHA/check-runs?per_page=100" "$CHECK_RUNS_RESPONSE"
api_get "actions/workflows/$WORKFLOW_ID" "$WORKFLOW_RESPONSE"
jq -e 'type == "array" and length <= 200' "$RULES_RESPONSE" >/dev/null || fail 'effective branch rules exceed the two-page completeness ceiling'
jq -e '.id == 259268962 and .path == ".github/workflows/ci.yml" and .state == "active"' "$WORKFLOW_RESPONSE" >/dev/null || fail 'registered workflow identity differs from fresh GitHub response'
jq -e '[.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] | sort == (["Library tests","Example unit smoke (ExUnit + ConnTest)","Install smoke (fresh phx.new + sigra.install)","Example HTTP smoke (boot + curl critical routes)","Example Playwright smoke (full lifecycle)"] | sort)' "$RULES_RESPONSE" >/dev/null || fail 'fresh effective required-check names differ from the frozen five-name contract'
RULE_PAGE_COUNT="$(jq -r '[.transactions[] | select(.route_id=="rules_main")] | length' "$REQUEST_LEDGER")"
[[ "$RULE_PAGE_COUNT" == 1 || "$RULE_PAGE_COUNT" == 2 ]] || fail 'fresh effective rules do not have one or two measured pages'
RULE_LAST_COUNT="$(jq -r '[.transactions[] | select(.route_id=="rules_main")][-1].response_body_base64 // empty' "$REQUEST_LEDGER" | base64 -d | jq 'length')"
(( RULE_LAST_COUNT < 100 )) || fail 'last effective rules page is full; terminal completeness is unknown'
FIRST_RULE_COUNT="$(jq -r '[.transactions[] | select(.route_id=="rules_main")][0].response_body_base64 // empty' "$REQUEST_LEDGER" | base64 -d | jq 'length')"
if [[ "$FIRST_RULE_COUNT" == 100 ]]; then [[ "$RULE_PAGE_COUNT" == 2 ]] || fail 'full first effective rules page requires a charged second page'; fi
jq -e 'type=="object" and ((.required_status_checks // {})|type=="object")' "$LEGACY_RESPONSE" >/dev/null || fail 'legacy branch-protection response is malformed'
jq -e 'type=="object" and (.check_runs|type=="array")' "$CHECK_RUNS_RESPONSE" >/dev/null || fail 'native check-run source response is incomplete'
for check_name in "Library tests" "Example unit smoke (ExUnit + ConnTest)" "Install smoke (fresh phx.new + sigra.install)" "Example HTTP smoke (boot + curl critical routes)" "Example Playwright smoke (full lifecycle)"; do
  jq -e --arg name "$check_name" --arg sha "$CHECK_SOURCE_SHA" '([.check_runs[] | select(.name==$name)] | length == 1) and ([.check_runs[] | select(.name==$name and .head_sha==$sha and (.app.id|type=="number") and .app.id > 0 and (.app.slug|type=="string") and .app.slug != "" and (.html_url|type=="string") and (.html_url|startswith("https://")))] | length == 1)' "$CHECK_RUNS_RESPONSE" >/dev/null \
    || fail "native check-run app/source identity is missing or duplicated: $check_name"
done
store_preflight "$RATE_RESPONSE" "$RATE_SOURCE" rate
store_preflight "$RULES_RESPONSE" "$RULES_SOURCE" rules
store_preflight "$WORKFLOW_RESPONSE" "$WORKFLOW_SOURCE" workflow
store_preflight "$LEGACY_RESPONSE" "$PHASE_DIR/253-RECOVERY-CANARY-PREFLIGHT-legacy-protection.json" legacy-protection
store_preflight "$CHECK_RUNS_RESPONSE" "$PHASE_DIR/253-RECOVERY-CANARY-PREFLIGHT-check-runs.json" check-runs
preserve_evidence
jq --slurpfile rate "$RATE_RESPONSE" --slurpfile rules "$RULES_RESPONSE" --slurpfile workflow "$WORKFLOW_RESPONSE" \
  --slurpfile legacy "$LEGACY_RESPONSE" --slurpfile check_runs "$CHECK_RUNS_RESPONSE" \
  --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" \
  --arg evidence_path "${EVIDENCE#${ROOT}/}" \
  '.preflight={initial_rate_limit:$rate[0],effective_rules:$rules[0],legacy_protection:$legacy[0],native_check_runs:$check_runs[0],registered_workflow:$workflow[0]} | .preserved_revisions += [{path:$evidence_path,ref:$ref,sha256:$sha,status:$status}]' \
  "$EVIDENCE" > "${EVIDENCE}.tmp" && mv "${EVIDENCE}.tmp" "$EVIDENCE"
record_budget
RATE_SOURCE="$PHASE_DIR/253-RECOVERY-CANARY-PREFLIGHT-rate.json"
RULES_SOURCE="$PHASE_DIR/253-RECOVERY-CANARY-PREFLIGHT-effective-rules.json"
WORKFLOW_SOURCE="$PHASE_DIR/253-RECOVERY-CANARY-PREFLIGHT-registered-workflow.json"
python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --mode preflight --evidence "$EVIDENCE" \
  || fail 'independent measured transport and effective check-source verification failed'
if [[ "$PREFLIGHT_ONLY" == true ]]; then
  echo "ci-gate-canary: fresh preflight retained (requests=$REQUEST_COUNT/$MAX_REQUESTS; no ref mutation or dispatch)"
  exit 0
fi

RATE_NOW="$RATE_SOURCE"
CORE_LEFT="$(jq -r '.resources.core.remaining // 0' "$RATE_NOW")"
(( CORE_LEFT > 250 )) || fail "GitHub core API budget is at or below 250 (remaining=$CORE_LEFT)"

if [[ -z "$CANDIDATE_SHA" ]]; then
  CANDIDATE_SHA="$(git rev-parse HEAD)"
  BRANCH_SUFFIX="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  FIXTURE_REF="refs/heads/gsd/253-replan-canary-fixture-$BRANCH_SUFFIX"
  FIXTURE_BLOB="$(git hash-object -w "$FIXTURE")"
  TMP_INDEX="$(mktemp "$WORK_DIR/index.XXXXXX")"
  rm -f "$TMP_INDEX"
  export GIT_INDEX_FILE="$TMP_INDEX"
  git read-tree "$CANDIDATE_SHA"
  git update-index --add --cacheinfo "100644,$FIXTURE_BLOB,.github/workflows/ci.yml"
  FIXTURE_TREE="$(git write-tree)"
  FIXTURE_SHA="$(printf 'Phase 253 Gate Canary fixture\n' | git commit-tree "$FIXTURE_TREE" -p "$CANDIDATE_SHA")"
  unset GIT_INDEX_FILE
  rm -f "$TMP_INDEX"
  git update-ref "$FIXTURE_REF" "$FIXTURE_SHA" 0000000000000000000000000000000000000000 || fail 'create-only local fixture ref already exists'
  [[ "$(git rev-parse "$FIXTURE_REF")" == "$FIXTURE_SHA" ]] || fail 'sealed local fixture ref did not read back'
  FIXTURE_BRANCH="${FIXTURE_REF#refs/heads/}"
  CANARY_STARTED_EPOCH="$(date +%s)"
  jq -n --slurpfile rate "$RATE_SOURCE" --slurpfile rules "$RULES_SOURCE" --slurpfile workflow "$WORKFLOW_SOURCE" \
    --arg candidate "$CANDIDATE_SHA" --arg fixture_ref "$FIXTURE_REF" --arg fixture_sha "$FIXTURE_SHA" --arg blob "$FIXTURE_BLOB" \
    --arg check_source "$CHECK_SOURCE_SHA" --argjson request_count "$REQUEST_COUNT" --argjson started_epoch "$CANARY_STARTED_EPOCH" \
    '{schema_version:"sigra.phase253.hosted-replan-evidence/v2",repository:"szTheory/sigra",expected:{candidate_sha:$candidate,fixture_ref:$fixture_ref,fixture_ref_state:"verified",workflow_id:259268962,workflow_path:".github/workflows/ci.yml",workflow_name:"Phase 253 Gate Canary",workflow_sha:$fixture_sha,workflow_blob:$blob,check_source_sha:$check_source,check_source_role:"server_parent"},preflight:{initial_rate_limit:$rate[0],effective_rules:$rules[0],registered_workflow:$workflow[0]},budget:{accounted_max_requests:120,new_measured_max_requests:117,max_requests:117,request_count:$request_count,max_jobs:45,max_minutes:60,started_epoch:$started_epoch,actual_jobs:0,elapsed_seconds:0},origin:{kind:"measured-v2"},transport_ledger:null,transport_receipts:[],dispatch_inputs:{},dispatch_input_metrics:[],preserved_revisions:[],scenarios:{},separate_verifier:{status:"pending"}}' > "$EVIDENCE"
  preserve_evidence
  jq --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" --arg path "${EVIDENCE#${ROOT}/}" \
    '.preserved_revisions += [{path:$path,ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "${EVIDENCE}.tmp"
  mv "${EVIDENCE}.tmp" "$EVIDENCE"
  git cat-file -e "$FIXTURE_SHA:.github/workflows/ci.yml" || fail 'fixture workflow blob is not in the immutable ref'
  FOUND_WORKFLOW_BLOB="$(git rev-parse "$FIXTURE_SHA:.github/workflows/ci.yml")"
  [[ "$FOUND_WORKFLOW_BLOB" == "$FIXTURE_BLOB" ]] || fail 'fixture workflow blob identity changed'
  preserve_evidence
  jq --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" --arg path "${EVIDENCE#${ROOT}/}" \
    '.expected.fixture_ref_state="verified" | .preserved_revisions += [{path:$path,ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "${EVIDENCE}.tmp"
  mv "${EVIDENCE}.tmp" "$EVIDENCE"
else
  FOUND_WORKFLOW_BLOB="$(git rev-parse "$FIXTURE_SHA:.github/workflows/ci.yml" 2>/dev/null || true)"
  [[ "$FOUND_WORKFLOW_BLOB" == "$FIXTURE_BLOB" ]] || fail 'saved fixture source identities do not resolve locally'
fi
record_budget

FIXTURE_BRANCH="${FIXTURE_REF#refs/heads/}"
publish_fixture_ref
if [[ "$PUBLISH_REF_ONLY" == true ]]; then
  echo "ci-gate-canary: remote fixture ref verified (requests=$REQUEST_COUNT/$MAX_REQUESTS; no workflow dispatch)"
  exit 0
fi
if [[ "$ALL_REMAINING" == true ]]; then
  SCENARIOS=(docs-only actual-failure missing-seam unexpected-skip cancelled)
else
  SCENARIOS=("$SCENARIO")
fi

dispatch_scenario() {
  local case_name="$1" run_list run_id run_json jobs_json artifacts_json artifact_id archive receipt_tmp reserve current_jobs new_jobs
  jq -e --arg name "$case_name" '.scenarios[$name] == null' "$EVIDENCE" >/dev/null || fail "scenario already has a receipt: $case_name"
  current_jobs="$(jq -r '.budget.actual_jobs // 0' "$EVIDENCE")"
  (( current_jobs + 6 <= MAX_JOBS )) || fail "dispatch would exceed the $MAX_JOBS-job ceiling"
  local input_json
  input_json="$(jq -cn --arg scenario "$case_name" --arg candidate "$CANDIDATE_SHA" --arg fixture "$FIXTURE_SHA" --arg blob "$FIXTURE_BLOB" \
    '{scenario:$scenario,candidate_sha:$candidate,fixture_sha:$fixture,fixture_blob:$blob}')"
  validate_dispatch_inputs "$input_json"
  api_post_dispatch "$input_json" || fail "dispatch failed for $case_name"
  record_budget
  run_list="$(mktemp "$WORK_DIR/runs.XXXXXX")"
  api_get "actions/workflows/$WORKFLOW_ID/runs?event=workflow_dispatch&branch=$FIXTURE_BRANCH&per_page=100" "$run_list"
  run_id="$(jq -r --arg branch "$FIXTURE_BRANCH" --arg sha "$FIXTURE_SHA" --arg title "Phase 253 Gate Canary / $case_name /" '[.workflow_runs[] | select(.workflow_id==259268962 and .head_branch==$branch and .head_sha==$sha and .event=="workflow_dispatch" and (.display_title|startswith($title)))] | sort_by(.run_number) | last | .id // empty' "$run_list")"
  [[ -n "$run_id" ]] || fail "dispatch receipt not found for $case_name"
  if [[ "$case_name" == cancelled ]]; then
    jq -e --argjson run_id "$run_id" --arg branch "$FIXTURE_BRANCH" --arg sha "$FIXTURE_SHA" \
      '.workflow_runs[] | select(.id==$run_id and .event=="workflow_dispatch" and .head_branch==$branch and .head_sha==$sha and .workflow_id==259268962)' \
      "$run_list" >/dev/null || fail 'refusing to cancel a run whose fixture identity is not exact'
    require_listed '{"action":"cancel_run","scenario":"cancelled"}'
    transport_call cancel_run POST /dev/null "$(jq -cn --argjson id "$run_id" '{run_id:$id}')" '{}' null one || fail 'identified canary cancellation failed'
    [[ "$LAST_REQUEST_STATUS" == 202 ]] || fail "identified canary cancellation returned HTTP $LAST_REQUEST_STATUS"
  fi
  run_json="$(mktemp "$WORK_DIR/run.XXXXXX")"
  TERMINAL_RUN_JSON="$run_json"
  local watch_status
  if watch_run "$run_id" "$case_name"; then watch_status=0; else watch_status=$?; fi
  record_budget
  (( watch_status != 124 )) || fail "watch exceeded its reserved four-minute window for $case_name"
  (( watch_status != 77 )) || fail "watch received a GitHub 403/429 rate-limit response; stop until reset"
  jobs_json="$(mktemp "$WORK_DIR/jobs.XXXXXX")"
  artifacts_json="$(mktemp "$WORK_DIR/artifacts.XXXXXX")"
  api_get "actions/runs/$run_id/jobs?per_page=100" "$jobs_json"
  api_get "actions/runs/$run_id/artifacts?per_page=100" "$artifacts_json"
  local run_attempt conclusion
  run_attempt="$(jq -r '.run_attempt' "$run_json")"
  conclusion="$(jq -r '.conclusion // ""' "$run_json")"
  if [[ "$conclusion" == failure ]]; then
    failed_logs="$(mktemp "$WORK_DIR/failed-logs.XXXXXX")"
    download_no_follow "https://api.github.com/repos/$REPO/actions/runs/$run_id/logs" "$failed_logs" 0 || fail "failed-log retrieval failed for run $run_id"
  fi
  current_jobs="$(jq -r '.budget.actual_jobs // 0' "$EVIDENCE")"
  new_jobs="$(jq -r '[.jobs[] | select(.conclusion != "skipped")] | length' "$jobs_json")"
  (( current_jobs + new_jobs <= MAX_JOBS )) || fail "hosted execution count exceeded $MAX_JOBS jobs"
  receipt_tmp="$(mktemp "$WORK_DIR/receipt.XXXXXX")"
  if [[ "$case_name" == cancelled ]]; then
    jq -n --slurpfile run "$run_json" --slurpfile jobs "$jobs_json" --slurpfile artifacts "$artifacts_json" \
      --arg run_id "$run_id" --argjson attempt "$run_attempt" '{run_id:$run_id,run_attempt:$attempt,run:$run[0],jobs:$jobs[0],artifacts:$artifacts[0]}' > "$receipt_tmp"
  else
    artifact_id="$(jq -r --arg name "gate-canary-$case_name-$run_id-$run_attempt" '[.artifacts[] | select(.name==$name and .expired==false and (.size_in_bytes|type)=="number" and .size_in_bytes<=2097152)] | if length==1 then .[0].id else empty end' "$artifacts_json")"
    [[ -n "$artifact_id" ]] || fail "expected same-run retained artifact missing for $case_name"
    archive="$(mktemp "$WORK_DIR/artifact.XXXXXX")"
    download_no_follow "https://api.github.com/repos/$REPO/actions/artifacts/$artifact_id/zip" "$archive" "$MAX_ARTIFACT_COMPRESSED" || fail "artifact download failed for $case_name"
    local artifact_data
    artifact_data="$(python3 "$PUBLISHER" --extract-canary-artifact "$archive")" || fail "retained artifact is malformed for $case_name"
    jq -n --slurpfile run "$run_json" --slurpfile jobs "$jobs_json" --slurpfile artifacts "$artifacts_json" \
      --arg run_id "$run_id" --argjson attempt "$run_attempt" --arg artifact_id "$artifact_id" --argjson retained "$artifact_data" \
      '{run_id:$run_id,run_attempt:$attempt,run:$run[0],jobs:$jobs[0],artifacts:$artifacts[0],retained_artifact:{artifact_id:$artifact_id,archive_sha256:$retained.archive_sha256,archive_base64:$retained.archive_base64,files:{"canary-result.json":$retained.file}}}' > "$receipt_tmp"
  fi
  preserve_evidence
  preserve_evidence
  jq --arg scenario "$case_name" --slurpfile receipt "$receipt_tmp" --argjson count "$REQUEST_COUNT" --argjson jobs "$((current_jobs + new_jobs))" --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" --arg path "${EVIDENCE#${ROOT}/}" \
    '.scenarios[$scenario]=$receipt[0] | .budget.request_count=$count | .budget.actual_jobs=$jobs | .preserved_revisions += [{path:$path,ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "${EVIDENCE}.tmp"
  mv "${EVIDENCE}.tmp" "$EVIDENCE"
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --mode canary --evidence "$EVIDENCE" --scenario "$case_name"
  record_budget
  [[ "$conclusion" == success && "$case_name" == actual-failure || "$conclusion" == success && "$case_name" == missing-seam || "$conclusion" == success && "$case_name" == unexpected-skip ]] && fail "negative source unexpectedly concluded success: $case_name"
}

for current_scenario in "${SCENARIOS[@]}"; do dispatch_scenario "$current_scenario"; done

if [[ "$ALL_REMAINING" == true ]]; then
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --mode canary --evidence "$EVIDENCE" --scenario sources || fail 'source matrix is incomplete before separate verifier dispatch'
  MATRIX_B64="$(python3 "$PUBLISHER" --compact-matrix "$EVIDENCE")" || fail 'compact verifier matrix exceeds its bounded dispatch input'
  current_jobs="$(jq -r '.budget.actual_jobs // 0' "$EVIDENCE")"
  (( current_jobs + 1 <= MAX_JOBS )) || fail "separate verifier would exceed the $MAX_JOBS-job ceiling"
  input_json="$(jq -cn --arg candidate "$CANDIDATE_SHA" --arg fixture "$FIXTURE_SHA" --arg blob "$FIXTURE_BLOB" --arg matrix "$MATRIX_B64" \
    '{scenario:"verifier",candidate_sha:$candidate,fixture_sha:$fixture,fixture_blob:$blob,matrix_evidence:$matrix}')"
  validate_dispatch_inputs "$input_json"
  api_post_dispatch "$input_json" || fail 'separate verifier dispatch failed'
  record_budget
  # The verifier run is found by its distinct workflow display title and exact fixture identity.
  VERIFY_LIST="$(mktemp "$WORK_DIR/verifier-runs.XXXXXX")"
  api_get "actions/workflows/$WORKFLOW_ID/runs?event=workflow_dispatch&branch=$FIXTURE_BRANCH&per_page=100" "$VERIFY_LIST"
  VERIFY_ID="$(jq -r --arg branch "$FIXTURE_BRANCH" --arg sha "$FIXTURE_SHA" '[.workflow_runs[] | select(.head_branch==$branch and .head_sha==$sha and .event=="workflow_dispatch" and (.display_title|startswith("Phase 253 Gate Canary / verifier /")))] | sort_by(.run_number) | last | .id // empty' "$VERIFY_LIST")"
  [[ -n "$VERIFY_ID" ]] || fail 'separate verifier run was not created'
  VERIFY_RUN="$(mktemp "$WORK_DIR/verifier-run.XXXXXX")"
  TERMINAL_RUN_JSON="$VERIFY_RUN"
  if watch_run "$VERIFY_ID" 'separate verifier'; then watch_status=0; else watch_status=$?; fi
  (( watch_status != 124 )) || fail 'separate verifier watch exceeded its reservation'
  (( watch_status != 77 )) || fail 'separate verifier watch received a GitHub 403/429; stop until reset'
  VERIFY_JOBS="$(mktemp "$WORK_DIR/verifier-jobs.XXXXXX")"
  api_get "actions/runs/$VERIFY_ID" "$VERIFY_RUN"
  api_get "actions/runs/$VERIFY_ID/jobs?per_page=100" "$VERIFY_JOBS"
  new_jobs="$(jq -r '[.jobs[] | select(.conclusion != "skipped")] | length' "$VERIFY_JOBS")"
  (( current_jobs + new_jobs <= MAX_JOBS )) || fail "separate verifier exceeded the $MAX_JOBS-job ceiling"
  preserve_evidence
  jq --argjson id "$VERIFY_ID" --slurpfile run "$VERIFY_RUN" --slurpfile jobs "$VERIFY_JOBS" --arg ref "$PRIOR_EVIDENCE_REF" --arg sha "$PRIOR_EVIDENCE_SHA" --arg status "$PRIOR_EVIDENCE_STATUS" --arg path "${EVIDENCE#${ROOT}/}" \
    '.separate_verifier={status:"passed",run_id:($id|tostring),job_conclusion:$run[0].conclusion,run:$run[0],jobs:$jobs[0]} | .budget.actual_jobs+=([$jobs[0].jobs[] | select(.conclusion != "skipped")] | length) | .budget.request_count+=(0) | .preserved_revisions += [{path:$path,ref:$ref,sha256:$sha,status:$status}]' "$EVIDENCE" > "${EVIDENCE}.tmp"
  mv "${EVIDENCE}.tmp" "$EVIDENCE"
  python3 "$ROOT/scripts/ci/ci-hosted-gate-verify.py" --mode canary --evidence "$EVIDENCE" --scenario matrix
fi

record_budget
[[ "$REQUEST_COUNT" -le "$MAX_REQUESTS" ]] || fail 'request budget exceeded'
echo "ci-gate-canary: retained evidence at $EVIDENCE (requests=$REQUEST_COUNT/$MAX_REQUESTS; job ceiling=$MAX_JOBS; time ceiling=${MAX_MINUTES}m)"
