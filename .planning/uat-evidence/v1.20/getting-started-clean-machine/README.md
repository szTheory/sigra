---
phase: 88
gauat_requirement: GAUAT-08
git_sha: f67b9fd
generated_by: phase-88 task-1 scaffold
generated_at: 2026-04-28T13:34:00Z
disposition: pending-human-witness
---

# GAUAT-08: Clean-Machine Getting-Started Evidence

This bundle records the bounded fresh-host walkthrough for `guides/introduction/getting-started.md`. Task 1 established the mechanical floor; Task 2 must add the human witness transcript, exact environment capture, and friction accounting before this evidence is complete.

## Witness scope

- Requirement: `GAUAT-08`
- Release-candidate SHA: `f67b9fd`
- Mechanical floor: `bash scripts/ci/getting-started-contract.sh`
- Mechanical floor status: `PASS` on `2026-04-28`
- Current status: waiting for blocking fresh-host human witness run

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
