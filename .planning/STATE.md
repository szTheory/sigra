---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Foundations
status: executing
stopped_at: Completed 22-01-PLAN.md
last_updated: "2026-04-16T12:49:50.319Z"
last_activity: 2026-04-16
progress:
  total_phases: 17
  completed_phases: 13
  total_plans: 67
  completed_plans: 64
  percent: 96
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-11 — v1.1 Foundations milestone)

**Core value:** Authentication that works out of the box with great DX — so developers can ship SaaS apps fast and grow with confidence.
**Current focus:** Phase 22 — passkeys-generator-wiring

## Current Position

Phase: 22 (passkeys-generator-wiring) — EXECUTING
Plan: 2 of 4
Status: Ready to execute
Last activity: 2026-04-16

Progress: [████████░░] 85% (11/13 mainline phases complete)

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v1.1 scope split decided 2026-04-11: Organizations + Passkeys in v1.1 "Foundations"; Admin UI + Impersonation + expanded Audit views deferred to v1.2 "Admin Dashboard". Reason: orgs is architecturally foundational and retrofitting it into an admin UI later would be painful. Rationale captured in `/Users/jon/.claude/plans/breezy-beaming-beacon.md`.
- v1.1 Organizations: logical multi-tenancy only — single DB, single PG schema, `org_id` FK pattern. No PG-schema-per-tenant or DB-per-tenant modes. Document extension point for host apps that need physical isolation.
- v1.1 Organizations: 3-enum role convention (`owner` / `admin` / `member`). Full RBAC / permission policies remain out of Sigra's scope per PROJECT.md Key Decisions.
- v1.1 will introduce the first conditional generator template pattern (via `--organizations` / `--passkeys` flags). This pattern is load-bearing for v1.2's `--admin` / `--no-admin` and must be designed carefully — **locked into Phase 11 as foundation**.
- v1.2 full direction earmarked in `.planning/v1.2-DIRECTION.md` (dormant). Reconfirm with user at v1.2 kick-off time; do not execute against it directly.
- Roadmap numbering: v1.1 phases start at 11 (continuing from v1.0 phase 10.1.1). 999.x backlog phases retained in place.
- Phase order respects the ARCHITECTURE.md Part D dependency graph: phase 11 + 12 are strict foundation; phases 13–18 (org track) and 19–21 (passkey track) run in parallel after foundation lands; phases 18 and 22 are serialization points; phase 23 gates the release.
- Every v1.2 load-bearing decision is embedded in the phase that ships it: reserved `:impersonating_from` field (phase 12), real `effective_user_id` audit column (phase 15), subdir feature manifest (phase 11), `admin` in reserved slug list (phase 13), nilify-on-delete FK (phase 13), `Sigra.Workers` behaviour (phase 15), passkey enrollment sudo gate (phase 21).
- [Phase 20]: Passkey challenges are signed into ceremony-specific Plug session slots and reconstructed from the signed payload during verification.
- [Phase 20]: Passkey challenge session slots are deleted only on callback success; callback and token failures preserve the slot.
- [Phase 20]: Sigra.Passkeys.config/0 now caches validated runtime passkey config in :persistent_term and exposes reset_cached_config/0 for tests.
- [Phase 20]: Passkey runtime config now fails fast on blank rp_id/origin and enforces timeout_ms bounds before any ceremony code runs.
- [Phase 20]: Per-user passkey ceremony throttling uses the fixed sigra:passkeys:<ceremony>:user:<id> namespace with a stable rate-limited error contract.
- [Phase 20]: Use // Sigra passkeys:start as the authoritative app.js idempotency gate and only mutate the standard colocated-hooks LiveSocket shape.
- [Phase 20]: Surface custom app.js fallback through installer manual-action reporting so stdout shows exact import and hook merge lines.
- [Phase 20]: PK-06 tamper coverage now flips a byte in the stored signed passkey challenge token and asserts the callback boundary is never reached.
- [Phase 20]: Sigra.Plug.PasskeyChallenge.verify/5 now isolates signed-token verification before challenge reconstruction so invalid tokens exit unambiguously before callback execution.
- [Phase 20]: Left installer fixtures unchanged because the default focused Phase 20 verifier subset passes once the timeout contract is explicit.
- [Phase 20]: Scoped the slow passkeys JS installer coverage to a module-level timeout instead of widening repo-wide ExUnit defaults.
- [Phase 20]: Browser WebAuthn hook verification is now automated with a Chromium Playwright spec using a virtual authenticator against the shipped generated templates.
- [Phase 20]: Manual fallback verification is now automated with a fresh Phoenix app smoke harness that applies the printed `app.js` instructions, builds assets, and boots successfully.
- [Phase 21]: Passkey login, MFA upgrade, enrollment completion, and delete completion finalize through plain SessionController POST actions, not LiveView events.
- [Phase 21]: Discoverable passkey login resolves the owning UserPasskey row by credential_id before reusing the known-user Sigra.Passkeys.authenticate/4 path.
- [Phase 21]: Passkey management mutation routes are injected only under the generated :require_sudo router pipeline.
- [Phase 21]: Passkey deletion is not a LiveView event and posts to the sudo-protected controller route with CSRF.
- [Phase 21]: Passkey enrollment and management live on /users/settings/mfa rather than a dedicated passkey page.
- [Phase 21]: Passkey registration success in the LiveView is recovery-only; credential completion remains controller-owned.
- [Phase 21]: MFA challenge users with passkeys now see an explicit Continue with passkey CTA before authenticator-code and backup-code fallbacks.
- [Phase 21]: Passkey success in the MFA LiveView submits passkey[response] JSON to /users/mfa/passkey instead of verifying credentials in LiveView.
- [Phase 21]: Browser passkey errors are mapped into recovery buckets and raw browser exception names are not rendered.
- [Phase 21]: Passkey-primary login remains one controller-rendered page with visible password and magic-link recovery. — Plan 21-04 implementation decision from SUMMARY.md key-decisions.
- [Phase 21]: Signup-time passkey enrollment starts only after email confirmation, then routes through sudo before /users/settings/mfa#passkeys. — Plan 21-04 implementation decision from SUMMARY.md key-decisions.
- [Phase 21]: Generated Auth owns the passkey-primary confirmed-email and magic-link recovery invariants. — Plan 21-04 implementation decision from SUMMARY.md key-decisions.
- [Phase 21]: Conditional UI is a progressive enhancement: unsupported browsers retain explicit passkey click, password, and magic-link recovery. — Plan 21-07 preserved recovery-first login posture while adding browser autofill support.
- [Phase 21]: Controller-rendered passkey-primary login uses attachPasskeyLogin({ enableConditionalUI: true }) on DOMContentLoaded instead of relying on LiveView hooks. — Controller pages have no LiveView process, so the generated static app.js binding owns passkey-primary page startup.
- [Phase 21]: Passkey hook success can POST passkey[response] to controller completion URLs, preserving the controller-owned session mutation boundary. — LiveView hooks still own recoverable browser ceremony state, but session creation remains a plain controller POST.
- [Phase 21-passkey-liveviews-post-auth-controller]: Example.Accounts passkey registration and authentication delegate through Application.get_env(:example, :passkey_ceremony_module, Sigra.Passkeys) so Plan 21-06 can stub WebAuthn ceremonies without hardware.
- [Phase 21-passkey-liveviews-post-auth-controller]: Example UI keeps passkey endpoint strings as literal paths because router route injection is outside Plan 21-05's owned file set.
- [Phase 21-passkey-liveviews-post-auth-controller]: Kept router/config/schema fixes outside plan 21-06 because ownership was limited to test and fixture files.
- [Phase 21-passkey-liveviews-post-auth-controller]: Used fixture-local passkey persistence bootstrap so tests can exercise passkey rows without editing migrations or generated schemas.
- [Phase 21-passkey-liveviews-post-auth-controller]: Made the Playwright smoke fall back to static controller markup when the example server is not already running.
- [Phase 21-passkey-liveviews-post-auth-controller]: passkey_primary_enabled is a Sigra.Config passkeys option with a false default; host apps opt into passkey-primary separately from general passkey support.
- [Phase 21-passkey-liveviews-post-auth-controller]: Example enrollment and delete routes are sudo-gated, while primary-login and MFA passkey routes remain reachable without sudo.
- [Phase 21-passkey-liveviews-post-auth-controller]: Example passkey runtime config is present in both config.exs and Example.Accounts.sigra_config/0 so controller and context paths share the same concrete schema and RP settings.
- [Phase 21-passkey-liveviews-post-auth-controller]: Passkey fixture persistence now depends on the concrete Example.Accounts.UserPasskey schema and migrated user_passkeys table.
- [Phase 21-passkey-liveviews-post-auth-controller]: Route completion tests seed signed Plug-session challenges with explicit bytes because current option routes produce nil challenge bytes outside plan 21-09 ownership.
- [Phase 21-passkey-liveviews-post-auth-controller]: MFA success mutation is proven at the controller boundary because the current Ecto session store maps persisted mfa_pending rows back to :standard before the route action.
- [Phase 21-passkey-liveviews-post-auth-controller]: Passkey challenge byte fallback lives in the registration and authentication builders so Plug session signing never receives nil challenge bytes.
- [Phase 21-passkey-liveviews-post-auth-controller]: Session type hydration explicitly whitelists mfa_pending while keeping unknown persisted strings mapped to :standard.
- [Phase 21]: Route-level ExUnit tests are the authoritative proof for passkey challenge JSON shape because the dev Playwright server lacks Sigra secret_key_base for challenge-producing paths.
- [Phase 21]: Playwright keeps only a hardware-avoidance SigraPasskeys.authenticate shim and no longer intercepts or fulfills the passkey options route.
- [Phase 22]: Passkeys default to true in the installer and bind through passkeys? as the single source of truth for later generator gating.
- [Phase 22]: Install summary text now reports passkeys as enabled by default or explicitly disabled via --no-passkeys from the parsed CLI flag state.
- [Phase 22]: Passkey coverage stays anchored at the feature manifest boundary without adding runner-specific logic.

### Pending Todos

- Run `/gsd-discuss-phase 17` first to lock decisions for Phase 17 (Invitation Flow + Email) — token storage shape, HMAC bind format, rate-limit budget, plug split vs reuse — then `/gsd-plan-phase 17`. Phase 16 baked in the seam: `<section id="pending-invitations-section">` and the disabled "Invite member" button are intentional extension points; Phase 17 should mirror Plan 05's event-handler naming and Plan 04's error-remap helper shape (per VERIFICATION.md recommendation).
- Phase 16 follow-up (do NOT block Phase 17): library slug-alias migration template uses `now()` in a Postgres partial-unique index predicate — Postgres rejects non-IMMUTABLE functions in index predicates. Plan 06 worked around it in the example app with a plain unique index on `old_slug`, but the library template still ships the partial-index form and may hit the same error on real hosts. Fix in a small dedicated phase or fold into Phase 17 prep.
- Run `/gsd-plan-phase 11` to begin decomposing Phase 11 (Generator Feature System).
- Before Phase 11 planning: spike the subdir pattern against `phx.gen.auth` 1.8.5 renderer (SUMMARY.md research flag).
- Plan Phase 21 next: passkey enrollment/authentication LiveViews, POST auth controller, sudo gate, duplicate detection, and generated host-app UI wiring. Context is captured in `.planning/phases/21-passkey-liveviews-post-auth-controller/21-CONTEXT.md`.

### Roadmap Evolution

- Phase 24 added: Repair Phase 16/17 organizations generator templates (addresses DEF-18-01 and DEF-18-02 — pre-existing Phase 16/17 org template bugs surfaced when Phase 18 Wave 1 registered `Features.Organizations`). This is outside the main 11-23 v1.1 sequence and can be prioritized separately.
- Phase 25 added: Fix Sigra.Upgrade duplicate-migration-version bug + restore upgrade integration tests (surfaced by PR #9 module-shadow archaeology; Bug A = test-helper parser, Bug B = real product bug in `Sigra.Upgrade` migration-timestamp generator). This is outside the main 11-23 v1.1 sequence and can be prioritized separately.

### Blockers/Concerns

- Conditional template generator pattern design must be right the first time — v1.2 depends on it. Lock pattern in Phase 11 before phases 12+ build on top.
- `test/upgrade_test.exs` fixture (phase 18) is a hard deliverable before the release gate in phase 23 — do not let it slip.
- Phase 21 should build strictly on the locked Phase 20 seam: `Sigra.Plug.PasskeyChallenge`, generated `passkey_browser.js` / `passkey_hooks.js`, and the explicit hook event contract.

## Session Continuity

Last session: 2026-04-16T12:49:50.316Z
Stopped at: Completed 22-01-PLAN.md
Resume file: None
