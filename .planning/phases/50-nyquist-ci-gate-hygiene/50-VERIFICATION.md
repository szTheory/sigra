---
status: complete
phase: "50"
verified: 2026-04-22
---

# Phase 50 verification — Nyquist policy (41-44) + installer golden CI contract

## Must-haves

| Item | Evidence |
|------|----------|
| Installer golden merge gate | **Canonical attestation:** the GitHub Actions job **`Install golden + idempotency contract (subprocess harness)`** (workflow job id **`install_golden_contract`** in [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml)) on the repository **default branch** (`main`). On every **`push`** to `main`, CI runs the same **`mix test …golden_diff… idempotency…`** bundle as local **`mix ci.install_golden`**. Treat a **required status check** for that job on `main` as the non-negotiable green signal — not a manually pasted table row. |
| Policy table published | `MAINTAINING.md` → **`## Nyquist policy (phases 41-44)`** |
| **41–44** validation files reference phase **50** closure | `41-VALIDATION.md` … `44-VALIDATION.md` updated to cite **`MAINTAINING.md`**, **`mix ci.install_golden`**, and/or **`install_golden_contract`** |

## Local merge gate (optional repro)

Postgres at `localhost:5432`, `postgres`/`postgres` per `CLAUDE.md`:

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden
```

Equivalent explicit invocation (same as the alias body):

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs
```

Local runs are **optional** for attestation; CI on `main` is authoritative when branch protection requires the job.

## CI attestation (canonical)

- **Job display name (match in GitHub UI / branch rules):** `Install golden + idempotency contract (subprocess harness)`
- **Workflow job id (YAML):** `install_golden_contract`
- **Default branch:** `main` — configure this job as a **required status check** (see **`MAINTAINING.md`** → branch protection runbook).
- **Truth model:** No maintainer pastes **PASS** or wall-clock seconds into this file for merge-gate proof; green on **`main`** for the job above is the receipt.

## Notes

- For debugging local failures, record `git rev-parse HEAD` in your own notes or CI logs — this file does not track per-run SHAs.
- PRs: the same job runs when the PR diff matches the path rules documented in **`MAINTAINING.md`** (installer + GA-adjacent `lib/sigra` paths).
