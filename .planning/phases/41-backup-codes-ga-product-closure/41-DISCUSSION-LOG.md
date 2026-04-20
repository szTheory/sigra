# Phase 41: Backup codes & GA product closure — Discussion log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `41-CONTEXT.md`.

**Date:** 2026-04-20  
**Phase:** 41 — Backup codes & GA product closure  
**Mode:** User requested **all** gray areas in one shot + parallel subagent research + principal synthesis into `41-CONTEXT.md` (no interactive menu).

**Areas covered:** Re-auth gate · Public API contract · Audit atomicity · Verification pyramid

---

## Re-authentication gate for rotation

| Option | Description | Selected |
|--------|-------------|----------|
| A | TOTP-only step-up | |
| B | Sudo + OR of passkey / TOTP; backup codes **not** for rotation | ✓ |
| C | Backup code consumes to authorize rotation (“mirror disable”) | ✗ (documented footgun; rejected for default) |
| D | Split: recovery vs policy-admin flows | ✓ (conceptual framing merged into B) |

**User's choice:** Delegated to research synthesis — **B + D framing** locked in CONTEXT **D-41-01**.

**Notes:** Install golden already places `MFASettingsLive` under `require_sudo`; example app did not — alignment flagged as implementation task.

---

## Public API contract

| Option | Description | Selected |
|--------|-------------|----------|
| A | Tagged `verification` param + `{:ok, %{backup_codes: codes}}` | ✓ |
| B | Bare string arity-2 only | ✗ |

**User's choice:** Synthesis — **D-41-02** (`Sigra.MFA.regenerate_backup_codes/4` + thin `Auth` delegate).

**Notes:** Transaction wrapper around `BackupCodes.regenerate/4` mandatory.

---

## Audit atomicity (Phase 41 vs AUD-06)

| Option | Description | Selected |
|--------|-------------|----------|
| A | Post-success `log_safe` only | ✗ (when audit on) |
| B | `Ecto.Multi` + `log_multi_safe` when audit configured | ✓ |

**User's choice:** Synthesis — **D-41-03**.

---

## Verification stack

| Option | Description | Selected |
|--------|-------------|----------|
| A | Example `DataCase` integration — old code fails after rotate | ✓ (GA-01 owner) |
| B | Playwright-only | ✗ |
| C | Template contract / golden only | Supplementary |

**User's choice:** Synthesis — **D-41-04**.

---

## Claude's discretion

- Test file naming and small audit metadata details (see CONTEXT).

## Deferred ideas

- Host-only opt-in for backup-code-gated rotation (explicit risk).
- AUD-06 bulk MFA audit migration (excluding regenerate once Phase 41 completes atomic path).
