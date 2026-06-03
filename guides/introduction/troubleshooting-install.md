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

## Optional deps (Oban, Hammer, OAuth, etc.)

**Symptom:** Compile errors referencing `Oban`, `Hammer`, or OAuth-related modules in generated code.

**Fix:** Add the optional dependency to the **host** `mix.exs` as documented in the installer output and in **`README.md`**. Sigra keeps optional integrations as **host** deps by design.

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

## First-run verification with `mix sigra.doctor`

Run this immediately after install from your host app root:

```bash
mix sigra.doctor
mix sigra.doctor --quiet
```

`mix sigra.doctor` prints one row per optional feature with these states:

- `[ ] missing` — optional dependency is not present; this is non-fatal unless you configured that feature.
- `[~] available` — dependency is loaded but the feature is not configured.
- `[✓] loaded` — dependency is loaded and the feature is configured/active.
- `[!] misconfigured` — feature is configured but required wiring/dependencies are missing.

Verdict lines come from the task output and must be interpreted literally:

- `OK: all configured features are properly wired.`
- `ERROR: misconfigured features detected (see above). Fix the issues above before deploying.`

Exit semantics are:

- `exit 0`: all configured features are wired correctly, or no optional features are configured.
- `exit 1`: at least one configured feature has broken wiring.

### Success example

```text
$ mix sigra.doctor --quiet
==> sigra.doctor

  [~] available oauth (OAuth/OIDC) (not configured)
  [~] available async_email (Swoosh + Oban) (not configured)
  [✓] loaded     rate_limiting (Hammer)

OK: all configured features are properly wired.
```

### Failure example (configured OAuth without Assent and async email without supervised Oban/Swoosh)

```text
$ mix sigra.doctor
==> sigra.doctor

  [!] misconfigured oauth (OAuth/OIDC) — OAuth providers are configured but Assent is missing.
  [!] misconfigured async_email (Swoosh + Oban) — Async email is configured but Swoosh and/or supervised Oban are missing.
  [ ] missing   enterprise_connections (Req)

Misconfigured features:
  oauth: configured providers but Assent is not loaded.
  async_email: enabled but requires both Swoosh and supervised Oban.
ERROR: misconfigured features detected (see above). Fix the issues above before deploying.
```

## Still stuck

- Search existing issues on the Sigra repository.
- For **GA / audit / Nyquist** language, see **`docs/ga-evidence.md`** and **`MAINTAINING.md`**.
