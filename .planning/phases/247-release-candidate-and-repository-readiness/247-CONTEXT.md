# Phase 247: Release Candidate and Repository Readiness - Context

**Gathered:** 2026-10-06 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Prepare an accurate, adopter-readable Sigra 1.6.0 release candidate from reviewed source, and account for every inherited checkout change and open PR before release work proceeds from a clean source checkout. This phase owns candidate and adopter documentation readiness plus source/PR disposition. Phase 248 owns exact-source release-gate behavior and receipts; Phase 249 owns publishing and public release proof.
</domain>

<decisions>
## Implementation Decisions

### Candidate identity and source
- **D-01:** Keep package version 1.6.0 and the existing Release Please PR #224 as the selected release vehicle. Treat its current head only as a draft: refresh and review the candidate after Phase 246 reaches its required evidence and the inherited checkout/PR inventory is dispositioned. Reconcile the reviewed source, manifest, mix.exs version, versioned changelog section, and HexDocs source reference before calling the candidate ready.
- **D-02:** Do not describe changes as part of 1.6.0 based only on roadmap intent, local implementation, or a stale Release Please branch. Candidate-facing claims must match the final reviewed source. In particular, Phase 246 is still incomplete and its required CI evidence is outstanding.

### Release notes and adopter guidance
- **D-03:** Keep Release Please as the version and commit-history mechanism, and provide a concise curated adopter summary under the actual 1.6.0 changelog heading. Describe user-visible effects in plain language; do not present internal phase IDs or planning notes as product changes. Preserve commit traceability only where it remains useful to adopters.
- **D-04:** Fold the candidate-specific slice of the pending Release Please Unreleased-block todo into READY-01: verify that 1.6.0 notes are under the versioned heading and that no candidate-specific summary remains stranded under Unreleased. This does not add the todo’s broader durable generator/CI guard to Phase 247.
- **D-05:** Use one adopter reading path: README upgrade entry → a new v1.6 upgrade guide → the 1.6.0 changelog entry. The guide must state supported compatibility from the final package constraints and verified CI matrix, the exact dependency update and check path, whether a database migration or mix sigra.upgrade action is required, and what existing generated hosts must do to receive any shipped generated route/form changes.
- **D-06:** Make the library/generated-host ownership boundary explicit. A dependency update alone does not rewrite previously generated routes, forms, or components. If the final 1.6.0 source includes Phase 246’s generated confirmation changes, explain that existing hosts must selectively adopt the relevant host-owned files to receive those changes; fresh generated hosts receive the updated output. State no migration only after confirming the final source has no schema change. Do not recommend rerunning the installer with force over customized files.
- **D-07:** Treat adopter documentation as the user experience in this phase: lead with who is affected, what changed, what action is needed, and how to verify it. Keep troubleshooting focused on failure symptoms. No application UI, admin UI, or visual design-system changes are in scope.

### Repository and PR readiness
- **D-08:** Before selecting candidate source, inventory both committed changes after the trusted base and all modified/untracked paths in the inherited checkout, and record a disposition for every open PR. Classify each as release-blocking, release-relevant, or separate follow-up. Preserve all inherited changes in their existing durable location until their disposition is recorded.
- **D-09:** Prepare release work from a clean, reviewed source checkout after the inventory is complete. Keep unrelated Phase 244, historical evidence, planning, and other inherited work out of the candidate unless it has an explicit release disposition and is present in the reviewed source.
- **D-10:** Refresh live PR and source state when readiness work executes. The 2026-10-06 snapshot is context only: PR #224 was open and mergeable at head 276e8c3f; 14 PRs were open. The checkout was on phase-244-playwright-measurement at e16f413d4, with Phase 246 commits, additional dirty paths, and no upstream. These facts can change and are not release evidence.

### the agent's Discretion
- Choose the inventory artifact shape and the clean-checkout mechanics that best preserve the inherited branch and make every disposition auditable.
- Choose the exact README placement, guide wording, changelog headings, and compatibility presentation using existing Sigra documentation patterns.
- Choose only compatibility claims and verification commands supported by the final candidate source and the project’s actual CI matrix.
- Reuse existing Release Please, HexDocs, and package-verification seams. Do not design Phase 248 automation as part of this phase.

### Folded Todos
- Candidate-specific portion of .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md: ensure the 1.6.0 reader-facing summary is folded into the versioned release section and is not stranded under Unreleased. The todo’s standing automation/CI solution remains deferred.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and project decisions
- .planning/ROADMAP.md § v1.49 Phase 247, plus Phase 248 and Phase 249 boundaries.
- .planning/REQUIREMENTS.md § READY-01 and READY-02.
- .planning/PROJECT.md — product purpose, hybrid library/generator model, and 1.6.0 target.
- .planning/METHODOLOGY.md — automation-first evidence, phase boundaries, decisive defaults, and adopter-centered truth.
- .planning/STATE.md — current milestone state and Phase 246 blocker.
- .planning/phases/246-generated-confirmation-recovery/246-CONTEXT.md — locked confirmation behavior and generated-host ownership.
- .planning/phases/246-generated-confirmation-recovery/246-03-PLAN.md and .planning/phases/246-generated-confirmation-recovery/246-MIX-CI-BLOCKED.md — current Phase 246 implementation/evidence boundary.
- .planning/research/v1.49-release-scope/REPO-STATE.md — inherited checkout and release-scope evidence.

### Release and adopter documentation
- release-please-config.json and .release-please-manifest.json.
- .github/workflows/release-please.yml and .github/workflows/hex-publish.yml.
- mix.exs — package version, constraints, files, ExDoc extras, and source reference.
- CHANGELOG.md — existing versioned release notes, Unreleased warning, and planning-milestone/SemVer distinction.
- README.md, guides/introduction/installation.md, guides/introduction/troubleshooting-install.md, and guides/introduction/upgrading-to-v1.5.md.
- .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md — folded candidate-specific check.
- prompts/elixir-opensource-libs-best-practices-deep-research.md.
- prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md.
- prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md.
- prompts/Building the gold-standard Elixir:Phoenix authentication library.md.
- [Release Please manifest guidance](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md).
- [Hex package publishing and dry-run inspection](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html).
- [Phoenix authentication generator reference](https://phoenix.hexdocs.pm/Mix.Tasks.Phx.Gen.Auth.html).
- [Ecto changelog](https://github.com/elixir-ecto/ecto/blob/master/CHANGELOG.md).
- [Laravel upgrade guide](https://laravel.com/framework/docs/12.x/upgrade).
- [Live Release Please PR #224](https://github.com/szTheory/sigra/pull/224) — recheck before execution.

No additional application UI or visual-design contract applies to this phase.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Release Please already updates the release manifest, mix.exs version, and changelog through PR #224.
- The release workflows already compare the version/tag/manifest and HexDocs source reference; the manual publish path also has package inspection and documentation checks that Phase 248 will exercise.
- The v1.5 changelog and upgrading-to-v1.5 guide already separate adopter-facing changes, upgrade notes, and host-owned generated code.

### Established Patterns
- Sigra is a hybrid library plus generator: security-critical shared behavior updates through the package, while generated routes, schemas, LiveViews, and components become host-owned files.
- Package SemVer is the adopter version truth. GSD milestone numbers such as v1.49 are maintainer coordination labels.
- Current documentation already distinguishes Added, Changed, and Upgrade notes, but generated Phase-prefixed bullets need a reader-facing summary.
- Release Please source state and local inherited work are separate: the live 1.6.0 PR changes three release metadata/changelog files, while the active local checkout contains Phase 246 commits and other inherited changes.

### Integration Points
- Candidate version truth spans the Release Please PR, manifest, mix.exs, changelog, ExDoc source_ref, README, and the new version-specific upgrade guide.
- The adopter path should start at README, explain affected existing generated hosts in the guide, and link to the versioned changelog for release detail.
- Repository readiness joins a full local commit/path inventory with a live open-PR inventory; later release-gate and publish evidence remain with Phases 248 and 249.
</code_context>

<specifics>
## Specific Ideas

- Keep the 1.6.0 package target and PR #224, while refreshing the candidate after Phase 246 evidence and source disposition are complete.
- Explain the confirmation changes only if they are in the final reviewed release source: the dependency update does not rewrite existing generated host code; existing hosts need selective adoption, and no database migration is required if confirmed against the final source.
- Give adopters an explicit update/check path from their host app root, using the bounded dependency constraint ~> 1.6.0 and commands verified against the final package.
- The current generated 1.6.0 notes contain Phase 242/244 identifiers. Replace those as reader-facing descriptions with concise statements of adopter-visible effects.
- The live PR list and working-tree state are snapshots; re-inventory at readiness execution time.
</specifics>

<deferred>
## Deferred Ideas

- Durable Release Please configuration or CI prevention for the Unreleased-block orphaning failure; Phase 247 only checks the current 1.6.0 candidate’s changelog placement.
- Broad doc/llms.txt version-drift automation and the full packaged-docs planning-reference sweep.
- Cleanup of unrelated legacy upgrade-guide links; the new v1.6 guide should use working links and existing documentation patterns.
- Release-gate polling/permissions/receipt changes, owned by Phase 248, and package publication/public proof, owned by Phase 249.
- Hex 1.20.0 resolver-ranking remediation, explicitly outside the v1.49 roadmap.
- Application UI redesign, admin UI work, and broad generated-auth coverage.

### Reviewed Todos (not folded)
- .planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md — durable generated-index drift handling is outside READY-01; doc/llms.txt is not in the Hex package file list.
- .planning/todos/pending/2026-09-18-packaged-docs-surface-carries-planning-paths-into-the-hex-tarball.md — broader package-documentation hygiene is outside the candidate-specific requirement; keep phase identifiers out of the 1.6.0 product summary without turning this into a wholesale docs sweep.
- .planning/todos/pending/2026-09-16-upgrade-guide-link-removal-was-lossy-where-a-lossless-fix-existed.md — concerns older guides; the new v1.6 guide will use valid adopter-facing links.
- .planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md and .planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md — release-lane behavior is outside Phase 247 and should be handled only within its owning scope.

Other todo.match-phase results were broad keyword matches unrelated to READY-01/02 and remain outside this phase.
</deferred>
