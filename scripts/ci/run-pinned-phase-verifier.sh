#!/usr/bin/env bash
# Run a digest-pinned phase verifier against evidence that milestone close-out
# has moved into .planning/milestones/v<X.Y>-phases/.
#
# The verifiers this wraps are sha256-pinned by the phase contract tests: their
# bytes are part of the reviewed record and MUST NOT change. They derive their
# own ROOT from $BASH_SOURCE and read "$ROOT/.planning/phases/<phase>", so the
# only way to point them at archived evidence without editing them is to give
# them a different ROOT. This builds a throwaway tree containing just the script
# and the resolved phase directory, then runs the script from there.
#
# Usage: run-pinned-phase-verifier.sh <verifier-basename> <phase-slug>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/scripts/ci/_phase-dir-resolve.sh"

verifier="${1:?usage: run-pinned-phase-verifier.sh <verifier-basename> <phase-slug>}"
phase="${2:?usage: run-pinned-phase-verifier.sh <verifier-basename> <phase-slug>}"

src="$ROOT/scripts/ci/$verifier"
[ -f "$src" ] || { echo "missing_verifier:$src" >&2; exit 1; }

phase_dir="$(resolve_phase_dir "$ROOT" "$phase")"
if [ ! -d "$phase_dir" ]; then
  # Fail against the path the verifier itself names, not the archive we looked in.
  echo "missing_phase_dir:.planning/phases/$phase" >&2
  exit 1
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/scripts/ci" "$stage/.planning/phases"
cp "$src" "$stage/scripts/ci/$verifier"
cp -R "$phase_dir" "$stage/.planning/phases/$phase"

exec bash "$stage/scripts/ci/$verifier"
