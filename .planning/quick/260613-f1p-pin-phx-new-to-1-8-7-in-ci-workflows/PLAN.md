---
quick_id: 260613-f1p
slug: pin-phx-new-to-1-8-7-in-ci-workflows
date: 2026-06-13
---

# Quick Task: Pin phx_new to 1.8.7 in CI workflows

## Problem
PR #52 CI broadly red. Root cause: `phx_new` is unpinned (`mix archive.install --force hex phx_new`)
and version **1.8.8** (2026-06-10) dropped the `type` attr from the generated host app's default
`<.button>`. Sigra's generated templates use `<.button type=…>`, so the generated app fails to compile
under `--warnings-as-errors`. Breaks: install smoke, install matrix ×4, passkeys smokes ×2, upgrade smoke,
`vault_promotion_test`, `golden_diff_test`. Not a brand-v2 regression — byte-identical callsites to green
`main`; PR #47 (off main) was green Jun 7 when latest phx_new was 1.8.7.

## Change
Pin `phx_new 1.8.7` (last-known-good) in all CI install spots:
- `.github/workflows/ci.yml` (×9)
- `.github/workflows/release-please.yml` (×1)
- `.github/workflows/hex-publish.yml` (×1)

Plus: file `SEED-004` for forward-compat with phx.new ≥1.8.8 button API (real fix deferred).

## Verification
Local: phx_new-1.8.7 archive installed + Postgres up → `mix test vault_promotion_test golden_diff_test`
= **3 tests, 0 failures**. golden fixture did NOT need regeneration (drift was purely the 1.8.8 bump).
Authoritative gate: PR #52 CI after push.
