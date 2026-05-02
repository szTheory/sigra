---
phase: 93-m2m-service-account-tokens-b2b-03
plan: "09"
subsystem: organizations/liveview
tags: [liveview, ui-spec, service-accounts, sudo, generator, hooks, gap-closure, b2b-03]

dependency_graph:
  requires:
    - 93-01 (Sigra.ServiceAccounts public API)
    - 93-04 (skeleton OrganizationServiceAccountsLive + router_injection)
  provides:
    - Full UI-SPEC parity OrganizationServiceAccountsLive template (1082 lines)
    - CopyToClipboard Phoenix.LiveView hook source + installer wiring
    - Example app mirror that compiles clean
  affects:
    - lib/sigra/install/features/organizations.ex (installer extended)
    - test/example compile correctness

tech_stack:
  added:
    - CopyToClipboard Phoenix.LiveView colocated hook (JS)
  patterns:
    - Passkeys-feature pattern for hook source + asset injection
    - DaisyUI DialogModal pattern for 5 modals
    - Sudo gate (current_password field) on all 4 mutating actions
    - Typed-confirm gate on Revoke SA modal
    - One-time credential disclosure (T-93-01 mitigation)

key_files:
  created:
    - priv/templates/sigra.install/organizations/copy_to_clipboard_hook.js
    - priv/templates/sigra.install/organizations/app_js_clipboard_injection.js
    - test/example/assets/js/clipboard_hook.js
  modified:
    - priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex
    - lib/sigra/install/features/organizations.ex
    - test/example/lib/example_web/live/organization_service_accounts_live.ex
    - test/example/lib/example_web/router.ex

decisions:
  - "Used Enum.find + case/if pattern instead of guard for to_string/1 comparison (guards cannot call String.Chars.to_string/1)"
  - "CopyToClipboard shipped via colocated hooks Path A in example app (no esbuild pipeline; phoenix_live_view compiler picks up assets/js/)"
  - "Template uses alias <%= app_module %>.Organizations for __sigra_org_config__() — mirrors organization_members_live.ex pattern"
  - "sigra_config/0 delegates to context_module.sigra_config() — consistent with other org LiveViews"

metrics:
  duration: "~45 minutes"
  completed: "2026-05-01"
  tasks: 3
  files: 7
---

# Phase 93 Plan 09: Full UI-SPEC Parity for OrganizationServiceAccountsLive Summary

**One-liner:** Full UI-SPEC-parity OrganizationServiceAccountsLive template (1082 lines) with 5 modals, sudo gates, typed-confirm, one-time disclosure, and CopyToClipboard hook wiring via passkeys-pattern installer.

## What Was Built

Plan 93-09 grew the 79-line skeleton OrganizationServiceAccountsLive (from 93-04) into the full UI-SPEC-parity implementation. This closes gap #4 from 93-VERIFICATION.md.

### Task 1 — Full UI-SPEC LiveView Template

`priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` rewritten from 79 lines to 1082 lines:

- **Index surface**: paginated SA table (≥1 SA) or empty-state card, row-action overflow menu (View / Revoke service account), Load more pagination
- **Detail surface**: breadcrumb, metadata section (name, description, created/updated timestamps), credentials table with Create credential CTA, Danger Zone for Revoke SA
- **5 modals**: Create SA, Create Credential, Credential Disclosure, Revoke SA, Revoke Credential
- **Sudo gates** on all 4 mutating actions (create SA, create credential, revoke SA, revoke credential): inline `current_password` field, `Sigra.Crypto.verify_password/2` re-verification, verbatim error copy "That password is incorrect."
- **Typed-confirm** on Revoke SA: input must equal `@service_account.name` exactly
- **One-time disclosure** (T-93-01): `acknowledged_credential` cleared on confirm click; secret never re-shown
- **phx-hook="CopyToClipboard"** on both disclosure copy buttons (no `onclick` fallback)
- **Typography**: `font-normal` / `font-semibold` only (revision 1 2-weight cap); `font-semibold` on heading, section headings, modal titles
- **All UI-SPEC verbatim copy**: "Service Accounts", "No service accounts yet.", "Create service account", "Credential disclosure", "This is the only time the client secret will be shown.", etc.

### Task 2 — CopyToClipboard Hook + Installer Wiring

- `priv/templates/sigra.install/organizations/copy_to_clipboard_hook.js` (NEW): reads `data-copy-text`, calls `navigator.clipboard.writeText()`, swaps `#copy-btn-text-{id}` to "Copied!" for 1500ms. Mirrors CopyBackupCodes at mfa_settings_live.ex:530-560.
- `priv/templates/sigra.install/organizations/app_js_clipboard_injection.js` (NEW): injection fragment for host `assets/js/app.js`, mirrors passkeys injection pattern.
- `lib/sigra/install/features/organizations.ex`: extended `files/1` to ship `copy_to_clipboard_hook.js` into host `assets/js/`; extended `injections/1` to append the clipboard injection fragment into host `assets/js/app.js`.
- `test/example/assets/js/clipboard_hook.js` (NEW): content-identical hook registered via colocated hooks in example app.

### Task 3 — Example App Mirror + Router :show Route

- `test/example/lib/example_web/live/organization_service_accounts_live.ex`: resolved template (all EEx tags substituted to `ExampleWeb`, `Example.Accounts`, `Example.Repo`, `Example.Organizations`).
- `test/example/lib/example_web/router.ex`: added `live "/service-accounts/:id", OrganizationServiceAccountsLive, :show` inside the `live_session :organization_scoped` block.
- Both `cd test/example && mix compile --warnings-as-errors` and root `mix compile --warnings-as-errors` pass clean.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed to_string/1 guard clause in find_or_load_sa/2**
- **Found during:** Task 3 (compilation error)
- **Issue:** `%{id: sa_id} = sa when to_string(sa_id) == to_string(id)` — `String.Chars.to_string/1` cannot be called inside a guard clause in Elixir
- **Fix:** Converted guard to `case/if` pattern: `%{id: sa_id} = sa -> if to_string(sa_id) == to_string(id), do: sa, else: nil`
- **Files modified:** both `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex` and `test/example/lib/example_web/live/organization_service_accounts_live.ex`
- **Commit:** aa02764

## Known Stubs

None — all modals, event handlers, and data loading paths are fully wired. `@disclosed_credential` flows from `create_credential` callback to the disclosure modal and is cleared on acknowledge. No placeholder values or "coming soon" text.

## Threat Flags

No new network endpoints, auth paths, or trust boundary changes introduced by this plan. All mutations route through `Sigra.ServiceAccounts` functions (established in 93-01) with sudo re-verification before each write.

## Self-Check: PASSED

Files verified:
- FOUND: priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex
- FOUND: priv/templates/sigra.install/organizations/copy_to_clipboard_hook.js
- FOUND: priv/templates/sigra.install/organizations/app_js_clipboard_injection.js
- FOUND: lib/sigra/install/features/organizations.ex
- FOUND: test/example/lib/example_web/live/organization_service_accounts_live.ex
- FOUND: test/example/lib/example_web/router.ex
- FOUND: test/example/assets/js/clipboard_hook.js

Commits verified:
- d80f801: feat(93-09): full UI-SPEC parity LiveView template for OrganizationServiceAccountsLive
- 4f7c982: feat(93-09): ship CopyToClipboard hook source + asset injection + installer wiring
- aa02764: feat(93-09): mirror template into example app + router :show route
