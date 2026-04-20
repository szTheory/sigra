#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
=== Sigra planning hygiene (maintainers) ===
Automated JSON audit helpers from external planning toolchains are not a supported path.
See MAINTAINING.md and use the "Planning hygiene" section (repo-native rg/find checks).

Example commands (repo root):
EOF

printf '%s\n' \
  '  find .planning/phases -mindepth 1 -maxdepth 1 -type d | while read -r dir; do' \
  '    compgen -G "$dir"/*-VERIFICATION.md >/dev/null || echo "missing VERIFICATION: $dir"' \
  '  done' \
  '' \
  '  rg -l '"'"'^nyquist_compliant: false'"'"' .planning/phases --glob '"'"'*-PLAN.md'"'"' || true'

echo
echo "--- results (phases missing VERIFICATION) ---"
find .planning/phases -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
  compgen -G "$dir"/*-VERIFICATION.md >/dev/null || echo "missing VERIFICATION: $dir"
done || true

echo "--- results (nyquist_compliant: false PLAN files) ---"
if command -v rg >/dev/null 2>&1; then
  rg -l '^nyquist_compliant: false' .planning/phases --glob '*-PLAN.md' || true
else
  echo "(rg not installed; install ripgrep or run the rg line above manually)" >&2
fi
