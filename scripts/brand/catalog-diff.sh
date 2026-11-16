#!/usr/bin/env bash
set -euo pipefail

# Before/after text-diff report for the brand catalog (BGEN-07).
#
# Compares two catalog directories and prints one unified diff per changed
# file plus a changed/added/removed summary. MANIFEST.json is ignored (it pins
# the capture, it is not catalog output), as is the macOS .DS_Store clutter.
# Every path in the report is relative to its input directory, so the output
# carries no absolute (home) paths and can be pasted into a public PR.
#
# Portable on purpose: no GNU-only diff flags, no bash 4 features (mapfile,
# associative arrays), `sort` and `comm` run under LC_ALL=C.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_BEFORE="${ROOT}/test/fixtures/brand/before"
DEFAULT_AFTER="${ROOT}/tmp/catalog-after"

FAIL_ON_DIFF=false

usage() {
  cat <<'EOF'
Usage: catalog-diff.sh [--fail-on-diff] [<before_dir> <after_dir>]

Print a per-file unified diff and a changed/added/removed summary between two
brand catalog directories. MANIFEST.json and .DS_Store files are ignored.

Defaults (when no directories are given):
  before_dir  test/fixtures/brand/before   (the immutable committed catalog)
  after_dir   tmp/catalog-after            (SIGRA_BRAND_CATALOG=after output)

Options:
  --fail-on-diff  exit 1 when any difference is found (default: report only)
  -h, --help      show this help

Exit status:
  0  report produced (or no differences)
  1  differences found and --fail-on-diff was given
  2  usage error (bad flag, wrong argument count, missing directory)
EOF
}

fail() {
  echo "catalog-diff: $*" >&2
  exit 2
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fail-on-diff)
      FAIL_ON_DIFF=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POSITIONAL+=("$1")
        shift
      done
      ;;
    -*)
      usage >&2
      fail "unknown argument: $1"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

case "${#POSITIONAL[@]}" in
  0)
    BEFORE="$DEFAULT_BEFORE"
    AFTER="$DEFAULT_AFTER"
    ;;
  2)
    BEFORE="${POSITIONAL[0]}"
    AFTER="${POSITIONAL[1]}"
    ;;
  *)
    usage >&2
    fail "expected either no directories or exactly two (<before_dir> <after_dir>), got ${#POSITIONAL[@]}"
    ;;
esac

if [[ ! -d "$BEFORE" ]]; then
  usage >&2
  fail "before directory does not exist: ${BEFORE}"
fi
if [[ ! -d "$AFTER" ]]; then
  usage >&2
  fail "after directory does not exist: ${AFTER} (produce the default one with: SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs)"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Sorted relative file lists, ignoring MANIFEST.json and .DS_Store at any depth.
list_files() {
  (
    cd "$1"
    find . -type f ! -name MANIFEST.json ! -name .DS_Store -print \
      | sed 's|^\./||' \
      | LC_ALL=C sort
  )
}

list_files "$BEFORE" >"${WORK}/before.list"
list_files "$AFTER" >"${WORK}/after.list"

LC_ALL=C comm -23 "${WORK}/before.list" "${WORK}/after.list" >"${WORK}/removed.list"
LC_ALL=C comm -13 "${WORK}/before.list" "${WORK}/after.list" >"${WORK}/added.list"
LC_ALL=C comm -12 "${WORK}/before.list" "${WORK}/after.list" >"${WORK}/common.list"

: >"${WORK}/changed.list"
: >"${WORK}/diffs.out"
CHANGED=0
while IFS= read -r rel; do
  if ! cmp -s "${BEFORE}/${rel}" "${AFTER}/${rel}"; then
    CHANGED=$((CHANGED + 1))
    printf '%s\n' "$rel" >>"${WORK}/changed.list"
    # diff exits 1 when the files differ; that is the expected case here.
    diff -u -L "before/${rel}" -L "after/${rel}" \
      "${BEFORE}/${rel}" "${AFTER}/${rel}" >>"${WORK}/diffs.out" || true
  fi
done <"${WORK}/common.list"

ADDED=0
while IFS= read -r _; do
  ADDED=$((ADDED + 1))
done <"${WORK}/added.list"

REMOVED=0
while IFS= read -r _; do
  REMOVED=$((REMOVED + 1))
done <"${WORK}/removed.list"

TOTAL=$((CHANGED + ADDED + REMOVED))

if [[ "$TOTAL" -eq 0 ]]; then
  echo "no differences"
  exit 0
fi

if [[ "$CHANGED" -gt 0 ]]; then
  cat "${WORK}/diffs.out"
  echo
  echo "Changed files (${CHANGED}):"
  sed 's/^/  /' "${WORK}/changed.list"
fi

if [[ "$ADDED" -gt 0 ]]; then
  echo "Added files (${ADDED}), present only in after:"
  sed 's/^/  /' "${WORK}/added.list"
fi

if [[ "$REMOVED" -gt 0 ]]; then
  echo "Removed files (${REMOVED}), present only in before:"
  sed 's/^/  /' "${WORK}/removed.list"
fi

echo "Summary: changed: ${CHANGED}, added: ${ADDED}, removed: ${REMOVED}"

if [[ "$FAIL_ON_DIFF" == true ]]; then
  exit 1
fi
exit 0
