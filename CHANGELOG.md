# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Sigra.Audit.log_safe/3` accepts a scope as the second positional argument.
  The scope is duck-typed on `%{user, active_organization, impersonating_from}`;
  pass `nil` explicitly for pre-authentication or truly anonymous call sites.
  `log_safe/2` remains as a thin shim that delegates to `log_safe/3` with a
  `nil` scope.
- `Sigra.Audit.Query` supports `:organization_id`, `:effective_user_id`, and
  `:organization_scope` filters. `:organization_scope` accepts `{:only, org_id}`
  or `{:including_global, org_id}` tagged tuples. The composite index
  `(organization_id, inserted_at)` is created on `audit_events` by the new
  alter migration to keep org-scoped queries off seq-scan plans at scale.
- `Sigra.Scope.build/3` library constructor for the host-app `%Scope{}` struct,
  used by login-time scope synthesis and by Sigra-aware workers. Also adds
  `Sigra.Scope.from_opts/2` and `Sigra.Scope.from_config/2` convenience
  constructors.
- `Sigra.Workers` behaviour — single `@callback perform(scope, args)` contract
  for Oban workers requiring tenant context. `Sigra.Workers.new/3` fails fast
  when required `"organization_id"` / `"actor_id"` arg keys are absent;
  `Sigra.Workers.fetch_arg!/2` is a belt+suspenders helper for worker
  `perform/1` implementations. `Sigra.Workers.AccountDeletion` is the
  reference implementation — it reconstructs the scope inside `perform/1`
  and delegates to `perform/2` with a real `%Scope{}`.
- `Sigra.Testing.assert_audit_logged/2` helper — a thin alias for
  `assert_audit_event/2` with the REQ DX-02 naming convention. Signature is
  `(map, keyword)` to match `assert_audit_event/2` exactly.
- Custom Credo check `Sigra.Credo.NoLogSafe2InLib` that forbids arity-2
  `Sigra.Audit.log_safe` calls in `lib/sigra/**` (with an exception for the
  shim definition itself and for `test/**`). Registered in `.credo.exs` via
  the `requires:` field so host apps pulling Sigra as a dep are not forced
  to take a Credo dependency.
- New migration `alter_audit_events_add_org_columns.exs` adds
  `organization_id :binary_id` (nullable, FK with
  `on_delete: :nilify_all` so historical rows survive organization deletion)
  and `effective_user_id :binary_id` (nullable, v1.2 impersonation anchor)
  columns to `audit_events`, plus the composite index
  `(organization_id, inserted_at)`. On Postgres, the migration uses
  `@disable_ddl_transaction true` + `create index(..., concurrently: true)`
  for zero-downtime deploy on production audit tables. On SQLite/MySQL, a
  plain `change/0` migration emits the same shape non-concurrently.

### Changed

- **BREAKING (behavior):** `session.create` audit now fires AFTER
  `select_active_organization` during login, so the very first audit event
  of a successful login carries the real `organization_id` rather than a
  `nil` one. Previously, `session.create` fired before the active-org
  selection step and always had a null org, meaning the v1.2 impersonation
  anchor would have no tenant to pin against. If you were relying on the
  old ordering (e.g. a log scraper keyed on null-org events for login
  detection), update your consumers to match the new ordering.
- **BREAKING (API):** `Sigra.Audit.Query.build/2` now raises
  `ArgumentError` on unknown filter keys instead of silently ignoring them.
  If your host app was passing an unknown key (e.g. `actor:` instead of
  `actor_id:`) the query previously returned unfiltered results — now it
  fails loudly. Rationale: silent-ignore on an audit query is a
  security-adjacent bug; audit systems must be loud about
  misconfiguration.
- **BREAKING (installer):** `Sigra.Workers.AccountDeletion` job args now
  require five additional stringified keys at enqueue time:
  `"organization_id"`, `"actor_id"`, `"scope_module"`, `"organization_schema"`,
  and `"audit_schema"`. Host apps that use the Sigra installer to generate
  the account-deletion Oban enqueue site should regenerate that site (or
  manually add the new args). The worker validates presence of all five
  via `fetch_arg!/2` up front BEFORE any `Module.safe_concat` call so the
  `KeyError` surfaces with the actual missing key.

