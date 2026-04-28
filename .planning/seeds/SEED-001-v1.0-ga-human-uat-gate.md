---
id: SEED-001
status: deferred
planted: 2026-04-11
planted_during: v1.0 milestone completion
trigger_when: Before Sigra v1.0 GA public announcement (tagged v1.0 → blog post / Hex.pm release / HN post)
scope: Medium
---

# SEED-001: Close the remaining 8 GA-risk UAT items before v1.0 GA public announcement

## Why This Matters

The v1.0 milestone audit (`.planning/milestones/v1.0-MILESTONE-AUDIT.md` after archival, currently at `.planning/v1.0-MILESTONE-AUDIT.md`) identified 19 HUMAN-UAT items that originally depended on a real browser, real email client, or live provider credentials. Phase 10.1.1 closed 7 of them with the first Playwright/CI harnesses. Phases 86-88 finish the shift-left work.

**Shift-left (2026-04-28):** All eight rows now have merge-blocking machine substitutes — see **`docs/uat-ci-coverage.md`**. The release gate is CI evidence, not a one-off manual witness run. Residual spot checks remain optional only when they measure something CI cannot own honestly, such as subjective copy tone or a third-party provider's live consent chrome.

**8 items remain** as GA-risk topics, but they are now **machine-closed** in the v1.20 launch posture. This seed exists to ensure the evidence surfaces and launch claims stay honest, not to force a manual ceremony after equivalent or stronger CI coverage already exists.

*Update 2026-04-28 (Phase 88):* All eight rows have evidence bundles under `.planning/uat-evidence/v1.20/`. However, `GAUAT-03..06` currently lack a remote GitHub Actions `ci_run_url`. Thus, this seed remains `deferred` (unvalidated) until Phase 87 provenance is closed or an explicit maintainer exception is filed.

### The 8 items

**Email visual rendering (phases 04 + 08):**
1. Phase 04: Lockout + suspicious-login email HTML quality — headings, CTA buttons, IP/location block render correctly in Gmail/Outlook/Apple Mail
2. Phase 08: 7 new email templates (email change, password change, account deletion, reactivation, etc.) — copywriting, CTA buttons, security footer per UI-SPEC

**OAuth flows (phase 05):**
3. `mix sigra.gen.oauth` in a fresh Phoenix 1.8 project — generator produces 12+ files, wires routes/config/vault child
4. End-to-end OAuth register/login cycle against a CI-owned issuer that mirrors the OIDC contract Sigra actually consumes
5. Provider linking + last-method unlink prevention — UI tooltip, disabled state, enable-after-password-set
6. Email-match confirmation flash + redirect flow

**Other GA-risk items:**
7. Phase 06: Backup code regeneration semantics — prove `regenerate_codes` end-to-end in the real MFA settings surface, including old-code invalidation and audit persistence
8. Phase 10: Getting-started guide works on a disposable Phoenix host via the documented install/runtime path

## When to Surface

**Trigger:** Before Sigra v1.0 GA public announcement — specifically the first of:
- First blog post / Hex.pm package push / HN announcement of v1.0
- First time Sigra is recommended as "use this in production" to an external developer
- Start of a v1.0.1 or v1.1 milestone that promotes the library more broadly

This seed should NOT surface during a pure bug-fix patch milestone (v1.0.1) unless the patch milestone also touches one of the affected subsystems. It SHOULD surface during `/gsd-new-milestone` if the new milestone's scope includes "public release", "GA", "announce", "blog", or "HackerNews". When it surfaces, the expected closure path is machine evidence plus honest residual-policy docs, not a manual witness bundle unless the requirement truly cannot be automated.

## Scope Estimate

**Small to medium** — mostly automation and evidence-maintenance work:
- keep the CI substitutes green and reproducible
- file the consolidated GAUAT results against the exact release SHA/tag
- record residuals honestly where CI is intentionally not the authority

If any row fails, that becomes a bug or a blocked launch condition depending on severity; it is no longer "covered" by planning a future manual pass.

## Breadcrumbs

Related code and docs:
- `.planning/v1.0-MILESTONE-AUDIT.md` — original HUMAN-UAT backlog reduction table that seeded this follow-up
- `.planning/phases/04-session-management-and-security-baseline/04-VERIFICATION.md` — `human_verification:` frontmatter with exact test + expected behavior
- `.planning/phases/05-oauth-and-social-login/05-VERIFICATION.md` — OAuth human-verification items
- `.planning/phases/06-multi-factor-authentication/06-VERIFICATION.md` — MFA and backup-code items
- `.planning/phases/08-account-lifecycle/08-VERIFICATION.md` — settings and email template items
- `.planning/phases/10-developer-experience/10-VERIFICATION.md` — docs + UX items
- `test/example/priv/playwright/tests/golden-path.spec.ts` — what IS automated; use as baseline when deciding what MUST still be human
- `docs/uat-ci-coverage.md` — SEED row → CI job / test mapping and explicit residual policy
- `guides/introduction/getting-started.md` — the guide exercised by the generated-host install/runtime lane
- `scripts/uat/RUNBOOK.md` — existing UAT runbook pattern; the GA UAT should follow the same format

## Notes

- The audit verdict was `passed` despite these 8 items remaining because the risk was primarily **UX-level** and evidence-shape, not missing core automated coverage. `docs/uat-ci-coverage.md` is now the canonical substitute map.
- When this seed surfaces, the right output is evidence closure and launch-truth filing. If a row cannot be automated honestly, state that as a residual or launch block explicitly instead of smuggling it back in as a hand-waved human gate.
- If item 7 turns up a real product defect, that is a bug-fix phase, not "UAT."
- Counterpart seed SEED-002 tracks the phase 9 `log_safe/3` atomicity followup which has a different trigger.
