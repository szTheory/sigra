---
id: SEED-001
status: deferred
planted: 2026-04-11
planted_during: v1.0 milestone completion
trigger_when: Before Sigra v1.0 GA public announcement (tagged v1.0 → blog post / Hex.pm release / HN post)
scope: Medium
---

# SEED-001: Run the remaining 8 human-only UAT items before v1.0 GA public announcement

## Why This Matters

The v1.0 milestone audit (`.planning/milestones/v1.0-MILESTONE-AUDIT.md` after archival, currently at `.planning/v1.0-MILESTONE-AUDIT.md`) identified 19 HUMAN-UAT items that required a real browser / real email client / real OAuth credentials to verify. Phase 10.1.1 closed 7 of them by adding the Playwright golden-path harness and 3 new CI smoke jobs. Another 4 are partially automated.

**Shift-left (2026-04):** Merge-blocking CI + tests now cover **structure and behavior** for most of the eight rows — see **`docs/uat-ci-coverage.md`** (ExUnit HTML contracts, `install_smoke` for `mix sigra.gen.oauth`, OAuth mock/Assent OIDC contracts, Playwright `ga-uat-shift-left.spec.ts`, getting-started doc contract). **Residual human (or Litmus-class) work** is mainly: real consumer mail clients (Gmail/Outlook/Apple), live Google consent UX, subjective clean-machine timing/friction, and proving backup-code **rotation semantics** once `mfa_regenerate_backup_codes` is wired.

**8 items remain** as GA-risk topics; most are **partially machine-closed** per `docs/uat-ci-coverage.md`. A human with a browser is still valuable before a loud public announcement — especially for client-specific email rendering — but the project no longer depends on an all-manual matrix for the same coverage depth.

### The 8 items

**Email visual rendering (phases 04 + 08):**
1. Phase 04: Lockout + suspicious-login email HTML quality — headings, CTA buttons, IP/location block render correctly in Gmail/Outlook/Apple Mail
2. Phase 08: 7 new email templates (email change, password change, account deletion, reactivation, etc.) — copywriting, CTA buttons, security footer per UI-SPEC

**OAuth real-credential flows (phase 05):**
3. `mix sigra.gen.oauth` in a fresh Phoenix 1.8 project — generator produces 12+ files, wires routes/config/vault child
4. End-to-end Google OAuth credential register/login cycle with real Google developer credentials
5. Provider linking + last-method unlink prevention — UI tooltip, disabled state, enable-after-password-set
6. Email-match confirmation flash + redirect flow

**Other human-only items:**
7. Phase 06: Backup code regeneration wiring — the `regenerate_codes` handler has a TODO comment; verify whether phase 10.1 closed it or if it still has a real wiring gap
8. Phase 10: Clean-machine read-through of `guides/introduction/getting-started.md` — a developer unfamiliar with Sigra follows it end-to-end on a fresh Phoenix app in under 30 minutes without tribal knowledge

## When to Surface

**Trigger:** Before Sigra v1.0 GA public announcement — specifically the first of:
- First blog post / Hex.pm package push / HN announcement of v1.0
- First time Sigra is recommended as "use this in production" to an external developer
- Start of a v1.0.1 or v1.1 milestone that promotes the library more broadly

This seed should NOT surface during a pure bug-fix patch milestone (v1.0.1) unless the patch milestone also touches one of the affected subsystems. It SHOULD surface during `/gsd-new-milestone` if the new milestone's scope includes "public release", "GA", "announce", "blog", or "HackerNews".

## Scope Estimate

**Medium** — a full day of manual QA for one person:
- ~2 hours setting up Google OAuth developer credentials (items 3–6)
- ~1 hour running email visual QA across 3 mail clients (items 1, 2)
- ~30 min verifying the backup code regeneration handler in a real MFA flow (item 7)
- ~1 hour clean-machine read-through on a fresh Phoenix app (item 8)
- ~30 min writing results into a `v1.0-GA-UAT-RESULTS.md` file

Each item can be a single-line pass/fail entry. If any fail, that becomes a bug ticket against the next patch milestone, not a blocker on the GA gate itself (unless critical).

## Breadcrumbs

Related code and docs:
- `.planning/v1.0-MILESTONE-AUDIT.md` — full HUMAN-UAT backlog reduction table (19 → 8 still-human-only)
- `.planning/phases/04-session-management-and-security-baseline/04-VERIFICATION.md` — `human_verification:` frontmatter with exact test + expected behavior
- `.planning/phases/05-oauth-and-social-login/05-VERIFICATION.md` — OAuth human-verification items
- `.planning/phases/06-multi-factor-authentication/06-VERIFICATION.md` — MFA and backup-code items
- `.planning/phases/08-account-lifecycle/08-VERIFICATION.md` — settings and email template items
- `.planning/phases/10-developer-experience/10-VERIFICATION.md` — docs + UX items
- `test/example/priv/playwright/tests/golden-path.spec.ts` — what IS automated; use as baseline when deciding what MUST still be human
- `docs/uat-ci-coverage.md` — SEED row → CI job / test mapping and explicit residual policy
- `guides/introduction/getting-started.md` — the doc to read clean-machine-style
- `scripts/uat/RUNBOOK.md` — existing UAT runbook pattern; the GA UAT should follow the same format

## Notes

- The audit verdict was `passed` despite these 8 items remaining, because the remaining risk was primarily **UX-level** (client mail, live IdP chrome) rather than missing automated tests. CI now fakes much of the **same intent** (HTML structure, generator paths, mock OAuth, browser flows); see `docs/uat-ci-coverage.md`.
- When this seed surfaces, the right output is a single one-day task, not a new phase. Capture as `/gsd-add-todo` or a tiny 999.x backlog item; do not over-engineer.
- If item 7 (backup code regeneration) turns out to have a real wiring bug, that IS a bug-fix phase in v1.0.1 — not a UAT item.
- Counterpart seed SEED-002 tracks the phase 9 `log_safe/3` atomicity followup which has a different trigger.
