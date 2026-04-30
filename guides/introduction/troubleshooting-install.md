# Troubleshooting install

Common failures when adding Sigra to a Phoenix 1.8+ app and how to fix them.

## PostgreSQL connection refused

**Symptom:** `DBConnection.ConnectionError` during `mix ecto.migrate` or `mix test`.

**Fix:** Start Postgres; align `config/dev.exs` / `config/test.exs` host, port, user, password, and database name. For Sigra library development, the repo documents a Docker one-liner in **`CLAUDE.md`**.

## `mix sigra.install` errors or partial files

**Symptom:** Missing `Accounts`, `UserAuth`, or migration files.

**Fix:** Run from the **host app root** (where `mix.exs` lives). Re-run `mix sigra.install` — the task refuses to overwrite edited files; merge manually if prompted. Use `--yes` for non-interactive installs.

## UUID vs integer primary keys

**Symptom:** Surprises if you assumed integer IDs.

**Fix:** The installer defaults to **`binary_id`**. Pass `--no-binary-id` to `mix sigra.install` if you need bigint PKs and align foreign keys accordingly.

## Optional deps (Oban, bcrypt, EQRCode, Hammer, OAuth, etc.)

**Symptom:** `mix sigra.doctor` shows `FAIL enforced ...`, or the host raises a tagged missing-dependency error when you trigger async email, bcrypt-hash verification, or MFA QR enrollment.

**Fix:** Run `mix sigra.doctor` first. Add the missing dependency to the **host** `mix.exs` only for the capability you actually enabled. Sigra keeps optional integrations as **host** deps by design, so Oban, `bcrypt_elixir`, and `eqrcode` become blocking only when the host opts into async/background delivery, real bcrypt migration verification, or TOTP QR rendering.

## Tests fail only in CI

**Symptom:** Green locally, red on GitHub Actions.

**Fix:** Ensure CI starts Postgres and sets `PG*` (or your repo’s convention). Sigra’s own workflows use strict jobs — mirror the same services block for host apps.

## Upgrading between Sigra versions

**Symptom:** You are on an older **`{:sigra, ...}`** line and want a safe bump.

**Fix:**

1. Read **`CHANGELOG.md`** for breaking or behavioral changes on the Hex line you target.
2. Use the planning-milestone upgrade pages for **maintainer / docs context**, not as a substitute for SemVer:
   - **[Upgrading notes — toward v1.7](upgrading-to-v1.7.html)** — post–v1.6 Nyquist **41–44**, OAuth↔audit CI, docs hub pointers.
   - **[Upgrading notes — toward v1.8](upgrading-to-v1.8.html)** — post–v1.7 **adopter polish** framing + host checklist.

Then bump the dependency, **`mix deps.get`**, and re-run **`mix test`** (and **`mix sigra.upgrade --yes`** only when **`CHANGELOG.md`** or release notes tell you to).

## Still stuck

- Search existing issues on the Sigra repository.
- For **GA / audit / Nyquist** language, see **`docs/ga-evidence.md`** and **`MAINTAINING.md`**.
