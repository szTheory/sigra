#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="${ROOT_DIR}/scripts/maintainers/prune-stale-branches.sh"
PHASE_244="${ROOT_DIR}/.planning/phases/244-playwright-test-1-59-1-1-62-1-alone"
PHASE_245_DIR=".planning/phases/245-branch-prune-local-and-remote"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# D-01 is a precondition even for a disposable fixture: verify Phase 244's
# completion, resolved blocker, and explicit PR dispositions before any ref move.
[[ "$(sed -n 's/^status: //p' "${PHASE_244}/244-VERIFICATION.md" | head -1)" == passed ]] \
  || fail 'D-01: Phase 244 verification is not passed'
summary_count=$(find "${PHASE_244}" -maxdepth 1 -name '244-??-SUMMARY.md' -type f | wc -l | tr -d ' ')
[[ "$summary_count" == 8 ]] || fail "D-01: expected eight completed Phase 244 summaries, found ${summary_count}"
[[ -f "${ROOT_DIR}/.planning/todos/resolved/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md" ]] \
  || fail 'D-01: Phase 242 contract blocker lacks a resolved todo record'
grep -q 'deferred_missing_live_candidate_with_measured_drift' "${PHASE_244}/244-PLAYWRIGHT-EVIDENCE.json" \
  || fail 'D-01: Phase 244 lacks its final PR #213 disposition'
grep -q 'PR #283' "${PHASE_244}/244-03-SUMMARY.md" \
  || fail 'D-01: Phase 244 draft PR #283 disposition is not recorded'
printf 'D-01 readiness confirmed: Phase 244 complete; PR #213 deferred/closed; PR #283 disposition recorded.\n'

TEMP_DIR="$(mktemp -d)"
LOCAL_APPLY_PID=""
cleanup() {
  if [[ -n "$LOCAL_APPLY_PID" ]]; then kill "$LOCAL_APPLY_PID" 2>/dev/null || true; wait "$LOCAL_APPLY_PID" 2>/dev/null || true; fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT
REPO="${TEMP_DIR}/repo"
git clone -q --shared "$ROOT_DIR" "$REPO"
git -C "$REPO" config user.name 'GSD Fixture'
git -C "$REPO" config user.email 'gsd-fixture@example.invalid'
git -C "$REPO" config gc.auto 0
git -C "$REPO" config maintenance.auto false
git -C "$REPO" checkout -q -b fixture-prune-local
ROOT_OID="$(git -C "$REPO" rev-parse HEAD)"
git -C "$REPO" branch stale/merged "$ROOT_OID"
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
  mkdir -p "${REPO}/$(dirname "$source")"
  cp "${ROOT_DIR}/${source}" "${REPO}/${source}"
done
perl -0pi -e "s/^source_commit:.*/source_commit: ${ROOT_OID}/m" \
  "${REPO}/.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-SUMMARY.md" \
  "${REPO}/.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/260926-dzu-SUMMARY.md"
git -C "$REPO" add "${READINESS_SOURCES[@]}"
git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit Phase 244 readiness sources'
BARE_ORIGIN="${TEMP_DIR}/origin.git"
git init -q --bare --initial-branch=main "$BARE_ORIGIN"
export PRUNE_TEST_LOCAL_ORIGIN="$BARE_ORIGIN"
git -C "$REPO" remote set-url origin "$BARE_ORIGIN"
git -C "$REPO" push -q origin HEAD:refs/heads/main
git -C "$REPO" fetch -q origin
git -C "$REPO" remote set-head origin main

# Keep production origin validation pinned to GitHub. The test-only git shim
# aliases local fixture URL queries to the canonical identity while leaving
# fetch/push operations pointed at the disposable bare repository.
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
if [[ "${PRUNE_TEST_COORDINATOR_PAUSE:-0}" == 1 \
  && " $* " == *" update-ref --no-deref -d refs/heads/stale/merged "* ]]; then
  printf 'delete-boundary\n' > "$PRUNE_TEST_COORDINATOR_READY_FIFO"
  IFS= read -r release_signal < "$PRUNE_TEST_COORDINATOR_RELEASE_FIFO"
fi
exec "$PRUNE_TEST_REAL_GIT" "$@"
GIT
chmod +x "${FIXTURE_GIT_DIR}/git"
export PRUNE_TEST_REAL_GIT PRUNE_TEST_REMAP_LOCAL_ORIGIN=1
export PATH="${FIXTURE_GIT_DIR}:$PATH"

SNAPSHOT_PATH="${PHASE_245_DIR}/245-LOCAL-REFS.tsv"
READINESS_PATH="${PHASE_245_DIR}/245-READINESS.json"
ALLOWLIST_PATH="${PHASE_245_DIR}/245-BRANCH-DELETE-ALLOWLIST.tsv"
PR_STATE_PATH="${PHASE_245_DIR}/245-OPEN-PR-STATE.json"
SAFETY_PATH="${PHASE_245_DIR}/245-SAFETY-PUBLISH.tsv"
mkdir -p "${REPO}/${PHASE_245_DIR}"
bash "$HELPER" capture-local --repo "$REPO" --output "${REPO}/${SNAPSHOT_PATH}"
bash "$HELPER" capture-readiness --repo "$REPO"
cat > "${REPO}/${PR_STATE_PATH}" <<'JSON'
{"schema_version":1,"repository":"szTheory/sigra","actor":"fixture-user","limit":1000,"captured_at":"2026-09-27T00:00:00Z","pull_requests":[]}
JSON
printf 'side\tref\toid\ttype\treason\n' > "${REPO}/${SAFETY_PATH}"

BIN_DIR="${TEMP_DIR}/bin"
mkdir -p "$BIN_DIR"
cat > "${BIN_DIR}/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'auth status') exit 0 ;;
  'api user') printf '%s\n' fixture-user ;;
  'pr list') printf '%s\n' '[]' ;;
  *) echo 'unexpected gh invocation' >&2; exit 2 ;;
esac
GH
chmod +x "${BIN_DIR}/gh"
export PATH="${BIN_DIR}:$PATH"
export PRUNE_GH_SCENARIO=valid

git -C "$REPO" add "$SNAPSHOT_PATH" "$READINESS_PATH" "$PR_STATE_PATH" "$SAFETY_PATH"
git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit pre-prune snapshot and readiness'
SNAPSHOT_COMMIT="$(git -C "$REPO" rev-parse HEAD)"
printf 'side\tref\toid\ttype\treason\nlocal\trefs/heads/stale/merged\t%s\tcommit\tmerged fixture branch\n' "$ROOT_OID" > "${REPO}/${ALLOWLIST_PATH}"
git -C "$REPO" add "$ALLOWLIST_PATH"
git -C "$REPO" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: commit exact-name local allowlist'
ALLOWLIST_COMMIT="$(git -C "$REPO" rev-parse HEAD)"
COORDINATOR="${ROOT_DIR}/scripts/maintainers/repo-mutation-coordinator.sh"
COMMON_DIR="$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)"
COORDINATOR_ROOT="${COMMON_DIR}/sigra-branch-worktree-coordinator"
if bash "$COORDINATOR" install --repo "$REPO" > "$TEMP_DIR/coordinator-install.out" 2>&1; then
  grep -Fq 'SUPPORTED: coordinator symbolic HEAD hook enforced' "$TEMP_DIR/coordinator-install.out" \
    || fail 'supported runtime install did not prove symbolic HEAD hook coverage'
else
  grep -Fq 'coordinator_symbolic_head_hook_unsupported' "$TEMP_DIR/coordinator-install.out" \
    || fail "coordinator install failed for an unexpected reason: $(cat "$TEMP_DIR/coordinator-install.out")"
  [[ ! -e "$COORDINATOR_ROOT" ]] \
    || fail 'unsupported runtime created persistent coordinator files in the fixture repository'
  [[ -z "$(git -C "$REPO" config --local --get core.hooksPath 2>/dev/null || true)" ]] \
    || fail 'unsupported runtime changed the fixture repository hooks path'
  bash "$HELPER" verify-snapshot --repo "$REPO" --snapshot-commit "$SNAPSHOT_COMMIT" \
    --snapshot "$SNAPSHOT_PATH" --readiness-commit "$ALLOWLIST_COMMIT" --readiness "$READINESS_PATH"
  REPORT="$(bash "$HELPER" local --repo "$REPO" --snapshot-commit "$SNAPSHOT_COMMIT" \
    --allowlist-commit "$ALLOWLIST_COMMIT" --allowlist "$ALLOWLIST_PATH" --readiness "$READINESS_PATH")"
  grep -Fq 'refs/heads/stale/merged' <<<"$REPORT" || fail 'report-only output omitted the exact target ref'
  if bash "$HELPER" local --repo "$REPO" --apply --snapshot-commit "$SNAPSHOT_COMMIT" \
    --allowlist-commit "$ALLOWLIST_COMMIT" --allowlist "$ALLOWLIST_PATH" --readiness "$READINESS_PATH" \
    --pr-state-commit "$SNAPSHOT_COMMIT" --pr-state "$PR_STATE_PATH" --safety-list "$SAFETY_PATH" \
    > "$TEMP_DIR/local-apply.out" 2>&1; then
    fail 'unsupported runtime accepted local apply'
  fi
  grep -Fq 'shared_coordinator_unavailable: coordinator_symbolic_head_hook_unsupported' "$TEMP_DIR/local-apply.out" \
    || fail "unsupported local apply did not report its capability blocker: $(cat "$TEMP_DIR/local-apply.out")"
  git -C "$REPO" show-ref --verify --quiet refs/heads/stale/merged \
    || fail 'unsupported local apply removed its candidate ref'
  bash "$HELPER" verify-objects --repo "$REPO" --snapshot-commit "$SNAPSHOT_COMMIT" --snapshot "$SNAPSHOT_PATH"
  git -C "$REPO" cat-file -e "${ROOT_OID}^{commit}" \
    || fail 'unsupported local apply lost its snapshotted object'
  printf 'PASS: unsupported Git refused coordinator installation and local deletion; exact ref and object remain.\n'
  exit 0
fi

bash "$HELPER" verify-snapshot --repo "$REPO" --snapshot-commit "$SNAPSHOT_COMMIT" \
  --snapshot "$SNAPSHOT_PATH" --readiness-commit "$ALLOWLIST_COMMIT" --readiness "$READINESS_PATH"
REPORT="$(bash "$HELPER" local --repo "$REPO" --snapshot-commit "$SNAPSHOT_COMMIT" \
  --allowlist-commit "$ALLOWLIST_COMMIT" --allowlist "$ALLOWLIST_PATH" --readiness "$READINESS_PATH")"
grep -Fq 'refs/heads/stale/merged' <<<"$REPORT" || fail 'report-only output omitted the exact target ref'
git -C "$REPO" show-ref --verify --quiet refs/heads/stale/merged \
  || fail 'report-only pass changed the fixture branch'
git -C "$REPO" push -q origin refs/heads/stale/merged:refs/heads/stale/merged
git --git-dir="$BARE_ORIGIN" symbolic-ref HEAD refs/heads/stale/merged
if bash "$HELPER" local --repo "$REPO" --apply --snapshot-commit "$SNAPSHOT_COMMIT" \
  --allowlist-commit "$ALLOWLIST_COMMIT" --allowlist "$ALLOWLIST_PATH" --readiness "$READINESS_PATH" \
  --pr-state-commit "$SNAPSHOT_COMMIT" --pr-state "$PR_STATE_PATH" --safety-list "$SAFETY_PATH" > "$TEMP_DIR/live-default.out" 2>&1; then
  fail 'local apply accepted a branch renamed to the live origin default after snapshot capture'
fi
grep -Fq 'protected_live_default_branch: refs/heads/stale/merged' "$TEMP_DIR/live-default.out" \
  || fail 'local apply did not identify the renamed live default branch'
git -C "$REPO" show-ref --verify --quiet refs/heads/stale/merged \
  || fail 'live default rejection changed the fixture candidate ref'
git --git-dir="$BARE_ORIGIN" symbolic-ref HEAD refs/heads/main

COORDINATOR_READY="${TEMP_DIR}/coordinator-delete-ready"
COORDINATOR_RELEASE="${TEMP_DIR}/coordinator-delete-release"
COMPETING_WORKTREE="${TEMP_DIR}/competing-worktree"
mkfifo "$COORDINATOR_READY" "$COORDINATOR_RELEASE"
exec 8<>"$COORDINATOR_READY"
exec 9<>"$COORDINATOR_RELEASE"
PRUNE_TEST_COORDINATOR_PAUSE=1 \
PRUNE_TEST_COORDINATOR_READY_FIFO="$COORDINATOR_READY" \
PRUNE_TEST_COORDINATOR_RELEASE_FIFO="$COORDINATOR_RELEASE" \
bash "$HELPER" local --repo "$REPO" --apply --snapshot-commit "$SNAPSHOT_COMMIT" \
  --allowlist-commit "$ALLOWLIST_COMMIT" --allowlist "$ALLOWLIST_PATH" --readiness "$READINESS_PATH" \
  --pr-state-commit "$SNAPSHOT_COMMIT" --pr-state "$PR_STATE_PATH" --safety-list "$SAFETY_PATH" \
  > "$TEMP_DIR/local-apply.out" 2>&1 &
LOCAL_APPLY_PID=$!
if ! IFS= read -r -t 15 -u 8 delete_signal; then
  wait "$LOCAL_APPLY_PID" 2>/dev/null || true
  LOCAL_APPLY_PID=""
  cat "$TEMP_DIR/local-apply.out" >&2
  fail 'capability-supported local prune did not reach the expected-OID deletion boundary under the coordinator'
fi
[[ "$delete_signal" == delete-boundary ]] || fail "unexpected prune boundary signal: $delete_signal"
if git -C "$REPO" worktree add -q "$COMPETING_WORKTREE" stale/merged > "$TEMP_DIR/competing-attach.out" 2>&1; then
  fail 'competing worktree attached the local prune candidate while the coordinator was held'
fi
grep -Fq 'branch_or_worktree_ref_change_during_coordinator_window' "$TEMP_DIR/competing-attach.out" \
  || fail 'competing worktree attach was not rejected by the shared coordinator hook'
git -C "$REPO" show-ref --verify --quiet refs/heads/stale/merged \
  || fail 'candidate branch disappeared before the competing worktree attach was checked'
if git -C "$REPO" worktree list --porcelain | grep -F 'branch refs/heads/stale/merged' >/dev/null; then
  fail 'competing worktree was registered on the prune candidate'
fi
printf 'continue\n' >&9
wait "$LOCAL_APPLY_PID" || fail "coordinated local apply failed: $(cat "$TEMP_DIR/local-apply.out")"
LOCAL_APPLY_PID=""
exec 8>&- 8<&-
exec 9>&- 9<&-
grep -Fq 'deleted local ref refs/heads/stale/merged' "$TEMP_DIR/local-apply.out" \
  || fail 'unchanged eligible branch was not deleted under the coordinator'
git -C "$REPO" show-ref --verify --quiet refs/heads/stale/merged \
  && fail 'coordinated local apply left the candidate branch present'
bash "$HELPER" verify-objects --repo "$REPO" --snapshot-commit "$SNAPSHOT_COMMIT" --snapshot "$SNAPSHOT_PATH"
git -C "$REPO" cat-file -e "${ROOT_OID}^{commit}" \
  || fail 'pre-prune object is no longer readable'
printf 'PASS: report-only, supported-runtime local deletion, competing-attach rejection, and snapshot object proof.\n'
