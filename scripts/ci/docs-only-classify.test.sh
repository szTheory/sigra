#!/usr/bin/env bash
# Self-test for docs-only-classify.sh (Phase 230 FAST-05 / D-07).
#
# This is FAST-05's in-phase falsifiable evidence: `ci.yml` triggers on
# `pull_request: branches: [main]`, so any pre-merge pull request's
# base-to-HEAD diff necessarily carries this phase's own non-Markdown
# changes and can never classify docs_only=true end-to-end (an observed
# `true` run is a post-merge obligation -- AFTER-DOCSONLY). This self-test
# proves the classification rule in both directions, plus the empty-input
# and crafted-path cases, entirely hermetically -- no network, no `git`, no
# `gh` -- so the rule cannot rot silently between phases.
#
# Test cases:
#   A: Markdown + .planning/** list                        -> docs_only=true
#   B: same list + a non-docs path (mixed diff)             -> docs_only=false
#   C: a single .planning/**/*.md path                      -> docs_only=true
#   D: a single .planning/** non-Markdown path               -> docs_only=true
#   E: empty stdin                                           -> docs_only=true
#   F: docs.md/evil.ex (contains .md, does not end in it)    -> docs_only=false
#   G: .planning-evil/x.ex (resembles the prefix, no match)  -> docs_only=false
#   H: a git-quoted path with an embedded escape             -> docs_only=false
#   I: case B's list in reversed order                       -> same as B
#   J: an unknown flag                                       -> exit 2, stderr message
#   K: every successful invocation above emits exactly one line
#      matching docs_only=(true|false)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/docs-only-classify.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

run_classify() {
  # $1 = stdin content (may be empty); no network, no git repository needed.
  printf '%s' "$1" | bash "$SCRIPT"
}

# ---- Test A: Markdown + .planning/** list -> docs_only=true -----------
echo "Test A: Markdown + .planning/** list -> docs_only=true"
OUT_A="$(run_classify $'README.md\n.planning/ROADMAP.md\nguides/recipes/local-development.md\n')"
if [[ "$OUT_A" == "docs_only=true" ]]; then
  pass "Test A: ${OUT_A}"
else
  fail "Test A: got '${OUT_A}', want docs_only=true"
fi

# ---- Test B: same list + a non-docs path -> docs_only=false -----------
echo "Test B: mixed diff (one non-docs path added) -> docs_only=false"
LIST_B=$'README.md\n.planning/ROADMAP.md\nguides/recipes/local-development.md\n.github/workflows/ci.yml\n'
OUT_B="$(run_classify "$LIST_B")"
if [[ "$OUT_B" == "docs_only=false" ]]; then
  pass "Test B: ${OUT_B}"
else
  fail "Test B: got '${OUT_B}', want docs_only=false"
fi

# ---- Test C: a single .planning/**/*.md path -> docs_only=true --------
echo "Test C: a single .planning/**/*.md path -> docs_only=true"
OUT_C="$(run_classify $'.planning/phases/230-x/230-01-PLAN.md\n')"
if [[ "$OUT_C" == "docs_only=true" ]]; then
  pass "Test C: ${OUT_C}"
else
  fail "Test C: got '${OUT_C}', want docs_only=true"
fi

# ---- Test D: a single .planning/** non-Markdown path -> docs_only=true
echo "Test D: a single .planning/** non-Markdown path -> docs_only=true"
OUT_D="$(run_classify $'.planning/graphs/graph.json\n')"
if [[ "$OUT_D" == "docs_only=true" ]]; then
  pass "Test D: ${OUT_D}"
else
  fail "Test D: got '${OUT_D}', want docs_only=true"
fi

# ---- Test E: empty stdin -> docs_only=true -----------------------------
echo "Test E: empty stdin -> docs_only=true"
OUT_E="$(run_classify '')"
if [[ "$OUT_E" == "docs_only=true" ]]; then
  pass "Test E: ${OUT_E}"
else
  fail "Test E: got '${OUT_E}', want docs_only=true"
fi

# ---- Test F: docs.md/evil.ex -> docs_only=false ------------------------
echo "Test F: docs.md/evil.ex (contains .md, does not end in it) -> docs_only=false"
OUT_F="$(run_classify $'docs.md/evil.ex\n')"
if [[ "$OUT_F" == "docs_only=false" ]]; then
  pass "Test F: ${OUT_F}"
else
  fail "Test F: got '${OUT_F}', want docs_only=false"
fi

# ---- Test G: .planning-evil/x.ex -> docs_only=false --------------------
echo "Test G: .planning-evil/x.ex (resembles the prefix without matching) -> docs_only=false"
OUT_G="$(run_classify $'.planning-evil/x.ex\n')"
if [[ "$OUT_G" == "docs_only=false" ]]; then
  pass "Test G: ${OUT_G}"
else
  fail "Test G: got '${OUT_G}', want docs_only=false"
fi

# ---- Test H: a git-quoted path with an embedded escape -----------------
echo 'Test H: a git-quoted path with an embedded escape (quoted-newline .md) -> docs_only=false'
OUT_H="$(run_classify $'"a\\nb.md"\n')"
if [[ "$OUT_H" == "docs_only=false" ]]; then
  pass "Test H: ${OUT_H}"
else
  fail "Test H: got '${OUT_H}', want docs_only=false (a crafted filename must never force the true branch)"
fi

# ---- Test I: case B's list in reversed order -> same as B --------------
echo "Test I: reversed order produces the same output line as Test B"
LIST_I=$'.github/workflows/ci.yml\nguides/recipes/local-development.md\n.planning/ROADMAP.md\nREADME.md\n'
OUT_I="$(run_classify "$LIST_I")"
if [[ "$OUT_I" == "$OUT_B" ]]; then
  pass "Test I: reversed order is stable (${OUT_I})"
else
  fail "Test I: got '${OUT_I}', want '${OUT_B}' (order must not affect the result)"
fi

# ---- Test J: unknown flag -> exit 2, stderr message ---------------------
echo "Test J: unknown flag -> exit 2 with docs-only-classify: FAIL: unknown arg: --bogus-flag"
set +e
ERR_J="$(bash "$SCRIPT" --bogus-flag 2>&1 1>/dev/null)"
EXIT_J=$?
set -e
if [[ "$EXIT_J" -eq 2 && "$ERR_J" == "docs-only-classify: FAIL: unknown arg: --bogus-flag" ]]; then
  pass "Test J: exit ${EXIT_J}, stderr '${ERR_J}'"
else
  fail "Test J: exit=${EXIT_J} stderr='${ERR_J}'"
fi

# ---- Test K: every successful invocation emits exactly one line --------
echo "Test K: every successful case emits exactly one docs_only=(true|false) line"
K_OK=1
for out in "$OUT_A" "$OUT_B" "$OUT_C" "$OUT_D" "$OUT_E" "$OUT_F" "$OUT_G" "$OUT_H" "$OUT_I"; do
  LINE_COUNT=$(printf '%s' "$out" | grep -c '^' || true)
  if [[ "$LINE_COUNT" -ne 1 ]] || ! [[ "$out" =~ ^docs_only=(true|false)$ ]]; then
    K_OK=0
  fi
done
if [[ "$K_OK" -eq 1 ]]; then
  pass "Test K: every case emitted exactly one docs_only=(true|false) line"
else
  fail "Test K: at least one case did not emit exactly one docs_only=(true|false) line"
fi

# ---- Summary -----------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "docs-only-classify.test: FAIL"
  exit 1
fi

echo "docs-only-classify.test: PASS"
exit 0
