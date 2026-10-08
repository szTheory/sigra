#!/usr/bin/env bash
# Hermetic workflow-run, PR, and ci-gate identity contract for the guarded release merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ci/release-candidate-preflight.sh"
CI_WORKFLOW="${ROOT}/.github/workflows/ci.yml"
MERGE_WORKFLOW="${ROOT}/.github/workflows/release-pr-automerge.yml"
REPOSITORY="szTheory/sigra"
EXPECTED_SHA="0123456789abcdef0123456789abcdef01234567"
OTHER_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: preflight helper missing at $SCRIPT" >&2
  exit 2
fi

write_valid_fixtures() {
  cat > "$TMP/event.json" <<JSON
{"repository":"$REPOSITORY","workflow_name":"CI","run_id":12345,"event":"push","head_branch":"release-please--branches--main","head_sha":"$EXPECTED_SHA","conclusion":"success"}
JSON
  cat > "$TMP/run.json" <<JSON
{"repository":"$REPOSITORY","workflowName":"CI","databaseId":12345,"event":"push","headBranch":"release-please--branches--main","headSha":"$EXPECTED_SHA","conclusion":"success","url":"https://github.com/$REPOSITORY/actions/runs/12345"}
JSON
  cat > "$TMP/prs.json" <<JSON
[{"number":224,"state":"OPEN","title":"chore(main): release 1.6.0","baseRefName":"main","headRefName":"release-please--branches--main","headRefOid":"$EXPECTED_SHA","headRepository":{"nameWithOwner":"$REPOSITORY"},"labels":[{"name":"autorelease: pending"}],"url":"https://github.com/$REPOSITORY/pull/224"}]
JSON
  cat > "$TMP/jobs.json" <<'JSON'
[{"name":"ci-gate","conclusion":"success"}]
JSON
}

run_preflight() {
  set +e
  OUT="$(bash "$SCRIPT" --repository "$REPOSITORY" \
    --event-run "$TMP/event.json" --queried-run "$TMP/run.json" \
    --pull-requests "$TMP/prs.json" --gate-jobs "$TMP/jobs.json" 2>&1)"
  RC=$?
  set -e
}

echo "Test A: matching completed push run and one current PR head -> PASS"
write_valid_fixtures
run_preflight
if [[ "$RC" -eq 0 ]] && jq -e --arg sha "$EXPECTED_SHA" '.verdict == "PASS" and .pr_number == 224 and .head_sha == $sha' >/dev/null 2>&1 <<<"$OUT"; then
  pass "matching event, queried run, PR head, and ci-gate are accepted"
else
  fail "matching identity rejected (rc=$RC): $OUT"
fi

echo "Test B: synthetic pull_request workflow run -> rejected"
write_valid_fixtures
jq '.event = "pull_request"' "$TMP/event.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/event.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "pull_request run is rejected"; else fail "synthetic pull_request run accepted"; fi

echo "Test C: queried run head differs from event/PR -> rejected"
write_valid_fixtures
jq --arg sha "$OTHER_SHA" '.headSha = $sha' "$TMP/run.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/run.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "mismatched queried run head is rejected"; else fail "mismatched queried run head accepted"; fi

echo "Test D: missing run head identity -> rejected"
write_valid_fixtures
jq 'del(.headSha)' "$TMP/run.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/run.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "missing queried run head is rejected"; else fail "missing queried run head accepted"; fi

echo "Test E: multiple matching open candidates -> rejected"
write_valid_fixtures
jq '.[0].number = 225' "$TMP/prs.json" > "$TMP/changed.json"
jq -s '.[0] + .[1]' "$TMP/prs.json" "$TMP/changed.json" > "$TMP/prs.json.tmp" && mv "$TMP/prs.json.tmp" "$TMP/prs.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "multiple open release candidates are rejected"; else fail "multiple candidates were treated as one"; fi

echo "Test F: CI push trigger includes exactly the Release Please branch and preserves ci-gate"
if grep -q 'branches: \[main, release-please--branches--main\]' "$CI_WORKFLOW" \
   && grep -q '^  pull_request:' "$CI_WORKFLOW" && grep -q '^  ci-gate:' "$CI_WORKFLOW"; then
  pass "push target added without removing pull_request or ci-gate"
else
  fail "CI event contract is missing the exact release branch or existing gate"
fi

echo "Test G: merge workflow consumes completed CI workflow_run on the Release Please branch"
if grep -q 'workflow_run:' "$MERGE_WORKFLOW" \
   && grep -q 'workflows: \["CI"\]' "$MERGE_WORKFLOW" \
   && grep -q 'release-please--branches--main' "$MERGE_WORKFLOW" \
   && grep -q 'release-candidate-preflight.sh' "$MERGE_WORKFLOW"; then
  pass "trusted workflow_run route is present"
else
  fail "workflow_run route or preflight helper call is missing"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "release-candidate-preflight.test: FAIL"
  exit 1
fi
echo "release-candidate-preflight.test: PASS"
