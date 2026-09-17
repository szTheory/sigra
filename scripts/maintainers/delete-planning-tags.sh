#!/usr/bin/env bash
# delete-planning-tags.sh — delete the non-SemVer planning tags named by the committed
# allowlist at .planning/decisions/003-tag-delete-list.tsv, one literal tag name at a time.
#
# Phase 238 (REL-02 / SC-3), 238-CONTEXT D-13 and D-14.
#
# SAFETY RULESET (CRITICAL — do not bypass, do not "normalise"):
#   (1) REPORTING IS THE DEFAULT; MUTATION REQUIRES --apply. This INVERTS the prevailing
#       default of the other operator scripts in this repo, which mutate by default and
#       opt into reporting. The inversion is deliberate: every other script here is
#       reversible, and this one is not — a deleted ref on origin cannot be un-deleted
#       from the remote's point of view. Do not normalise it back to mutate-by-default.
#   (2) The delete set comes ONLY from the allowlist. No glob, no wildcard, no prefix
#       expansion ever reaches a delete invocation. `v1.4*` matches BOTH `v1.4` (a
#       planning tag, in the delete set) and `v1.4.0` (a three-component SemVer tag that
#       backs a published GitHub Release and a published Hex package). That collision is
#       the whole reason this script exists.
#   (3) Exactly ONE pass runs per invocation. The local pass, its verification, the remote
#       pass and its verification are FOUR separate invocations, never chained into one
#       command — a verification that runs in the same process as the mutation it checks
#       is not an independent observation.
#   (4) A delete that fails for any reason other than the tag already being absent ABORTS
#       the pass with a named reason and a non-zero exit. The status is never suppressed:
#       a suppressed status would also hide a genuine server-side rejection.
#   (5) The remote pass is driven by `remote=yes` rows only. 18 of the planning tags are
#       local-only, and `git push origin --delete` on a local-only tag errors.
#   (6) THIS SCRIPT MUST NEVER BE WIRED INTO ANY CI LANE. Its value is the auditability of
#       a one-shot destructive operation, not repetition. There is nothing here for a
#       recurring job to do, and a recurring job would be a standing deletion hazard.
#   (7) No garbage collection, no reflog expiry, no prune. This script runs none of them
#       and neither does the phase around it; the deleted objects stay recoverable.
#
# Usage:
#   bash scripts/maintainers/delete-planning-tags.sh <pass> [--apply] [--allowlist PATH]
#
#   <pass>   exactly one of:
#              local          delete the local refs named by rows with local=yes
#              verify-local   assert the local tag listing equals the local keep-set
#              remote         delete the origin refs named by rows with remote=yes
#              verify-remote  assert origin's tag listing equals the remote keep-set
#
#   --apply             perform the deletion. WITHOUT IT NOTHING IS MUTATED — the pass
#                       reports, per row, what it would do and why. The verify passes are
#                       read-only and run identically with or without this flag.
#   --allowlist PATH    read the delete set from PATH instead of the default
#                       .planning/decisions/003-tag-delete-list.tsv. Same format. This
#                       exists so the malformed-input paths (a zero-row allowlist, a
#                       missing header, a wrong column count, a set naming only tags that
#                       do not exist) can be exercised against a fixture — a safety
#                       behavior reachable only by editing the real data file is a
#                       behavior nobody will ever test.
#
# The two keep expressions differ, and the asymmetry is load-bearing: the archive
# namespace is local-only and never reached origin, so a shared expression would fail the
# remote verification. Both admit an optional prerelease or build suffix on the three
# numeric components, because the release automation may mint a release-candidate tag
# during the deletion window (238-CONTEXT D-05) and a bare three-component expression
# would classify that entirely benign tag as drift.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_ALLOWLIST="${ROOT}/.planning/decisions/003-tag-delete-list.tsv"

KEEP_LOCAL_RE='^(v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?|archive/.*)$'
KEEP_REMOTE_RE='^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$'
EXPECTED_HEADER='tag	local	remote	class	pre_delete_sha	reason'
NON_VACUITY_FLOOR=1

fail() { echo "delete-planning-tags: FAIL: $*" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
usage: delete-planning-tags.sh <local|verify-local|remote|verify-remote> [--apply] [--allowlist PATH]

  local          delete local refs named by allowlist rows with local=yes
  verify-local   assert the local tag listing equals the local keep-set
  remote         delete origin refs named by allowlist rows with remote=yes
  verify-remote  assert origin's tag listing equals the remote keep-set

  --apply             mutate. Reporting is the default; without this flag nothing changes.
  --allowlist PATH    use PATH instead of .planning/decisions/003-tag-delete-list.tsv
USAGE
  exit 2
}

PASS=""
APPLY=0
ALLOWLIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    local|verify-local|remote|verify-remote)
      [[ -z "$PASS" ]] || fail "more_than_one_pass_selector: '$PASS' then '$1'; exactly one pass runs per invocation"
      PASS="$1"; shift;;
    --apply)     APPLY=1; shift;;
    --allowlist) [[ $# -ge 2 ]] || fail "allowlist_flag_missing_value"; ALLOWLIST="$2"; shift 2;;
    -h|--help)   usage;;
    *) echo "delete-planning-tags: FAIL: unknown argument: $1" >&2; usage;;
  esac
done

[[ -n "$PASS" ]] || { echo "delete-planning-tags: FAIL: no pass selector given" >&2; usage; }
[[ -n "$ALLOWLIST" ]] || ALLOWLIST="$DEFAULT_ALLOWLIST"
# Resolve the allowlist against the CALLER's cwd before anything changes directory, so a
# relative --allowlist means what the operator typed rather than something relative to the
# repository root.
case "$ALLOWLIST" in /*) ;; *) ALLOWLIST="$PWD/$ALLOWLIST";; esac

command -v git >/dev/null 2>&1 || fail "git_not_on_path"
command -v sort >/dev/null 2>&1 || fail "sort_not_on_path"
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || fail "not_a_git_repository: $ROOT"
# Every git invocation below runs from the repository root with no -C, so the delete call
# sites read exactly `git tag -d "$tag"` / `git push origin --delete "$tag"` — one literal
# name, no path indirection between the reader and the destructive verb.
cd "$ROOT"
[[ -f "$ALLOWLIST" ]] || fail "allowlist_not_found: $ALLOWLIST"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Allowlist parse, fail-closed
# ---------------------------------------------------------------------------
ROWS="${WORK}/rows.tsv"
: > "$ROWS"
header_seen=0
line_no=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_no=$((line_no + 1))
  [[ -z "$line" ]] && continue
  case "$line" in \#*) continue;; esac
  if [[ "$header_seen" -eq 0 ]]; then
    [[ "$line" == "$EXPECTED_HEADER" ]] || fail "allowlist_header_missing_or_wrong: line $line_no of $ALLOWLIST is not the six named tab-separated columns"
    header_seen=1
    continue
  fi
  fields=$(awk -F'\t' '{print NF}' <<<"$line")
  [[ "$fields" -eq 6 ]] || fail "allowlist_row_wrong_column_count: line $line_no has $fields fields, expected 6"
  printf '%s\n' "$line" >> "$ROWS"
done < "$ALLOWLIST"

[[ "$header_seen" -eq 1 ]] || fail "allowlist_header_missing_or_wrong: no header row found in $ALLOWLIST"
row_count=$(grep -c . "$ROWS" || true)
[[ "$row_count" -ge 1 ]] || fail "allowlist_parsed_zero_rows: $ALLOWLIST yielded no data rows — the parse broke, this is not a pass"

while IFS=$'\t' read -r tag _l _r _c _s _reason; do
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$ ]] && fail "allowlist_row_names_a_release_tag: $tag"
  case "$tag" in archive/*) fail "allowlist_row_names_an_archive_tag: $tag";; esac
done < "$ROWS"

echo "delete-planning-tags: pass=$PASS apply=$APPLY allowlist=$ALLOWLIST rows=$row_count"
[[ "$APPLY" -eq 1 ]] || echo "delete-planning-tags: REPORTING ONLY — no ref will be touched (pass --apply to mutate)"

# ---------------------------------------------------------------------------
# Listings
# ---------------------------------------------------------------------------
list_local() {
  git tag > "$1"
}

list_remote() {
  # The transport failure and the legitimately-empty listing are different facts and must not
  # share one exit status. `git ls-remote` runs alone so its status is its own; only the `grep -v`
  # (which exits 1 on a tagless remote) is allowed to be swallowed.
  local raw="${WORK}/remote-raw.txt"
  git ls-remote --tags origin > "$raw" </dev/null \
    || fail "remote_listing_failed: git ls-remote --tags origin exited non-zero (no ref was touched)"
  sed 's#.*refs/tags/##' "$raw" | grep -v '\^{}' > "$1" || true
}

# ---------------------------------------------------------------------------
# Delete passes — one literal tag name per invocation, taken from the row's first field
# ---------------------------------------------------------------------------
run_local_pass() {
  local deleted=0 absent=0 would=0
  while IFS=$'\t' read -r tag loc _rem _class _sha _reason; do
    [[ "$loc" == "yes" ]] || continue
    if ! git rev-parse -q --verify "refs/tags/${tag}" >/dev/null 2>&1 </dev/null; then
      echo "  absent  ${tag} (already gone locally; skipped, not an error)"
      absent=$((absent + 1))
      continue
    fi
    if [[ "$APPLY" -eq 0 ]]; then
      echo "  would delete local ref refs/tags/${tag} (allowlist row, local=yes)"
      would=$((would + 1))
      continue
    fi
    local out
    if ! out=$(git tag -d "$tag" 2>&1 </dev/null); then
      fail "local_delete_failed: ${tag}: ${out}"
    fi
    echo "  deleted ${tag}"
    deleted=$((deleted + 1))
  done < "$ROWS"
  echo "delete-planning-tags: local pass done — deleted=${deleted} absent=${absent} would_delete=${would}"
}

run_remote_pass() {
  git remote get-url origin >/dev/null 2>&1 || fail "no_origin_remote"
  local present="${WORK}/remote-present.txt"
  list_remote "$present"
  # Same floor compare_side applies: an empty listing would relabel every remote row as the one
  # permissible skip ("already gone on origin") and print a green receipt for a pass that read
  # nothing. An empty parse is never a pass.
  local n_present
  n_present=$(grep -c . "$present" || true)
  [[ "$n_present" -ge "$NON_VACUITY_FLOOR" ]] \
    || fail "remote_listing_empty: the parse broke, this is not a pass"
  local deleted=0 absent=0 would=0
  while IFS=$'\t' read -r tag _loc rem _class _sha _reason; do
    [[ "$rem" == "yes" ]] || continue
    if ! grep -qxF "$tag" "$present"; then
      echo "  absent  ${tag} (already gone on origin; skipped, not an error)"
      absent=$((absent + 1))
      continue
    fi
    if [[ "$APPLY" -eq 0 ]]; then
      echo "  would delete origin ref refs/tags/${tag} (allowlist row, remote=yes)"
      would=$((would + 1))
      continue
    fi
    local out
    if ! out=$(git push origin --delete "$tag" 2>&1 </dev/null); then
      echo "$out" >&2
      echo "delete-planning-tags: if the rejection above is GH013 the tag-namespace ruleset governs deletion;" >&2
      echo "  238-02 observed that it does NOT (238-EVIDENCE.md AFTER-DELETE-PROBE, enforcement left active)," >&2
      echo "  so a GH013 here means the live ruleset changed. Do not retry blind: re-read the ruleset, and if a" >&2
      echo "  flip window is genuinely required set enforcement to 'disabled', run this pass, flip it back to" >&2
      echo "  'active', and record the window and the reason in the evidence ledger." >&2
      fail "remote_delete_failed: ${tag}"
    fi
    echo "  deleted ${tag} (origin)"
    deleted=$((deleted + 1))
  done < "$ROWS"
  echo "delete-planning-tags: remote pass done — deleted=${deleted} absent=${absent} would_delete=${would}"
}

# ---------------------------------------------------------------------------
# Verify passes — per-side set comparison, both operands sorted at compare time
# ---------------------------------------------------------------------------
compare_side() {
  local side="$1" listing="$2" keep_re="$3"
  local keep="${WORK}/${side}-keep.txt"
  local a="${WORK}/${side}-listing.sorted"
  local b="${WORK}/${side}-keep.sorted"
  grep -E "$keep_re" "$listing" > "$keep" || true

  local n_listing n_keep
  n_listing=$(grep -c . "$listing" || true)
  n_keep=$(grep -c . "$keep" || true)
  echo "delete-planning-tags: ${side} listing=${n_listing} keep-set=${n_keep} (keep expression: ${keep_re})"
  [[ "$n_listing" -ge "$NON_VACUITY_FLOOR" ]] || fail "${side}_listing_empty: the parse broke, this is not a pass"
  [[ "$n_keep" -ge "$NON_VACUITY_FLOOR" ]] || fail "${side}_keep_set_empty: the parse broke, this is not a pass"

  sort -u "$listing" > "$a"
  sort -u "$keep" > "$b"
  if ! diff -u "$b" "$a" > "${WORK}/${side}.diff" 2>&1; then
    cat "${WORK}/${side}.diff" >&2
    fail "${side}_set_not_equal_to_keep_set"
  fi
  echo "delete-planning-tags: ${side} set-equal to its regex-derived keep-set"
}

case "$PASS" in
  local)
    run_local_pass;;
  remote)
    run_remote_pass;;
  verify-local)
    LISTING="${WORK}/local.txt"
    list_local "$LISTING"
    compare_side "local" "$LISTING" "$KEEP_LOCAL_RE";;
  verify-remote)
    git remote get-url origin >/dev/null 2>&1 || fail "no_origin_remote"
    LISTING="${WORK}/remote.txt"
    list_remote "$LISTING"
    compare_side "remote" "$LISTING" "$KEEP_REMOTE_RE";;
  *)
    fail "unreachable_pass_selector: $PASS";;
esac
