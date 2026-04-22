---
status: draft
phase: "50"
verified: 2026-04-22
---

# Phase 50 verification — Nyquist policy (41-44) + installer golden CI contract

## Must-haves

| Item | Evidence |
|------|----------|
| Installer golden merge gate green | `mix ci.install_golden` (alias in root `mix.exs`; runs `test/sigra/install/golden_diff_test.exs` + `test/sigra/install/idempotency_test.exs`) — **pending** in this draft until executed with Postgres and recorded below |
| Policy table published | `MAINTAINING.md` → **`## Nyquist policy (phases 41-44)`** |
| **41–44** validation files reference phase **50** closure | `41-VALIDATION.md` … `44-VALIDATION.md` updated to cite **`MAINTAINING.md`**, **`mix ci.install_golden`**, and/or **`install_golden_contract`** |

## Merge gate

Postgres at `localhost:5432`, `postgres`/`postgres` per `CLAUDE.md`:

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden
```

Equivalent explicit invocation (same as the alias body):

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs
```

## Automated checks run

| Step | Result |
|------|--------|
| `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden` | **Not recorded** (`status: draft`) — Phase 51 executor: local **`mix ci.install_golden`** did not finish in bounded time (hung >33m at **`Running ExUnit`** with no case output; likely tmp-app **`mix deps.get`** / network as in prior note). **`install_golden_contract`** is not yet visible as a named job on recent **`origin/main`** Actions listings for this repo snapshot — record a green **`install_golden_contract`** run **URL + database id** here (or a local **PASS (Ns)** timing) before flipping to **`status: passed`**. |

## Notes

- Git SHA for this update: `git rev-parse HEAD` → `d785d3a3c4315dd9195505c0937f37c1664e28ca`.
- **Draft reason (Phase 51):** Same local stall class as the prior note. No fabricated **PASS** — maintainer should rerun the merge gate locally with a warm Hex cache **or** paste a successful GitHub Actions **`install_golden_contract`** run link + run id once that job is present on the default branch workflow.

