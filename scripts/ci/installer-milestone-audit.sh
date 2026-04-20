#!/usr/bin/env bash
# INT-01..INT-03 greps from .planning/milestones/v1.2-MILESTONE-AUDIT.md (Phase 35 / ROADMAP SC5).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

fail() {
  echo "installer-milestone-audit: FAIL: $*" >&2
  exit 1
}

echo "==> installer-milestone-audit: INT-01 router mounts"
grep -q "UsersIndexLive" priv/templates/sigra.install/admin/router_injection.ex ||
  fail "INT-01: missing UsersIndexLive in router_injection.ex"
grep -q "UserShowLive" priv/templates/sigra.install/admin/router_injection.ex ||
  fail "INT-01: missing UserShowLive in router_injection.ex"

echo "==> installer-milestone-audit: INT-02 impersonation controller template"
test -f priv/templates/sigra.install/admin/impersonation_controller.ex ||
  fail "INT-02: missing impersonation_controller.ex"
grep -q "defmodule" priv/templates/sigra.install/admin/impersonation_controller.ex ||
  fail "INT-02: impersonation_controller.ex missing defmodule"

echo "==> installer-milestone-audit: INT-03 admin files/1 lists controllers"
grep -q "impersonation_controller.ex" lib/sigra/install/features/admin.ex ||
  fail "INT-03: impersonation_controller.ex not referenced in admin.ex"
grep -q "audit_export_controller.ex" lib/sigra/install/features/admin.ex ||
  fail "INT-03: audit_export_controller.ex not referenced in admin.ex"

echo "OK: installer-milestone-audit"
