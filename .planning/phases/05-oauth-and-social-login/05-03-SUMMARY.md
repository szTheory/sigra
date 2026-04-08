---
phase: 05-oauth-and-social-login
plan: 03
subsystem: auth
tags: [oauth, generator, mix-task, eex-templates, cloak-ecto, injection]

# Dependency graph
requires:
  - phase: 05-oauth-and-social-login
    plan: 01
    provides: OAuthError, Config oauth section, Identity struct, strategy wrappers
  - phase: 05-oauth-and-social-login
    plan: 02
    provides: Sigra.OAuth orchestrator, Callback processor, Auth extensions, Testing helpers
provides:
  - mix sigra.gen.oauth Mix task generating all OAuth files into host app
  - 12 EEx templates (schema, vault, migration, controller, HTML, settings, emails, test helpers)
  - Injector extensions for OAuth route, config, and vault supervision tree injection
  - Generator tests verifying template content, injection idempotency, and module loading
affects: [05-04, 05-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [incremental generator pattern with --providers/--live/--no-vault flags, idempotent injection with separate markers]

key-files:
  created:
    - lib/mix/tasks/sigra.gen.oauth.ex
    - priv/templates/sigra.gen.oauth/user_identity.ex
    - priv/templates/sigra.gen.oauth/vault.ex
    - priv/templates/sigra.gen.oauth/encrypted_binary.ex
    - priv/templates/sigra.gen.oauth/oauth_migration.exs
    - priv/templates/sigra.gen.oauth/oauth_controller.ex
    - priv/templates/sigra.gen.oauth/oauth_html.ex
    - priv/templates/sigra.gen.oauth/oauth_buttons.html.heex
    - priv/templates/sigra.gen.oauth/oauth_settings.html.heex
    - priv/templates/sigra.gen.oauth/oauth_settings_live.ex
    - priv/templates/sigra.gen.oauth/provider_linked_email.ex
    - priv/templates/sigra.gen.oauth/provider_unlinked_email.ex
    - priv/templates/sigra.gen.oauth/oauth_test_helpers.ex
    - test/sigra/install/oauth_generator_test.exs
  modified:
    - lib/sigra/install/injector.ex

key-decisions:
  - "OAuth routes use separate marker '# Sigra OAuth' from base install marker to allow independent injection"
  - "Vault injection detects 'children = [' pattern and inserts after it for supervision tree integration"
  - "Provider config uses string concatenation instead of heredocs to avoid interpolation issues in Mix task"

patterns-established:
  - "Incremental generator: mix sigra.gen.oauth is separate from mix sigra.install per D-57"
  - "Generator idempotency: skips existing files, separate injection markers prevent duplicate injection"
  - "Template override: user can place custom templates in priv/templates/sigra.gen.oauth/ to override library defaults"

requirements-completed: [OAUTH-01, OAUTH-02, OAUTH-03, OAUTH-04, OAUTH-05, OAUTH-06, OAUTH-07, OAUTH-08]

# Metrics
duration: 7min
completed: 2026-04-08
---

# Phase 5 Plan 3: OAuth Generator Summary

**mix sigra.gen.oauth Mix task generating 12+ EEx templates (UserIdentity schema with encrypted tokens, Vault, migration, OAuth controller, brand-icon HTML module, dynamic provider buttons, settings page with link/unlink, email notifications) plus idempotent route/config/vault injection**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-08T14:33:51Z
- **Completed:** 2026-04-08T14:40:48Z
- **Tasks:** 2
- **Files modified:** 15

## Accomplishments

- Mix task `mix sigra.gen.oauth` with `--providers`, `--live`, and `--no-vault` flags for flexible generation
- UserIdentity schema template with `Encrypted.Binary` fields for access/refresh tokens, two unique constraints, provider normalization to lowercase
- Vault and Encrypted.Binary templates following cloak_ecto pattern with `CLOAK_KEY` env var and AES-256-GCM encryption
- Migration template creating `user_identities` table with unique indexes on `(user_id, provider)` and `(provider, provider_uid)`
- OAuth controller template handling request/callback with HMAC state in session, PKCE code_verifier, return_to support, link confirmation, and all error cases with safe messages
- OAuthHTML module with inline SVG brand icons for Google (multicolor G), GitHub (octocat), Apple (logo), Facebook (f), and generic globe fallback -- all 20x20px with `aria-hidden="true"`
- Dynamic OAuth buttons template rendering from configured providers with "Continue with {Provider}" label and "or" divider
- Connected Accounts settings page (controller HTML variant) showing linked providers with unlink confirmation, disabled unlink when last provider without password, "Set a password" hint, and "Add a sign-in method" section
- LiveView settings variant with `handle_event("unlink")` and live data loading
- Provider linked/unlinked email notification templates with HTML+text multipart and "Not you? Secure your account" security prompt
- OAuth test helpers template with `oauth_login/3` convenience function
- Injector extensions: `inject_oauth_routes/2`, `inject_oauth_config/2`, `inject_vault_child/2` -- all idempotent with separate markers
- Generator checks for `cloak_ecto` dependency at task level and raises helpful error if missing
- Generator detects existing files and injections, skips with message for safe re-runs
- 23 tests covering injection idempotency, template content verification, and module loading

## Task Commits

1. **Task 1: EEx templates for schema, vault, migration, controller, and emails** - `3ee1c4a` (feat)
2. **Task 2: Mix task, OAuth UI templates, route/config injection, and generator tests** - `69c3a25` (feat)

## Files Created/Modified

- `lib/mix/tasks/sigra.gen.oauth.ex` - Mix task with provider detection, file generation, and injection
- `lib/sigra/install/injector.ex` - Extended with inject_oauth_routes, inject_oauth_config, inject_vault_child
- `priv/templates/sigra.gen.oauth/user_identity.ex` - UserIdentity Ecto schema with encrypted fields
- `priv/templates/sigra.gen.oauth/vault.ex` - Cloak Vault with CLOAK_KEY env var
- `priv/templates/sigra.gen.oauth/encrypted_binary.ex` - Cloak.Ecto.Binary type
- `priv/templates/sigra.gen.oauth/oauth_migration.exs` - user_identities table migration
- `priv/templates/sigra.gen.oauth/oauth_controller.ex` - OAuth request/callback controller
- `priv/templates/sigra.gen.oauth/oauth_html.ex` - Provider icons and display names
- `priv/templates/sigra.gen.oauth/oauth_buttons.html.heex` - Dynamic OAuth button group
- `priv/templates/sigra.gen.oauth/oauth_settings.html.heex` - Connected Accounts settings page
- `priv/templates/sigra.gen.oauth/oauth_settings_live.ex` - LiveView settings variant
- `priv/templates/sigra.gen.oauth/provider_linked_email.ex` - Provider linked email notification
- `priv/templates/sigra.gen.oauth/provider_unlinked_email.ex` - Provider unlinked email notification
- `priv/templates/sigra.gen.oauth/oauth_test_helpers.ex` - OAuth test helpers
- `test/sigra/install/oauth_generator_test.exs` - 23 tests for generator and injector

## Decisions Made

- OAuth routes use separate `# Sigra OAuth` marker from base install `# Sigra authentication` marker so they can be injected independently
- Vault injection uses regex to find `children = [` in application.ex and inserts the child spec after the bracket
- Provider config generation uses string concatenation instead of heredoc strings to avoid Elixir interpolation issues in the Mix task module
- Generator detects context name from existing sigra config or defaults to "Accounts"

## Deviations from Plan

None -- plan executed exactly as written.

## Threat Mitigations Applied

| Threat ID | Mitigation | Verified |
|-----------|-----------|----------|
| T-05-15 | Controller stores HMAC-signed state in session, clears after callback | Yes - template content verified |
| T-05-16 | Session params use sigra_oauth_* prefix, cleared after processing | Yes - template content verified |
| T-05-17 | Controller uses safe_message/1 for error flashes, generic messages only | Yes - template content verified |
| T-05-18 | UserIdentity uses Encrypted.Binary (AES-256-GCM via cloak_ecto) | Yes - template content verified |
| T-05-19 | Vault raises on missing CLOAK_KEY via System.fetch_env!/1 at startup | Yes - template content verified |
| T-05-20 | Routes follow standard Phoenix scope pattern, no special privileges | Yes - injection tested |

## Self-Check: PASSED

- All 15 files verified present on disk
- Both commits (3ee1c4a, 69c3a25) verified in git log
- All acceptance criteria patterns found in source files
- 23 tests pass with 0 failures
- mix compile --warnings-as-errors succeeds

---
*Phase: 05-oauth-and-social-login*
*Completed: 2026-04-08*
