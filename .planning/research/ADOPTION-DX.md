# Sigra v1.32 Research: 1.0 Launch + Adoption DX

**Project:** Sigra (Elixir/Phoenix auth library)  
**Date:** 2026-05-31  
**Mode:** Ecosystem (adoption + launch DX)  
**Overall confidence:** MEDIUM-HIGH

## Summary Recommendation

Ship v1.32 as a **Launch Readiness + Adoption Funnel** milestone, not a feature milestone. The best path is:

1. Tighten a single “first 15 minutes” evaluator path (README + Hex + ExDoc + demo).
2. Publish a blunt “production contract” (what Sigra owns vs host owns).
3. Add explicit migration/upgrade lanes by adopter archetype (from `phx.gen.auth`, Pow, Guardian/Ueberauth stacks).
4. Package announcement artifacts around proof, not claims (screenshots + CI evidence + rough edges).
5. Add AI-consumption assets (`llms.txt` + structured “copy/paste setup blocks” consistency).

Sigra already has strong substrate (v1.31 seeded demo, guide map, CI proof posture). The adoption bottleneck is now **discoverability, clarity, and low-friction trial-to-integration conversion**.

---

## Launch Approach Tradeoffs

## Approach A: “Feature-heavy 1.0”

**Pros**
- Looks larger on paper.
- May attract “checklist shoppers.”

**Cons**
- Dilutes launch message.
- Increases support surface right before adoption push.
- Risks repeating “great code, unclear onboarding” failure mode.

**Recommendation:** Do not choose for v1.32.

## Approach B: “Docs-only polish pass”

**Pros**
- Low engineering risk.
- Fast to ship.

**Cons**
- Doesn’t fully close first-run friction if installer ergonomics / migration lanes remain implicit.
- Easy to under-sell value if no launch package and narrative.

**Recommendation:** Better than A, still insufficient alone.

## Approach C: “Adoption Funnel Milestone” (recommended)

**Pros**
- Converts evaluator curiosity into successful local run + integration confidence.
- Reuses existing proof assets (`test/example`, Playwright, UAT/CI evidence).
- Preserves Sigra’s principle-of-least-surprise stance.

**Cons**
- Requires disciplined prioritization (many “small” UX docs tasks).
- Needs strict non-goals to avoid scope creep.

**Recommendation:** Choose this for v1.32.

---

## Lessons From Successful Projects

## What they do right (portable to Sigra)

1. **One-command install with explicit generated files (Pow, Devise, Phoenix generators).**  
   Why it works: users can predict blast radius and trust setup.
2. **Clear boundary statements (Ueberauth + Guardian split).**  
   Why it works: avoids false assumptions about what a package does.
3. **Quickstarts by app type (Auth0, Clerk).**  
   Why it works: users self-select correct integration path immediately.
4. **Migration-forward messaging when strategy changes (Auth.js → Better Auth, Lucia deprecation/migration docs).**  
   Why it works: reduces abandonment when ecosystem shifts.
5. **Structured nav with quickstart + examples + API reference (django-allauth).**  
   Why it works: supports both skimmers and deep integrators.

## What they get wrong (avoid in Sigra)

1. **Fragmented docs with unclear “start here” hierarchy.**
2. **Marketing-first claims without runnable proof.**
3. **Version/migration ambiguity between docs, package metadata, and release notes.**
4. **Hidden caveats about security defaults / host responsibilities.**

---

## Sigra-Specific Footguns To Prevent

1. **Multiple entry points with no canonical “if you are X, do Y now.”**
2. **Mixing planning milestone language with Hex semver in public-facing docs.**
3. **Evaluator path drift between README, ExDoc guides, and `test/example/README.md`.**
4. **Not surfacing rough-edge personas early (Dave/Frank) which are currently a strength.**
5. **Migration ambiguity for teams on `phx.gen.auth` or Pow-era setups.**
6. **First-run surprises around mailer/Oban/passkeys/org defaults not being explained in one compact checklist.**

---

## Concrete Milestone Requirement Candidates (v1.32)

## A. README + Hex Package Page Contract

1. Add a **Launch lane** at top: “Try in 5 minutes” (`cd test/example && mix setup && mix phx.server`), with expected outcome bullets.
2. Add **Adopter lanes**:
   - “Greenfield Phoenix 1.8 app”
   - “Existing `phx.gen.auth` app”
   - “Pow/Guardian/Ueberauth stack”
3. Add a one-screen **Ownership Contract** table:
   - Sigra owns
   - Generated host owns
   - Out of scope
4. Add “Top 5 surprises avoided” callout (enumeration posture, org defaults, passkeys fallback, etc.).

## B. ExDoc IA + Getting Started Path

1. Add explicit `Start Here` guide order:
   - Installation
   - Getting Started
   - Demo Showcase
   - Production Checklist
   - Migration Guides
2. Create **Migration index page** linking all upgrade docs + new external migration lanes.
3. Add “choose your path” decision block at top of Getting Started.

## C. Demo Showcase Conversion

1. Add one “persona intent map” section in `demo-showcase`:
   - Who to log in as
   - What flow each persona proves
   - What failure mode each persona proves
2. Add a **single screenshot grid** on README/HexDocs landing path (credentials, admin, audit).
3. Add explicit “what this demo does NOT prove” section to sustain trust posture.

## D. Announcement Materials

1. Ship a `1.0 launch announcement` draft with:
   - Problem framing
   - 3 core differentiators
   - 3 explicit non-goals
   - Runnable proof links
2. Ship a concise “release notes for adopters” doc:
   - Who should upgrade now
   - Who can wait
   - Breaking/behavior changes (if any)

## E. Migration + Upgrade Story

1. Add **`migrating-from-phx-gen-auth.md`**:
   - Scope/session concepts alignment
   - Auth table/token differences
   - Incremental adoption sequence
2. Add **`migrating-from-pow-or-guardian.md`**:
   - Session vs token assumptions
   - OAuth ownership split
   - Cutover checklist
3. Add upgrade risk matrix (low/med/high migration effort).

## F. First-Run Ergonomics

1. Add a “doctor-first” setup snippet (`mix sigra.doctor`) right after install/migrate.
2. Add explicit expected success output examples for setup commands.
3. Add a short troubleshooting matrix mapped to most common first-run failures.

## G. AI Consumption (`llms.txt` + structure)

1. Ensure `llms.txt` includes:
   - canonical start path
   - ownership boundaries
   - migration guides
   - security posture caveats
2. Keep command snippets stable and duplicated consistently across README + ExDoc pages to reduce LLM hallucinated variants.

---

## Launch / Adoption Non-Goals

1. No net-new auth primitives in v1.32.
2. No hosted-control-plane positioning.
3. No broad admin-feature expansion.
4. No large UI redesign of generated host.
5. No compliance certification claims.
6. No multi-framework expansion beyond Phoenix-first contract.

---

## Recommended v1.32 Success Criteria

1. New evaluator can run demo from zero to first meaningful flow in <= 10 minutes.
2. README/HexDocs/demo pages all point to the same canonical first path.
3. Migration path exists for `phx.gen.auth` and Pow/Guardian stacks.
4. Announcement assets are proof-backed and publish-ready at release cut.
5. Fewer “where do I start?”/“what does Sigra own?” support questions post-launch.

---

## Confidence Notes

- **HIGH:** Phoenix/Pow/Ueberauth/Guardian/Devise/allauth/Auth0/Oban patterns around quickstarts, generators, and docs structure are clear from official docs/READMEs.
- **MEDIUM:** Auth.js/Better Auth ecosystem transition implications for Sigra positioning (relevant lesson is documentation/migration clarity, not direct feature parity).
- **MEDIUM:** Clerk docs IA specifics from accessible pages; principle (quickstart-first) is still well-supported.

---

## Sources

- Sigra local context:
  - `.planning/PROJECT.md`
  - `.planning/MILESTONE-ARC.md`
  - `.planning/MILESTONES.md`
  - `README.md`
  - `guides/introduction/getting-started.md`
  - `guides/introduction/demo-showcase.md`
  - `test/example/README.md`
  - `docs/uat-ci-coverage.md`
- Phoenix `mix phx.gen.auth` docs: https://phoenix.hexdocs.pm/mix_phx_gen_auth.html
- Pow README (install + generators + extensions): https://github.com/pow-auth/pow
- Ueberauth README (scope boundary): https://github.com/ueberauth/ueberauth
- Guardian README (token library positioning): https://github.com/ueberauth/guardian
- Devise README (getting started + generator posture): https://github.com/heartcombo/devise
- django-allauth docs (quickstart + broad IA): https://docs.allauth.org/en/latest/
- Oban docs (installation/testing docs posture): https://oban.hexdocs.pm/
- Auth.js getting started (project now part of Better Auth): https://authjs.dev/getting-started
- Lucia deprecation/migration pages:
  - https://v3.lucia-auth.com/
  - https://lucia-auth.com/lucia-v3/migrate
- Auth0 docs quickstart model: https://auth0.com/docs/get-started
- Clerk docs quickstart example: https://clerk.com/docs/react/getting-started/quickstart
