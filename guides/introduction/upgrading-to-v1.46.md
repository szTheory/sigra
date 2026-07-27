# Upgrading generated hosts for v1.46 adopter experience

Sigra's generated files belong to the host application. This upgrade is therefore additive and opt-in: update the library normally, then choose which generated UI and first-admin changes to adopt. Do not use `--force` over customized files.

## 1. Upgrade the dependency first

In a dedicated branch with a database backup:

    mix deps.update sigra
    mix compile --warnings-as-errors
    mix test

Use the package version and release notes in `CHANGELOG.md` as the SemVer source of truth; v1.46 is the planning milestone label.

## 2. Add the persisted first-admin seam

Re-run the installer with the same feature flags and naming arguments used by the app. The installer creates missing files and skips host-owned files that already exist:

    mix sigra.install Accounts User users --yes

Review the diff before migrating. For an admin-enabled UUID/Postgres install, the additive files are equivalent to:

- `priv/repo/migrations/*_create_platform_admin_grants.exs`
- `lib/my_app/accounts/platform_admin_grant.ex`
- `lib/my_app/sigra_admin_access.ex`
- `lib/mix/tasks/sigra.admin.{grant,revoke,list,check}.ex`
- `test/my_app/sigra_admin_policy_test.exs`

Keep your original `--no-*`, `--no-binary-id`, table, and auth-prefix choices when re-running the installer. A host installed with `--no-admin` should not add these files.

If `lib/my_app/sigra_admin_policy.ex` is customized, the installer leaves it untouched. Opt in by changing only the platform-admin callback:

```elixir
@impl true
def platform_admin?(scope), do: MyApp.SigraAdminAccess.platform_admin?(scope)
```

Keep `admin_org_ids/1` and any other host policy rules as they are. There is no first-user fallback, email allowlist, browser bootstrap route, or password-taking admin task.

Run the migration before the first grant:

    mix ecto.migrate
    mix sigra.admin.grant --email operator@example.com
    mix sigra.admin.check --email operator@example.com

The account must already exist, be confirmed, and not be soft-deleted. Grant and revoke mutations commit their audit rows in the same transaction. Both commands are repeat-safe; `list` and `check` are read-only.

## 3. Adopt the generated-auth contract selectively

The v1.46 templates replace utility-shaped markup with a bounded `sigra-auth-*` vocabulary, preserve scoped compatibility selectors for older host templates, establish one configuration-derived primary action, and improve mismatch/recovery/security copy. Existing generated templates are not rewritten automatically.

For a customized app, compare rather than overwrite:

1. Generate a disposable fresh Phoenix host using the same Sigra flags.
2. Diff its `sigra_auth.css` and auth templates against the host.
3. Adopt semantic classes and state copy by flow, keeping host-specific product decisions.
4. Exercise Light, Dark, and System, keyboard focus, reduced motion, forced colors, long copy, and 320px reflow before merging.

The compatibility selectors in the new stylesheet let older generated markup continue to render while a host migrates incrementally. Do not copy admin `sg-*` or demo-product `vt-*` classes into generated auth templates.

## 4. Preserve impersonation protections

If the host customized its generated auth context or controllers, compare the new templates and ensure the current scope reaches every sensitive operation. While impersonating, deny:

- password change;
- MFA disable and backup-code regeneration;
- passkey registration, rename, and deletion;
- account deletion schedule and cancellation;
- personal data export;
- API-token management.

Keep the library's typed impersonation denial and user-safe UI handling rather than duplicating an ad hoc boolean check in each controller.

## 5. Verify and roll back safely

Before deploy:

    mix test
    mix sigra.admin.list

Smoke-test register/confirm → grant → password login → `/admin` → audit filtering → revoke/deny in a staging database. Confirm each filter has one submitted value and that active filters, sort, pagination, URL presets, and CSV export agree.

To roll back access without reverting schema, run `mix sigra.admin.revoke`. To roll back policy delegation, restore the previous `platform_admin?/1` implementation; leaving the additive grant table in place is harmless. Drop the table only in a separately reviewed migration after verifying no deployment still calls `SigraAdminAccess`.
