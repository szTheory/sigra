---
phase: 237-canonical-b2c-generator-contract
reviewed: 2026-08-05T02:50:25Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - scripts/ci/passkeys-opt-out-smoke.sh
  - test/sigra/install/generator_passkeys_opt_out_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 237: Code Review Report

**Reviewed:** 2026-08-05T02:50:25Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

The B2C generator assertions and fixture source locks are coherent, and the focused source-lock test passes. However, the authoritative smoke does not preserve its required isolated, bounded server lifecycle when a boot check fails: it uses a predictable shared `/tmp` log and bypasses its only server cleanup trap on failure. This leaves the B2C-01/T-237-04 lifecycle proof unreliable and can expose a local file-clobber primitive.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Predictable shared server log permits local file clobbering

**Classification:** BLOCKER

**File:** `scripts/ci/passkeys-opt-out-smoke.sh:268`

**Issue:** The smoke redirects server output to fixed, predictable names such as `/tmp/sigra_b2c_alpha-server.log`. A local unprivileged process can pre-create one as a symlink, and shell redirection follows it, so executing the documented local smoke can truncate an arbitrary file writable by the caller. Parallel smoke invocations also write to the same log, causing nondeterministic diagnostics. This violates the phase requirement that the harness use isolated temporary paths.

**Fix:** Keep the log inside the invocation-owned `mktemp` tree (for example, `local server_log="${app_dir}/server.log"`) and use `"${server_log}"` for both redirection and the failure diagnostic. That removes the predictable shared `/tmp` target and ensures each leg has its own log.

## Warnings

### WR-01: Boot-timeout path leaks the background Phoenix server

**Classification:** WARNING

**File:** `scripts/ci/passkeys-opt-out-smoke.sh:270-284`

**Issue:** The only cleanup for `server_pid` is a `RETURN` trap. The timeout branch calls `exit 1`, which terminates the shell rather than returning from `run_leg`, so the `RETURN` trap is not run. A failing boot can therefore leave `mix phx.server` alive, retaining its port and database connections and contaminating later local/CI smoke work. This fails the plan's explicit server-process-cleanup and bounded-lifecycle requirement.

**Fix:** Track the PID in an EXIT-safe cleanup handler, in addition to normal successful-path shutdown. For example, set a script-scope `SERVER_PID`, have the existing EXIT cleanup kill/wait for it before removing `TMP_ROOT`, set it immediately after backgrounding the server, and clear it after the successful `kill`/`wait`. Preserve the generated-host log before cleanup when reporting a timeout.

---

_Reviewed: 2026-08-05T02:50:25Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
