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

## Still stuck

- Search existing issues on the Sigra repository.
- For **GA / audit / Nyquist** language, see **`docs/ga-evidence.md`** and **`MAINTAINING.md`**.
