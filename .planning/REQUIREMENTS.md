# Requirements: Sigra — v1.20 GA Launch (SEED closure + public release)

**Defined:** 2026-04-25
**Milestone:** v1.20 — GA Launch — SEED closure + public release
**Selected seeds:** SEED-001 (human GA UAT), SEED-002 (OAuth audit atomicity remainder)

## v1.20 Requirements

### Leg 1 — SEED-002 OAuth audit atomicity closure (AUD-21)

Closes the C-1 caveat that has hung over Phase 9 since v1.0. After this leg, every `log_safe/3` integration site in `lib/sigra/oauth/*` and the OAuth/ops Phase 45 T2 inventory uses atomic `Repo.transaction/1` + `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` when `:audit_schema` is set, matching the discipline already shipped in `Sigra.MFA`, `Sigra.Account`, and `Sigra.APIToken`.

- [x] **AUD-21-01
** — Convert OAuth/ops `log_safe/3` clusters at **AUD-04 rows 052–056, 058, 063** (per `.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`) to atomic `Repo.transaction/1` + `Ecto.Multi` + `log_multi_safe`. On audit-insert failure: callers see `{:error, _}` and business-op rolls back; on `:audit_schema` unset: behavior preserved (telemetry-on-commit only).
- [x] **AUD-21-02
** — Audit-aware test coverage at `test/sigra/oauth_audit_atomic_test.exs` (or extension of existing OAuth ceremony tests) proves: happy-path co-fate, audit-off parity, fault-injection rollback (CHECK guard) for each new atomic site.
- [x] **AUD-21-03
** — Planning truth refresh: `45-AUD-04-INVENTORY.md` rows 052–056/058/063 marked T1 with phase reference; `09-VERIFICATION.md` C-1 matrix updated; `09-03-SUMMARY.md` post-batch narrative added; `CHANGELOG.md` `[Unreleased]` trace bullet.
- [x] **AUD-21-04
** — Phase 9 **C-1 caveat downgraded from PASS-WITH-CAVEATS to PASS** in `09-VERIFICATION.md` frontmatter (`caveats: []` or removal) and `09-03-SUMMARY.md` summary block, with explicit reference to AUD-21 closure. SEED-002 status flipped to `validated` in `.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md` frontmatter.
- [x] **AUD-21-05
** — Per-phase merge gate (`*-VERIFICATION.md`) in the implementing phase directory; `mix ci.audit_45` still green; library test suite + 5 CI gates remain green on `main`.

### Leg 2 — SEED-001 GA UAT closure (GAUAT)

Closes the 8 GA-risk UAT items listed in `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md`. Each requirement maps to machine-authoritative evidence with recorded outcome and supporting artifacts. No GAUAT row requires a human witness to ship.

- [x] **GAUAT-01** — **Phase 04 lockout + suspicious-login email visual regression (automated)** — Phase 86 ships the `email_visual_regression` CI job rendering both templates (`lockout_notification_email`, `suspicious_login_email`) across {Chromium, WebKit} × {light, dark} via Premailex-inlined HTML + Playwright `toHaveScreenshot`, plus extended ExUnit asserts (computed WCAG contrast, byte budget vs Gmail 102 KB clip, multipart parity, recipient correctness, XSS fuzz, Outlook-Word-engine deny-list, image tripwire) and caniemail.com CSS-feature lint. Eight baselines committed under `test/example/priv/playwright/__snapshots__/email-visual.spec.ts/`. Evidence (README, manifest.json, hero PNGs, contrast-summary.json, byte-budget.csv) under `.planning/uat-evidence/v1.20/email-phase-04/`. Phase-86 CONTEXT.md D-86-09 records the documented residual (legacy Outlook desktop Word engine — EOL Oct 2026; subjective copy tone — handled in PR review; spam-folder placement — adopter deliverability surface). 0 human MUA passes required.
- [x] **GAUAT-02** — **Phase 08 lifecycle email visual regression (automated)** — Same harness covers the 7 lifecycle templates (`email_change_confirmation_email`, `email_change_notification_email`, `email_changed_email`, `password_changed_email`, `deletion_scheduled_email`, `deletion_cancelled_email`, `deletion_finalized_email`); 28 baselines committed; evidence under `.planning/uat-evidence/v1.20/email-phase-08/`. Same residual policy as GAUAT-01. 0 human MUA passes required.
- [ ] **GAUAT-03** — **`mix sigra.gen.oauth` fresh-host smoke (automated)** — Extended `scripts/ci/install-smoke.sh` runs on every PR: `mix phx.new` + `sigra.install` + `sigra.gen.oauth --providers google,github` + `mix compile --warnings-as-errors` + `MIX_ENV=test mix test`, emitting `oauth-gen: 12/12 expected artifacts present, mix test green`. Transcript tee'd to `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` (CI artifact + GitHub release asset on `v*` tags). Reshaped from human terminal-transcript capture per Phase 87 D-87-04 (precedent: Phase 86 D-86-08).
- [ ] **GAUAT-04** — **End-to-end OAuth register/login cycle (automated)** — Playwright spec `oauth-register.spec.ts` drives Sigra's example app against the in-process `Sigra.Testing.OAuthIssuer` (TestServer-backed, RS256 ID tokens, real PKCE — mirrors Assent's own `OIDCTestCase` precedent). Cells: provider button → 302 to /authorize with state nonce → mock auto-consent → callback → user + identity row + session cookie → logout → re-login (same user, no new identity row). Evidence: pass/fail manifest + Playwright trace under `.planning/uat-evidence/v1.20/oauth-google/`. Adopter-side real-credential check ships separately as `mix sigra.oauth.smoketest --provider=google` per Phase 87 D-87-03. Reshaped from human screen-recording capture per Phase 87 D-87-01 (0 human UAT — matches Auth.js / Spring Security / Assent / pow_assent / Devise+omniauth ecosystem convention).
- [ ] **GAUAT-05** — **Provider linking + last-method unlink prevention (automated)** — Playwright spec `oauth-link.spec.ts` covers four visual states: (1) linked-with-password (unlink enabled), (2) only-oauth-no-password (unlink disabled, tooltip matches verbatim source from `oauth_settings_live.ex:92`), (3) after-set-password (button re-enabled), (4) post-unlink (`user_identities` row absent, password login still works). Evidence: 4-row manifest + one hero PNG of the disabled-tooltip state under `.planning/uat-evidence/v1.20/oauth-link/`. Reshaped from human four-state screenshot capture per Phase 87 D-87-05.
- [ ] **GAUAT-06** — **Email-match confirmation flash + redirect (automated)** — Playwright spec `oauth-email-match.spec.ts` covers: pre-seeded user with password → mock issuer returns matching email + novel sub → flash text matches verbatim source from `oauth_controller.ex:96` → redirect to login → password login → identity row created → `provider_linked_email` arrival in `/dev/mailbox/json`. Evidence: 4-row manifest + flash-text + DB-probe + mailbox JSON under `.planning/uat-evidence/v1.20/oauth-email-match/`. Reshaped from human screenshot capture per Phase 87 D-87-05.
- [x] **GAUAT-07
** — **Backup-code regeneration E2E proof (automated)** — `mfa-backup-rotation.spec.ts` drives the real MFA settings flow in the example app (register/confirm/login → sudo → enroll MFA → capture pre-rotation backup code → regenerate via fresh TOTP) and proves both user-visible and persisted outcomes: new backup codes shown once, old plaintext no longer matches any current code, and `mfa.backup_codes_regenerate` audit persistence. Evidence under `.planning/uat-evidence/v1.20/mfa-backup-rotation/`; CI gate is `.github/workflows/ci.yml / mfa_e2e_playwright`. 0 human UAT required.
- [x] **GAUAT-08
** — **Generated-host getting-started proof (automated)** — `scripts/ci/install-smoke.sh` runs the real getting-started path on a disposable Phoenix 1.8 host (`mix phx.new` → Sigra install → compile/migrate → generated-host auth lifecycle test → boot the app and hit the documented routes) and emits machine-readable environment, transcript, and lifecycle evidence under `.planning/uat-evidence/v1.20/getting-started-clean-machine/`. Subjective first-read timing/friction is explicitly non-gating. 0 human UAT required.
- [x] **GAUAT-09** — **Results filing + seed closure** — `.planning/v1.20-GA-UAT-RESULTS.md` is written with one explicit row per GAUAT-01..08, links to the machine evidence directories under `.planning/uat-evidence/v1.20/`, and a final go/no-go disposition for the launch leg. SEED-001 moves to `validated` when those rows have release-authoritative evidence on the launch SHA/tag; no human-only exception path remains for GAUAT-07
 or GAUAT-08.

### Leg 3 — Public launch execution (LAUNCH)

Executes the v1.5 `MAINT-01` First Public Launch checklist for the first time. Sequenced *after* legs 1 and 2 close so the launch is defensible. Failures here roll back narrowly (delete announcement, mark Hex release as broken) without invalidating legs 1 and 2.

- [x] **LAUNCH-01
** — **Hex.pm publish v1.20** — Bump `mix.exs` version to `1.20.0`; tag `v1.20` annotated; `mix hex.publish` (with reviewable diff against the prior published version, if any); verify package shows on hex.pm with correct description, links, optional-deps, and ExDoc. Record release URL. (If this is Sigra's first-ever Hex publish, also covers `mix hex.user auth` setup if not already configured.)
- [x] **LAUNCH-02
** — **README "use this in production" promotion** — Update README from "production readiness available" framing to an explicit "Use this in production" section with: link to v1.20 GA evidence, link to Phase 9 C-1 PASS attestation (post-AUD-21), getting-started link, version-pin guidance. ExDoc landing path mirrors the change.
- [x] **LAUNCH-03** — **Announcement post drafted + published** — *(Waived: User focus is purely on library quality, not publicity. Discussed in Phase 90.)*
- [x] **LAUNCH-04** — **Hacker News submission** — *(Waived: User focus is purely on library quality. Discussed in Phase 90.)*
- [x] **LAUNCH-05** — **Elixir community soft-launch** — *(Waived: User focus is purely on library quality. Discussed in Phase 90.)*
- [x] **LAUNCH-06** — **MAINTAINING.md post-launch monitoring lane** — *(Waived: User focus is purely on library quality, skipped in Phase 90.)*
- [x] **LAUNCH-07
** — **CHANGELOG + ExDoc final alignment** — `CHANGELOG.md` v1.20.0 section finalized: covers AUD-21 (audit completeness PASS), GAUAT closure pointer, launch metadata, upgrade notes (none expected — pure additive). ExDoc extras include `upgrading-to-v1.20.md` (or "no upgrade required" stub if changeset is purely additive); `mix docs --warnings-as-errors` clean.

## Future requirements

- **Week-one launch-feedback follow-ups** — sized as a v1.21 patch milestone if signal warrants. Not pre-scoped.
- **Phase 45 T2 stragglers** beyond 052–056/058/063, if any surface during AUD-21 inventory walk — captured as `EX-45-*` with reopen triggers, deferred to a later milestone.
- **`sigra_lockspire` glue package per ADR 001** — still awaiting companion-app trigger; explicitly out of scope for v1.20.
- **30d post-launch retrospective** — formal retrospective on launch-week outcomes, distinct from the LAUNCH-06 monitoring checkpoints. Triggered automatically at the 30d mark.

## Out of scope

- **Reopening 999.x archaeology** — assurance work uses newly numbered phases.
- **Re-auditing Phase 45 merge gate (`mix ci.audit_45`) beyond regression needed for AUD-21 edits.**
- **Responding to launch feedback during the v1.20 milestone window** — captured in LAUNCH-06 monitoring lane and routed to a follow-up milestone.
- **`sigra_lockspire` / ADR 001** — deferred until a real companion-app trigger fires.
- **Marketing site / standalone landing page** — README + announcement post cover positioning. A dedicated marketing site is a later concern.
- **Paid promotion / sponsorships** — organic only for first launch.

## Traceability

| REQ-ID    | Phase |
|-----------|-------|
| AUD-21-01 | 85    |
| AUD-21-02 | 85    |
| AUD-21-03 | 85    |
| AUD-21-04 | 85    |
| AUD-21-05 | 85    |
| GAUAT-01  | 86    |
| GAUAT-02  | 86    |
| GAUAT-03  | 87    |
| GAUAT-04  | 87    |
| GAUAT-05  | 87    |
| GAUAT-06  | 87    |
| GAUAT-07  | 88    |
| GAUAT-08  | 88    |
| GAUAT-09  | 88    |
| LAUNCH-01 | 89    |
| LAUNCH-02 | 89    |
| LAUNCH-03 | 90    |
| LAUNCH-04 | 90    |
| LAUNCH-05 | 90    |
| LAUNCH-06 | 90    |
| LAUNCH-07 | 89    |

_(Phase column populated by gsd-roadmapper, 2026-04-25. 21/21 requirements mapped to exactly one phase across Phases 85–90.)_
