#!/usr/bin/env bash
# Phase 235 RED gate: the protected collector must exist before its hermetic
# fake-gh fixture suite can exercise the production executable.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$ROOT/scripts/ci/capture-terminal-ratification-evidence.sh"
WORKFLOW="$ROOT/.github/workflows/terminal-ratification-evidence.yml"

test -x "$COLLECTOR"
test -s "$WORKFLOW"
