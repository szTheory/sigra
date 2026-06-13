---
status: complete
quick_id: 260613-f1p
slug: pin-phx-new-to-1-8-7-in-ci-workflows
date: 2026-06-13
---

# Quick Task Complete: Pin phx_new to 1.8.7

## What changed
- Pinned `mix archive.install --force hex phx_new` → `… phx_new 1.8.7` in all 11 CI install spots:
  `.github/workflows/ci.yml` (×9), `release-please.yml` (×1), `hex-publish.yml` (×1).
- Filed `.planning/seeds/SEED-004-phx-new-button-forward-compat.md` (forward-compat follow-up).

## Why
phx_new 1.8.8 (2026-06-10) dropped `type` from the generated `<.button>` `:global` include,
breaking the generated app under `--warnings-as-errors`. Unpinned CI silently upgraded between
PR #47's green run (Jun 7, phx_new 1.8.7) and PR #52's red run (Jun 13, phx_new 1.8.8). Pinning to
1.8.7 restores deterministic green for install/golden/vault jobs.

## Verification
- Local (phx_new-1.8.7 + Postgres on :5432): `mix test test/sigra/install/vault_promotion_test.exs
  test/sigra/install/golden_diff_test.exs` → **3 tests, 0 failures**.
- golden fixture required **no** regeneration (drift was purely the phx_new bump).
- Authoritative: PR #52 CI run after push.

## Follow-up
SEED-004 — make Sigra forward-compatible with phx.new ≥1.8.8 button, then bump/remove the pin.
