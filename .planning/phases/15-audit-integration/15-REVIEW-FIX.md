---
phase: 15-audit-integration
fixed_at: 2026-04-12T00:00:00Z
review_path: .planning/phases/15-audit-integration/15-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 15: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** .planning/phases/15-audit-integration/15-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (warnings; 0 critical, 6 info out of scope)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: `suspicious_login.ex` drops resolved user_id instead of building a scope

**Files modified:** `lib/sigra/suspicious_login.ex`
**Commit:** 7337e63
**Applied fix:** Replaced the hard-coded `nil` scope argument in the `Sigra.Audit.log_safe("security.suspicious_login", ...)` call with `Sigra.Scope.from_config(config, %{id: user_id})`. This ensures `effective_user_id` (and any organization_id resolvable from config) lands on the audit row for this high-signal security event, restoring v1.2 impersonation anchor semantics. `actor_id: user_id` in opts still wins over the scope default as before. Verified `Sigra.Scope.from_config/2` exists (lib/sigra/scope.ex:64) before applying.

### WR-03: `Sigra.Lockout.reset!/2` contains dead `_ = user` / `result` statements

**Files modified:** `lib/sigra/lockout.ex`
**Commit:** a522941
**Applied fix:** Removed the dead `result = ...`, `_ = user`, and return-`result` pattern along with the dangling comment block describing audit behavior that does not exist in the function. `reset!/2` is now a straightforward three-line pipe that builds the changeset and calls `repo.update!/1`. No behavior change; the function already returned the updated user struct.

### WR-02: Credo check `NoLogSafe2InLib` false-positives on unrelated aliased `Audit` modules

**Files modified:** `lib/sigra/credo/no_log_safe2_in_lib.ex`
**Commit:** 0c24a82
**Applied fix:** Added a "Known limitation" section to the module's `@moduledoc` documenting that the walker matches the bare `[:Audit]` alias form without cross-referencing the file's alias declarations, and pointing operators at the `# credo:disable-for-next-line Sigra.Credo.NoLogSafe2InLib` escape hatch. This is the lower-risk remediation path suggested by the review (the alternative — resolving aliases against the AST header — would require threading file-level alias state into the prewalk and was not applied to avoid introducing behavior changes to a check module under iteration 1).

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
