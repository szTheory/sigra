# Research Summary: v1.32 RELEASE-ADOPTION

**Date:** 2026-05-31
**Milestone:** v1.32 RELEASE-ADOPTION
**Decision:** Cut real Hex `1.0.0` directly from `main`, then run a proof-backed adoption push. Do not add new auth primitives in this milestone.

## Recommendation

Treat v1.32 as a truth-and-adoption milestone:

1. Make the Hex `1.0.0` decision explicit and enforceable across version metadata, changelog, docs, release automation, and maintainer runbook.
2. Publish a stable public contract for Sigra's library API, generated-host ownership model, SemVer/deprecation policy, supported stack ranges, and security invariants.
3. Turn the v1.31 demo into the canonical evaluator funnel: first 10 minutes, persona map, screenshots, proof links, and honest limitations.
4. Add migration/adoption lanes for the real audiences: greenfield Phoenix 1.8, existing `phx.gen.auth`, and Pow/Guardian/Ueberauth-style stacks.
5. Package launch materials around evidence, not slogans: release notes, announcement draft, CI/UAT proof bundle, post-1.0 hotfix policy.

## Approach Tradeoffs

### Direct `1.0.0` from `main` (selected)

**Pros:** least confusing for adopters, uses existing Release Please + CI substrate, aligns with Sigra's current maturity, avoids a public RC support train.

**Cons:** less external pre-GA feedback than a release candidate.

**Why selected:** Sigra already has strong install, example, dep-off, docs, doctor, and UAT evidence. The bottleneck is clarity and adopter conversion, not more pre-release ceremony.

### Public `1.0.0-rc.N`

**Pros:** useful if broad downstream validation is needed before final GA.

**Cons:** creates split docs/messaging, additional support burden, and install-target ambiguity.

**Decision:** keep as a fallback only if the hardening window finds a blocker that genuinely needs external validation.

### Feature-heavy launch

**Pros:** larger headline.

**Cons:** destabilizes the contract right before 1.0 and repeats the "great code, unclear onboarding" failure mode.

**Decision:** explicitly out of scope.

## Ecosystem Lessons

- Phoenix, Devise, Pow, and Ash show that generators win adoption when the generated blast radius and upgrade story are explicit.
- Ueberauth and Guardian show the value of a narrow, repeated scope statement; users trust libraries that say what they do not own.
- Ecto, Plug, Phoenix, and Oban set the bar for changelogs, deprecation posture, tagged docs, source links, and mechanical release runbooks.
- Django/allauth, Spring Security, Auth.js, Clerk, Auth0, and Supabase reinforce the adoption pattern: quickstart-first docs, clear path selection, runnable examples, and explicit operational limits.
- For Sigra specifically, the hybrid library+generator model is the moat. The 1.0 launch should explain and prove that model, not obscure it behind marketing.

## Requirements Seed

- Release truth and SemVer contract
- Public API/generated-host ownership contract
- Release gate matrix and publish runbook
- Upgrade/adoption lanes from `0.3.x`, `phx.gen.auth`, and existing auth stacks
- Security invariants and non-goals
- Evaluator funnel, demo persona map, screenshots, and proof bundle
- Announcement and post-release hotfix policy

## Non-Goals

- No SCIM, hosted control plane, generic compliance platform, or new auth primitives.
- No broad admin expansion, authorization policy engine, or frontend component library.
- No Mailglass adapter resurrection or other previously corrected overclaims.
- No public RC train unless a concrete release blocker appears.

## Research Inputs

- `.planning/research/RELEASE-MECHANICS.md`
- `.planning/research/ADOPTION-DX.md`
- `.planning/research/ECOSYSTEM-BENCHMARKS.md`
- `.planning/research/LOCAL-PROMPT-SYNTHESIS.md`
