---
slug: adoption-evidence-and-demo-showcase
title: Adoption evidence verdict + Demo Showcase next-build wedge
status: dormant
created: 2026-05-29
updated: 2026-05-29
---

# Thread: Adoption evidence verdict + Demo Showcase next-build wedge

## Goal

Preserve a repo-grounded milestone-boundary assessment (done 2026-05-29) so the next milestone starts
from truth instead of re-litigating "are we blocked on adoption evidence?". Records the verdict, the
one genuine gap, and the recommended next build (Demo Showcase) with its overbuild guardrails.

## Context

*Created 2026-05-29 from a milestone next-step + adoption-evidence assessment (3 parallel repo-inspection passes).*

**Done-band: 90–95% — near-done / diminishing returns soon (for stated scope).** Every major flow is
REAL & TESTED in `lib/` (~120 modules): password/session, magic-link/reset/confirm, MFA (TOTP + backup
codes + trust-browser + enforcement), WebAuthn/passkeys (full ceremony + sign-count policy), OAuth (5
providers + enterprise SAML/SSO + JIT), API/bearer + JWT tokens, rate-limiting, audit, orgs, admin
console, webhooks, data-lifecycle. ~2252 lib tests + a 236-test example app, install-golden diff,
greenfield `install-smoke.sh`, an 11-spec Playwright suite incl. a register→confirm→login→MFA→logout
golden-path, and a 977-line CI with a dep-off lane.

**Adoption-evidence verdict: NOT blocked.** The automation backbone (E2E browser coverage, install-
path verification on every PR, happy-path smoke) the user feared was missing **already exists** and is
strong (~80% of the instinct is already built). This finding should stop future passes from
re-deriving whether E2E/install proof exists.

**The genuine gap (narrow, real):**
1. `test/example/priv/repo/seeds.exs` is **empty** — a fresh `mix setup` lands on a blank DB; no
   "spin up and click around a realistic SaaS" experience. Test *fixtures* (`auth_fixtures.ex`, 7
   scenarios) are excellent, but they serve the test perspective, not the evaluator perspective.
2. The example app is a **headless test fixture**, not positioned/documented as an adopter-facing
   showcase — no realistic domain/persona framing, no screenshots in README/guides, no one-command
   demo path for the README's "Evaluating" lane.

**Meta-insight:** the honest bottleneck for "is Sigra done?" is **absence of real adopters, not
missing features**. The Demo Showcase is the best remaining *build* because it's the evaluation-funnel
conversion surface; after it, the highest-leverage move is non-code (1.0 Hex cut + adoption push).

## Recommended next build: "Demo Showcase"

Convert `test/example/` into double-duty adopter proof + evaluator showcase (reuses existing E2E/CI
infra — low net-new code, high adopter leverage). Coherent with the shipped "extend `test/example/`
over a new `examples/` dir" decision (STATE.md) and the unbuilt "reference starter app" remainder of
SUITE-INTEGRATION (MILESTONE-ARC.md:205).

**Done-enough =**
- a realistic domain + 4–6 personas (admin w/ MFA + multi-org, standard user, invited-unconfirmed,
  locked, OAuth-linked, passkey user)
- idempotent `seeds.exs`
- one-command spin-up (`mix setup && mix phx.server` → fully populated, clickable realistic SaaS)
- a README/guide "try it locally" path with screenshots
- the Playwright golden-path extended to exercise seeded data

**Overbuild guardrails (do NOT):**
- build a *separate standalone demo repo* — extend `test/example/` (the nested-app drift cost was
  already paid in Phase 114)
- turn it into a marketing site, a component library, or a generic seeding framework
- seed host-app domain data beyond what makes auth/account features legible

## Inconsistencies flagged (lower confidence where docs drift)

- Working branch name `v1.28-data-lifecycle` is stale; active work is **v1.30** (PROJECT.md + STATE.md).
- STATE.md progress block says Phase 137 "Plan 1 of 3 / 0/4 phases", but git shows 137-02/137-03
  already merged (`eb64903`, `a945a9b`, `523b631`). STATE.md is the lowest-precedence handoff doc —
  trust git/ROADMAP; Phase 137 is largely executed.

## References

- `.planning/MILESTONE-ARC.md` (Candidates — Demo Showcase added; SUITE-INTEGRATION starter-app remainder)
- `.planning/PROJECT.md` (Key Decisions — adoption-not-features framing)
- `test/example/priv/repo/seeds.exs` (empty — the gap)
- `test/example/test/support/fixtures/auth_fixtures.ex` (strong test fixtures; evaluator gap)
- `test/example/priv/playwright/tests/golden-path.spec.ts` (existing E2E golden-path to extend)
- `.github/workflows/ci.yml`, `scripts/ci/install-smoke.sh` (install-path proof already strong)

## Next Steps

- After v1.30 closes, scope the Demo Showcase milestone (pick the realistic domain + persona set).
- Decide the seed shape: deterministic, idempotent, re-runnable; no `Date.now()`-style nondeterminism.
- Wire `mix setup` so a fresh clone is fully populated; add screenshots to README "Evaluating" lane.
- Then prioritize the 1.0 Hex cut + adoption push over any further feature wedge.
