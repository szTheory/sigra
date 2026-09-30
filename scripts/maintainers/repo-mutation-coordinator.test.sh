#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COORDINATOR="${ROOT_DIR}/scripts/maintainers/repo-mutation-coordinator.sh"
TEMP_DIR="$(mktemp -d)"
MAIN="${TEMP_DIR}/main"
PEER="${TEMP_DIR}/peer"
COORDINATOR_ROOT=""
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
cleanup() {
  [[ -z "${HOLDER_PID:-}" ]] || { kill "$HOLDER_PID" 2>/dev/null || true; wait "$HOLDER_PID" 2>/dev/null || true; }
  [[ -z "${LEASE_GIT_PID:-}" ]] || { kill "$LEASE_GIT_PID" 2>/dev/null || true; wait "$LEASE_GIT_PID" 2>/dev/null || true; }
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

inventory_scan() {
  local root="$1" result status=0
  result="$(node "$ROOT_DIR/scripts/maintainers/prune-stale-branches-admission.mjs" coverage --repo "$root" 2>&1)" || status=$?
  printf '%s\n' "$result"
  (( status == 0 ))
}

command -v jq >/dev/null 2>&1 || fail 'jq is required'
command -v node >/dev/null 2>&1 || fail 'node is required for production mutation inventory'

# The installer capability probe must reject this Git executable before it
# publishes any coordinator files or changes the disposable target config.
PROBE_MAIN="${TEMP_DIR}/capability-main"
PROBE_PEER="${TEMP_DIR}/capability-peer"
git init -q --initial-branch=main "$PROBE_MAIN"
git -C "$PROBE_MAIN" config user.name 'GSD Coordinator Capability Fixture'
git -C "$PROBE_MAIN" config user.email 'gsd-coordinator@example.invalid'
printf 'capability fixture\n' > "$PROBE_MAIN/root.txt"
git -C "$PROBE_MAIN" add root.txt
git -C "$PROBE_MAIN" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: capability root'
git -C "$PROBE_MAIN" worktree add -q -b capability-peer "$PROBE_PEER" main
FAKE_GIT_BIN="${TEMP_DIR}/ambient-git-bin"
mkdir -p "$FAKE_GIT_BIN"
cat > "${FAKE_GIT_BIN}/git" <<'FAKE_GIT'
#!/usr/bin/env sh
printf 'ambient PATH git must not run\n' >&2
exit 91
FAKE_GIT
chmod 755 "${FAKE_GIT_BIN}/git"
PINNED_VERIFY_OUTPUT="$(PATH="${FAKE_GIT_BIN}:${PATH}" bash -c 'source "$1"; sigra_coordinator_pin_git; printf "git=%s version=%s\n" "$SIGRA_COORDINATOR_GIT_PATH" "$(git --version)"' _ "$COORDINATOR" 2>&1)" \
  || fail "coordinator used an ambient Git path: ${PINNED_VERIFY_OUTPUT}"
grep -Fq 'git=/usr/bin/git version=git version 2.50.1' <<< "$PINNED_VERIFY_OUTPUT" \
  || fail "capability fixture did not report the exact pinned runtime: ${PINNED_VERIFY_OUTPUT}"
PROBE_COMMON_DIR="$(git -C "$PROBE_MAIN" rev-parse --path-format=absolute --git-common-dir)"
PROBE_COORDINATOR_ROOT="${PROBE_COMMON_DIR}/sigra-branch-worktree-coordinator"
PROBE_HOOKS_BEFORE="$(git -C "$PROBE_MAIN" config --local --get core.hooksPath 2>/dev/null || true)"
PROBE_HEAD_BEFORE="$(git -C "$PROBE_PEER" symbolic-ref -q HEAD)"
if bash "$COORDINATOR" install --repo "$PROBE_MAIN" >"$TEMP_DIR/capability-install.log" 2>&1; then
  grep -Fq 'SUPPORTED: coordinator symbolic HEAD hook enforced' "$TEMP_DIR/capability-install.log" \
    || fail 'successful install did not report a direct symbolic-HEAD capability proof'
  [[ "$(git -C "$PROBE_MAIN" config --local --get core.hooksPath)" == "${PROBE_COORDINATOR_ROOT}/hooks" ]] \
    || fail 'supported capability fixture did not install the verified shared hooks path'
  [[ -x "${PROBE_COORDINATOR_ROOT}/hooks/reference-transaction" ]] \
    || fail 'supported capability fixture did not publish its reference-transaction hook'
  printf 'PASS: supported runtime capability probe installed only in its disposable fixture.\n'
else
  if ! grep -Fq 'coordinator_symbolic_head_hook_unsupported' "$TEMP_DIR/capability-install.log"; then
    fail "capability install failed for an unexpected reason: $(cat "$TEMP_DIR/capability-install.log")"
  fi
  [[ "$(git -C "$PROBE_MAIN" config --local --get core.hooksPath 2>/dev/null || true)" == "$PROBE_HOOKS_BEFORE" ]] \
    || fail 'unsupported capability probe changed the target core.hooksPath'
  [[ ! -e "$PROBE_COORDINATOR_ROOT" ]] \
    || fail 'unsupported capability probe created persistent coordinator files in the target repo'
  [[ "$(git -C "$PROBE_PEER" symbolic-ref -q HEAD)" == "$PROBE_HEAD_BEFORE" ]] \
    || fail 'unsupported capability probe changed the target linked-worktree HEAD'
  printf 'PASS: unsupported runtime capability probe refused before target configuration or hook writes.\n'
  exit 0
fi

git init -q --initial-branch=main "$MAIN"
git -C "$MAIN" config user.name 'GSD Coordinator Fixture'
git -C "$MAIN" config user.email 'gsd-coordinator@example.invalid'
git -C "$MAIN" config gc.auto 0
git -C "$MAIN" config maintenance.auto false
printf 'coordinator fixture\n' > "$MAIN/root.txt"
git -C "$MAIN" add root.txt
git -C "$MAIN" -c gc.auto=0 -c maintenance.auto=false commit -q -m 'fixture: coordinator root'
ROOT_OID="$(git -C "$MAIN" rev-parse HEAD)"
git -C "$MAIN" worktree add -q -b peer "$PEER" main

OLD_HOOKS="$(git -C "$MAIN" rev-parse --path-format=absolute --git-path hooks)"
mkdir -p "$OLD_HOOKS"
HOOK_LOG="$TEMP_DIR/previous-hook.log"
cat > "$OLD_HOOKS/reference-transaction" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
phase="$1"
printf '%s\n' "$phase" >> "$GSD_COORDINATOR_TEST_HOOK_LOG"
if [[ "$phase" == prepared && -n "${GSD_COORDINATOR_TEST_READY_FIFO:-}" ]]; then
  printf 'prepared\n' > "$GSD_COORDINATOR_TEST_READY_FIFO"
  IFS= read -r release_signal < "$GSD_COORDINATOR_TEST_RELEASE_FIFO"
fi
cat >/dev/null
HOOK
chmod 755 "$OLD_HOOKS/reference-transaction"
printf '#!/usr/bin/env bash\nexit 0\n' > "$OLD_HOOKS/post-checkout"
chmod 755 "$OLD_HOOKS/post-checkout"
export GSD_COORDINATOR_TEST_HOOK_LOG="$HOOK_LOG"

git -C "$MAIN" config extensions.worktreeConfig true
git -C "$PEER" config --worktree core.hooksPath "$OLD_HOOKS"
if bash "$COORDINATOR" install --repo "$MAIN" >"$TEMP_DIR/override-install.log" 2>&1; then
  fail 'coordinator install accepted a pre-existing linked-worktree hook override'
fi
grep -q 'worktree_specific_hooks_path_prevents_install' "$TEMP_DIR/override-install.log" \
  || fail "pre-existing hook override did not produce a specific install failure: $(cat "$TEMP_DIR/override-install.log")"
[[ -z "$(git -C "$MAIN" config --local --get core.hooksPath 2>/dev/null || true)" ]] \
  || fail 'failed install changed the shared core.hooksPath config'
[[ ! -e "$(git -C "$MAIN" rev-parse --git-common-dir)/sigra-branch-worktree-coordinator/hooks" ]] \
  || fail 'failed install published a coordinator hook before the conflict was resolved'
git -C "$PEER" config --worktree --unset core.hooksPath

bash "$COORDINATOR" install --repo "$MAIN"
COMMON_DIR="$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)"
COORDINATOR_ROOT="$COMMON_DIR/sigra-branch-worktree-coordinator"
[[ "$(git -C "$PEER" rev-parse --path-format=absolute --git-path hooks)" == "$COORDINATOR_ROOT/hooks" ]] || fail 'linked worktree does not use common hooks'
[[ -L "$COORDINATOR_ROOT/previous-reference-transaction" ]] || fail 'existing reference hook was not chained'
[[ -L "$COORDINATOR_ROOT/hooks/post-checkout" && -x "$COORDINATOR_ROOT/hooks/post-checkout" ]] || fail 'existing executable hook was not preserved'
bash "$COORDINATOR" install --repo "$MAIN" >/dev/null || fail 'coordinator install is not idempotent'
git -C "$PEER" config --worktree core.hooksPath "$OLD_HOOKS"
if bash "$COORDINATOR" verify --repo "$MAIN" >"$TEMP_DIR/override-verify.log" 2>&1; then
  fail 'coordinator verification accepted a linked-worktree hook override'
fi
grep -q registered_worktree_hooks_mismatch "$TEMP_DIR/override-verify.log" \
  || fail 'linked-worktree hook override did not produce a specific mismatch'
git -C "$PEER" config --worktree --unset core.hooksPath
bash "$COORDINATOR" verify --repo "$MAIN" >/dev/null || fail 'coordinator did not recover after the fixture override was removed'

# A missing chained hook also makes verification fail closed.
mv "$COORDINATOR_ROOT/previous-reference-transaction" "$TEMP_DIR/prior-hook-backup"
if bash "$COORDINATOR" verify --repo "$MAIN" >"$TEMP_DIR/missing-chain-verify.log" 2>&1; then
  fail 'coordinator verification accepted a missing chained reference hook'
fi
grep -q previous_reference_transaction_hook_missing "$TEMP_DIR/missing-chain-verify.log" \
  || fail 'missing chained hook did not produce a specific verification failure'
mv "$TEMP_DIR/prior-hook-backup" "$COORDINATOR_ROOT/previous-reference-transaction"
bash "$COORDINATOR" verify --repo "$MAIN" >/dev/null || fail 'coordinator did not verify after restoring the fixture hook chain'

bash "$COORDINATOR" run --repo "$MAIN" --operation owner-ref-proof -- git -C "$MAIN" branch owner-authorized "$ROOT_OID"
git -C "$MAIN" show-ref --verify --quiet refs/heads/owner-authorized || fail 'owner token did not permit its ref transaction'
printf '%s\t%s\t%s\n' "$ROOT_OID" "$ROOT_OID" refs/heads/hook-chain-probe \
  | "$COORDINATOR_ROOT/hooks/reference-transaction" preparing
grep -q '^preparing$' "$HOOK_LOG" || fail 'previous hook did not receive preparing'
grep -q '^prepared$' "$HOOK_LOG" || fail 'previous hook did not receive prepared'
grep -q '^committed$' "$HOOK_LOG" || fail 'previous hook did not receive committed'

# Pause a real Git ref transaction in its prepared hook; the lease must block acquisition.
LEASE_READY="$TEMP_DIR/lease-ready"; LEASE_RELEASE="$TEMP_DIR/lease-release"
mkfifo "$LEASE_READY" "$LEASE_RELEASE"
exec 8<>"$LEASE_READY"; exec 9<>"$LEASE_RELEASE"
GSD_COORDINATOR_TEST_READY_FIFO="$LEASE_READY" GSD_COORDINATOR_TEST_RELEASE_FIFO="$LEASE_RELEASE" \
  git -C "$PEER" branch lease-in-flight "$ROOT_OID" >"$TEMP_DIR/lease-git.log" 2>&1 &
LEASE_GIT_PID=$!
IFS= read -r -t 15 -u 8 lease_signal || fail 'Git did not reach prepared hook'
[[ "$lease_signal" == prepared ]] || fail "unexpected lease signal: $lease_signal"
if bash "$COORDINATOR" run --repo "$MAIN" --operation must-not-acquire -- touch "$TEMP_DIR/must-not-run" >"$TEMP_DIR/lease-acquire.log" 2>&1; then
  fail 'coordinator acquired during an in-flight ref transaction'
fi
grep -q coordinator_ref_transactions_in_flight "$TEMP_DIR/lease-acquire.log" || fail 'in-flight lease was not reported'
[[ ! -e "$TEMP_DIR/must-not-run" ]] || fail 'command ran after rejected acquisition'
printf 'continue\n' >&9
wait "$LEASE_GIT_PID" || fail "fixture Git transaction failed: $(cat "$TEMP_DIR/lease-git.log")"
LEASE_GIT_PID=""
exec 8>&- 8<&-; exec 9>&- 9<&-
git -C "$PEER" show-ref --verify --quiet refs/heads/lease-in-flight || fail 'leased Git transaction did not resume'

# Unresolved leases are never auto-reclaimed.
mkdir "$COORDINATOR_ROOT/transactions/txn-stale-fixture"
if bash "$COORDINATOR" run --repo "$MAIN" --operation stale-lease -- true >"$TEMP_DIR/stale-lease.log" 2>&1; then
  fail 'coordinator ignored an unresolved lease'
fi
grep -q coordinator_ref_transactions_in_flight "$TEMP_DIR/stale-lease.log" || fail 'stale lease did not fail closed'
rmdir "$COORDINATOR_ROOT/transactions/txn-stale-fixture"

# Hold the common lock and try ref updates and attachments through the peer worktree.
READY_FIFO="$TEMP_DIR/owner-ready"; RELEASE_FIFO="$TEMP_DIR/owner-release"
HOLDER_LOG="$TEMP_DIR/owner.log"; HOLDER_SCRIPT="$TEMP_DIR/hold-coordinator.sh"
mkfifo "$READY_FIFO" "$RELEASE_FIFO"
exec 10<>"$READY_FIFO"; exec 11<>"$RELEASE_FIFO"
cat > "$HOLDER_SCRIPT" <<'HOLDER'
#!/usr/bin/env bash
set -euo pipefail
git -C "$FIXTURE_MAIN" branch owner-during-lock "$FIXTURE_ROOT_OID"
printf 'held\n' > "$FIXTURE_READY_FIFO"
IFS= read -r release_signal < "$FIXTURE_RELEASE_FIFO"
HOLDER
chmod 755 "$HOLDER_SCRIPT"
bash "$COORDINATOR" run --repo "$MAIN" --operation held-lock-proof -- \
  env FIXTURE_MAIN="$MAIN" FIXTURE_ROOT_OID="$ROOT_OID" FIXTURE_READY_FIFO="$READY_FIFO" FIXTURE_RELEASE_FIFO="$RELEASE_FIFO" bash "$HOLDER_SCRIPT" \
  >"$HOLDER_LOG" 2>&1 &
HOLDER_PID=$!
IFS= read -r -t 15 -u 10 held_signal || fail 'coordinator owner did not hold the common lock'
[[ "$held_signal" == held ]] || fail "unexpected owner signal: $held_signal"
if bash "$COORDINATOR" run --repo "$MAIN" --operation competing-apply -- \
  touch "$TEMP_DIR/second-owner-ran" >"$TEMP_DIR/competing-owner.log" 2>&1; then
  fail 'second coordinator owner acquired while the first owner was active'
fi
grep -q coordinator_busy_or_stale_lock_present "$TEMP_DIR/competing-owner.log" \
  || fail 'second coordinator owner did not report the held common lock'
[[ ! -e "$TEMP_DIR/second-owner-ran" ]] || fail 'competing owner command ran while lock was held'

if git -C "$PEER" branch blocked-branch "$ROOT_OID" >"$TEMP_DIR/blocked-branch.log" 2>&1; then fail 'uncoordinated branch creation passed'; fi
grep -q branch_or_worktree_ref_change_during_coordinator_window "$TEMP_DIR/blocked-branch.log" || fail 'branch creation lacked coordinator rejection'
git -C "$PEER" show-ref --verify --quiet refs/heads/blocked-branch && fail 'blocked branch was created'

if git -C "$PEER" update-ref refs/heads/blocked-update "$ROOT_OID" >"$TEMP_DIR/blocked-update.log" 2>&1; then fail 'uncoordinated update-ref passed'; fi
grep -q branch_or_worktree_ref_change_during_coordinator_window "$TEMP_DIR/blocked-update.log" || fail 'update-ref lacked coordinator rejection'
git -C "$PEER" show-ref --verify --quiet refs/heads/blocked-update && fail 'blocked update-ref ref was created'

hook_count_before_head_probe="$(wc -l < "$HOOK_LOG" | tr -d ' ')"
if git -C "$PEER" symbolic-ref HEAD refs/heads/main >"$TEMP_DIR/head-probe.log" 2>&1; then
  [[ "$(git -C "$PEER" symbolic-ref HEAD)" == refs/heads/main ]] \
    || fail 'direct symbolic HEAD update returned success without changing the linked-worktree branch'
  git -C "$PEER" symbolic-ref HEAD refs/heads/peer \
    || fail 'could not restore the fixture worktree HEAD after the capability probe'
  [[ "$(wc -l < "$HOOK_LOG" | tr -d ' ')" == "$hook_count_before_head_probe" ]] \
    || fail 'direct symbolic HEAD probe returned success after invoking the reference-transaction hook'
  SYMBOLIC_HEAD_RESULT='bypassed-hook'
  printf 'KNOWN LIMITATION: direct git symbolic-ref HEAD bypasses reference-transaction on this Git build.\n'
else
  grep -q branch_or_worktree_ref_change_during_coordinator_window "$TEMP_DIR/head-probe.log" \
    || fail "direct symbolic HEAD probe failed for an unexpected reason: $(cat "$TEMP_DIR/head-probe.log")"
  [[ "$(git -C "$PEER" symbolic-ref HEAD)" == refs/heads/peer ]] \
    || fail 'rejected direct symbolic HEAD update changed the linked-worktree branch'
  SYMBOLIC_HEAD_RESULT='gated-by-hook'
  printf 'PASS: direct git symbolic-ref HEAD is gated by the reference-transaction hook on this Git build.\n'
fi

ATTACHED="$TEMP_DIR/attached"
if git -C "$MAIN" worktree add -q "$ATTACHED" owner-authorized >"$TEMP_DIR/blocked-existing-branch-worktree.log" 2>&1; then
  fail 'uncoordinated worktree add of an existing branch passed'
fi
grep -q branch_or_worktree_ref_change_during_coordinator_window "$TEMP_DIR/blocked-existing-branch-worktree.log" \
  || fail 'existing-branch worktree add lacked coordinator rejection'
if git -C "$MAIN" worktree list --porcelain | grep -F "worktree $ATTACHED" >/dev/null; then
  fail 'blocked existing-branch worktree appeared in registry'
fi
if git -C "$MAIN" worktree add -q -b blocked-worktree "$ATTACHED" main >"$TEMP_DIR/blocked-worktree.log" 2>&1; then fail 'uncoordinated worktree add passed'; fi
grep -q branch_or_worktree_ref_change_during_coordinator_window "$TEMP_DIR/blocked-worktree.log" || fail 'worktree add lacked coordinator rejection'
git -C "$MAIN" show-ref --verify --quiet refs/heads/blocked-worktree && fail 'blocked worktree branch was created'
if git -C "$MAIN" worktree list --porcelain | grep -F "worktree $ATTACHED" >/dev/null; then fail 'blocked worktree appeared in registry'; fi

printf 'continue\n' >&11
wait "$HOLDER_PID" || fail "coordinator owner failed: $(cat "$HOLDER_LOG")"
HOLDER_PID=""
exec 10>&- 10<&-; exec 11>&- 11<&-
[[ "$(git -C "$MAIN" rev-parse --verify refs/heads/owner-during-lock)" == "$ROOT_OID" ]] || fail 'owner mutation did not complete'
bash "$COORDINATOR" status --repo "$PEER" | grep -q 'lock=free' || fail 'coordinator lock was not released'

git -C "$MAIN" worktree add -q -b after-lock "$ATTACHED" main
[[ "$(git -C "$ATTACHED" symbolic-ref HEAD)" == refs/heads/after-lock ]] || fail 'worktree attach failed after release'

inventory_scan "$ROOT_DIR" || fail 'production mutation inventory found an uncoordinated entry point'
PROBE="$TEMP_DIR/inventory-probe"; mkdir -p "$PROBE"
cp -R "$ROOT_DIR/scripts" "$PROBE/scripts"
printf '#!/usr/bin/env bash\ngit -C "$repo" update-ref refs/heads/uncoordinated HEAD\n' > "$PROBE/scripts/maintainers/rogue-mutator.sh"
if inventory_scan "$PROBE" >/dev/null 2>&1; then fail 'inventory did not detect an added uncoordinated ref mutator'; fi

printf 'PASS: coordinator gates branch/worktree mutations; symbolic_head=%s; owner tokens, leases, hooks, and inventory verified.\n' "$SYMBOLIC_HEAD_RESULT"
