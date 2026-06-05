# Phase 145: 1.0 Contract And Release Truth - Context

**Gathered:** 2026-05-31 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 145 locks the public 1.0 contract and removes version/scope ambiguity before release automation work. It covers REL1-01, REL1-04, and CONTRACT-01..04: aligned release-truth surfaces, planning-milestone-vs-Hex-version messaging, supported stack ranges, ownership boundaries, SemVer/deprecation posture, and visible security invariants/non-goals.

This phase does not build release gates/runbooks beyond the contract and metadata alignment needed to make them coherent. Phase 146 owns the deterministic release gate matrix and maintainer runbook. Phase 147 owns upgrade/migration lanes. Phase 148 owns the evaluator funnel. Phase 149 owns launch evidence and announcement materials.
</domain>

<decisions>
## Implementation Decisions

### Release Source Of Truth
- **D-01:** Treat `mix.exs` as the canonical package version source and align `mix.exs`, `.release-please-manifest.json`, `CHANGELOG.md`, README/public docs, maintainer docs, release tag, Hex version, and HexDocs `source_ref` around a direct Hex `1.0.0` cut from `main`.
- **D-02:** Keep a public RC train out of the default plan. RCs are fallback only if a concrete blocker appears during hardening that genuinely needs external validation.

### Public Version-Axis Messaging
- **D-03:** Add or refresh a concise public explainer for Sigra's two version axes: planning milestones (`v1.x` GSD/internal tranche labels) versus installable Hex SemVer (`0.3.0` today, `1.0.0` for this release). This explainer must be visible from top-level public docs, not only in maintainer/internal docs.
- **D-04:** Remove or update stale public install-range examples as part of the same truth pass so README/HexDocs do not suggest an older package line while the release contract says `1.0.0`.

### Single 1.0 Contract Surface
- **D-05:** Define one canonical "1.0 contract" surface that covers supported Elixir, OTP, Phoenix, Ecto, Postgres, and optional-dependency posture, then link detailed docs from that surface.
- **D-06:** Use Sigra's real contract as the promise, not every transitive dependency's theoretical range. Elixir support starts from Sigra's `mix.exs` requirement (`~> 1.18`); OTP support should follow the Elixir 1.18 compatibility window; Phoenix/Ecto support should follow Sigra's declared dependency ranges and Phoenix 1.8 target; Postgres support should be stated as Sigra's tested/supported posture, not Postgrex's historical full range.
- **D-07:** Optional-dependency posture should point at `Sigra.OptionalDeps`, `Sigra.Doctor`, and `mix sigra.doctor` as the operational truth: optional features degrade or hard-fail according to documented feature wiring, and users should be able to inspect the feature matrix after install.

### Release Please 1.0 Jump
- **D-08:** Keep the existing pre-1.0 bump settings for ordinary `0.x` behavior, but use an explicit `release-as: "1.0.0"` override for the one-time 1.0 Release PR, then remove or update it after the release PR merges so subsequent releases return to conventional-commit-derived SemVer.

### Ownership Boundaries
- **D-09:** Preserve the hybrid model as the public contract: security-sensitive library code ships through the Hex package and receives dependency-update fixes; generated schemas, contexts, routes, LiveViews, templates, and product policy live in the host application.
- **D-10:** Make the 1.0 contract explicitly separate library-owned surfaces, generated-host-owned surfaces, and shared seams. Shared seams include mail, Oban/background work, OAuth providers, audit forwarding, optional companion libraries, and host policy hooks.
- **D-11:** Do not overclaim host-owned authorization, business policy, deployment controls, mail deliverability, compliance certification, or hosted identity behavior.

### Security Invariants And Non-Goals
- **D-12:** Add or standardize a top-level security invariants and non-goals table that says what Sigra guarantees versus what remains the host application's responsibility.
- **D-13:** The invariants table should cover sessions, tokens, MFA/passkeys, audit durability, optional mail/Oban/OAuth responsibilities, generated-host ownership, and host-owned authz/business policy.
- **D-14:** The non-goals remain locked for v1.32: no new auth primitives, SCIM, hosted control plane, generic compliance platform, broad generated-host UI redesign, Mailglass adapter resurrection, public RC train by default, or opinionated authorization engine.

### the agent's Discretion

Planning agents may choose the exact doc shape, file names, section ordering, and test strategy, provided the resulting work satisfies the decisions above and keeps the public contract readable from README/HexDocs. Prefer concise top-level public framing with deeper detail linked from canonical docs.

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
- `.planning/research/RELEASE-MECHANICS.md`
- `.planning/research/ADOPTION-DX.md`
- `.planning/research/ECOSYSTEM-BENCHMARKS.md`
- `.planning/research/LOCAL-PROMPT-SYNTHESIS.md`
- `mix.exs`
- `.release-please-manifest.json`
- `release-please-config.json`
- `CHANGELOG.md`
- `README.md`
- `MAINTAINING.md`
- `docs/NEXT-STEPS-MANUAL.md`
- `SECURITY.md`
- `lib/sigra.ex`
- `lib/sigra/optional_deps.ex`
- `lib/sigra/doctor.ex`
- `lib/mix/tasks/sigra.doctor.ex`
- `guides/introduction/installation.md`
- `guides/introduction/getting-started.md`
- `guides/recipes/deployment.md`
- `guides/flows/audit-logging.md`
- `guides/introduction/suite-integration.md`
- `docs/uat-ci-coverage.md`
- `docs/ga-evidence.md`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `mix.exs` already centralizes `@version`, package metadata, dependency ranges, Hex package file list, ExDoc extras, and `source_ref: "v#{@version}"`.
- `release-please-config.json` and `.release-please-manifest.json` already provide Release Please manifest-mode release automation.
- `CHANGELOG.md` already contains a "Planning milestones vs Hex releases" explainer that can be updated for the real 1.0 cut.
- `README.md` already explains the library+generator model, "Where code lives", prerequisites, installer path, and maintainer docs pointer.
- `MAINTAINING.md` already documents Release Please automation, Hex publish mechanics, manual recovery, SemVer for pre-1.0, optional-dependency SOT, and dual version axes.
- `Sigra.OptionalDeps`, `Sigra.Doctor`, and `Mix.Tasks.Sigra.Doctor` are the existing optional-dependency truth surfaces.

### Established Patterns

- Sigra prefers release truth over marketing claims: docs should say what the package owns, what generated hosts own, and where evidence lives.
- Public docs should use concise top-level entry points and link deeper detail instead of duplicating large matrices.
- Optional integrations are explicitly optional and must remain standalone-safe.
- Planning milestone labels and Hex package versions are distinct; the docs already acknowledge this but need 1.0-specific alignment.
- Security/operator claims should distinguish Sigra library guarantees from host deployment, compliance, mail, authorization, and business policy responsibilities.

### Integration Points

- Release metadata integration points: `mix.exs`, `.release-please-manifest.json`, `release-please-config.json`, `CHANGELOG.md`, tag `v1.0.0`, Hex publish, and HexDocs source links.
- Public contract integration points: README, ExDoc extras, `CHANGELOG.md`, `MAINTAINING.md`, `SECURITY.md`, and focused guide/docs pages.
- Compatibility contract integration points: `mix.exs` dependency ranges, `.tool-versions`, Phoenix/Ecto/Postgrex realities, and public prerequisites tables.
- Optional-dependency contract integration points: `Sigra.OptionalDeps`, `Sigra.Doctor`, `mix sigra.doctor`, installation/troubleshooting docs, and deployment recipe.
</code_context>

<specifics>
## Specific Ideas

- Use `release-as: "1.0.0"` for the one-time Release Please jump, then remove/update it after merge per Release Please manifest docs.
- State OTP support in terms of Elixir 1.18 compatibility, not a hand-rolled OTP policy.
- State Postgres support as Sigra's tested/supported posture rather than inheriting Postgrex's broad historical compatibility claim.
- Keep public contract language crisp enough for adopters and AI-consumption assets to quote without merging maintainer-only planning labels into install guidance.
</specifics>

<deferred>
## Deferred Ideas

None -- analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</deferred>
