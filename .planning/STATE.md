---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed 10.1.1-07-PLAN.md
last_updated: "2026-04-11T17:07:06.554Z"
last_activity: 2026-04-11
progress:
  total_phases: 12
  completed_phases: 12
  total_plans: 60
  completed_plans: 60
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-05)

**Core value:** Authentication that works out of the box with great DX — so developers can ship SaaS apps fast and grow with confidence.
**Current focus:** Phase 10.1.1 — example-app-repair-ci-install-usage-smoke-harness

## Current Position

Phase: 10.1.1
Plan: Not started
Status: Ready to execute
Last activity: 2026-04-11

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 54
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 3 | - | - |
| 02 | 2 | - | - |
| 03 | 6 | - | - |
| 04 | 6 | - | - |
| 05 | 3 | - | - |
| 06 | 5 | - | - |
| 07 | 4 | - | - |
| 08 | 5 | - | - |
| 09 | 5 | - | - |
| 10.1 | 7 | - | - |
| 10.1.1 | 8 | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
| Phase 10.1.1 P01 | 10min | 3 tasks | 3 files |
| Phase 10.1.1 P02 | 12min | 2 tasks | 6 files |
| Phase 10.1.1 P03 | 17min | 2 tasks | 7 files |
| Phase 10.1.1 P04 | 15min | 2 tasks | 7 files |
| Phase 10.1.1 P05 | 8min | 3 tasks | 17 files |
| Phase 10.1.1 P06 | 3min | 3 tasks | 4 files |
| Phase 10.1.1 P07 | 11min | 3 tasks | 9 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Foundation: Hybrid lib+generator boundary — security-critical code in library dep, customizable UX in generated code
- Foundation: No macro-based schema injection — generated schemas are plain Ecto calling library functions
- Foundation: Opaque database-backed tokens for sessions — no JWT for browser auth
- Foundation: Ecto-only data layer — no adapter abstraction
- Foundation: Behaviours + callbacks at every extensibility point — no macros
- [Phase 10.1.1]: Restored ex_doc default formatters ['html','markdown'] in docs/0 rather than deleting the override — intent stays documented at the call site
- [Phase 10.1.1]: UAT runbook brew Postgres restore command duplicated in prerequisite AND teardown sections — end-of-session operators are unlikely to scroll back
- [Phase 10.1.1]: Phase 10.1.1: Used existing host-app helper deliver_user_confirmation_instructions/2 instead of non-existent Sigra.Auth.request_confirmation/2 that RESEARCH.md referenced
- [Phase 10.1.1]: B6: picked Sigra.SessionStores.Ecto as single source of truth; legacy user_tokens context='session' path deleted from both example and installer template
- [Phase 10.1.1]: Plan snippet bug fixed inline: Base.url_decode64 required before Sigra.Token.hash_token — raw session token is Base64url-encoded, stored hash is SHA-256 of raw bytes
- [Phase 10.1.1]: B9/D-12: login page is a plain controller in BOTH --live and --no-live modes; LiveView's <.form> registers phx-submit and swallows browser submits
- [Phase 10.1.1]: Plan 10.1.1-05: B8 root cause was two-layered — type mismatch AND audit_schema not wired; fixed both in example_app and installer template (Rule 2)
- [Phase 10.1.1]: Plan 10.1.1-05: D-10 installer default flipped to binary_id: true via Keyword.get(opts, :binary_id, true); sigra.gen.oauth aligned; D-11 respected — no --primary-key flag added
- [Phase 10.1.1]: Plan 10.1.1-06: --yes on mix sigra.install is a no-op placeholder (grep confirmed no interactive surface) — accepted by OptionParser and discarded, documented in @moduledoc
- [Phase 10.1.1]: Plan 10.1.1-06: install_smoke + example_http_smoke run parallel (no needs:) to keep PR wall clock at max(jobs) rather than sum; http-smoke gates on 5xx only so 302-to-login is success
- [Phase 10.1.1]: Plan 10.1.1-07: Playwright Test chosen for browser smoke (frameLocator iframe support for Swoosh mailbox); otplib TOTP defaults align with NimbleTOTP defaults — no config drift
- [Phase 10.1.1]: Plan 10.1.1-07: SHA-pinned actions/setup-node v4.0.4 + actions/upload-artifact v4.4.3 on introduction; D-15 honored — retries live in playwright.config.ts, never at the Actions layer

### Roadmap Evolution

- Phase 10.1 inserted after Phase 10: Installer and library fixes — deferred items from phase 10 review/security/validation (URGENT)
- Phase 10.1.1 inserted after Phase 10.1: example-app repair + CI install/usage smoke harness — 9 DX bugs found during v1.0 UAT session, see .planning/v1.0-UAT-RESULTS.md (URGENT, v1.0 blocker)

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 4 (MFA): Session state machine for `mfa_pending` → `mfa_complete` is complex — draw out state diagram before coding (flagged in research)
- Phase 3 (OAuth): Account linking confirmation flow has security implications — review PITFALLS.md section 7 before implementation
- Phase 1: Multi-database migration generation for MySQL/SQLite — map DDL differences (citext, etc.) before generator is built

## Session Continuity

Last session: 2026-04-11T01:41:47.939Z
Stopped at: Completed 10.1.1-07-PLAN.md
Resume file: None
