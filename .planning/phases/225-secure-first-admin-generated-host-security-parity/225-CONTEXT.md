# Phase 225 Context

## Decision

Fresh admin-enabled hosts need an explicit, persisted authorization fact rather than a TODO policy or an inferred first user. The host owns the schema, access module, policy, lifecycle tasks, and tests. Existing policies remain host-owned and are never overwritten.

## Contract

- A grant is active while `revoked_at` is nil and unique per user.
- Only an existing, confirmed, non-deleted account can be granted.
- Grant/revoke are repeat-safe; only real mutations emit atomic audit evidence.
- CLI actors are represented as system operations; the selected account is the audit target.
- `--no-admin` emits no grant artifacts.
- Customized adopters opt into one policy delegation line after adding the migration/module/tasks.
- All listed account-security operations receive current scope and deny while impersonating.

## Rejected

- First registered user, email-domain, environment-email, or browser bootstrap inference.
- Password-taking admin tasks.
- Rewriting a customized `SigraAdminPolicy` during upgrade.
