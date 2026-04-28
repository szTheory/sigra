---
phase: 88
gauat_requirement: GAUAT-07
git_sha: 367a164
generated_by: phase-88 manual witness scaffold
generated_at: 2026-04-28T12:39:44Z
disposition: pending-human-witness
---

# GAUAT-07: MFA Backup-Code Rotation Evidence

This bundle is text-first by design. Transcript and persisted-state proof carry the security claim; screenshots only show that the human flow happened.

## Witness scope

- Requirement: `GAUAT-07`
- Release-candidate SHA: `367a164`
- Locked decisions: `D-88-01` through `D-88-05`
- Current status: human witness run not yet captured

## Artifact inventory

| Artifact class | Status | Path | Purpose |
|----------------|--------|------|---------|
| transcript | pending | `transcript.log` | Timestamped operator log for the regenerate flow, including the chosen pre-rotation plaintext backup code. |
| invalidation-proof | pending | `reports/old-code-reuse.txt` | Explicit proof that the chosen pre-rotation backup code fails after regeneration. |
| audit-proof | pending | `reports/audit-row.json` | Persisted `mfa.backup_codes_regenerate` audit evidence. |
| screenshots | pending | `screenshots/` | Minimal UI evidence only: sudo prompt, regenerate modal, shown-once state, audit UI row if used. |

## Outcome

Pending the blocking human witness run. Do not cite this bundle as a completed GAUAT-07 proof pack until `transcript.log`, `reports/old-code-reuse.txt`, `reports/audit-row.json`, and the four required screenshots are populated.

## Redaction rules

- Do not expose raw backup codes except for one tightly scoped shown-once capture.
- Do not treat screenshots as invalidation proof.
- Keep the audit artifact explicit enough for reviewers to match `mfa.backup_codes_regenerate` against `lib/sigra/mfa.ex`.
