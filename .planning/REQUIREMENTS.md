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

### Leg 2 — SEED-001 human UAT execution (GAUAT)

Executes the 8 GA-risk UAT items listed in `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md`. Each requirement maps to one observable human verification with recorded outcome (pass / fail-with-issue) and supporting evidence.

- [ ] **GAUAT-01** — **Phase 04 lockout + suspicious-login email visual QA** — Render both templates in Gmail (web), Outlook (web), Apple Mail (macOS). Verify: heading hierarchy, CTA button contrast, IP/location block layout. Capture screenshots → `.planning/uat-evidence/v1.20/email-phase-04/`. File pass/fail row with notes.
- [ ] **GAUAT-02** — **Phase 08 lifecycle email visual QA** — Render the 7 lifecycle templates (email change, email change confirmation, password change, account deletion, reactivation, etc.) in Gmail / Outlook / Apple Mail. Verify per UI-SPEC: copywriting accuracy, CTA buttons, security footer. Capture screenshots → `.planning/uat-evidence/v1.20/email-phase-08/`. File one row per template.
- [ ] **GAUAT-03** — **`mix sigra.gen.oauth` fresh-host smoke** — On a freshly-generated Phoenix 1.8 app, run `mix sigra.gen.oauth`. Verify: 12+ files emitted, routes/config/vault child wired, `mix compile --warnings-as-errors` clean, `mix test` green for generated host. Record terminal transcript → `.planning/uat-evidence/v1.20/oauth-gen/`.
- [ ] **GAUAT-04** — **End-to-end Google OAuth register/login cycle** — With real Google developer credentials configured, complete: provider button → consent → callback → user record created → session established → logout → re-login via same provider. Capture screen recording or staged screenshots → `.planning/uat-evidence/v1.20/oauth-google/`. File pass/fail row with timing.
- [ ] **GAUAT-05** — **Provider linking + last-method unlink prevention** — Existing user adds Google OAuth; UI shows linked state; attempt to unlink last auth method shows tooltip + disabled state; enable-after-password-set unblocks unlink. Evidence: screenshots of all four states.
- [ ] **GAUAT-06** — **Email-match confirmation flash + redirect flow** — Sign in via Google with an email that matches an existing user; flash message displays correctly; redirect lands at expected post-login destination; `user_identities` row created. Evidence: screenshots + DB row check transcript.
- [ ] **GAUAT-07** — **Backup-code regeneration human verification** — On a real MFASettingsLive in the example app, exercise `regenerate_backup_codes` end-to-end (sudo prompt → TOTP → new codes shown once → old codes invalidated → audit row visible). Verify v1.4 GA-01 wiring matches user-visible behavior. Evidence: screenshots + audit-row check.
- [ ] **GAUAT-08** — **Clean-machine getting-started timed run** — A developer unfamiliar with Sigra follows `guides/introduction/getting-started.md` end-to-end on a fresh Phoenix 1.8 app, target <30 minutes wall-clock, with no tribal-knowledge assists. Record start/end timestamps and friction notes (any place the guide stalls). Evidence: timestamped transcript + friction-list note.
- [ ] **GAUAT-09** — **Results filing + seed closure** — `.planning/v1.20-GA-UAT-RESULTS.md` written with one pass/fail/blocked row per GAUAT-01..08, links to evidence directories under `.planning/uat-evidence/v1.20/`, and a final go/no-go disposition for the launch leg. SEED-001 status flipped to `validated` (or `partially-validated` with reopen trigger if any item failed) in `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` frontmatter.

### Leg 3 — Public launch execution (LAUNCH)

Executes the v1.5 `MAINT-01` First Public Launch checklist for the first time. Sequenced *after* legs 1 and 2 close so the launch is defensible. Failures here roll back narrowly (delete announcement, mark Hex release as broken) without invalidating legs 1 and 2.

- [ ] **LAUNCH-01** — **Hex.pm publish v1.20** — Bump `mix.exs` version to `1.20.0`; tag `v1.20` annotated; `mix hex.publish` (with reviewable diff against the prior published version, if any); verify package shows on hex.pm with correct description, links, optional-deps, and ExDoc. Record release URL. (If this is Sigra's first-ever Hex publish, also covers `mix hex.user auth` setup if not already configured.)
- [ ] **LAUNCH-02** — **README "use this in production" promotion** — Update README from "production readiness available" framing to an explicit "Use this in production" section with: link to v1.20 GA evidence, link to Phase 9 C-1 PASS attestation (post-AUD-21), getting-started link, version-pin guidance. ExDoc landing path mirrors the change.
- [ ] **LAUNCH-03** — **Announcement post drafted + published** — Long-form post covering: (a) what Sigra is and why it exists, (b) positioning vs Pow / phx.gen.auth (without disparaging Pow — credit the prior art), (c) hybrid lib+generator architecture rationale, (d) what shipped v1.0–v1.20, (e) getting-started call-to-action, (f) where to file issues / contribute. Self-hosted blog or dev.to / Medium acceptable. Record canonical URL.
- [ ] **LAUNCH-04** — **Hacker News submission** — Submit announcement post to HN with title that reads honestly (no clickbait, no false-claim "production-ready" if anything material is open). Stay reachable in the comments for 4–8 hours after submission. Record: submission URL, peak score, top 3 comments + responses, and any issues filed against Sigra as a result.
- [ ] **LAUNCH-05** — **Elixir community soft-launch** — Post to: elixir-lang Discord (or active Elixir community Discord), elixirforum.com, and one of {Twitter/X, Bluesky, Mastodon}. Brief, link-driven posts pointing at the announcement. Record post URLs.
- [ ] **LAUNCH-06** — **MAINTAINING.md post-launch monitoring lane** — Add a `Post-launch monitoring (v1.20)` section to `MAINTAINING.md` with concrete checkpoints at 24h / 7d / 30d. Each checkpoint enumerates: open issues count, Hex downloads, GitHub star delta, time-to-first-response on issues, and a triage SLA (e.g. acknowledge within 24h, resolve sev-1 within 72h). Initial 24h checkpoint filled in as part of this requirement; 7d and 30d remain pending with documented owner.
- [ ] **LAUNCH-07** — **CHANGELOG + ExDoc final alignment** — `CHANGELOG.md` v1.20.0 section finalized: covers AUD-21 (audit completeness PASS), GAUAT closure pointer, launch metadata, upgrade notes (none expected — pure additive). ExDoc extras include `upgrading-to-v1.20.md` (or "no upgrade required" stub if changeset is purely additive); `mix docs --warnings-as-errors` clean.

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
