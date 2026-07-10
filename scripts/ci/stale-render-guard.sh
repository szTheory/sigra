#!/usr/bin/env bash
# Phase 216 Plan 06 (HARNESS-02): stale-render trust guard.
#
# Hard-fails CI when the captured evidence bundles cannot be trusted:
#   1. ABSENCE: no bundles found under eval/ — hard FAIL (D-08: opposite of tier guard's skip)
#   2. SHA MISMATCH: any bundle's app_git_sha != git HEAD — hard FAIL (D-07)
#   3. UNREACHABLE: bundle_sha not reachable in git — LOUD error, FAIL (D-07)
#   4. SOURCE NEWER: admin source was changed after the bundle was captured —
#      git diff --name-only <bundle_sha> HEAD -- <admin globs> non-empty → FAIL (D-07)
#
# Admin source globs anchored to the same paths the installer-detect step uses
# (ci.yml:88) plus the committed CSS and LiveView admin sources:
#   lib/sigra/admin/**
#   lib/sigra/admin.ex
#   lib/sigra/live_view/admin_scope.ex
#   priv/templates/sigra.install/admin/**
#   priv/static/assets/sigra_admin.css
#   test/example/priv/static/assets/sigra_admin.css
#
# Git plumbing only — never mtime (actions/checkout#468 stamps every file with
# the run-time mtime, making mtime false-pass 100% in CI).
#
# Usage:
#   bash scripts/ci/stale-render-guard.sh
#   (no --base arg needed: guard reads app_git_sha from bundle.json, not a base ref)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVAL_DIR="${ROOT}/test/example/priv/playwright/eval"

fail() {
  echo "stale-render-guard: FAIL: $*" >&2
  exit 1
}

# ── Admin source globs (same paths as installer-detect, plus CSS and LiveViews) ──
# These are paths that, if changed after a bundle was captured, mean the render
# is potentially stale and must not be trusted.
ADMIN_GLOBS=(
  "lib/sigra/admin"
  "lib/sigra/admin.ex"
  "lib/sigra/live_view/admin_scope.ex"
  "priv/templates/sigra.install/admin"
  "priv/static/assets/sigra_admin.css"
  "test/example/priv/static/assets/sigra_admin.css"
)

# ── Resolve current HEAD ───────────────────────────────────────────────────────
HEAD_SHA=$(git -C "$ROOT" rev-parse HEAD)

# ── Locate all bundle.json files ──────────────────────────────────────────────
# Look for bundles under eval/<any-sha>/<surface>/<cell>/bundle.json
mapfile -t BUNDLE_FILES < <(find "$EVAL_DIR" -name "bundle.json" 2>/dev/null | sort)

if [[ ${#BUNDLE_FILES[@]} -eq 0 ]]; then
  # Absence of bundles is a hard FAIL (D-08). This differs from the tier guard
  # which skips on empty base (decrease impossible without baseline). For the
  # render guard, absent bundles means no render was done at this HEAD — untrusted.
  fail "no bundle.json files found under ${EVAL_DIR}. Run the admin-eval Playwright spec first."
fi

echo "stale-render-guard: checking ${#BUNDLE_FILES[@]} bundle(s) against HEAD ${HEAD_SHA}"

violations=0

for BUNDLE_FILE in "${BUNDLE_FILES[@]}"; do
  # ── Read app_git_sha from bundle.json ─────────────────────────────────────
  BUNDLE_APP_SHA=$(grep '"app_git_sha"' "$BUNDLE_FILE" 2>/dev/null | sed 's/.*"app_git_sha": *"//;s/".*//' | tr -d '[:space:]')

  if [[ -z "$BUNDLE_APP_SHA" ]]; then
    echo "stale-render-guard: FAIL: could not read app_git_sha from ${BUNDLE_FILE}" >&2
    violations=1
    continue
  fi

  BUNDLE_REL="${BUNDLE_FILE#${ROOT}/}"

  # ── Check 1: app_git_sha must match current HEAD ──────────────────────────
  if [[ "$BUNDLE_APP_SHA" != "$HEAD_SHA" ]]; then
    echo "stale-render-guard: FAIL: bundle ${BUNDLE_REL} was captured at ${BUNDLE_APP_SHA} but HEAD is ${HEAD_SHA}" >&2
    violations=1
    continue  # no point running further checks on this bundle
  fi

  # ── Check 2: git cat-file -e — error LOUDLY if sha is unreachable ─────────
  # (git cat-file -e exits non-zero if the object does not exist in the repo)
  if ! git -C "$ROOT" cat-file -e "${BUNDLE_APP_SHA}^{commit}" 2>/dev/null; then
    echo "stale-render-guard: FAIL: bundle sha ${BUNDLE_APP_SHA} is unreachable in git (from ${BUNDLE_REL})" >&2
    echo "stale-render-guard: this may indicate a shallow clone or a corrupted bundle" >&2
    violations=1
    continue
  fi

  # ── Check 3: admin source newer than bundle ───────────────────────────────
  # Run git diff --name-only <bundle_sha> HEAD -- <admin globs>
  # If any admin source file changed between the bundle's sha and HEAD, the render is stale.
  DIFF_OUTPUT=$(git -C "$ROOT" diff --name-only "${BUNDLE_APP_SHA}" HEAD -- "${ADMIN_GLOBS[@]}" 2>/dev/null || true)

  if [[ -n "$DIFF_OUTPUT" ]]; then
    echo "stale-render-guard: FAIL: admin source changed since bundle ${BUNDLE_REL} was captured at ${BUNDLE_APP_SHA}:" >&2
    echo "$DIFF_OUTPUT" | sed 's/^/  /' >&2
    echo "stale-render-guard: re-run the admin-eval spec to capture fresh bundles." >&2
    violations=1
  fi
done

if [[ "$violations" -ne 0 ]]; then
  exit 1
fi

echo "stale-render-guard: PASS (${#BUNDLE_FILES[@]} bundle(s) verified at HEAD ${HEAD_SHA})"
