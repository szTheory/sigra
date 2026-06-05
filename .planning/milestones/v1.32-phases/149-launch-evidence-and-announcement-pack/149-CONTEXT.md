# Phase 149: Launch Evidence And Announcement Pack - Context

**Gathered:** 2026-05-31 (assumptions mode with subagent research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 149 packages the public Sigra 1.0 story around proof, comparisons, release notes, and AI-consumption routing. It covers LAUNCH-01 through LAUNCH-04: a publish-ready 1.0 announcement package, honest alternatives comparison, compact evidence bundle, AI-consumption index, and release-note guidance for who should upgrade now, who can wait, and how first-14-day regressions are triaged.

This phase does not add auth primitives, change the public 1.0 contract, alter generated-host behavior, redesign the demo, create a public RC train, add SCIM, build a hosted control plane, add compatibility shims, or introduce broad new release automation. Phase 145 owns contract and release truth. Phase 146 owns the release gate/runbook and hotfix policy. Phase 147 owns upgrade and migration lanes. Phase 148 owns the evaluator funnel.
</domain>

<decisions>
## Implementation Decisions

### Canonical Launch Pack
- **D-01:** Create a repo-resident canonical 1.0 launch pack under `docs/launch/v1.0/` and route the GitHub Release body, README/HexDocs entry points, changelog guidance, and AI-consumption index to that pack.
- **D-02:** The launch pack should be docs-first and evidence-first, not blog-first. External blog/social copy can quote or point to the pack later, but the repo-owned pack is the source of truth.
- **D-03:** The core narrative is: Sigra 1.0 is a stability and trust release for Phoenix 1.8+ auth; the product moat is the hybrid library plus generator model; security-sensitive primitives stay updateable in the library while generated host code remains inspectable and host-owned.
- **D-04:** The announcement artifact must include problem framing, core differentiators, explicit non-goals, proof links, upgrade/migration guidance, and "who should upgrade now vs wait" guidance.

### Honest Alternatives Comparison
- **D-05:** Add a public Sigra-vs-alternatives comparison page or launch-pack section that compares by ownership model, scope coverage, migration/cutover risk, operational burden, and upgrade ergonomics.
- **D-06:** Compare Sigra against four categories: Phoenix `mix phx.gen.auth`, Pow plus Guardian plus Ueberauth-style composition, hosted auth providers, and Sigra's own hybrid model.
- **D-07:** Position Sigra as a boundary-first Phoenix-native hybrid, not as "better at everything." The comparison must say when not to choose Sigra.
- **D-08:** Preserve exact scope boundaries from prior phases: `phx.gen.auth` is the official minimal/generated baseline; Ueberauth is challenge/provider oriented; Guardian is token-toolkit oriented; Pow-style stacks may be valid for existing stable apps but carry Phoenix 1.8 compatibility and composition concerns; hosted auth is valid when managed operations matter more than in-repo control.
- **D-09:** The alternatives page must avoid overclaiming ecosystem equivalence, automatic migration, hosted-auth replacement, provider certification, or compliance outcomes.

### Compact Evidence Bundle
- **D-10:** Create a compact attachable evidence bundle page, preferably `docs/launch/v1.0/evidence.md` or `docs/launch-evidence-v1-0.md`, that links to canonical proof instead of duplicating the full release runbook or UAT matrix.
- **D-11:** Include evidence rows for release gate status, docs warnings-as-errors, UAT-to-CI mapping, upgrade smoke, demo screenshot proof, known limitations, post-publish Hex visibility, HexDocs/source-link truth, and any waivers.
- **D-12:** Use live-release placeholders only for facts that cannot exist before the real release, such as final Hex visibility, final HexDocs page, final GitHub Release URL, and release-ref CI run URLs.
- **D-13:** Use pinned tag URLs for release proof outside the Hex tarball. Do not use `main` blob links for release evidence.
- **D-14:** The evidence bundle must explicitly state what the proof does not prove: no compliance certification, no live provider certification, no host deployment warranty, no hosted control plane, and no guarantee that generated-host local modifications are covered.

### Release Notes And Audience Guidance
- **D-15:** Add or prepare a release-note/adopter-guidance section that clearly says who should upgrade now, who can wait, and what first-14-day adopter triage looks like.
- **D-16:** Keep release notes human-curated and version-clear under the existing Keep-a-Changelog style. Do not scatter upgrade-now/wait guidance across multiple competing docs.
- **D-17:** Link release-note guidance to the 1.0 contract, upgrade guide, migration lanes, demo showcase, launch evidence bundle, and Phase 146 release runbook/hotfix policy.
- **D-18:** Preserve the planning-milestone-vs-Hex-SemVer distinction in every launch surface. Public launch copy should headline Hex `1.0.0`, not internal v1.32 milestone labels.

### AI-Consumption Routing
- **D-19:** Keep `doc/llms.txt` as the generated ExDoc AI-consumption map and make it route first to installation, the 1.0 contract, ownership boundaries, security/non-goals, migration lanes, demo showcase, launch evidence, and release-note guidance.
- **D-20:** Add a top-level `llms.txt` mirror or equivalent package/root pointer if it improves discoverability without creating a second source of truth. If added, it must point to the same canonical docs and avoid a separate policy vocabulary.
- **D-21:** Do not create separate adopter and maintainer AI indices unless planning can enforce ownership. A single curated hub is the least surprising path for Phase 149.

### Scope And Verification
- **D-22:** Keep implementation to docs, evidence packaging, release/announcement copy, routing, and narrow docs-contract tests if needed.
- **D-23:** Verification should prove link presence, ExDoc inclusion, AI-index routing, changelog/release-note routing, evidence-bundle boundaries, and absence of stale/misleading claims. It should not require live Hex publish proof before the real release.

### the agent's Discretion

Planning agents may choose exact filenames and section ordering, provided the canonical pack is easy to attach to the release/announcement and all public paths converge. Prefer a small number of durable docs over many tiny pages. Prefer link-based evidence aggregation over copied matrices.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/METHODOLOGY.md`
- `.planning/research/SUMMARY.md`
- `.planning/research/ADOPTION-DX.md`
- `.planning/research/ECOSYSTEM-BENCHMARKS.md`
- `.planning/research/RELEASE-MECHANICS.md`
- `.planning/research/LOCAL-PROMPT-SYNTHESIS.md`
- `prompts/Auth Domain Language - A Field Guide.md` if renamed, otherwise `prompts/Auth Domain Language — A Field Guide.md`
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md`
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`
- `prompts/biggest-gaps-elixir-auth.md`
- `prompts/elixir-opensource-libs-best-practices-deep-research.md`
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/sigra-auth-oss-lib-name.md`
- `.planning/phases/145-1-0-contract-and-release-truth/145-CONTEXT.md`
- `.planning/phases/146-release-gate-and-maintainer-runbook/146-CONTEXT.md`
- `.planning/phases/147-upgrade-and-migration-lanes/147-CONTEXT.md`
- `.planning/phases/148-evaluator-funnel-and-first-run-dx/148-CONTEXT.md`
- `README.md`
- `CHANGELOG.md`
- `mix.exs`
- `doc/llms.txt`
- `SECURITY.md`
- `docs/release-runbook-v1-0.md`
- `docs/ga-evidence.md`
- `docs/uat-ci-coverage.md`
- `guides/introduction/contract.md`
- `guides/introduction/installation.md`
- `guides/introduction/demo-showcase.md`
- `guides/introduction/upgrading-to-v1.0.md`
- `guides/introduction/migrating-from-phx-gen-auth.md`
- `guides/introduction/migrating-from-pow-guardian-ueberauth.md`
- `test/example/README.md`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts`
- `guides/assets/demo-credentials-demo-showcase-chromium.png`
- `guides/assets/admin-user-list-demo-showcase-chromium.png`
- `guides/assets/admin-user-detail-demo-showcase-chromium.png`
- `guides/assets/audit-explorer-demo-showcase-chromium.png`
- `.github/workflows/ci.yml`
- `https://hexdocs.pm/phoenix/mix_phx_gen_auth.html`
- `https://hexdocs.pm/phoenix/scopes.html`
- `https://github.com/pow-auth/pow`
- `https://hexdocs.pm/guardian/introduction-overview.html`
- `https://github.com/ueberauth/ueberauth`
- `https://llmstxt.org/`
- `https://keepachangelog.com/en/1.0.0/`
- `https://semver.org/`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `README.md` already has lane-based routing, first install commands, security posture, and release evidence links.
- `guides/introduction/contract.md` already captures version axes, supported stack, ownership boundaries, SemVer/deprecation policy, security invariants, and non-goals.
- `docs/release-runbook-v1-0.md` already contains the release gate matrix, release evidence checklist, dry-run/package inspection, publish/recovery path, post-publish checks, and first-14-day hotfix policy.
- `docs/ga-evidence.md` already works as an evidence router and defines pinned tag URL policy for release proof outside the Hex tarball.
- `docs/uat-ci-coverage.md` already records machine-vs-human proof boundaries, including upgrade/migration proof.
- `guides/introduction/demo-showcase.md` plus the four committed screenshots provide evaluator proof and explicit limitations.
- `guides/introduction/upgrading-to-v1.0.md`, `migrating-from-phx-gen-auth.md`, and `migrating-from-pow-guardian-ueberauth.md` provide the audience guidance the launch pack should route to.
- `doc/llms.txt` already exists as an AI-consumption table of contents and should be curated rather than replaced.
- `mix.exs` already controls ExDoc extras, package files, package description, and docs source-ref behavior.

### Established Patterns

- Public docs should be maps and contracts, not marketing claims.
- Release evidence should link to canonical proof and state proof boundaries.
- Generated-host ownership must stay explicit wherever upgrade, migration, or comparison copy appears.
- Sigra should preserve Phoenix-native ergonomics: generated code is inspectable, library behavior is updateable, and docs use exact commands.
- The repo's prompt corpus consistently favors calm infrastructure-grade positioning, explicit non-goals, security invariants, and proof-backed trust over broad slogans.

### Integration Points

- Launch pack integration: `docs/launch/v1.0/*`, `mix.exs` ExDoc extras/groups, README, CHANGELOG, GitHub Release body, `doc/llms.txt`, and optional top-level `llms.txt`.
- Alternatives comparison integration: Phase 147 migration guides, Phase 145 contract/non-goals, README lane table, and launch pack.
- Evidence integration: `docs/release-runbook-v1-0.md`, `docs/ga-evidence.md`, `docs/uat-ci-coverage.md`, GitHub Actions run URLs, Hex/HexDocs URLs, demo screenshots, and post-publish placeholders.
- Verification integration: docs build with warnings-as-errors, targeted grep/link contract tests, ExDoc extras inclusion, AI-index routing, and absence checks for stale overclaims.
</code_context>

<specifics>
## Specific Ideas

- Recommended doc shape:
  - `docs/launch/v1.0/announcement.md`
  - `docs/launch/v1.0/alternatives.md`
  - `docs/launch/v1.0/evidence.md`
  - optionally `docs/launch/v1.0/release-notes.md` if CHANGELOG needs a concise canonical companion rather than a long section.
- GitHub Release body should be a short distribution surface that links to the canonical launch pack, not the only copy of the launch narrative.
- Alternatives comparison should use a matrix with columns like "Best fit", "Ownership", "Operational burden", "Migration risk", "What to watch".
- Evidence bundle should include waiver row fields from the runbook only when applicable: gate, reason, approver, evidence URL, expiry.
- `doc/llms.txt` should explicitly prioritize current 1.0 paths over historical upgrade pages so AI tools do not overfit to old milestone labels.
- Announcement tone should be calm and technical: "self-hosted Phoenix auth with an updateable security core and inspectable generated host code."
</specifics>

<deferred>
## Deferred Ideas

- External blog/site/social launch copy is deferred until the repo-owned pack is stable.
- Machine-generated evidence artifacts are deferred; useful later if Sigra starts recurring audited release attestations.
- Separate adopter/maintainer AI indices are deferred unless the single curated hub proves insufficient.
- Public RC train remains fallback only if a concrete release blocker appears.
- New auth primitives, SCIM, hosted control plane, compatibility shims, and broad generated-host UI redesign remain out of scope.

### Reviewed Todos (not folded)

None.
</deferred>
