# Phase 134: Recipe-Only Companion Libraries - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-28
**Phase:** 134-recipe-only-companion-libraries
**Mode:** assumptions (`minimal_decisive` calibration)
**Areas analyzed:** Per-recipe content scope (Accrue, Lockspire, Relyra, Rulestead),
mix.exs sequencing, phase sequencing

## Assumptions Presented

### Per-Recipe Content Scope & Shape

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Accrue recipe pins BOTH `lib/sigra/organizations/callbacks.ex:17-18,38-48` (seat gating) AND `lib/sigra/hooks.ex:1-103` (lifecycle); host implements `Accrue.Auth` (5+2 callbacks); `log_audit/2` cross-links audit; no invented Accrue webhooks | Confident | organizations/callbacks.ex callback table; accrue/lib/accrue/auth.ex:41-49; STACK.md:108; FEATURES.md AF-07 |
| Lockspire recipe is CONCRETE companion to v1.7 `companion-oauth-provider.md`; pins AccountResolver `:14-39` (5+1); reads `current_scope.user` `scope.ex:18-25`; quotes ADR 001 in Non-goals; no duplication | Confident | ROADMAP.md:125; lockspire/lib/lockspire/host/account_resolver.ex:14-39; ADR 001; companion-oauth-provider.md:38 |
| Relyra recipe pins `Sigra.Auth.create_session/4` (`auth.ex:1284`), NOT STACK.md:111's `Sigra.Session.create_session/3`; pins `Relyra.start_login/3`+`consume_response/3`; inline OIDC-vs-SAML matrix; Non-goals = SAML metadata/keys/SLO | Confident | auth.ex:1284 (verified); session.ex has no create_session (grep-verified); relyra/lib/relyra.ex:28-29; FEATURES.md:48, AF-02 |
| Rulestead recipe pins `~> 0.1` Hex line; surfaces 1.0.0-vs-0.1 mismatch neutrally; shows `Rulestead.enabled?` + `RulesteadPolicy` from `current_scope`; planner verifies which Rulestead surface is canonical at write time | Likely | rulestead.ex:1189-1192 (`@spec enabled?(map(),Context.t())`) vs README:111 (`enabled?("flag",conn)`); STACK.md:34; FEATURES.md:26 |

### mix.exs + Phase Sequencing

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One atomic commit: append four `extras:` entries (after mix.exs:227) AND remove four `skip_undefined_reference_warnings_on:` entries + Phase 133 comment header (mix.exs:174-179); zero `groups_for_extras:` edits | Confident | mix.exs:174-179, 225-236 (verified); Phase 133 D-06/D-07; Phase 132 D-11 |
| Single sequential plan, six steps (4 recipes → mix.exs → verification gates); not four parallel plans (mix.exs race, zero throughput gain) | Confident | Phase 132 D-17/D-18; Phase 133 D-20/D-21 |

## Corrections Made

No corrections — user selected "Yes, proceed"; all assumptions confirmed as presented.

## External Research

None performed. All four sister-repo behaviour contracts were read directly from local
checkouts under `/Users/jon/projects/{accrue,lockspire,relyra,rulestead}/`; the
`gsd-assumptions-analyzer` left the "Needs External Research" section empty.

## Notable Findings Surfaced During Analysis

- **STACK.md:111 drift (load-bearing):** STACK.md names `Sigra.Session.create_session/3`
  for the Relyra session hand-off, but the actual function is `Sigra.Auth.create_session/4`
  (`lib/sigra/auth.ex:1284`); `lib/sigra/session.ex` has no `create_session` at all
  (grep-verified). Captured as CONTEXT D-09 — the single most consequential pin in the phase.
- **REQUIREMENTS.md RC-03 phrasing nuance:** RC-03 names `lib/sigra/hooks.ex` for Accrue
  seat-limit gating, but the actual seat-gating seam is
  `lib/sigra/organizations/callbacks.ex` (`before_add_member/4`). `hooks.ex` is the
  user-lifecycle seam. Both are legitimate Sigra hook-style seams; the Accrue recipe pins
  both with the split made explicit (CONTEXT D-01).
- **FEATURES.md F-RC-03 vs ROADMAP.md RC-04 framing:** FEATURES framed Lockspire as a v1.7
  recipe "touch-up"; ROADMAP.md:125 / REQUIREMENTS.md RC-04 scope it as a NEW concrete
  recipe cross-linking the v1.7 architectural one. CONTEXT follows ROADMAP/REQUIREMENTS
  (new concrete recipe); rewriting the v1.7 recipe beyond a reciprocal back-link is deferred.
