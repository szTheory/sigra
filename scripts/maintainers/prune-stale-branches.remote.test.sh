#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="${ROOT_DIR}/scripts/maintainers/prune-stale-branches.sh"
COORDINATOR="${ROOT_DIR}/scripts/maintainers/repo-mutation-coordinator.sh"
PHASE_244="${ROOT_DIR}/.planning/phases/244-playwright-test-1-59-1-1-62-1-alone"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

# Production sees only GitHub origins. This fixture-only shim reports the
# canonical URL for a configured local bare origin while forwarding all real
# Git fetch/push operations to the disposable repository.
FIXTURE_GIT_DIR="${TEMP_DIR}/fixture-git-bin"
mkdir -p "$FIXTURE_GIT_DIR"
PRUNE_TEST_REAL_GIT="$(command -v git)"
cat > "${FIXTURE_GIT_DIR}/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PRUNE_TEST_REMAP_LOCAL_ORIGIN:-0}" == 1 && " $* " == *" remote get-url "* ]]; then
  actual="$("$PRUNE_TEST_REAL_GIT" "$@")"
  if [[ -n "${PRUNE_TEST_LOCAL_ORIGIN:-}" && "$actual" == "$PRUNE_TEST_LOCAL_ORIGIN" ]]; then
    printf '%s\n' 'https://github.com/szTheory/sigra.git'
    exit 0
  fi
fi
exec "$PRUNE_TEST_REAL_GIT" "$@"
GIT
chmod +x "${FIXTURE_GIT_DIR}/git"
export PRUNE_TEST_REAL_GIT PRUNE_TEST_REMAP_LOCAL_ORIGIN=1
export PATH="${FIXTURE_GIT_DIR}:$PATH"

node --test "${ROOT_DIR}/scripts/maintainers/prune-stale-branches-pr-audit.test.mjs"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ "$(sed -n 's/^status: //p' "${PHASE_244}/244-VERIFICATION.md" | head -1)" == passed ]] \
  || fail 'D-01: Phase 244 verification is not passed'
[[ -f "${ROOT_DIR}/.planning/todos/resolved/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md" ]] \
  || fail 'D-01: Phase 242 blocker lacks resolved disposition'
grep -q 'deferred_missing_live_candidate_with_measured_drift' "${PHASE_244}/244-PLAYWRIGHT-EVIDENCE.json" \
  || fail 'D-01: Phase 244 PR #213 disposition is absent'
grep -q 'PR #283' "${PHASE_244}/244-03-SUMMARY.md" \
  || fail 'D-01: Phase 244 PR #283 disposition is absent'

BIN_DIR="${TEMP_DIR}/bin"
mkdir -p "$BIN_DIR"
cat > "${BIN_DIR}/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GH_CALL_LOG"
if [[ "$1 $2" == 'auth status' ]]; then
  [[ "${PRUNE_GH_SCENARIO:-valid}" != auth-fail ]] || { echo 'not logged in' >&2; exit 1; }
  exit 0
fi
if [[ "$1 $2" == 'pr list' ]]; then
  case "${PRUNE_GH_SCENARIO:-valid}" in
    list-fail) echo 'HTTP 503' >&2; exit 1 ;;
    rate-limit) echo 'HTTP 429 rate limit' >&2; exit 1 ;;
    changing-pr)
      calls=0
      [[ ! -f "$PR_CALL_COUNT_FILE" ]] || calls="$(cat "$PR_CALL_COUNT_FILE")"
      calls=$((calls + 1))
      printf '%s\n' "$calls" > "$PR_CALL_COUNT_FILE"
      if (( calls == 1 )); then cat "$PR_JSON_PATH"; else cat "$PR_CHANGED_JSON_PATH"; fi
      ;;
    *) cat "$PR_JSON_PATH" ;;
  esac
  exit 0
fi
if [[ "$1" == api && "$2" == user* ]]; then
  printf '%s\n' '{"login":"fixture-user"}'
  exit 0
fi
if [[ "$1" == api && "$2" == repos/szTheory/sigra* ]]; then
  if [[ "${PRUNE_GH_SCENARIO:-valid}" == push-denied ]]; then
    printf '%s\n' '{"full_name":"szTheory/sigra","permissions":{"push":false}}'
  else
    printf '%s\n' '{"full_name":"szTheory/sigra","permissions":{"push":true}}'
  fi
  exit 0
fi
echo 'unexpected gh command' >&2
exit 2
GH
chmod +x "${BIN_DIR}/gh"
export PATH="${BIN_DIR}:$PATH"
export GH_CALL_LOG="${TEMP_DIR}/gh-calls.log"
: > "$GH_CALL_LOG"
export PR_CALL_COUNT_FILE="${TEMP_DIR}/pr-call-count"

cat > "${TEMP_DIR}/prs.json" <<'JSON'
[
  {"number":219,"state":"OPEN","headRefName":"gsd/238-generated-auth-runtime-proof-evidence","baseRefName":"main","headRefOid":"1111111111111111111111111111111111111111","baseRefOid":"2222222222222222222222222222222222222222"}
]
JSON
export PR_JSON_PATH="${TEMP_DIR}/prs.json"
CAPTURE="${TEMP_DIR}/capture.json"
bash "$HELPER" capture-prs --repo "$ROOT_DIR" --output "$CAPTURE"
jq -e '.repository == "szTheory/sigra" and .limit == 1000 and (.pull_requests | length) == 1 and .pull_requests[0].number == 219 and .pull_requests[0].headRefName == "gsd/238-generated-auth-runtime-proof-evidence"' "$CAPTURE" >/dev/null \
  || fail 'complete PR capture did not preserve the head/base identity'

python3 - "$TEMP_DIR/truncated.json" <<'PY'
import json, sys
row = {"number": 1, "state": "OPEN", "headRefName": "h", "baseRefName": "main", "headRefOid": "1" * 40, "baseRefOid": "2" * 40}
with open(sys.argv[1], "w") as f:
    json.dump([dict(row, number=i + 1) for i in range(1000)], f)
PY
export PR_JSON_PATH="${TEMP_DIR}/truncated.json"
export PRUNE_GH_SCENARIO=valid
if bash "$HELPER" capture-prs --repo "$ROOT_DIR" --output "${TEMP_DIR}/truncated-capture.json" >/dev/null 2>&1; then
  fail 'a PR result at the explicit limit was accepted as complete'
fi
[[ ! -e "${TEMP_DIR}/truncated-capture.json" ]] || fail 'truncated PR output was written as a valid capture'

cat > "${TEMP_DIR}/malformed.json" <<'JSON'
[{"number":7,"state":"OPEN","headRefName":"feature","baseRefName":"main","headRefOid":"1111111111111111111111111111111111111111","baseRefOid":null}]
JSON
export PR_JSON_PATH="${TEMP_DIR}/malformed.json"
if bash "$HELPER" capture-prs --repo "$ROOT_DIR" --output "${TEMP_DIR}/malformed-capture.json" >/dev/null 2>&1; then
  fail 'a PR row with an incomplete base OID was accepted'
fi
cat > "${TEMP_DIR}/duplicate.json" <<'JSON'
[{"number":8,"state":"OPEN","headRefName":"feature-a","baseRefName":"main","headRefOid":"1111111111111111111111111111111111111111","baseRefOid":"2222222222222222222222222222222222222222"},{"number":8,"state":"OPEN","headRefName":"feature-b","baseRefName":"main","headRefOid":"3333333333333333333333333333333333333333","baseRefOid":"2222222222222222222222222222222222222222"}]
JSON
export PR_JSON_PATH="${TEMP_DIR}/duplicate.json"
if bash "$HELPER" capture-prs --repo "$ROOT_DIR" --output "${TEMP_DIR}/duplicate-capture.json" >/dev/null 2>&1; then
  fail 'a PR result with duplicate identities was accepted'
fi

BARE="${TEMP_DIR}/origin.git"
WORK="${TEMP_DIR}/origin-work"
export PRUNE_TEST_LOCAL_ORIGIN="$BARE"
git init -q --bare --initial-branch=main "$BARE"
git clone -q --shared "$ROOT_DIR" "$WORK"
git -C "$WORK" config user.name 'GSD Fixture'
git -C "$WORK" config user.email 'gsd-fixture@example.invalid'
git -C "$WORK" config gc.auto 0
git -C "$WORK" config maintenance.auto false
git -C "$WORK" checkout -q -b main
READINESS_SOURCE_BASE="$(git -C "$WORK" rev-parse HEAD)"
READINESS_SOURCES=(
  .planning/state.json
  .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-VERIFICATION.md
  .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json
  .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-04-SUMMARY.md
  .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-08-SUMMARY.md
  .planning/todos/resolved/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md
  .planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-SUMMARY.md
  .planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-ESCALATED.log
  .planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md
)
for source in "${READINESS_SOURCES[@]}"; do
  mkdir -p "${WORK}/$(dirname "$source")"
  cp "${ROOT_DIR}/${source}" "${WORK}/${source}"
done
perl -0pi -e "s/^source_commit:.*/source_commit: ${READINESS_SOURCE_BASE}/m" \
  "${WORK}/.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-SUMMARY.md" \
  "${WORK}/.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md"
git -C "$WORK" add "${READINESS_SOURCES[@]}"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit Phase 244 readiness sources'
git -C "$WORK" remote set-url origin "$BARE"
# The shared source checkout carries live tracking refs; strip this D-04 name
# from the isolated fixture so the absent-only publication case stays absent.
git -C "$WORK" update-ref -d refs/remotes/origin/safety/local-main-before-release-cleanup-20260831 2>/dev/null || true
git -C "$WORK" tag -d archive/local-main-pre-235-recovery >/dev/null 2>&1 || true
git -C "$WORK" tag -a archive/recovery -m 'fixture annotated tag'
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false push -q origin refs/heads/main:refs/heads/main
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false push -q origin refs/tags/archive/recovery:refs/tags/archive/recovery
bash "$COORDINATOR" install --repo "$WORK"
ORIGIN_CAPTURE="${TEMP_DIR}/origin.tsv"
bash "$HELPER" capture-origin --repo "$WORK" --output "$ORIGIN_CAPTURE"
TAG_OID="$(git -C "$WORK" rev-parse refs/tags/archive/recovery)"
PEELED_OID="$(git -C "$WORK" rev-parse 'refs/tags/archive/recovery^{}')"
grep -Fq $'refs/tags/archive/recovery\t'"$TAG_OID"$'\ttag\t'"$PEELED_OID"$'\tcommit\t-' "$ORIGIN_CAPTURE" \
  || fail 'origin capture lost the annotated tag object or peeled target'
grep -Fq $'refs/remotes/origin/HEAD\t'"$(git -C "$WORK" rev-parse refs/heads/main)"$'\tcommit\t-\t-\trefs/heads/main' "$ORIGIN_CAPTURE" \
  || fail 'origin capture lost the advertised HEAD symbolic target'

# Origin identity accepts only the exact GitHub host and repository in the
# supported HTTPS, SSH URL, and SCP-style SSH forms. Stop at mocked auth for
# accepted URLs so these parser fixtures never contact GitHub.
export PRUNE_GH_SCENARIO=auth-fail
for origin_url in \
  'https://github.com/szTheory/sigra.git' \
  'ssh://git@github.com/szTheory/sigra.git' \
  'git@github.com:szTheory/sigra.git'; do
  git -C "$WORK" remote set-url origin "$origin_url"
  IDENTITY_RECEIPT="${TEMP_DIR}/identity-accepted.json"
  if bash "$HELPER" preflight-origin-access --repo "$WORK" --operation delete \
    --ref refs/heads/stale/delete --output "$IDENTITY_RECEIPT" >/dev/null 2>&1; then
    fail "origin identity fixture unexpectedly passed mocked auth for ${origin_url}"
  fi
  jq -e '.checks[0] == {check:"origin_identity",status:"passed"} and
    .checks[1] == {check:"gh_auth",status:"failed"}' "$IDENTITY_RECEIPT" >/dev/null \
    || fail "supported exact GitHub origin was not accepted: ${origin_url}"
done
for origin_url in \
  'https://evilgithub.com/szTheory/sigra.git' \
  'https://github.com.evil/szTheory/sigra.git' \
  'git@notgithub.com:szTheory/sigra.git' \
  'git@github.com.evil:szTheory/sigra.git' \
  'ssh://git@notgithub.com/szTheory/sigra.git' \
  'ssh://git@github.com.evil/szTheory/sigra.git' \
  'https://github.com/other/sigra.git' \
  'ssh://git@github.com/szTheory/sigra-fork.git' \
  'git@github.com:szTheory/sigra-mirror.git'; do
  git -C "$WORK" remote set-url origin "$origin_url"
  IDENTITY_RECEIPT="${TEMP_DIR}/identity-rejected.json"
  if bash "$HELPER" preflight-origin-access --repo "$WORK" --operation delete \
    --ref refs/heads/stale/delete --output "$IDENTITY_RECEIPT" >/dev/null 2>&1; then
    fail "lookalike GitHub host was accepted: ${origin_url}"
  fi
  jq -e '.checks[0] == {check:"origin_identity",status:"failed"} and
    .origin_identity == "unknown"' "$IDENTITY_RECEIPT" >/dev/null \
    || fail "lookalike GitHub host did not fail at origin identity: ${origin_url}"
done
git -C "$WORK" remote set-url origin "$BARE"
export PRUNE_GH_SCENARIO=valid

for scenario in list-fail rate-limit auth-fail; do
  export PRUNE_GH_SCENARIO="$scenario"
  failed_capture="${TEMP_DIR}/${scenario}-capture.json"
  if bash "$HELPER" capture-prs --repo "$WORK" --output "$failed_capture" >/dev/null 2>&1; then
    fail "unsafe GitHub response was accepted for scenario ${scenario}"
  fi
  [[ ! -e "$failed_capture" ]] || fail "failed PR query wrote a success capture for ${scenario}"
done
cat > "${TEMP_DIR}/prs.json" <<'JSON'
[{"number":219,"state":"OPEN","headRefName":"gsd/238-generated-auth-runtime-proof-evidence","baseRefName":"main","headRefOid":"1111111111111111111111111111111111111111","baseRefOid":"2222222222222222222222222222222222222222"}]
JSON
export PR_JSON_PATH="${TEMP_DIR}/prs.json"
export PRUNE_GH_SCENARIO=push-denied
DENIED_RECEIPT="${TEMP_DIR}/denied-preflight.json"
git -C "$WORK" branch probe/publish HEAD
if bash "$HELPER" preflight-origin-access --repo "$WORK" --operation publish \
  --ref refs/heads/probe/publish --output "$DENIED_RECEIPT" >/dev/null 2>&1; then
  fail 'origin preflight accepted a repository without push permission'
fi
jq -e '.result == "failed" and .detail == "access_or_safety_check_failed"' "$DENIED_RECEIPT" >/dev/null \
  || fail 'denied access did not leave a safe failure receipt'
export PRUNE_GH_SCENARIO=valid

# Build a complete offline lifecycle fixture: divergent CI safety tips, an
# origin-only safety ref, one local-only safety ref, and one remote/tracking
# deletion row. Every mutation remains inside this throwaway bare origin.
git -C "$WORK" branch ci/phase-235-16-source-complete HEAD
git -C "$WORK" branch safety/local-main-before-release-cleanup-20260831 HEAD
git -C "$WORK" branch stale/delete HEAD
git -C "$WORK" branch safety/local-main-before-release-cleanup-remote HEAD
git -C "$WORK" tag -a archive/local-main-pre-235-recovery -m 'fixture safety tag'
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false push -q origin \
  refs/heads/stale/delete:refs/heads/stale/delete \
  refs/heads/safety/local-main-before-release-cleanup-remote:refs/heads/safety/local-main-before-release-cleanup-remote \
  refs/tags/archive/local-main-pre-235-recovery:refs/tags/archive/local-main-pre-235-recovery
git -C "$WORK" checkout -q -b remote-ci
printf 'origin ci divergence\n' >> "${WORK}/fixture.txt"
git -C "$WORK" add fixture.txt
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: divergent origin safety tip'
REMOTE_CI_OID="$(git -C "$WORK" rev-parse HEAD)"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false push -q origin \
  refs/heads/remote-ci:refs/heads/ci/phase-235-16-source-complete
git -C "$WORK" branch -f safety/local-main-before-release-cleanup-20260831 "$REMOTE_CI_OID"
git -C "$WORK" branch safety/local-main-before-release-cleanup-origin-only "$REMOTE_CI_OID"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false push -q origin \
  refs/heads/safety/local-main-before-release-cleanup-origin-only:refs/heads/safety/local-main-before-release-cleanup-origin-only
git -C "$WORK" checkout -q main
git -C "$WORK" branch -D remote-ci >/dev/null
git -C "$WORK" branch -D safety/local-main-before-release-cleanup-origin-only >/dev/null
git -C "$WORK" update-ref refs/remotes/origin/stale/delete "$(git -C "$WORK" rev-parse refs/heads/stale/delete)"
# Keep a stale direct tracking target behind origin/HEAD in the committed
# snapshot so a forged HEAD tracking row exercises symbolic-ref protection.
git -C "$WORK" update-ref refs/remotes/origin/prune-symref-target "$(git -C "$WORK" rev-parse refs/heads/main)"
git -C "$WORK" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/prune-symref-target
git -C "$WORK" symbolic-ref refs/remotes/origin/prune-alias refs/remotes/origin/prune-symref-target

PHASE_DIR=".planning/phases/245-branch-prune-local-and-remote"
mkdir -p "${WORK}/${PHASE_DIR}"
SNAPSHOT_PATH="${PHASE_DIR}/245-LOCAL-REFS.tsv"
ORIGIN_PATH="${PHASE_DIR}/245-ORIGIN-REFS.tsv"
PR_STATE_PATH="${PHASE_DIR}/245-OPEN-PR-STATE.json"
READINESS_PATH="${PHASE_DIR}/245-READINESS.json"
ALLOWLIST_PATH="${PHASE_DIR}/245-BRANCH-DELETE-ALLOWLIST.tsv"
SAFETY_PATH="${PHASE_DIR}/245-SAFETY-PUBLISH.tsv"
PREFLIGHT_PATH="${PHASE_DIR}/245-ORIGIN-ACCESS-PREFLIGHT.json"
ROOT_OID="$(git -C "$WORK" rev-parse refs/heads/main)"
cat > "${TEMP_DIR}/prs.json" <<JSON
[{"number":219,"state":"OPEN","headRefName":"gsd/238-generated-auth-runtime-proof-evidence","baseRefName":"main","headRefOid":"3333333333333333333333333333333333333333","baseRefOid":"${ROOT_OID}"}]
JSON
export PR_JSON_PATH="${TEMP_DIR}/prs.json"
bash "$HELPER" capture-local --repo "$WORK" --output "${WORK}/${SNAPSHOT_PATH}"
bash "$HELPER" capture-origin --repo "$WORK" --output "${WORK}/${ORIGIN_PATH}"
bash "$HELPER" capture-prs --repo "$WORK" --output "${WORK}/${PR_STATE_PATH}"
printf 'side\tref\toid\ttype\treason\nsafety-publish\trefs/heads/safety/local-main-before-release-cleanup-20260831\t%s\tcommit\tlocal-only safety anchor\n' \
  "$(git -C "$WORK" rev-parse refs/heads/safety/local-main-before-release-cleanup-20260831)" > "${WORK}/${SAFETY_PATH}"
bash "$HELPER" capture-readiness --repo "$WORK"
git -C "$WORK" add "$SNAPSHOT_PATH" "$ORIGIN_PATH" "$PR_STATE_PATH" "$SAFETY_PATH" "$READINESS_PATH"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit pre-prune inventories and readiness'
INVENTORY_COMMIT="$(git -C "$WORK" rev-parse HEAD)"
ORIGIN_BEFORE_UNAPPROVED="$(git --git-dir="$BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)"
printf 'side\tref\toid\ttype\treason\nsafety-publish\trefs/heads/safety/forged-publish-destination\t%s\tcommit\tunapproved fixture destination\n' \
  "$ROOT_OID" > "${WORK}/${SAFETY_PATH}"
git -C "$WORK" add "$SAFETY_PATH"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit unapproved safety destination'
UNAPPROVED_SAFETY_COMMIT="$(git -C "$WORK" rev-parse HEAD)"
if bash "$HELPER" safety-publish --repo "$WORK" --apply --snapshot-commit "$INVENTORY_COMMIT" \
  --safety-commit "$UNAPPROVED_SAFETY_COMMIT" --safety-list "$SAFETY_PATH" \
  --readiness-commit "$INVENTORY_COMMIT" --readiness "$READINESS_PATH" \
  --pr-state-commit "$INVENTORY_COMMIT" --pr-state "$PR_STATE_PATH" > "$TEMP_DIR/unapproved-safety.out" 2>&1; then
  fail 'direct safety-publish accepted an unapproved destination without verify-allowlist'
fi
grep -Fq 'safety_publish_destination_not_approved' "$TEMP_DIR/unapproved-safety.out" \
  || fail 'unapproved safety publication did not identify the rejected destination'
[[ "$(git --git-dir="$BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)" == "$ORIGIN_BEFORE_UNAPPROVED" ]] \
  || fail 'unapproved safety publication changed the isolated bare origin'
git -C "$WORK" show "$INVENTORY_COMMIT:$SAFETY_PATH" > "${WORK}/${SAFETY_PATH}"
git -C "$WORK" add "$SAFETY_PATH"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: restore exact safety publication list'
DELETE_OID="$(git -C "$WORK" rev-parse refs/heads/stale/delete)"
printf 'side\tref\toid\ttype\treason\nremote\trefs/heads/stale/delete\t%s\tcommit\tfixture stale origin branch\ntracking\trefs/remotes/origin/stale/delete\t%s\tcommit\tmatching local tracking ref\n' \
  "$DELETE_OID" "$DELETE_OID" > "${WORK}/${ALLOWLIST_PATH}"
git -C "$WORK" add "$ALLOWLIST_PATH"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit exact operation allowlist'
ALLOWLIST_COMMIT="$(git -C "$WORK" rev-parse HEAD)"
PREFLIGHT_RECEIPT="${TEMP_DIR}/publish-preflight.json"
bash "$HELPER" preflight-origin-access --repo "$WORK" --operation publish \
  --ref refs/heads/safety/local-main-before-release-cleanup-20260831 --output "$PREFLIGHT_RECEIPT"
jq -e '.result == "passed" and ([.checks[] | select(.status == "passed")] | length) == 9' "$PREFLIGHT_RECEIPT" >/dev/null \
  || fail 'successful preflight omitted one or more command status checks'
cp "$PREFLIGHT_RECEIPT" "${WORK}/${PREFLIGHT_PATH}"
git -C "$WORK" add "$PREFLIGHT_PATH"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit safety publish preflight'
PREFLIGHT_COMMIT="$(git -C "$WORK" rev-parse HEAD)"
sed 's/3333333333333333333333333333333333333333/4444444444444444444444444444444444444444/' \
  "$PR_JSON_PATH" > "${TEMP_DIR}/changed-prs.json"
export PR_CHANGED_JSON_PATH="${TEMP_DIR}/changed-prs.json"
export PRUNE_GH_SCENARIO=changing-pr
: > "$PR_CALL_COUNT_FILE"
if bash "$HELPER" safety-publish --repo "$WORK" --apply --snapshot-commit "$INVENTORY_COMMIT" \
  --origin-commit "$INVENTORY_COMMIT" --allowlist-commit "$ALLOWLIST_COMMIT" \
  --evidence-commit "$INVENTORY_COMMIT" --pr-state-commit "$INVENTORY_COMMIT" \
  --preflight-commit "$PREFLIGHT_COMMIT" --safety-list "$SAFETY_PATH" >/dev/null 2>&1; then
  fail 'a changed live PR identity did not block safety publication'
fi
if git -C "$WORK" ls-remote --heads origin refs/heads/safety/local-main-before-release-cleanup-20260831 | grep -q .; then
  fail 'PR drift rejection mutated the fixture origin'
fi
export PRUNE_GH_SCENARIO=valid
rm -f "$PR_CALL_COUNT_FILE"
SAFETY_REF=refs/heads/safety/local-main-before-release-cleanup-20260831
SAFETY_SOURCE_OID="$(git -C "$WORK" rev-parse "$SAFETY_REF")"
git -C "$WORK" merge-base --is-ancestor "$ROOT_OID" "$SAFETY_SOURCE_OID" \
  || fail 'safety race source is not a descendant of the concurrent value'
if git --git-dir="$BARE" show-ref --verify --quiet "$SAFETY_REF"; then
  fail 'safety race destination unexpectedly exists before publication'
fi
RACE_BIN_DIR="${TEMP_DIR}/race-bin"
mkdir -p "$RACE_BIN_DIR"
REAL_GIT="$PRUNE_TEST_REAL_GIT"
cat > "${RACE_BIN_DIR}/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PRUNE_TEST_REMAP_LOCAL_ORIGIN:-0}" == 1 && " $* " == *" remote get-url "* ]]; then
  actual="$("$REAL_GIT" "$@")"
  if [[ -n "${PRUNE_TEST_LOCAL_ORIGIN:-}" && "$actual" == "$PRUNE_TEST_LOCAL_ORIGIN" ]]; then
    printf '%s\n' 'https://github.com/szTheory/sigra.git'
    exit 0
  fi
fi
joined=" $* "
if [[ "$joined" == *" push "* && "$joined" != *" --dry-run "* \
  && "$joined" == *" origin ${RACE_REFSPEC} "* ]]; then
  printf '%s\n' "$joined" >> "$RACE_PUSH_LOG"
  if [[ ! -e "$RACE_TRIGGERED" ]]; then
    if [[ -n "${RACE_EXPECTED_OLD_OID:-}" ]]; then
      "$REAL_GIT" --git-dir="$RACE_BARE" update-ref "$RACE_TARGET_REF" "$RACE_VALUE_OID" "$RACE_EXPECTED_OLD_OID"
    else
      "$REAL_GIT" --git-dir="$RACE_BARE" update-ref "$RACE_TARGET_REF" "$RACE_VALUE_OID"
    fi
    : > "$RACE_TRIGGERED"
  fi
fi
exec "$REAL_GIT" "$@"
GIT
chmod +x "${RACE_BIN_DIR}/git"
SAFETY_RACE_LOG="${TEMP_DIR}/safety-race-pushes.log"
SAFETY_RACE_TRIGGERED="${TEMP_DIR}/safety-race-triggered"
: > "$SAFETY_RACE_LOG"
if SAFETY_RACE_OUTPUT="$(PATH="${RACE_BIN_DIR}:$PATH" REAL_GIT="$REAL_GIT" RACE_BARE="$BARE" \
  RACE_TARGET_REF="$SAFETY_REF" RACE_VALUE_OID="$ROOT_OID" RACE_REFSPEC="${SAFETY_REF}:${SAFETY_REF}" \
  RACE_PUSH_LOG="$SAFETY_RACE_LOG" RACE_TRIGGERED="$SAFETY_RACE_TRIGGERED" \
  bash "$HELPER" safety-publish --repo "$WORK" --apply --snapshot-commit "$INVENTORY_COMMIT" \
  --origin-commit "$INVENTORY_COMMIT" --allowlist-commit "$ALLOWLIST_COMMIT" \
  --readiness-commit "$INVENTORY_COMMIT" --readiness "$READINESS_PATH" --pr-state-commit "$INVENTORY_COMMIT" \
  --preflight-commit "$PREFLIGHT_COMMIT" --safety-list "$SAFETY_PATH" 2>&1)"; then
  ACTUAL_SAFETY_OID="$(git --git-dir="$BARE" rev-parse "$SAFETY_REF" 2>/dev/null || printf absent)"
  fail "absent-only safety lease accepted a destination created after preflight: expected=absent observed=${ACTUAL_SAFETY_OID} source=${SAFETY_SOURCE_OID}"
fi
printf '%s\n' "$SAFETY_RACE_OUTPUT"
[[ -e "$SAFETY_RACE_TRIGGERED" ]] || fail 'safety publication race did not reach the push boundary'
grep -Fq "safety_publish_lease_rejected: ${SAFETY_REF} expected=absent observed=${ROOT_OID}" <<< "$SAFETY_RACE_OUTPUT" \
  || fail 'safety lease rejection did not record the absent expectation and observed OID'
[[ "$(git --git-dir="$BARE" rev-parse "$SAFETY_REF")" == "$ROOT_OID" ]] \
  || fail 'safety lease rejection changed the concurrent destination value'
[[ "$(wc -l < "$SAFETY_RACE_LOG" | tr -d ' ')" == 1 ]] || fail 'safety lease rejection retried the push'
git --git-dir="$BARE" update-ref -d "$SAFETY_REF" "$ROOT_OID"

bash "$HELPER" safety-publish --repo "$WORK" --apply --snapshot-commit "$INVENTORY_COMMIT" \
  --origin-commit "$INVENTORY_COMMIT" --allowlist-commit "$ALLOWLIST_COMMIT" \
  --readiness-commit "$INVENTORY_COMMIT" --readiness "$READINESS_PATH" --pr-state-commit "$INVENTORY_COMMIT" \
  --preflight-commit "$PREFLIGHT_COMMIT" --safety-list "$SAFETY_PATH"
bash "$HELPER" verify-allowlist --repo "$WORK" --snapshot-commit "$INVENTORY_COMMIT" \
  --origin-commit "$INVENTORY_COMMIT" --allowlist-commit "$ALLOWLIST_COMMIT" \
  --pr-state-commit "$INVENTORY_COMMIT" --evidence-commit "$INVENTORY_COMMIT" --safety-list "$SAFETY_PATH"

PREFLIGHT_RECEIPT="${TEMP_DIR}/delete-preflight.json"
bash "$HELPER" preflight-origin-access --repo "$WORK" --operation delete \
  --ref refs/heads/stale/delete --output "$PREFLIGHT_RECEIPT"
cp "$PREFLIGHT_RECEIPT" "${WORK}/${PREFLIGHT_PATH}"
git -C "$WORK" add "$PREFLIGHT_PATH"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit origin delete preflight'
PREFLIGHT_COMMIT="$(git -C "$WORK" rev-parse HEAD)"
COMMON_ARGS=(--repo "$WORK" --snapshot-commit "$INVENTORY_COMMIT" --origin-commit "$INVENTORY_COMMIT" \
  --allowlist-commit "$ALLOWLIST_COMMIT" --readiness-commit "$INVENTORY_COMMIT" --readiness "$READINESS_PATH" \
  --pr-state-commit "$INVENTORY_COMMIT" --preflight-commit "$PREFLIGHT_COMMIT" --safety-list "$SAFETY_PATH")

# Public --repo selection alone must not authorize writes to a local origin.
# Instrument git push as well as comparing the remote refs to prove both apply
# paths reject the origin identity before reaching the mutation boundary.
LOCAL_APPLY_GUARD="${TEMP_DIR}/local-apply-guard"
mkdir -p "$LOCAL_APPLY_GUARD"
LOCAL_APPLY_PUSH_LOG="${TEMP_DIR}/local-apply-pushes.log"
: > "$LOCAL_APPLY_PUSH_LOG"
cat > "${LOCAL_APPLY_GUARD}/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PRUNE_TEST_REMAP_LOCAL_ORIGIN:-0}" == 1 && " $* " == *" remote get-url "* ]]; then
  actual="$("$REAL_GIT" "$@")"
  if [[ -n "${PRUNE_TEST_LOCAL_ORIGIN:-}" && "$actual" == "$PRUNE_TEST_LOCAL_ORIGIN" ]]; then
    printf '%s\n' 'https://github.com/szTheory/sigra.git'
    exit 0
  fi
fi
if [[ " $* " == *" push "* ]]; then printf '%s\n' "$*" >> "$LOCAL_APPLY_PUSH_LOG"; fi
exec "$REAL_GIT" "$@"
GIT
chmod +x "${LOCAL_APPLY_GUARD}/git"
REAL_GIT="$PRUNE_TEST_REAL_GIT"
export REAL_GIT LOCAL_APPLY_PUSH_LOG
LOCAL_ORIGIN_BEFORE_DENIAL="$(git --git-dir="$BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)"
if LOCAL_DENIAL_OUTPUT="$(env PRUNE_STALE_BRANCHES_TEST_ALLOW_LOCAL_ORIGIN=1 PRUNE_TEST_REMAP_LOCAL_ORIGIN=0 \
  PATH="${LOCAL_APPLY_GUARD}:$PATH" bash "$HELPER" remote "${COMMON_ARGS[@]}" --apply 2>&1)"; then
  fail 'remote apply accepted a local origin selected with --repo despite the old environment bypass variable'
fi
grep -Fq 'origin_repository_identity_mismatch' <<< "$LOCAL_DENIAL_OUTPUT" \
  || fail "remote apply did not reject the local origin identity: ${LOCAL_DENIAL_OUTPUT}"
[[ "$(git --git-dir="$BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)" == "$LOCAL_ORIGIN_BEFORE_DENIAL" ]] \
  || fail 'remote apply changed the local origin before rejecting its identity'
[[ ! -s "$LOCAL_APPLY_PUSH_LOG" ]] || fail 'remote apply reached git push before rejecting the local origin'
if LOCAL_DENIAL_OUTPUT="$(env PRUNE_STALE_BRANCHES_TEST_ALLOW_LOCAL_ORIGIN=1 PRUNE_TEST_REMAP_LOCAL_ORIGIN=0 \
  PATH="${LOCAL_APPLY_GUARD}:$PATH" bash "$HELPER" safety-publish --repo "$WORK" --apply \
  --snapshot-commit "$INVENTORY_COMMIT" --origin-commit "$INVENTORY_COMMIT" \
  --allowlist-commit "$ALLOWLIST_COMMIT" --readiness-commit "$INVENTORY_COMMIT" \
  --readiness "$READINESS_PATH" --pr-state-commit "$INVENTORY_COMMIT" \
  --preflight-commit "$PREFLIGHT_COMMIT" --safety-list "$SAFETY_PATH" 2>&1)"; then
  fail 'safety-publish apply accepted a local origin selected with --repo despite the old environment bypass variable'
fi
grep -Fq 'origin_repository_identity_mismatch' <<< "$LOCAL_DENIAL_OUTPUT" \
  || fail "safety-publish did not reject the local origin identity: ${LOCAL_DENIAL_OUTPUT}"
[[ "$(git --git-dir="$BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)" == "$LOCAL_ORIGIN_BEFORE_DENIAL" ]] \
  || fail 'safety-publish changed the local origin before rejecting its identity'
[[ ! -s "$LOCAL_APPLY_PUSH_LOG" ]] || fail 'safety-publish reached git push before rejecting the local origin'

# A trusted fetch URL must not authorize writes to a separately configured
# push destination. Guard git invocations as well as both bare repositories so
# these apply-path checks prove they stop before any push is attempted.
PUSH_DESTINATION_BARE="${TEMP_DIR}/untrusted-push.git"
git init -q --bare --initial-branch=main "$PUSH_DESTINATION_BARE"
PUSH_GUARD_BIN="${TEMP_DIR}/push-guard-bin"
mkdir -p "$PUSH_GUARD_BIN"
PUSH_GUARD_LOG="${TEMP_DIR}/push-guard.log"
: > "$PUSH_GUARD_LOG"
cat > "${PUSH_GUARD_BIN}/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PRUNE_TEST_REMAP_LOCAL_ORIGIN:-0}" == 1 && " $* " == *" remote get-url "* ]]; then
  actual="$("$REAL_GIT" "$@")"
  if [[ -n "${PRUNE_TEST_LOCAL_ORIGIN:-}" && "$actual" == "$PRUNE_TEST_LOCAL_ORIGIN" ]]; then
    printf '%s\n' 'https://github.com/szTheory/sigra.git'
    exit 0
  fi
fi
if [[ " $* " == *" push "* ]]; then printf '%s\n' "$*" >> "$PUSH_GUARD_LOG"; fi
exec "$REAL_GIT" "$@"
GIT
chmod +x "${PUSH_GUARD_BIN}/git"
REAL_GIT="$PRUNE_TEST_REAL_GIT"
export REAL_GIT PUSH_GUARD_LOG
git -C "$WORK" remote set-url --push origin "$PUSH_DESTINATION_BARE"
ORIGIN_REFS_BEFORE_PUSH_MISMATCH="$(git --git-dir="$BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)"
if PUSH_MISMATCH_OUTPUT="$(PRUNE_TEST_REMAP_LOCAL_ORIGIN=1 PATH="${PUSH_GUARD_BIN}:$PATH" bash "$HELPER" remote "${COMMON_ARGS[@]}" --apply 2>&1)"; then
  fail 'remote deletion accepted a trusted fetch URL with an untrusted push URL'
fi
grep -Eq 'origin_(push_destination_identity_mismatch|repository_identity_mismatch)' <<< "$PUSH_MISMATCH_OUTPUT" \
  || fail "remote deletion did not fail closed on the mismatched push URL: ${PUSH_MISMATCH_OUTPUT}"
[[ "$(git --git-dir="$BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)" == "$ORIGIN_REFS_BEFORE_PUSH_MISMATCH" ]] \
  || fail 'mismatched push URL changed the trusted fetch origin'
[[ -z "$(git --git-dir="$PUSH_DESTINATION_BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)" ]] \
  || fail 'mismatched push URL changed its configured push destination'
if PUSH_MISMATCH_OUTPUT="$(PRUNE_TEST_REMAP_LOCAL_ORIGIN=1 PATH="${PUSH_GUARD_BIN}:$PATH" bash "$HELPER" safety-publish --repo "$WORK" --apply \
  --snapshot-commit "$INVENTORY_COMMIT" --origin-commit "$INVENTORY_COMMIT" \
  --allowlist-commit "$ALLOWLIST_COMMIT" --readiness-commit "$INVENTORY_COMMIT" \
  --readiness "$READINESS_PATH" --pr-state-commit "$INVENTORY_COMMIT" \
  --preflight-commit "$PREFLIGHT_COMMIT" --safety-list "$SAFETY_PATH" 2>&1)"; then
  fail 'safety publication accepted a trusted fetch URL with an untrusted push URL'
fi
grep -Eq 'origin_(push_destination_identity_mismatch|repository_identity_mismatch)' <<< "$PUSH_MISMATCH_OUTPUT" \
  || fail "safety publication did not fail closed on the mismatched push URL: ${PUSH_MISMATCH_OUTPUT}"
[[ "$(git --git-dir="$BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)" == "$ORIGIN_REFS_BEFORE_PUSH_MISMATCH" ]] \
  || fail 'mismatched push URL changed the trusted fetch origin during safety publication'
[[ -z "$(git --git-dir="$PUSH_DESTINATION_BARE" for-each-ref --format='%(refname)%09%(objectname)' refs/heads refs/tags)" ]] \
  || fail 'safety publication changed its configured push destination'
[[ ! -s "$PUSH_GUARD_LOG" ]] || fail 'mismatched push URL reached a git push command'
git -C "$WORK" config --unset-all remote.origin.pushurl

COMMON_DIR="$(git -C "$WORK" rev-parse --path-format=absolute --git-common-dir)"
COORDINATOR_ROOT="${COMMON_DIR}/sigra-branch-worktree-coordinator"
mkdir "${COORDINATOR_ROOT}/lock"
printf '%s\n' '{"schema_version":1,"token":"fixture-stale-owner-token","pid":"0","host":"fixture","operation":"concurrent-apply","repo":"fixture","common_dir":"fixture","created_at":"fixture"}' \
  > "${COORDINATOR_ROOT}/lock/owner.json"
if bash "$HELPER" remote "${COMMON_ARGS[@]}" --apply >/dev/null 2>&1; then
  fail 'a second concurrent apply was not rejected by the shared coordinator lock'
fi
rm -f "${COORDINATOR_ROOT}/lock/owner.json"
rmdir "${COORDINATOR_ROOT}/lock"
if git -C "$WORK" ls-remote --heads origin refs/heads/stale/delete | grep -q .; then
  :
else
  fail 'lock rejection occurred after the remote branch had changed'
fi
REMOTE_DELETE_REF=refs/heads/stale/delete
REMOTE_RACE_LOG="${TEMP_DIR}/remote-delete-race-pushes.log"
REMOTE_RACE_TRIGGERED="${TEMP_DIR}/remote-delete-race-triggered"
: > "$REMOTE_RACE_LOG"
if REMOTE_RACE_OUTPUT="$(PATH="${RACE_BIN_DIR}:$PATH" REAL_GIT="$REAL_GIT" RACE_BARE="$BARE" \
  RACE_TARGET_REF="$REMOTE_DELETE_REF" RACE_VALUE_OID="$REMOTE_CI_OID" RACE_EXPECTED_OLD_OID="$DELETE_OID" \
  RACE_REFSPEC=":${REMOTE_DELETE_REF}" RACE_PUSH_LOG="$REMOTE_RACE_LOG" RACE_TRIGGERED="$REMOTE_RACE_TRIGGERED" \
  bash "$HELPER" remote "${COMMON_ARGS[@]}" --apply 2>&1)"; then
  fail 'expected-OID remote deletion lease accepted a concurrently advanced destination'
fi
printf '%s\n' "$REMOTE_RACE_OUTPUT"
[[ -e "$REMOTE_RACE_TRIGGERED" ]] || fail 'remote deletion race did not reach the push boundary'
grep -Fq "remote_delete_lease_rejected: ${REMOTE_DELETE_REF} expected=${DELETE_OID}/commit observed=${REMOTE_CI_OID}" <<< "$REMOTE_RACE_OUTPUT" \
  || fail 'remote deletion lease rejection did not record expected and observed OIDs'
[[ "$(git --git-dir="$BARE" rev-parse "$REMOTE_DELETE_REF")" == "$REMOTE_CI_OID" ]] \
  || fail 'remote deletion lease rejection removed or changed the concurrent branch value'
[[ "$(wc -l < "$REMOTE_RACE_LOG" | tr -d ' ')" == 1 ]] || fail 'remote deletion lease rejection retried the push'
git --git-dir="$BARE" update-ref "$REMOTE_DELETE_REF" "$DELETE_OID" "$REMOTE_CI_OID"

# Direct remote apply must re-read the live default after preflight and reject
# a candidate that became the origin default, without verify-allowlist.
git --git-dir="$BARE" symbolic-ref HEAD "$REMOTE_DELETE_REF"
if REMOTE_DEFAULT_OUTPUT="$(bash "$HELPER" remote "${COMMON_ARGS[@]}" --apply 2>&1)"; then
  fail 'direct remote apply accepted a candidate renamed to the live origin default'
fi
grep -Fq "protected_live_default_branch: ${REMOTE_DELETE_REF}" <<< "$REMOTE_DEFAULT_OUTPUT" \
  || fail 'remote live-default rejection did not identify the protected candidate'
[[ "$(git --git-dir="$BARE" rev-parse "$REMOTE_DELETE_REF")" == "$DELETE_OID" ]] \
  || fail 'remote live-default rejection changed the bare-origin candidate'
git --git-dir="$BARE" symbolic-ref HEAD refs/heads/main

git -C "$WORK" remote set-url origin 'git@notgithub.com:szTheory/sigra.git'
if LOOKALIKE_APPLY_OUTPUT="$(bash "$HELPER" remote "${COMMON_ARGS[@]}" --apply 2>&1)"; then
  fail 'remote apply accepted a lookalike origin hostname'
fi
grep -Fq 'origin_repository_identity_mismatch' <<< "$LOOKALIKE_APPLY_OUTPUT" \
  || fail 'remote apply did not reject the lookalike origin identity'
[[ "$(git --git-dir="$BARE" rev-parse "$REMOTE_DELETE_REF")" == "$DELETE_OID" ]] \
  || fail 'lookalike-origin remote apply changed the isolated origin'
git -C "$WORK" remote set-url origin "$BARE"

bash "$HELPER" remote "${COMMON_ARGS[@]}" --apply
git -C "$WORK" update-ref refs/remotes/origin/stale/delete "$DELETE_OID"
git --git-dir="$BARE" symbolic-ref HEAD refs/heads/stale/delete
if TRACKING_DEFAULT_OUTPUT="$(bash "$HELPER" tracking "${COMMON_ARGS[@]}" --apply 2>&1)"; then
  fail 'tracking apply accepted an absent/malformed live origin default identity'
fi
grep -Eq 'live_origin_default_(query_failed|query_ambiguous_or_absent|target_invalid)' <<< "$TRACKING_DEFAULT_OUTPUT" \
  || fail 'tracking apply did not fail closed on its unavailable live default target'
[[ "$(git -C "$WORK" rev-parse refs/remotes/origin/stale/delete)" == "$DELETE_OID" ]] \
  || fail 'tracking live-default rejection changed the local tracking ref'
git --git-dir="$BARE" symbolic-ref HEAD refs/heads/main
bash "$HELPER" tracking "${COMMON_ARGS[@]}" --apply
printf 'side\tref\toid\ttype\treason\ntracking\trefs/remotes/origin/prune-alias\t%s\tcommit\tforged symbolic tracking alias\n' \
  "$(git -C "$WORK" rev-parse refs/remotes/origin/prune-symref-target)" > "${WORK}/${ALLOWLIST_PATH}"
git -C "$WORK" add "$ALLOWLIST_PATH"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit non-HEAD symbolic tracking alias row'
NON_HEAD_SYMBOLIC_ALLOWLIST_COMMIT="$(git -C "$WORK" rev-parse HEAD)"
if TRACKING_ALIAS_OUTPUT="$(bash "$HELPER" tracking "${COMMON_ARGS[@]}" \
  --allowlist-commit "$NON_HEAD_SYMBOLIC_ALLOWLIST_COMMIT" --apply 2>&1)"; then
  fail 'tracking apply accepted a non-HEAD symbolic tracking snapshot row'
fi
grep -Fq 'tracking_ref_snapshot_is_symbolic: refs/remotes/origin/prune-alias' <<< "$TRACKING_ALIAS_OUTPUT" \
  || fail "non-HEAD symbolic tracking rejection did not identify the alias: ${TRACKING_ALIAS_OUTPUT}"
[[ "$(git -C "$WORK" symbolic-ref refs/remotes/origin/prune-alias)" == refs/remotes/origin/prune-symref-target ]] \
  || fail 'non-HEAD symbolic tracking rejection changed the alias'
git -C "$WORK" show-ref --verify --quiet refs/remotes/origin/prune-symref-target \
  || fail 'non-HEAD symbolic tracking rejection deleted the alias target branch'
printf 'side\tref\toid\ttype\treason\ntracking\trefs/remotes/origin/HEAD\t%s\tcommit\tforged symbolic tracking alias\n' \
  "$(git -C "$WORK" rev-parse refs/remotes/origin/prune-symref-target)" > "${WORK}/${ALLOWLIST_PATH}"
git -C "$WORK" add "$ALLOWLIST_PATH"
git -C "$WORK" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit symbolic tracking alias row'
SYMBOLIC_ALLOWLIST_COMMIT="$(git -C "$WORK" rev-parse HEAD)"
if TRACKING_ALIAS_OUTPUT="$(bash "$HELPER" tracking "${COMMON_ARGS[@]}" \
  --allowlist-commit "$SYMBOLIC_ALLOWLIST_COMMIT" --apply 2>&1)"; then
  fail 'tracking apply accepted refs/remotes/origin/HEAD from a symbolic snapshot row'
fi
grep -Eq 'tracking_(origin_head_alias_not_allowed|ref_snapshot_is_symbolic)' <<< "$TRACKING_ALIAS_OUTPUT" \
  || fail "symbolic tracking rejection did not identify the alias: ${TRACKING_ALIAS_OUTPUT}"
[[ "$(git -C "$WORK" symbolic-ref refs/remotes/origin/HEAD)" == refs/remotes/origin/prune-symref-target ]] \
  || fail 'symbolic tracking rejection changed the origin/HEAD alias'
git -C "$WORK" show-ref --verify --quiet refs/remotes/origin/prune-symref-target \
  || fail 'symbolic tracking rejection deleted the alias target branch'
git -C "$WORK" show-ref --verify --quiet refs/remotes/origin/stale/delete \
  && fail 'matching tracking ref remained after the expected-OID tracking pass'
bash "$HELPER" verify-local "${COMMON_ARGS[@]}"
bash "$HELPER" verify-remote "${COMMON_ARGS[@]}"
bash "$HELPER" verify-safety "${COMMON_ARGS[@]}"
bash "$HELPER" verify-prs "${COMMON_ARGS[@]}"
bash "$HELPER" verify-objects "${COMMON_ARGS[@]}"
printf 'PASS: live PR capture completeness guards and independent origin annotated-tag inventory.\n'
