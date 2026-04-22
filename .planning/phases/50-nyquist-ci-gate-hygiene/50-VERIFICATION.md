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
| `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden` | **Not recorded yet** (`status: draft`) — flip to **PASS** (exit 0) + timing when run on a clean tree before marking `status: passed`. |

## Notes

- Git SHA when this draft was written (documentation slice landed; merge gate still open): `git rev-parse HEAD` → `7b30ae4dc9bd00ab4054bb0b8a4fadc7904d0eb5`.
- **Draft reason:** Local merge-gate attempts in this workspace stalled for extended periods inside the tmp-app **`mix deps.get`** step (no Hex timeout hit; likely environment/network). CI job **`install_golden_contract`** is the intended visibility path on **`push` to `main`** and on PRs touching installer paths — run the merge gate there (or locally with a warm Hex cache) before setting **`status: passed`**.
