---
phase: 134-recipe-only-companion-libraries
plan: "01"
subsystem: docs
tags: [recipes, companion-libs, exdoc, accrue, lockspire, relyra, rulestead]
dependency_graph:
  requires: [Phase 133 suite-integration narrative, Phase 132 LOCKED recipe template]
  provides: [RC-03 accrue.md, RC-04 lockspire.md, RC-05 relyra.md, RC-06 rulestead.md, mix.exs extras registration]
  affects: [mix docs --warnings-as-errors gate, Phase 136 PROOF-01 re-run, suite-integration.md cross-links]
tech_stack:
  added: []
  patterns: [Phase 132 LOCKED recipe template, validated_against HTML-comment form, D-20 banned-phrase grep gate]
key_files:
  created:
    - guides/recipes/companion-libs/accrue.md
    - guides/recipes/companion-libs/lockspire.md
    - guides/recipes/companion-libs/relyra.md
    - guides/recipes/companion-libs/rulestead.md
  modified:
    - mix.exs
decisions:
  - "Lockspire AccountResolver: 4 required + 2 optional (verify_backchannel_user_code/3 and redirect_for_logout/2 are both optional per @optional_callbacks line 36)"
  - "Relyra session-mint: Sigra.Auth.create_session/4 at lib/sigra/auth.ex:1284 — never Sigra.Session.create_session/3"
  - "Rulestead: RulesteadPolicy implements can?/4 (authorizer.ex:146-150), never authorize/4; canonical adopter entry is Rulestead.Runtime.enabled?/3"
  - "mix.exs atomic two-block edit: extras: append + skip_undefined_reference_warnings_on: removal in one commit"
metrics:
  duration: "363 seconds"
  completed_date: "2026-05-28"
  tasks_completed: 6
  files_changed: 5
---

# Phase 134 Plan 01: Recipe-Only Companion Libraries Summary

Four SAML/OAuth/billing/feature-flag integration recipes plus one atomic `mix.exs` edit — closes RC-03..RC-06 and removes the four Phase 133 bridge suppressions so `mix docs --warnings-as-errors` resolves all cross-links cleanly.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Write accrue.md (RC-03) | 7cf3c0d | guides/recipes/companion-libs/accrue.md |
| 2 | Write lockspire.md (RC-04) | c1766a7 | guides/recipes/companion-libs/lockspire.md |
| 3 | Write relyra.md (RC-05) | 00b7bd3 | guides/recipes/companion-libs/relyra.md |
| 4 | Write rulestead.md (RC-06) | 90a373c | guides/recipes/companion-libs/rulestead.md |
| 5 | Atomic mix.exs two-block edit | d82b937 | mix.exs |
| 6 | Phase verification gate | 8ba5893 (fix) | guides/recipes/companion-libs/accrue.md |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ExDoc autolink warning for Sigra.Organizations.add_member/4**
- **Found during:** Task 6 (`mix docs --warnings-as-errors` gate)
- **Issue:** `accrue.md:172` used the backtick form `Sigra.Organizations.add_member/4` which ExDoc attempted to auto-link. The actual function is `add_member/5` (takes config, scope, org, user, role). The wrong arity produced an undefined-reference warning that failed the `--warnings-as-errors` gate.
- **Fix:** Rephrased the sentence to avoid the `Module.function/arity` pattern; the information content is preserved without an auto-linked reference to an internal function.
- **Files modified:** `guides/recipes/companion-libs/accrue.md`
- **Commit:** 8ba5893

## Verification Results

All three Task 6 gates passed:

1. `mix docs --warnings-as-errors` exits 0 — all four recipes registered in `extras:`, four Phase 133 skip-warnings suppressions removed, ExDoc resolves all cross-links.
2. D-20 banned-phrase grep returns zero matches across all four files.
3. Structural-heading loop: all four files carry `## Failure modes`, `## Non-goals`, `> **Sigra works fully standalone.**` banner, and `validated_against:` line.

Validated-against pins confirmed correct:
- `accrue ~> 1.2` ✓
- `lockspire ~> 1.2` ✓
- `relyra ~> 1.2` ✓
- `rulestead ~> 0.1` ✓

RESEARCH corrections encoded:
- Relyra: `Sigra.Auth.create_session/4` present; zero occurrences of `Sigra.Session.create_session` ✓
- Lockspire: 4 required + 2 optional (NOT "5 required"); `verify_backchannel_user_code/3` explicitly optional ✓
- Rulestead: `Rulestead.Runtime.enabled?/3` + `Rulestead.enabled?/2` present; zero occurrences of fabricated `enabled?("flag", conn)`; `can?/4` is the host policy callback ✓

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This was a DOCS-ONLY phase — four new `.md` recipe files plus one `mix.exs` ExDoc-config edit. The Sigra runtime attack surface is unchanged.

## Known Stubs

None. All four recipes contain real wiring guidance backed by verified line-range pins; no placeholder content.

## Self-Check: PASSED

- `guides/recipes/companion-libs/accrue.md` — EXISTS
- `guides/recipes/companion-libs/lockspire.md` — EXISTS
- `guides/recipes/companion-libs/relyra.md` — EXISTS
- `guides/recipes/companion-libs/rulestead.md` — EXISTS
- All commits (7cf3c0d, c1766a7, 00b7bd3, 90a373c, d82b937, 8ba5893) — CONFIRMED in git log
