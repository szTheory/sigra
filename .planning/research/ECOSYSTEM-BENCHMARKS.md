# ECOSYSTEM BENCHMARKS: Sigra v1.32 (1.0 Hex Cut + Adoption Push)

**Project:** Sigra  
**Mode:** Ecosystem benchmark  
**Date:** 2026-05-31  
**Overall confidence:** MEDIUM-HIGH (high on Elixir/Phoenix sources; medium on cross-ecosystem contrasts)

## Benchmark Table

| Project | What they did right | Where teams get cut | What Sigra should copy |
|---|---|---|---|
| Phoenix `mix phx.gen.auth` | Opinionated starter with explicit security notes, migration references, and generated host-owned code (`UserAuth`, scopes, plugs) | Generated code can drift from upstream improvements unless upgrade path is explicit | Keep hybrid model, but publish a strict “generated host contract” and upgrade diff workflow |
| Pow | Modular extension architecture and clear config precedence (function/plug opts over app env) | Historic version/platform fit issues can stall adoption confidence | Preserve modular core, but aggressively publish compatibility matrix and support window |
| Ueberauth | Narrow scope: challenge phase only; composable with other auth layers | Strategy ecosystem quality varies; users can assume “full auth system” when it is not | Keep Sigra scope boundaries explicit (“what Sigra owns vs host owns”) in every install surface |
| Guardian | Clear “token toolkit, not full auth” positioning and behavior-based extensibility | JWT misuse and over-claim risk if users treat library defaults as complete security architecture | Avoid “secure by default” over-claims; publish claim validation and rotation invariants as explicit contract |
| Ash Authentication | Strong install automation (`igniter`), docs-first onboarding, explicit recommended path | Larger abstraction surface means steeper mental model | Adopt one-command install/doctor + generated verification checklist, without over-expanding abstraction |
| Devise | Mature generator flow, large ecosystem/wiki/extensions, stable adoption messaging | Customization complexity and upgrade gotchas (parameter sanitizer shifts, etc.) | Ship an “integration cookbook” + “breaking-change playbook” before 1.0 |
| Django auth + allauth | Batteries-included core + modular add-ons + explicit settings/middleware contracts | Easy to misconfigure when mixing headless/social/session settings | Add machine-checkable config diagnostics (`mix sigra.doctor --strict`) for common miswiring |
| Spring Security | Explicit architecture docs (filter chain order, auth vs authz separation) | Misordered filters/custom hooks cause subtle production bugs | Publish canonical Sigra request lifecycle diagram and extension insertion points |
| Passport.js | Strategy middleware contract is simple and composable | Strategy selection and session semantics are often under-documented in app code | Keep provider auth as bounded integration seam, never the core identity model |
| Auth.js | Multi-framework adapters + copy/paste quickstarts + example apps | Framework churn can force migration overhead | Keep framework target narrow (Phoenix-first) and avoid adapter sprawl pre-1.0 |
| Clerk/Auth0/Supabase (hosted contrast) | Fast time-to-value, clear quickstarts, strong operational docs | Vendor coupling + migration complexity + pricing/operational constraints | Use them as messaging contrast: Sigra = self-hosted control + host-owned code + transparent boundaries |

## Lessons To Copy (for 1.0 Readiness + Adoption)

1. **Narrow contract, explicit boundaries win trust.**  
   Best examples (Guardian, Ueberauth, Spring docs) are explicit about what they do *not* do.

2. **Generator success is not enough; upgradeability is the product.**  
   Phoenix `phx.gen.auth` and Devise patterns show install is easy, but adoption trust is retained by clear migration guidance.

3. **Security claims must be scoped to invariants, not vibes.**  
   Successful projects avoid blanket claims and document exact guarantees, defaults, and operator responsibilities.

4. **Examples are part of API stability.**  
   Auth.js, Phoenix, and Devise all lean on runnable examples to reduce interpretation drift.

5. **Diagnostics reduce support load and improve conversion.**  
   Django’s system-check mindset and Sigra’s existing `mix sigra.doctor` direction are strong adoption multipliers.

## Footguns To Avoid

1. **“1.0” without a locked public API surface.**  
   If Sigra cuts 1.0 while still moving core callback/contracts unpredictably, adoption will stall.

2. **Over-claiming security outcomes.**  
   Claiming “production secure” without threat-model boundaries, rotation guidance, and host responsibility matrix invites backlash.

3. **Generator/library contract ambiguity.**  
   If adopters cannot tell what updates via `mix deps.update` vs what they own in generated code, upgrades become fear-driven.

4. **Upgrade docs that are purely narrative.**  
   Need executable/machine-checkable steps, not only prose.

5. **Optional dependency sprawl in the default path.**  
   Core install must stay minimal and deterministic; advanced slices should be clearly optional.

## Sigra-Specific Architecture + DX Recommendations (v1.32)

## 1) Public API Stability Gate for 1.0

- Freeze and publish:
  - Stable modules/functions/callbacks list (`@public_api` inventory doc).
  - Explicit “experimental/private” list with removal policy.
  - SemVer policy section in README + `MAINTAINING.md`.
- Add CI contract checks:
  - Fail if public API removals occur without `CHANGELOG` breaking section + upgrade guide entry.

## 2) Generator/Library Ownership Contract

- Add a single canonical doc: `docs/contract/library-vs-generated.md`
  - “Library-owned (updatable)”
  - “Generated host-owned (you maintain)”
  - “Shared seam points (callbacks/behaviours)”
- Generate this summary at install completion with links.

## 3) 1.0 Upgrade Path (from current `0.3.x`)

- Ship `guides/introduction/upgrading-to-v1.0.md` with:
  - Breaking change table (`before`/`after`)
  - Schema/migration impact matrix
  - Generated file diff strategy
  - Rollback notes
- Add `mix sigra.doctor --upgrade 1.0` to detect known blockers before cutover.

## 4) Security Claims Refactor

- Replace broad marketing claims with a **Security Invariants** table:
  - Token lifecycle guarantees
  - Session revocation behavior
  - MFA/passkey guarantees
  - Audit write co-fate guarantees
  - Explicit non-goals and host responsibilities
- Add “threats not covered” section (host infra, email reputation, IdP outages, business-logic authz).

## 5) Adoption Messaging Pack

- Publish “Why Sigra vs alternatives” section with honest tradeoffs:
  - vs `phx.gen.auth` (generated-only)
  - vs Pow/Guardian/Ueberauth composition
  - vs hosted Auth (Clerk/Auth0/Supabase)
- Add two adopter lanes:
  - **Fast lane:** minimal setup, default features, production checklist
  - **Control lane:** advanced seams (OAuth, passkeys, orgs, audit forwarders)

## 6) Example + Verification as Release Gate

- Keep `test/example` as executable contract and add 1.0-specific gates:
  - Fresh install smoke
  - Upgrade smoke from previous minor
  - Docs command transcript verification
  - Security-sensitive flow assertions (password reset, token revoke, MFA challenge, passkey login)

## Scope Boundaries For v1.32 (1.0 Hex Cut + Adoption Push)

**Must include:**

1. Public API freeze + SemVer policy
2. 1.0 upgrade guide + doctor upgrade checks
3. Security invariants/non-goals documentation
4. Install/upgrade examples verified in CI
5. Adoption messaging refresh (tradeoff-first, honest comparison)

**Should include (if capacity):**

1. Compatibility matrix (Elixir/Phoenix/Ecto/OTP)
2. “Known limitations” page linked from README top section

**Do not include in v1.32:**

1. New major auth feature surfaces (avoid destabilizing 1.0 contract)
2. Broad new provider integrations
3. Framework expansion beyond Phoenix-first posture

## Recommended Release Narrative (Sigra 1.0)

Use this positioning shape:

- “Sigra 1.0 is a **stability and trust release**.”
- “Hybrid architecture is now contractually documented: security core in library, UX/policy in generated host code.”
- “Upgrade path is explicit and machine-checkable.”
- “Security claims are bounded to documented invariants and operational assumptions.”

## Confidence Notes

- **HIGH confidence:** Phoenix `phx.gen.auth`, Ecto/Elixir deprecation norms, Guardian/Ueberauth/Ash docs, Django core docs, Spring Security architecture references.
- **MEDIUM confidence:** Devise/Passport/Auth.js/hosted-auth contrasts due to ecosystem breadth and varying doc depth in this pass.

## Sources

- Phoenix `mix phx.gen.auth` task + guide: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Auth.html, https://hexdocs.pm/phoenix/mix_phx_gen_auth.html
- Phoenix auth intro/API auth: https://hexdocs.pm/phoenix/authn_authz.html, https://hexdocs.pm/phoenix/api_authentication.html
- Pow: https://github.com/pow-auth/pow
- Ueberauth: https://github.com/ueberauth/ueberauth
- Guardian: https://guardian.hexdocs.pm/introduction-overview.html
- Ash Authentication: https://ash-authentication.hexdocs.pm/get-started.html
- Ecto changelog/deprecation posture: https://hexdocs.pm/ecto/changelog.html, https://hexdocs.pm/elixir/compatibility-and-deprecations.html
- Devise: https://github.com/heartcombo/devise
- Django auth: https://docs.djangoproject.com/en/dev/topics/auth/
- django-allauth: https://docs.allauth.org/en/latest/index.html, https://docs.allauth.org/en/dev/installation/quickstart.html
- Spring Security architecture: https://docs.spring.io/spring-security/reference/7.0/servlet/architecture.html
- Passport middleware/strategies: https://www.passportjs.org/concepts/authentication/middleware/
- Auth.js: https://authjs.dev/
- Clerk architecture overview: https://clerk.com/docs/guides/how-clerk-works/overview
- Supabase Auth + migration/rate limits: https://supabase.com/docs/guides/auth/, https://supabase.com/docs/guides/troubleshooting/migrating-auth-users-between-projects, https://supabase.com/docs/guides/auth/rate-limits
- Auth0 quickstarts: https://auth0.com/docs/quickstart/
