# Local Prompt Synthesis: v1.32 “1.0 Hex Cut + Adoption Push”

**Project:** Sigra  
**Date:** 2026-05-31  
**Scope:** Local repo evidence only (`prompts/`, planning files, release/docs/demo surfaces)

## Local Readiness Findings

1. **Core product posture is mature for an adoption-led milestone.**
   - `.planning/PROJECT.md` and `.planning/STATE.md` show v1.31 shipped/archived, no active blockers, and explicit “next milestone starts at Phase 145.”
   - `test/example` is now a usable evaluator surface (seeded personas, `/demo/credentials`, Playwright proof, demo guide).
   - Trust surfaces already exist: CI gates, `mix sigra.doctor`, bounded optional-dep posture, and clear docs around machine-vs-human coverage.

2. **The milestone arc already points to non-code adoption as the next best move.**
   - `.planning/MILESTONE-ARC.md` explicitly says the bottleneck is “absence of real adopters, not missing features.”
   - It prioritizes “1.0 Hex cut + adoption push” over additional feature wedges unless concrete adopter pain proves otherwise.

3. **Release mechanics are mostly in place but messaging/version coherence is still fragile.**
   - `release-please-config.json` + `.release-please-manifest.json` + `MAINTAINING.md` define an automation path.
   - `CHANGELOG.md` already warns about dual axes (planning v1.x vs Hex semver 0.x), but that confusion remains a real adoption risk.

4. **Docs are strong but still carry trust-fragility seams.**
   - README is high quality and evaluator-friendly.
   - Some wording still mixes “typical Postgres setup” with historical traces mentioning other adapters; this can re-open scope ambiguity if not normalized before a 1.0 declaration.

## Prompt-Derived Principles (from `prompts/*.md`)

1. **Sigra should remain an authentication library, not an authorization platform.**
   - Prompt corpus repeatedly separates authn vs authz and warns against policy-heavy expansion.

2. **Hybrid model is the product moat: hardened library core + host-owned generated code.**
   - Multiple prompts reinforce “generator-compatible, Phoenix-native, no macro-heavy black box.”

3. **Trust is earned via edge-case behavior and evidence, not feature slogans.**
   - Recurring emphasis: enumeration resistance, token hygiene, audit truth, rollback safety, explicit non-goals, and CI-backed claims.

4. **Adoption depends on lowering integration burden more than adding primitives.**
   - Ecosystem prompts frame pain as “too much stitching”; current Sigra docs/demo should be positioned as the antidote.

5. **Brand tone should stay infrastructure-grade and calm.**
   - `sigra-auth-oss-lib-name.md` argues for technical, non-marketing positioning; launch copy should reflect that.

## Contradictions / Stale Claims to Resolve Before v1.32

1. **Dual version axis confusion is still active debt.**
   - `MAINTAINING.md` documents milestone-axis `@doc since` values that can look numerically inconsistent with Hex removal targets.
   - For a “1.0” push, this must be explained crisply in release notes and docs to avoid trust loss.

2. **README dependency snippet is stale relative to current package version.**
   - README first integration still shows `{:sigra, "~> 0.2"}` while `mix.exs` is `0.3.0`.
   - Not a runtime bug, but it weakens release-truth optics during adoption.

3. **Historical adapter language can conflict with current “Postgres-honest” posture.**
   - Current strategic docs emphasize Postgres baseline/honesty.
   - Legacy changelog/history references to MySQL/SQLite behavior can confuse newcomers if not framed as historical.

4. **“1.0 hex cut” phrasing vs current semver policy needs a formal decision.**
   - `MAINTAINING.md` says “do not jump to 1.0.0 unless explicitly decided with coordinated messaging.”
   - v1.32 must either: (a) make that explicit decision, or (b) run an adoption push on 0.x without implying API-stability guarantees.

5. **Prompt corpus includes externally researched claims with dates that may age.**
   - For this milestone, prompts should be treated as principles, not live market facts.

## Proposed Milestone Requirement Categories (v1.32)

1. **Release Truth & SemVer Contract**
   - Single canonical narrative across `mix.exs`, `CHANGELOG.md`, `README.md`, `MAINTAINING.md`, and release automation.
   - Explicit statement of what “1.0” means (API stability, deprecation policy, support expectations).

2. **Adopter Evaluation Funnel**
   - Make evaluator path frictionless and measurable: README lane, demo guide, screenshots, one-command run, known limitations.
   - Keep OAuth live-provider caveat explicit (seeded identity vs live credentials).

3. **Docs Consistency & Scope Honesty**
   - Resolve stale wording and historical ambiguity.
   - Ensure non-goals and ownership boundaries are visible on first read.

4. **Operational Confidence for Maintainers**
   - Confirm release-please + publish recovery path is rehearsal-backed.
   - Ensure tag/source_ref/docs reproducibility and “copy-safe” links.

5. **Evidence Packaging for Adoption**
   - Curate a compact “why trust this” bundle (CI gates, UAT/CI mapping, doctor diagnostics, demo proof) without overclaiming certifications.

## Risks / Footguns

1. **Semantic confusion between planning milestones and installable versions** can undermine launch clarity.
2. **Declaring 1.0 too early** without explicit API stability contract can increase support burden and churn.
3. **Over-indexing on new features instead of adoption conversion** violates current strategic evidence.
4. **Reintroducing previously corrected claims** (e.g., Mailglass adapter posture) can damage trust quickly.
5. **Treating demo as production proof** instead of evaluator proof risks overclaiming.
6. **Documentation drift after release cut** can desync changelog/readme/automation truth.

## Explicit Non-Goals for v1.32

1. New auth primitives (SCIM, hosted control plane, broad compliance platform, generic back-office expansion).
2. Authorization opinionation inside Sigra core (roles/policies beyond current seams).
3. Re-architecting session store, full account-center redesign, or unrelated UI polish campaigns.
4. Provider-certification claims (live IdP/browser matrix as mandatory gate).
5. Reopening already-bounded corrigenda unless new contradictory evidence appears.

## Recommendation

Treat **v1.32** as a **truth-and-adoption milestone**, not a feature milestone:
- If choosing a real **Hex `1.0.0`** cut: make API-stability/deprecation/support commitments explicit and enforceable in docs + release process.
- If not ready for those commitments: run the same adoption push under **0.x** with explicit wording (“pre-1.0, production-viable, bounded contract”) and defer 1.0 branding.

Given current local evidence, the highest-leverage path is to optimize for **adopter conversion clarity and trust coherence**, not additional surface area.
