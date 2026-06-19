#!/usr/bin/env bash
# Phase 158 (ADMIN-UI-COHERENCE): automated replacement for the manual
# "human eyeballs `git status` before re-recording admin-checkpoint baselines".
#
# Fails the build if any Playwright snapshot PNG OUTSIDE an explicit allowlist
# changed vs a git base ref. The allowlist is a committed manifest
# (test/example/priv/playwright/snapshot-allowlist) whose STEADY STATE is empty,
# so on an ordinary PR ANY baseline change fails until the PR declares the
# intended-delta slug in the same diff — encoding the milestone's
# "zero re-records is the proof" discipline as machine policy.
#
# Slugs are keyed by stripping the `-admin-checkpoints-{chromium,mobile,dark}.png`
# suffix, so one allowlist line covers all three projects of an intended change.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SNAP_DIR="${SNAP_DIR:-test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots}"
ALLOWLIST="${ROOT}/test/example/priv/playwright/snapshot-allowlist"
BASE="HEAD"
CANARY="impersonation-banner"
REQUIRE_ALL=0
declare -a EXTRA_ALLOW=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    --allowlist) ALLOWLIST="$2"; shift 2;;
    --allow) EXTRA_ALLOW+=("$2"); shift 2;;
    --canary) CANARY="$2"; shift 2;;
    --require-all) REQUIRE_ALL=1; shift;;
    *) echo "snapshot-canary-guard: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "snapshot-canary-guard: FAIL: $*" >&2
  exit 1
}

# --- load allowlist slugs (committed manifest + --allow flags) ---------------
declare -A ALLOWED=()
if [[ -f "$ALLOWLIST" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs || true)"
    [[ -n "$line" ]] && ALLOWED["$line"]=1
  done < "$ALLOWLIST"
fi
for s in "${EXTRA_ALLOW[@]:-}"; do
  [[ -n "$s" ]] && ALLOWED["$s"]=1
done

slug_of() {
  basename "$1" | sed -E \
    's/-admin-checkpoints-(chromium|mobile|dark)\.png$//;
     s/-admin-design-(chromium|mobile|dark)\.png$//'
}

# --- collect changed snapshot files: tracked diff + untracked ---------------
declare -A CHANGED_SLUGS=()
note() {
  local sl="$1" kind="$2"
  if [[ -z "${CHANGED_SLUGS[$sl]:-}" ]]; then
    CHANGED_SLUGS[$sl]="$kind"
  elif [[ "${CHANGED_SLUGS[$sl]}" != "$kind" ]]; then
    CHANGED_SLUGS[$sl]="mixed"
  fi
}

# Tracked add/modify/delete vs BASE, scoped to the snapshot dir.
while IFS=$'\t' read -r status path; do
  [[ -z "${path:-}" ]] && continue
  case "$path" in "$SNAP_DIR"/*.png) ;; *) continue;; esac
  case "$status" in
    A*) note "$(slug_of "$path")" added;;
    D*) note "$(slug_of "$path")" deleted;;
    *)  note "$(slug_of "$path")" modified;;
  esac
done < <(git -C "$ROOT" diff --name-status "$BASE" -- "$SNAP_DIR" 2>/dev/null || true)

# Untracked (?? in porcelain) — NEW files not yet `git add`ed.
while IFS= read -r line; do
  [[ "$line" == '??'* ]] || continue
  path="${line:3}"
  case "$path" in "$SNAP_DIR"/*.png) ;; *) continue;; esac
  note "$(slug_of "$path")" added
done < <(git -C "$ROOT" status --porcelain -- "$SNAP_DIR" 2>/dev/null || true)

# --- evaluate ---------------------------------------------------------------
violations=0
for sl in "${!CHANGED_SLUGS[@]}"; do
  kind="${CHANGED_SLUGS[$sl]}"
  if [[ "$sl" == "$CANARY" ]]; then
    # A canary is a tripwire against UNINTENDED drift of an ESTABLISHED baseline,
    # so it fires on modify/delete/mixed — never on first establishment. Pure
    # `added` is the legitimate one-time birth of the canary (e.g. a brand-new
    # gallery introduced wholesale vs a base that lacks it); tolerating it keeps
    # the tripwire armed for every future incremental PR while letting the
    # introduction PR pass. The canary is still NOT allowlistable.
    if [[ "$kind" == "added" ]]; then
      echo "snapshot-canary-guard: OK canary first-established (added): ${CANARY}"
      continue
    fi
    fail "canary snapshot ${kind}: '${CANARY}' must stay byte-green — modify/delete of an established canary is forbidden"
  fi
  if [[ -z "${ALLOWED[$sl]:-}" ]]; then
    echo "snapshot-canary-guard: FAIL: unintended snapshot change: ${sl} (${kind}) — not in ${ALLOWLIST}" >&2
    violations=1
  else
    echo "snapshot-canary-guard: OK intended ${kind} delta: ${sl}"
  fi
done

if [[ "$REQUIRE_ALL" -eq 1 ]]; then
  for sl in "${!ALLOWED[@]}"; do
    if [[ -z "${CHANGED_SLUGS[$sl]:-}" ]]; then
      echo "snapshot-canary-guard: FAIL: declared intended delta '${sl}' did not change" >&2
      violations=1
    fi
  done
fi

if [[ "$violations" -ne 0 ]]; then
  exit 1
fi

echo "snapshot-canary-guard: PASS (${#CHANGED_SLUGS[@]} changed slug(s), all within allowlist)"
