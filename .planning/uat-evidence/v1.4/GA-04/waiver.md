# GA-04 — Async variant (**D-42-03**)

Synchronous witnessed runs are default. **Async** evidence is allowed only when **all** apply:

1. **Terminal transcript** (or `asciinema`-class log) covering the full attempt.
2. **First failure wins** — stop at first mismatch; no undocumented fixes mid-run.
3. Same **friction table** as synchronous protocol (`step | expected | actual | class | owner`).

If any condition is missing, do not treat the run as GA-04 admissible proof.
