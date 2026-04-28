---
phase: 88
gauat_requirement: GAUAT-08
git_sha: 367a164
generated_by: phase-88 manual witness scaffold
generated_at: 2026-04-28T12:40:27Z
disposition: pending-human-witness
---

# GAUAT-08: Clean-Machine Getting-Started Evidence

This bundle records the bounded fresh-host walkthrough for `guides/introduction/getting-started.md`. It is intentionally small: transcript, exact environment capture, and a friction log.

## Witness scope

- Requirement: `GAUAT-08`
- Release-candidate SHA: `367a164`
- Mechanical floor: `bash scripts/ci/getting-started-contract.sh`
- Current status: human witness run not yet captured

## Artifact inventory

| Artifact class | Status | Path | Purpose |
|----------------|--------|------|---------|
| transcript | pending | `transcript.log` | Timestamped walkthrough log including `START`, `FIRST_SERVER_BOOT`, `FIRST_SUCCESSFUL_REGISTER_LOGIN_RESET`, and `END`. |
| environment | pending | `env.txt` | Exact host OS and prerequisite versions used during the witness run. |
| friction-log | pending | `friction-log.md` | Explicit record of stalls, hints, workarounds, and any source spelunking. |

## Outcome

Pending the blocking human witness run. Do not cite this bundle as completed GAUAT-08 evidence until the transcript, environment capture, and friction log are populated from a fresh temporary Phoenix 1.8 host.

## Timing rules

- Record the four milestone timestamps directly in `transcript.log`.
- Treat the under-30-minute claim as an auditable attestation, not an automatic pass condition.
- If off-script help was required, record it in `friction-log.md` rather than smoothing the story.
