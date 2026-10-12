# Phase 249: Publish and Prove Sigra 1.6.0 - Context

**Gathered:** 2026-10-09 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Finish the already-published Sigra 1.6.0 release proof: verify that Hex, versioned HexDocs, the Git tag, the gated source commit, required CI, and a committed machine-readable receipt all identify the same release. Close out the live repository state by recording dispositions for open PRs and reconciling local worktrees without losing inherited work. This phase also includes the user-approved `doc/llms.txt` refresh and a durable drift guard that keeps ExDoc's tracked index current without adding a manual step to Release Please. It does not reopen the 1.6.0 package contents or redesign the release platform.

Current hosted evidence identifies release run `37875238705`, attempt 3, tag `v1.6.0`, source SHA `9e80cb78d6374b1ed4074d5fef6b613fee879dca`, and a successful published outcome. The verified workflow artifact still needs to be copied into durable committed evidence. Live `main` was `e2fa303017364c7e496c3c620f7b709c8e90c8fb`; open Release Please PR #302 proposes 1.6.1. Refresh all live identities before planning and execution. The shared root checkout is an older, dirty branch and is not the source of truth for release code.
</domain>

<decisions>
## Implementation Decisions

### Exact release identity and public proof
- **D-01:** Treat tag `v1.6.0` and gated source SHA `9e80cb78d6374b1ed4074d5fef6b613fee879dca` as one immutable identity. Verify the Hex package metadata and published version, versioned HexDocs availability, source-reference destination, and Git tag resolution against that identity; a matching version string alone is insufficient.
- **D-02:** Verify the live HexDocs source reference through to the GitHub tag and commit. The release workflow's rendered-link string check is useful but does not by itself prove that the live destination resolves to the intended source.
- **D-03:** Commit a sanitized, machine-readable 1.6.0 receipt derived from the successful GitHub workflow artifact. It must identify the release run/attempt, package version, tag, gated source SHA, required CI run, Hex package, versioned docs, and source reference. Retain the hosted artifact as provenance; never include secret values.
- **D-04:** Bind required-CI evidence to the release source commit that produced `v1.6.0`. Record later protected-main commits separately so post-release maintenance is not mistaken for the package's source. Use current GitHub run and tag data, not stale local planning snapshots.

### Generated documentation index and hands-off releases
- **D-05:** Keep `doc/llms.txt` as a tracked ExDoc-generated artifact. Refresh it for the current 1.6.0 main source and add a required build-then-compare check after `mix docs --warnings-as-errors`; the check must cover both the version title and generated navigation/module rows.
- **D-06:** Keep Release Please version bumps fully automated. A trusted-main automation path must refresh only `doc/llms.txt` on the fixed Release Please candidate before exact-head auto-merge can succeed, then allow ordinary CI to rerun on the new head. The docs build receives no write token; the narrowly scoped write step rechecks the candidate SHA, uses a non-force update, and fails closed on races or errors. A stale or failed candidate never bypasses the required drift check or auto-merge gate.
- **D-07:** Do not rely on Release Please `extra-files` alone for this artifact: it can update a version marker but cannot regenerate ExDoc's dynamic module/navigation rows, and ExDoc removes inline updater annotations when rebuilding. Keep normal PRs subject to the same drift check; their failure message should say how to regenerate and commit the index.

### Repository and PR closeout
- **D-08:** Refresh the complete worktree and open-PR inventories during closeout. Record each PR's release-blocking, release-relevant, or separate-follow-up disposition. The previously observed snapshot had five worktrees, extensive dirty root changes, fourteen open PRs, and Release Please PR #302 for 1.6.1; treat those counts and identities as prompts to recheck, not current proof.
- **D-09:** Preserve inherited and user work until its disposition is explicit and durable. Do not use reset, clean, force-push, or unrelated PR merges to manufacture a clean status. Satisfy the all-worktrees-clean criterion only after preserving each change set; if a change cannot be safely dispositioned, report the remaining blocker rather than claim success.
- **D-10:** Apply the existing guarded exact-head Release Please auto-merge policy only to eligible Release Please candidates with successful required CI on their current head. Record other PRs as follow-up when they are unrelated; do not merge them merely to reduce the queue.

### the agent's Discretion
- Choose the receipt's stable project path and exact schema while retaining the required source, tag, package, documentation, CI, run, and attempt identities.
- Choose the helper/workflow boundaries for index refresh, bounded race recovery, and actionable diagnostics, while keeping the build unprivileged and the write permission narrowly scoped.
- Choose deterministic tests for generated-index equality, version/module drift, candidate refresh, stale-head races, and failure behavior. Use the existing ExDoc and GitHub Actions seams rather than adding a new publishing platform.
- Choose the closeout ledger format and preservation mechanics after inspecting each live worktree and PR. Do not assume the old 60-path/14-PR snapshot is complete.
- Keep the operator experience centered on a clear CI result and linked receipt. This is release engineering and documentation work; no product UI, admin UI, or brandbook changes apply.

### Folded Todos
- `.planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md` — refresh the 1.6.0 index and add a durable CI drift guard that also keeps Release Please candidates automatic.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and project contract
- `.planning/ROADMAP.md` § Phase 249 — release proof scope and three success criteria.
- `.planning/REQUIREMENTS.md` § REL-01 and REL-02 — live Hex/HexDocs/source proof, protected-main CI, committed receipt, and closeout requirements.
- `.planning/PROJECT.md` — product goal and 1.6.0 milestone context.
- `.planning/METHODOLOGY.md` — automation-first verification, evidence feasibility, preservation, and escalation boundaries.
- `.planning/VERIFICATION-POLICY.md` — deterministic evidence and exact-SHA expectations.
- `.planning/STATE.md` — current GSD route and outstanding maintenance; refresh before execution.

### Decisions and prior release work
- `.planning/phases/247-release-candidate-and-repository-readiness/247-CONTEXT.md` — candidate truth, preservation of inherited work, and release/PR inventory boundaries.
- `.planning/phases/248-exact-source-release-gate/248-CONTEXT.md` — tag/SHA identity, protected exact-head auto-merge, required CI, publish sequencing, and receipt contract.
- `.planning/phases/248-exact-source-release-gate/248-VERIFICATION.md` — historical 13/18 report; treat as stale maintenance input and re-evaluate separately.
- `.planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md` — folded ExDoc index drift problem and original guard recommendation.

### Release code and evidence seams
- `.github/workflows/ci.yml` — required `ci-gate` and current ExDoc build placement.
- `.github/workflows/release-please.yml` — trusted main release orchestration and Release Please token boundary.
- `.github/workflows/hex-publish.yml` — manual dry-run/publish recovery path and version/source validation.
- `.github/workflows/release-pr-automerge.yml` — exact-head, required-CI guarded merge behavior.
- `scripts/ci/release-receipt.sh` and its tests — terminal release receipt schema and validation.
- `scripts/ci/release-post-publish-verify.sh` — post-publish verification and current source-link evidence.
- `mix.exs`, `.release-please-manifest.json`, `release-please-config.json`, and `doc/llms.txt` — package version, generated docs configuration, and tracked-index state.
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — hands-off Release Please/Hex flow, least-privilege CI, and docs-as-a-gate guidance.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — Elixir OSS package/documentation and tagged source-link expectations.

### Live and primary-source references
- [Release workflow run 37875238705](https://github.com/szTheory/sigra/actions/runs/37875238705) — successful attempt 3 and retained 1.6.0 result artifact; refresh the artifact and exact run data before receipt commit.
- [Protected main at discussion time](https://github.com/szTheory/sigra/commit/e2fa303017364c7e496c3c620f7b709c8e90c8fb) — later post-release main commit, distinct from the 1.6.0 package source.
- [Open Release Please PR #302](https://github.com/szTheory/sigra/pull/302) — 1.6.1 candidate observed during discussion; refresh before disposition.
- [Release Please customization docs](https://github.com/googleapis/release-please/blob/main/docs/customizing.md) — supported extra-file updaters and limitations.
- [Release Please manifest-releaser docs](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) — plugin lifecycle and implementation boundary.
- [ExDoc repository](https://github.com/elixir-lang/ex_doc) and [ExDoc changelog](https://hexdocs.pm/ex_doc/changelog.html) — Markdown formatter and generated `llms.txt` behavior.
- [GitHub Actions event-trigger documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) — token-triggered workflow behavior and event-chain constraints.
- [GitHub Actions secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use) — token, permission, and workflow-code security boundaries.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 248 already produces a terminal success artifact keyed by release run and attempt. Reuse and validate its schema rather than inventing a second release identity model.
- `release-post-publish-verify.sh` already checks published version and rendered source-link text; extend the evidence boundary with live destination resolution rather than replacing its local contract checks.
- `release-pr-automerge.yml` already waits for required CI and merges only the current head SHA. The docs refresh must create a new candidate head and let this existing guard observe fresh CI.
- `mix docs --warnings-as-errors` already runs in required library CI and the release lane. Add the targeted tracked-file diff at the existing required docs seam.
- ExDoc's generated `doc/llms.txt` contains both a package-version title and generated navigation/module rows; the entire tracked file must match the build output.

### Established Patterns and Risks
- The published 1.6.0 artifact and workflow run bind to source SHA `9e80cb78d6374b1ed4074d5fef6b613fee879dca`; the successful run is not a substitute for committing its verified receipt.
- Live main's `mix.exs` reports 1.6.0 while its tracked `doc/llms.txt` title still reports 1.5.0. Open Release Please PR #302 reports 1.6.1 while its title is also 1.5.0. This confirms version-only refresh and future-candidate automation must both be covered.
- The root checkout is at `576c1e572bf9bbe0142b9d260167fe57c5e63beb` on `phase-244-playwright-measurement`, with inherited dirty files. Use a clean, current main-based workspace for release-source investigation and protect the root work.
- Release Please `extra-files` cannot regenerate dynamic ExDoc rows. A plain `mix docs` then diff gate would correctly fail stale candidates but would strand the automated release unless a trusted refresh job updates the candidate and triggers new required CI.
- GitHub suppresses ordinary workflow triggers caused only by `GITHUB_TOKEN` pushes. Any automatic candidate refresh must deliberately preserve the fresh-CI/auto-merge event chain, scope the write token away from the build, and fail closed on stale-head races.
- The existing repository prompts favor Release Please, Hex, ExDoc, least-privilege permissions, deterministic CI, and clear machine-readable evidence. This phase has no frontend or admin UI surface.

### Integration Points
- The required CI index-drift check belongs next to the existing ExDoc build and must feed `ci-gate`.
- A trusted-main refresh step/job must update only the fixed Release Please candidate's `doc/llms.txt`; its new push must produce an ordinary exact-head CI run before the existing auto-merge gate can pass.
- Phase 249's committed receipt joins the published package, versioned docs, source tag/SHA, and release CI run. The worktree/PR disposition ledger records repository closeout separately.
</code_context>

<specifics>
## Specific Ideas

- Make the happy path fully automatic: Release Please proposes the version; ExDoc index refresh runs without maintainer intervention; ordinary required CI proves the generated index is current; the existing exact-head gate merges only a green current candidate.
- Keep `doc/llms.txt` user-facing and generated. A regular contributor should receive a concrete CI message that points to the command and file to regenerate; Release Please candidates should be repaired by trusted automation.
- Keep the 1.6.0 release source identity separate from later main changes and from the currently open 1.6.1 Release Please candidate.
- Preserve every inherited change set until its owner and disposition are clear. A clean-worktree claim must have evidence, not an aggressive cleanup command.
</specifics>

<deferred>
## Deferred Ideas

- New publishers, a broad CI/CD redesign, a multi-repository release platform, or a custom ExDoc/Release Please plugin.
- Merging unrelated Dependabot, evidence, or product PRs solely to empty the queue; each receives an explicit follow-up disposition instead.
- Phase 248's separate hosted manual-dry-run and failure/cancellation-artifact verification maintenance; Phase 249's published success proof does not close those historical gaps.
- Auth/admin UI, brandbook, product API, or unrelated feature work; this phase has no UI/UX design surface.

### Reviewed Todos (not folded)
- Other lexical matches from `todo.match-phase 249` were not directly about publishing/proving 1.6.0 and remain pending; do not auto-acknowledge them.
</deferred>

---

*Phase: 249-publish-and-prove-sigra-1-6-0*
*Context gathered: 2026-10-09*
