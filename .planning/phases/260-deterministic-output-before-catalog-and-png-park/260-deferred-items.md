# Phase 260 Deferred Items

Out-of-scope discoveries logged by the plans of this phase. Each plan adds its own
section; plan 05 adds the owed pre-262 shipped-byte fixes, the 56-class CSS gap, the
Pages-workflow compare note and the SC-1 wording reconciliation.

## From plan 03 (raw inputs for the before catalog)

### 1. The generated reset-password request page returns HTTP 500 (executed evidence)

`GET /users/reset-password` on a freshly generated `--live` host answers 500:
`CaseClauseError ... nil` raised from `ResetPasswordLive.mount/3` at
`reset_password_live.ex:132` (the generated route `live "/reset-password",
ResetPasswordLive` carries no live action, so `live_action` is `nil`). The todo
`.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md`
recorded this as "read in source, not executed"; plan 03 executed it against a booted
generated host (phx_new 1.8.8 + `mix sigra.install --yes Accounts User users --no-passkeys`).

Not fixed here: plan 03 may not change `lib/` or `priv/`. How the catalog treats it:

- `scripts/ci/admin-acceptance-smoke.sh --test catalog` pins this one page as an
  expected 500, accepted only when the dev error page carries the exact signature
  (`CaseClauseError at GET /users/reset-password` and `ResetPasswordLive.mount/3`).
  The error page (local paths, stack) is never kept; `pages/reset-password.html`
  holds a one-line marker comment.
- When the template is fixed the page answers 200 and the script fails until the
  `reset-password|/users/reset-password|500` entry is changed to `200`, so the
  baseline cannot go stale silently.
- Plan 05's manifest `deferred_shipped_byte_fixes` should name this fix, and the
  `before` file for this slug is a marker, not a rendered page.

### 2. The smoke script and `tmp/db.env` disagree about which Postgres to use

With `source tmp/db.env` exported, `mix ecto.drop` and `mix ecto.create` in the generated
host follow `PGPORT` (the dockerized test Postgres), but the host's `Repo` connects to
`localhost:5432` (the generated config sets `hostname: "localhost"` and no port). The
result is `duplicate_table` on the first migrate against whichever stale
`sigra_admin_smoke_*` database exists on 5432. Plan 03's own verify command sources
`tmp/db.env`, so it fails in this environment; the target was run with the `PG*` and
`SIGRA_TEST_PG_*` variables unset instead (`env -u PGPORT -u PGHOST -u PGUSER -u PGPASSWORD
-u PGDATABASE ...`), which works because all three commands then reach 5432. Plan 05
should run the target the same way. Pre-existing script behavior, untouched.

### 3. Two generated email builders are not in the raw set

`email_change_confirmation_email/3` and `email_change_notification_email/3` end a
sentence with the new address and a period. The raw-directory address scan reads that as
a domain ending `.test.` and flags it, although the root privacy rule accepts it. They
were left out of the capture rather than loosening the scan; plan 05 may add them if it
settles the scan regex.

### 4. `unconfirmed` and `locked` tier-2 pages hold the same persona

The seeds carry one unconfirmed persona (`dave`) and it is also the locked one, so
`admin-user-show-unconfirmed` and `admin-user-show-locked` (and the sessions and audit
pairs) render the same account. The slugs are kept because the plan fixes the slug list.
