# 239-03 SC-4 Mirror Checklist

One row per template edited by plan 239-02's sweep commit (`cafd9a53`). Each row carries the
template's pre-sweep union-token count and exactly one disposition: a `test/example/` counterpart
path with its mirrored line count (this plan, 239-03), `n/a — already absent` (the counterpart
already carried zero tokens before this plan touched anything), or `no counterpart (delivered by
injection)` (the template has no `{:eex, ...}` file-emission target in
`lib/sigra/install/features/*.ex` — it's spliced into an existing file by the generator, not
rendered to a new one).

## Mirrored counterparts (30 files, 110 template token lines)

| Template (pre-sweep tokens) | Disposition |
|---|---|
| priv/templates/sigra.install/organizations/live/organization_members_live.ex (18) | Mirrored → `test/example/lib/example_web/live/organization_members_live.ex` (18 lines) |
| priv/templates/sigra.install/organizations/organizations.ex (12) | Mirrored → `test/example/lib/example/organizations.ex` (12 lines) |
| priv/templates/sigra.install/organizations/live/organization_settings_live.ex (11) | Mirrored → `test/example/lib/example_web/live/organization_settings_live.ex` (11 lines) |
| priv/templates/sigra.install/core/auth_fixtures.ex (8) | Mirrored → `test/example/test/support/fixtures/auth_fixtures.ex` (8 lines) |
| priv/templates/sigra.install/core/user_auth.ex (7) | Mirrored → `test/example/lib/example_web/user_auth.ex` (7 lines) |
| priv/templates/sigra.install/core/emails.ex (4) | Mirrored → `test/example/lib/example/accounts/emails.ex` (4 lines) |
| priv/templates/sigra.install/core/mfa_settings_live.ex (4) | Mirrored → `test/example/lib/example_web/live/mfa_settings_live.ex` (4 lines) |
| priv/templates/sigra.install/core/sigra_auth.css (4) | Mirrored → `test/example/priv/static/assets/sigra_auth.css` (4 lines) |
| priv/templates/sigra.install/core/auth.ex (4) — **renamed (D-21): context module** | Mirrored → `test/example/lib/example/accounts.ex` (4 lines) |
| priv/templates/sigra.install/organizations/live/organizations_live/index.ex (4) | Mirrored → `test/example/lib/example_web/live/organizations_live/index.ex` (4 lines) |
| priv/templates/sigra.install/core/audit_event.ex (3) | Mirrored → `test/example/lib/example/accounts/audit_event.ex` (3 lines) |
| priv/templates/sigra.install/core/mfa_challenge_live.ex (3) | Mirrored → `test/example/lib/example_web/live/mfa_challenge_live.ex` (3 lines) |
| priv/templates/sigra.install/core/reset_password_live.ex (3) | Mirrored → `test/example/lib/example_web/live/reset_password_live.ex` (3 lines) |
| priv/templates/sigra.install/core/reset_password_controller.ex (3) | Mirrored → `test/example/lib/example_web/controllers/reset_password_controller.ex` (3 lines) |
| priv/templates/sigra.install/organizations/controllers/organization_switch_controller.ex (3) | Mirrored → `test/example/lib/example_web/controllers/organization_switch_controller.ex` (3 lines) |
| priv/templates/sigra.install/core/scope.ex (2) | Mirrored → `test/example/lib/example/accounts/scope.ex` (2 lines) |
| priv/templates/sigra.install/organizations/live/invitation_accept_live.ex (2) | Mirrored → `test/example/lib/example_web/live/invitation_accept_live.ex` (2 lines) |
| priv/templates/sigra.install/organizations/components/org_switcher.ex (2) | Mirrored → `test/example/lib/example_web/components/org_switcher.ex` (2 lines) |
| priv/templates/sigra.install/organizations/organization.ex (2) | Mirrored → `test/example/lib/example/accounts/organization.ex` (2 lines) |
| priv/templates/sigra.install/core/registration_live.ex (1) | Mirrored → `test/example/lib/example_web/live/registration_live.ex` (1 line) |
| priv/templates/sigra.install/core/confirmation_live.ex (1) | Mirrored → `test/example/lib/example_web/live/confirmation_live.ex` (1 line) |
| priv/templates/sigra.install/core/reset_password_html.ex (1) | Mirrored → `test/example/lib/example_web/controllers/reset_password_html.ex` (1 line) |
| priv/templates/sigra.install/core/sudo_controller.ex (1) | Mirrored → `test/example/lib/example_web/controllers/auth/sudo_controller.ex` (1 line) |
| priv/templates/sigra.install/core/sudo_html.ex (1) | Mirrored → `test/example/lib/example_web/controllers/auth/sudo_html.ex` (1 line) |
| priv/templates/sigra.install/core/user.ex (1) | Mirrored → `test/example/lib/example/accounts/user.ex` (1 line) |
| priv/templates/sigra.install/core/user_token.ex (1) | Mirrored → `test/example/lib/example/accounts/user_token.ex` (1 line) |
| priv/templates/sigra.install/admin/admin_hooks.js (1) | Mirrored → `test/example/assets/js/admin_hooks.js` (1 line) |
| priv/templates/sigra.install/core/login_html.ex (1) — **renamed (D-21): renders into session_html.ex** | Mirrored → `test/example/lib/example_web/controllers/session_html.ex` (1 line) |
| priv/templates/sigra.install/organizations/live/organizations_live/new.ex (1) | Mirrored → `test/example/lib/example_web/live/organizations_live/new.ex` (1 line) |
| priv/templates/sigra.install/core/migration.exs (1) — **renamed (D-21): timestamped migration** | Mirrored → `test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs` (1 line) |

Sum of the "Mirrored counterparts" pre-sweep template token column: 110, across 30 files —
matching the SC-4 edit budget exactly.

## Already-absent counterparts (4 files, honest divergence — no edit made)

These four counterparts already carried **zero** union-token lines before this plan touched
anything, while their source templates carried non-zero counts. No edit was made — a phantom
edit here would misrepresent an already-diverged file as freshly swept. This divergence, together
with the no-counterpart rows below, **is** the FUT-01 diagnosis carried into plan 239-04 (D-25).

| Template (pre-sweep tokens) | Disposition |
|---|---|
| priv/templates/sigra.install/core/settings_live.ex (4) | n/a — already absent (`test/example/lib/example_web/live/settings_live.ex`) |
| priv/templates/sigra.install/core/error_handler.ex (1) — **renamed (D-21)** | n/a — already absent (`test/example/lib/example_web/auth_error_handler.ex`) |
| priv/templates/sigra.install/organizations/organization_invitation.ex (2) | n/a — already absent (`test/example/lib/example/accounts/organization_invitation.ex`) |
| priv/templates/sigra.install/organizations/migration.exs (13) — **renamed (D-21): timestamped migration** | n/a — already absent (`test/example/priv/repo/migrations/20260410125245_create_organizations.exs`) |

## No-counterpart templates (12 files, delivered by injection — D-22)

These templates have no `{:eex, ...}` file-emission target in `lib/sigra/install/features/*.ex` —
the generator splices their content into an existing file (or, for `sigra.upgrade/`, applies them
as an upgrade-time patch script) rather than rendering them as a standalone file. `test/example/`
therefore has no counterpart path to mirror into by construction, not by omission.

| Template | Disposition |
|---|---|
| priv/templates/sigra.install/core/mfa_challenge_controller.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/organizations/organization_invitation_email.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/core/mfa_challenge_html.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/core/mfa_settings_html.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/core/token_controller.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/core/api_token_created_email.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/organizations/router_injection.ex | no counterpart (delivered by injection) |
| priv/templates/sigra.install/sigra.upgrade/data_migration.exs | no counterpart (delivered by injection) |
| priv/templates/sigra.upgrade/alter_add_personal.exs | no counterpart (delivered by injection) |
| priv/templates/sigra.upgrade/alter_add_owner_user_id.exs | no counterpart (delivered by injection) |
| priv/templates/sigra.gen.oauth/oauth_settings_live.ex | no counterpart (delivered by injection) |

## Scoping statement

Repo-wide, `test/example/` carried 476 planning-bookkeeping token lines across 94 files before
this plan. This commit deliberately swept only the **110 token lines across 30 counterpart
files** that SC-4 mandates (the direct counterparts of templates plan 239-02 edited) — leaving
the remaining ~366 token lines across the other ~64 files in `test/example/` untouched, on
purpose, for a future milestone to scope and sweep independently. `test/example/` is a
hand-maintained generated-app mirror that already drifts behind `priv/templates/` by design (see
`reference_installer_template_drift.md`); this plan's job was narrowly to keep the 30 direct
counterparts of the swept templates from contradicting the sweep, not to bring the whole
hand-maintained tree into alignment.
