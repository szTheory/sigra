---
phase: 41
slug: backup-codes-ga-product-closure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-20
---

# Phase 41 — Validation Strategy

> Feedback sampling for backup-code **rotation** + audit atomicity (**GA-01**).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`MIX_ENV=test`) |
| **Config file** | `config/test.exs` (example app) |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa/ --warnings-as-errors` (if lib-only tests added) |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/ --warnings-as-errors` |
| **Estimated runtime** | ~2–6 minutes (project-dependent) |

---

## Sampling Rate

- **After Plan 01 (library) commits:** Run **`mix test`** scoped to **`test/sigra`** MFA modules touched.
- **After Plan 02–03 (host + templates):** Run **`mix test test/example/...mfa...`** and new **`backup_code_rotation`** module.
- **Before phase sign-off:** Full **`test/example`** DataCase suite green for Postgres-backed paths.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 41-01-01 | 01 | 1 | GA-01 | T-41-01 | Rotation is all-or-nothing in DB | integration / unit | `mix test test/sigra/mfa/backup_codes_test.exs` (extend or add) | ⬜ | ⬜ pending |
| 41-02-01 | 02 | 2 | GA-01 | T-41-02 | Sudo gate before MFA settings | grep + compile | `grep -q require_sudo test/example/lib/example_web/router.ex` (post-change) | ⬜ | ⬜ pending |
| 41-04-01 | 04 | 3 | GA-01 | T-41-03 | Old plaintext fails after rotation | integration | `mix test test/example/**/*backup_code_rotation*_test.exs` | ⬜ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- [ ] Existing **`Example.DataCase`** + Postgres — no new framework install.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Browser regenerate UX | GA-01 | Optional belt-and-suspenders | After backend green: open `/users/settings/mfa`, sudo, rotate, confirm one-time display. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when phase verified
- Post **phase 50**, the root Mix alias **`mix ci.install_golden`** (see **`mix.exs`** → **`ci.install_golden`**) is the cited contract for the installer subprocess harness covering **`test/sigra/install/golden_diff_test.exs`** and **`test/sigra/install/idempotency_test.exs`**; CI mirrors it via job **`install_golden_contract`** (see **`MAINTAINING.md`**).

**Approval:** pending
