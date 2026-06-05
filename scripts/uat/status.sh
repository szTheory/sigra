#!/usr/bin/env bash
# Reprint the URLs/env for the last Sigra UAT stack started by scripts/uat/up.sh.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec "${REPO_ROOT}/scripts/uat/up.sh" --status "$@"
