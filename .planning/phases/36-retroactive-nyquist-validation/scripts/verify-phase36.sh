#!/usr/bin/env bash
# Gate: Phase 36 structural closure (VAL-02a + files for waiver doc).
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"
P36=.planning/phases/36-retroactive-nyquist-validation

test -f "$P36/36-INVENTORY.md"
test -f "$P36/36-WAIVERS.md"
grep -q "v1.2-MILESTONE-AUDIT" "$P36/36-WAIVERS.md"

# Live REQUIREMENTS is removed between milestones; fall back to the v1.3 archive
# where VAL-03 traceability for phase 36 still lives.
REQ=.planning/REQUIREMENTS.md
if [ ! -f "$REQ" ]; then
  REQ=.planning/milestones/v1.3-REQUIREMENTS.md
fi
grep -q "36-INVENTORY" "$REQ" || { echo "VAL-03: requirements doc must reference 36-INVENTORY ($REQ)" >&2; exit 1; }
grep -q "36-WAIVERS" "$REQ" || { echo "VAL-03: requirements doc must reference 36-WAIVERS ($REQ)" >&2; exit 1; }

for vf in \
  ".planning/phases/10.1.1-example-app-repair-ci-install-usage-smoke-harness/10.1.1-VALIDATION.md" \
  ".planning/phases/33-admin-shell-navigation-and-audit-preview-polish/33-VALIDATION.md" \
  ".planning/phases/999.1-nyquist-retroactive-validation-pass/999.1-VALIDATION.md" \
  ".planning/phases/999.2-dependabot-major-version-bumps/999.2-VALIDATION.md" \
  ; do
  test -f "$vf" || { echo "missing $vf" >&2; exit 1; }
  grep -q "nyquist_compliant:" "$vf" || { echo "missing nyquist frontmatter key in $vf" >&2; exit 1; }
done

if [ -d ".planning/phases/34-generated-host-e2e-and-phase-28-retroactive-verification" ]; then
  # Allow removal: dir must not exist OR must be non-empty (then fail loudly)
  cnt=$(find .planning/phases/34-generated-host-e2e-and-phase-28-retroactive-verification -mindepth 1 | wc -l | tr -d ' ')
  if [ "$cnt" = "0" ]; then
    echo "empty duplicate phase dir still present — remove it" >&2
    exit 1
  fi
fi

echo "verify-phase36.sh: OK"
