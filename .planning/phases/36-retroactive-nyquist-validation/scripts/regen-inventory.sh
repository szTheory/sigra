#!/usr/bin/env bash
# Regenerate TSV lines: phase_dir | validation_file | classification | notes
# Pipe into a spreadsheet or merge into 36-INVENTORY.md manually.
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"
for d in .planning/phases/*/; do
  name=$(basename "$d")
  shopt -s nullglob
  vfs=("$d"*-VALIDATION.md)
  if [ ${#vfs[@]} -eq 0 ]; then
    echo -e "${name}\t-\tMISSING\t"
    continue
  fi
  vf=$(basename "${vfs[0]}")
  if rg -q "nyquist_compliant:\s*true" "$d$vf" 2>/dev/null && rg -q "status:\s*approved" "$d$vf" 2>/dev/null; then
    cls=COMPLIANT_APPROVED
  elif rg -q "nyquist_compliant:\s*true" "$d$vf" 2>/dev/null; then
    cls=COMPLIANT_DRAFT_STATUS
  elif rg -q "^---" "$d$vf" 2>/dev/null && rg -q "Validation Architecture" "$d$vf" 2>/dev/null; then
    cls=LEGACY_FORMAT
  elif rg -qi "draft|TODO|TBD|FIXME|WIP|nyquist_compliant:\s*false" "$d$vf" 2>/dev/null; then
    cls=DRAFT_OR_FALSE
  else
    cls=REVIEW
  fi
  echo -e "${name}\t${vf}\t${cls}\t"
done | sort
