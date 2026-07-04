#!/usr/bin/env bash
# Phase 216 Plan 07 (HARNESS-01) + Phase 217 Plan 02 (AUTOFIX-01):
# admin-eval harness — thin orchestrator.
#
# Drives the full render → canonicalize → probe → bundle → guard pipeline for
# the Sigra admin eval harness (D-01/D-02). ONE bash entrypoint, ONE Playwright
# project family (admin-eval / admin-eval-mobile / admin-eval-dark). NO mix task,
# NO standalone Node CLI — the Playwright spec is the executable truth.
#
# Phase (a): render matrix + probes + bundles
#   Runs tests/admin-eval.spec.ts across all three eval projects. The spec
#   inlines writeBundleLocal (Rule 3 deviation, bundle.ts CJS shim) and writes
#   evidence bundles to eval/<app_git_sha>/<surface>/<cell>/.
#
# Phase (a2): fix-queue derivation (Phase 217 AUTOFIX-01 addition)
#   fix-queue-build.mjs — SOLE writer of open_findings in admin-render-sha.json
#     (D-12: one builder, two outputs — kills the previously hand-maintained count
#     drift). Reads all findings.json bundles, subtracts settled-findings.tsv,
#     emits fix-queue.json (committed, sorted, deduplicated) AND rewrites
#     open_findings per (surface, cell) in admin-render-sha.json.
#     MUST run BEFORE quality-findings-monotonic.sh reads open_findings (Pitfall 3).
#
# Phase (b): derivative guards (read committed ledgers — fast, deterministic)
#   stale-render-guard.sh     — bundles must be at HEAD and admin source must be
#                               unchanged since capture (D-07/D-08)
#   evidence-anchor-check.mjs — every finding's structural anchor must resolve in
#                               the captured DOM (D-09; cite-and-flip impossible)
#   fix-queue-lint.sh          — recomputes auto_eligible/priority/systemic_group,
#                               fails on drift; validates open_findings range (D-12)
#   quality-findings-monotonic.sh — open findings may not increase vs merge-base
#   award-guard.mjs            — verify-then-climb: axis can only rise with fresh
#                               verified_at_sha + resolving evidence (D-20)
#   settled-findings-lint.sh   — settled-findings.tsv sorted + no duplicates (D-22)
#
# Boot expectation: consume an already-booted SIGRA_EXAMPLE_URL (default
# http://localhost:4011) — same pattern as snapshot-recapture-gate.sh. The
# orchestrator does not embed a bespoke boot brain.
#
# Usage:
#   SIGRA_EXAMPLE_URL=http://localhost:4011 bash scripts/ci/admin-eval-harness.sh
#
# Local iteration recipe (see guides/reference/admin-eval-runbook.md):
#   scripts/db/up.sh   # boot ephemeral test PG
#   (cd test/example && MIX_ENV=dev PORT=4011 mix phx.server &)
#   # wait for app to respond, then:
#   bash scripts/ci/admin-eval-harness.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PW="${ROOT}/test/example/priv/playwright"
SIGRA_EXAMPLE_URL="${SIGRA_EXAMPLE_URL:-http://localhost:4011}"

# ── Phase (a): render matrix + probes + bundles ────────────────────────────────
# Run the admin-eval spec across all three projects:
#   admin-eval        — Desktop Chrome DPR1, HARD-GATE geometry (D-15)
#   admin-eval-mobile — iPhone 13, warn-only geometry
#   admin-eval-dark   — colorScheme:'dark', warn-only geometry
# The spec writes bundles to eval/<app_git_sha>/<surface>/<cell>/ (gitignored).

echo "admin-eval-harness: (a) render matrix + probes + bundles (3 projects)"
(
  cd "$PW" && \
  CI=true SIGRA_EXAMPLE_URL="$SIGRA_EXAMPLE_URL" \
    npx playwright test tests/admin-eval.spec.ts \
      --project=admin-eval \
      --project=admin-eval-mobile \
      --project=admin-eval-dark
)

# ── Phase (a2): fix-queue derivation ──────────────────────────────────────────
# fix-queue-build.mjs is the SOLE writer of open_findings in admin-render-sha.json
# (D-12). It must run AFTER bundles are written (Phase a) and BEFORE
# quality-findings-monotonic.sh reads open_findings (Phase b3 — Pitfall 3 ordering).
# It also writes fix-queue.json (committed, sorted, deduplicated open set).

echo "admin-eval-harness: (a2) fix-queue derivation + open_findings update (D-12)"
node "${ROOT}/scripts/ci/fix-queue-build.mjs"

# ── Phase (b): derivative guards ──────────────────────────────────────────────
# These guards read committed ledgers (admin-render-sha.json, admin-award-ledger.json,
# settled-findings.tsv) plus the freshly-captured bundles under eval/. They are also
# wired into fast_checks independently (reading committed state) for the CI merge gate —
# the orchestrator is the local/full-run driver, not the merge gate itself.

echo "admin-eval-harness: (b1) stale-render guard"
bash "${ROOT}/scripts/ci/stale-render-guard.sh"

echo "admin-eval-harness: (b2) evidence anchor integrity check"
node "${ROOT}/scripts/ci/evidence-anchor-check.mjs"

echo "admin-eval-harness: (b3) fix-queue derived-field lint (auto_eligible, priority, open_findings)"
bash "${ROOT}/scripts/ci/fix-queue-lint.sh"

echo "admin-eval-harness: (b4) quality findings monotonic guard"
bash "${ROOT}/scripts/ci/quality-findings-monotonic.sh" --base HEAD

echo "admin-eval-harness: (b5) award ledger verify-then-climb guard"
node "${ROOT}/scripts/ci/award-guard.mjs" --base HEAD

echo "admin-eval-harness: (b6) settled findings lint"
bash "${ROOT}/scripts/ci/settled-findings-lint.sh"

echo "admin-eval-harness: PASS — all phases green"
