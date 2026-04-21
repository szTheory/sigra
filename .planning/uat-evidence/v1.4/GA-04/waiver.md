# GA-04 — Async variant (**D-42-03**)

Synchronous witnessed runs are default. **Async** evidence is allowed only when **all** apply:

1. **Terminal transcript** (or `asciinema`-class log) covering the full attempt.
2. **First failure wins** — stop at first mismatch; no undocumented fixes mid-run.
3. Same **friction table** as synchronous protocol (`step | expected | actual | class | owner`).

If any condition is missing, do not treat the run as GA-04 admissible proof.

---

## Formal matrix waiver (Phase 46)

**reason:** A synchronous clean-machine witness with a reviewer meeting the **60**-day non-merge bar was not executed in the Phase 46 automation window.

**compensating controls:** CI **`getting_started_uat_contract`** job and **`scripts/ci/getting-started-contract.sh`** per `docs/uat-ci-coverage.md`; sole doc path `guides/introduction/getting-started.md` verified present at repo root.

**residual risk:** Host OS / toolchain permutations and wall-clock friction not captured without a live witness.

**expiry_or_next_trigger:** Run a full witness before a promoted release tag or renew this waiver with maintainer sign-off.

**owner:** Sigra

**date:** 2026-04-21
