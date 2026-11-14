# v1.49 Release Scope — Research Synthesis

**Status:** Research adopted for milestone v1.49. The user delegated the package-version choice; use the existing protected-main Release Please PR #224 proposing `1.6.0`. The GSD milestone remains v1.49. This research document itself does not publish anything.
**Research date:** 2026-10-06

## Executive Summary

Sigra's strongest v1.49 candidate is a bounded release-delivery milestone using the existing Release Please → exact-source CI gate → Hex workflow, ending in a published package and a durable receipt connecting source commit, version/tag, CI, package, and versioned HexDocs. The user delegated the package-version decision, so use protected-main PR #224 proposing `1.6.0`; its generated release notes identify package changes since 1.5.0, including runtime and generated-template work. Curate the generated notes and align adopter guidance to `~> 1.6.0`. v1.48 was an internal planning milestone, not a package release; REL-06 remains unsatisfied.

The adopter outcome is a clear account of what changed, compatibility and upgrade action, and version-specific documentation; the maintainer outcome is a reproducible, recoverable release with durable machine evidence. Align install guidance to `~> 1.6.0`; `~> 1.5.0` excludes 1.6.0. Neither 1.5.1 nor 1.6.0 alone repairs Hex's `latest_stable_version=1.20.0`, changes an existing lockfile, or fixes the broader resolver behavior. Recommended hardening is limited to this release lane: prevent cancellation of an active release, prove the tag resolves to Release Please's SHA, narrow permissions/secrets, and preserve gate plus success/failure receipts.

## Jobs to Be Done

- **Maintainer (inference):** “Cut the intended release from the exact reviewed source, prove it passed the release checks, publish the artifact and docs consistently, and retain enough evidence to diagnose or safely recover from partial failure.” Evidence: the current release workflow already contains the review PR, SHA gate, package checks, publish, and post-publish checks; its safety and recovery needs are called out in [AUTOMATION.md](AUTOMATION.md).
- **Adopter (inference from repository positioning and project prompts):** “Tell me what changed, whether it fits my Phoenix/Elixir app, and exactly what I must update or migrate without surprising auth behavior or generated-host changes.” The useful path is versioned changelog → explicit compatibility/action statement → the correct bounded dependency line → `mix deps.update sigra` and host-app checks, retaining/reviewing `mix.lock`. Source facts and limits are in [ADOPTER-DX.md](ADOPTER-DX.md).

## Strategy Comparison

| Strategy | Example / fit | Pros | Cons and tradeoffs | Recommendation |
|---|---|---|---|---|
| **Reviewed Release Please PR, then existing gated publish** | Current Sigra flow; open PR #224 proposes 1.6.0, then tag/SHA gate and Hex publishing | Reviewable version/changelog handoff; reuses existing checks and recovery route; no new publisher | Generated notes misclassify internal work; cancellation, mutable-tag checkout, permissions, and evidence gaps need bounded attention | **Adopted.** The user delegated version choice; keep the existing route, curate notes, and publish only the exact SHA whose gate passed. |
| **Manual tag dispatch/publish as normal path** | Existing runbook's manual recovery route | Explicit operator control; familiar fallback when automation is interrupted | Duplicates guards, adds routing burden, and a successful dispatch does not prove that the requested source SHA was tested | Retain only as documented recovery, with the same machine gates and receipt. |
| **Build once, attest tarball, publish that same artifact** | Proposed future supply-chain expansion | Could preserve a digest and provide build provenance | Current `mix hex.publish` rebuilds from source; research does not establish a supported exact-tarball publish path. A sidecar attestation would not prove Hex received those bytes; expands permissions and workflow surface | Defer; do not make it a release prerequisite. |
| **Version jump to outrank 1.20.0** | Publish 1.21.0 or higher to reclaim latest-stable ranking | Could change the visible ranking signal | Burns intervening version range and changes product/version policy; v1.48 explicitly excluded this cosmetic resolution strategy | Out of scope; do not fold into a patch-release milestone. |

## Consensus, Tensions, and Source Reconciliation

**Consensus:** all reports favor the existing Release Please path, versioned docs, and machine-verifiable release evidence. The user's delegation selects the existing `1.6.0` candidate. Use bounded `~> 1.6.0` guidance; omit internal CI/planning bookkeeping from adopter prose and state exactly what action the host app needs. Keep one normal publisher.

**Tensions resolved by chronology:** Phase 242's [safety closeout](../../milestones/v1.48-phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-SAFETY-CLOSEOUT.md) is dated 2026-09-22 and accurately states that registry, docs-root, resolver, and release outcomes were then unproven. Later evidence recorded in [v1.48 requirements](../../milestones/v1.48-REQUIREMENTS.md) supersedes only part of that snapshot: a September 22 dispatch completed the retirement and docs-revert steps, and an October 5 live recheck confirmed `1.20.0` is retired and the HexDocs root serves 1.5.0 docs. The same later check still found `latest_stable_version: 1.20.0`; REL-06 remains unsatisfied, with no 1.5.1 release receipt. Thus do not repeat the closeout's earlier “retirement unproven” as current archive truth, and do not turn successful retirement/docs correction into a resolver fix or package release.

**Version-lineage correction:** the protected upstream `main` was `5a00b90d` and CI was green there at the October 6 research check, but commit-subject counting was not sufficient to infer Release Please's version. The live Release Please PR [#224](https://github.com/szTheory/sigra/pull/224) was open against that exact main SHA and proposed `1.6.0`; its generated changelog had three feature entries. It was clean and its checks, including `ci-gate`, passed, but it had no recorded review decision. The user has since delegated the package-version choice, so v1.49 adopts the existing 1.6.0 candidate; recheck PR state, CI, and source lineage at execution time.

**Repository readiness:** there is one local worktree, on `phase-244-playwright-measurement` at `94051d8c`, with inherited uncommitted changes and no upstream. There are 14 open PRs: #224 is the release candidate; #283 is the Phase 244 draft; #266 and #219 are evidence/proof drafts; ten are Dependabot updates. Phase 247 should refresh and classify all open PRs by release relevance and disposition, then preserve or route worktree changes before producing a clean release source. It must not merge every open PR just to make the queue look empty. `main` CI was green on `5a00b90d` at the October 6 check; that is a starting snapshot, not proof for a later release SHA. The `1.20.0` ranking remains time-bound to the October 6 Hex API observation.

## Candidate v1.49 Goal and Requirements

**Adopted goal:** Complete the existing Release Please `1.6.0` release from the exact reviewed source, close the committed generated-confirmation fast-follow (SEED-011 findings A and D) plus adjacent verified finding B, provide adopter-facing upgrade information, and finish with green CI on the release/main source, clean local worktrees, a triaged open-PR inventory, and durable machine evidence connecting source SHA, package, and versioned docs.

Milestone requirements:

1. **Generated confirmation recovery:** verify SEED-011 findings A, B, and D against current templates and generated-host behavior; correct confirmed defects and prove anonymous and signed-in confirmation outcomes, acceptance of the spaced email code, and visible feedback with deterministic tests. B is included because it is a verified high-severity defect in the same confirmation journey. No human UAT is required for these contracts.
2. **Release PR correctness:** review #224 against the actual package diff; `mix.exs`, manifest, changelog heading, tag, package metadata, and ExDoc `source_ref` must agree. Curate notes and ensure the `Unreleased` warning cannot leak into packaged text.
3. **Repository readiness:** refresh and disposition every open PR as release-blocking, release-relevant, or separate follow-up; preserve inherited user changes; create a clean release source and finish with no dirty local worktrees.
4. **Exact-source release gate:** resolve the tag and assert it equals Release Please's output SHA before package work; test/build docs and inspect the unpacked Hex artifact from that immutable source. Preserve current tests, warning-free docs, package-content assertions, and Hex dry run.
5. **Bounded workflow hardening and evidence:** let an active release run finish without losing the latest Release Please evaluation; scope permissions by job; expose `HEX_API_KEY` only to the final publish step; retain the recovery path and machine-readable gate/success/failure receipts with version/tag, source SHA, workflow/run identity, verdict, URLs, attempts/timestamps, and failure/cancellation state.
6. **Published adopter outcome:** publish 1.6.0 from the gated source; verify Hex package, exact-version HexDocs and source link, final main CI, all PR dispositions, clean worktrees, and a committed receipt. Include accurate compatibility, generated-host action or explicit no-action statement, `~> 1.6.0`, and update/check commands.

## Bounded Phase Sequence (candidate)

Proposed phases begin at **246** and continue the v1.48 numbering.

| Phase | Candidate outcome | Rationale and evidence boundary |
|---|---|---|
| **246 — Generated confirmation recovery** | Verify and close the pre-committed SEED-011 findings A and D plus adjacent verified finding B, with generated-host regression checks for confirmation state, code paste, and visible feedback | Honors the explicit v1.48 fast-follow and closes the closely coupled high-severity confirmation-code issue while keeping email styling and remaining findings out of scope. |
| **247 — Release candidate and repo readiness** | Review the 1.6.0 package diff and adopter notes; refresh and disposition all open PRs; preserve inherited worktree changes and establish a clean release source | Align to the existing Release Please candidate without merging unrelated PRs or sweeping the mixed Phase 244/245 tree into the release. |
| **248 — Exact-source release automation** | Harden the existing Release Please lane: prevent active-run cancellation, prove tag/output-SHA equality, scope permissions and Hex secret, and retain gate/failure receipts; require green CI on the exact release source | Make the current release path reproducible; preserve the existing Release Please and `ci-gate` design. |
| **249 — Publish and public evidence** | Complete the reviewed release PR through the existing pipeline; verify Hex package, HexDocs, source link, and committed receipt against the same version/SHA; verify final main CI green, PR dispositions, and clean worktrees | End with the actual public release and evidence, not only release readiness. |

This order closes the committed adopter blocker first, then resolves source lineage, PR queue, and inherited worktree state before hardening the release lane and publishing. PR #224's checks were green at research time, but it was still open and had no recorded review decision; recheck CI and version/source alignment immediately before merge.

## Deterministic Evidence, Shift Left, and Risks

Follow [.planning/VERIFICATION-POLICY.md](../../VERIFICATION-POLICY.md): map every observable criterion to deterministic local/CI/API checks, capture exact command/run/artifact references, and treat stale, skipped, cancelled, unrelated, or missing signals as unproven. Prefer contract checks for version/changelog/fold alignment; integration checks for tag→SHA→CI→package identity; live GitHub/Hex/HexDocs observations for public state. Automate package inspection, warning-as-error docs, tests, dry run, post-publish version/docs/source checks, and failure receipts. Human review should be limited to editorial claims about shipped security/auth impact and upgrade actions that automation cannot prove; the already granted publication authorization is not a later workflow checkpoint unless the scope materially changes.

Key risks: active workflow cancellation can interrupt a publish; a mutable tag can diverge from the gated SHA; broad workflow permissions and dry-run secret exposure increase credential scope; generated notes can surface internal work; a missed changelog fold can ship the `Unreleased` warning; a green aggregate run or incomplete receipt can hide partial failure. The reports recommend bounded fixes for these rather than a new release system. Existing CI observations in AUTOMATION.md are point-in-time and are not a fresh release-tag gate.

## Explicitly Deferred / Out of Scope

- **Phase 245 branch-prune / REPO-04:** v1.48 records this unsatisfied, with unresolved historical PR-base and cleanup-history pairs. Keep it as separate carryover; do not make branch pruning a dependency or piggyback it on release work.
- **Auth browser and axe coverage:** v1.48 carries generated-auth browser coverage breadth and missing axe coverage as future work. They do not belong in this release-delivery scope.
- **`latest_stable_version=1.20.0` resolver question:** explicitly defer a version-policy or Hex-administrator remedy. 1.20.0 remains visible/retired per later archive evidence, but retirement does not change ranking/resolution; publishing 1.5.1 or 1.6.0 will not be described as a repair. Keep bounded install guidance and check public metadata again during the selected release.
- **New auth features, admin/UI work, brand changes, release platform, normal manual publishing, version jump to 1.21.0+, and exact-tarball attestation:** outside this bounded candidate.

## Prompt and Brandbook Inputs

The relevant project-authored inputs are `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` for release-lane framing, `prompts/elixir-opensource-libs-best-practices-deep-research.md`, `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md`, and `prompts/Auth Domain Language — A Field Guide.md` for audience and terminology. These prompts informed hypotheses and writing; they are not independent evidence of adopter behavior. The Phoenix and LiveView best-practice prompts and `brandbook/` were out of scope: no auth UI, visual identity, or brand asset change is proposed.

## Confidence and Gaps

| Area | Confidence | Notes |
|---|---|---|
| Existing release path and repository baseline | High | Directly inspected workflow, version metadata, changelog, and archive; remote CI is only a dated snapshot. |
| Automation hardening recommendations | Medium-high | Concrete workflow hazards are identified; implementation and live failure-path behavior remain to be proven. |
| Adopter JTBD and note format | Medium | Inferred from project prompts, docs routes, and Elixir library conventions, not adopter interviews. |
| Package version and release contents | Medium | PR #224 proposed 1.6.0 and had passing CI at research time; compatibility and adopter action still need review against the package diff. |
| Hex ranking / retirement | Medium, time-bound | v1.48 archive records October 5 live state; recheck at release time. No evidence supports resolver repair from 1.5.1. |

Open gaps for execution: verify current behavior for SEED-011 findings A, B, and D; refresh and disposition all current open PRs; preserve the dirty worktree content while producing a clean release worktree; curate PR #224 notes; rerun exact-source gates; repeat live Hex/API/docs observations immediately before and after publication.

## Sources

- Research reports: [ECOSYSTEM.md](ECOSYSTEM.md), [AUTOMATION.md](AUTOMATION.md), [REPO-STATE.md](REPO-STATE.md), [ADOPTER-DX.md](ADOPTER-DX.md).
- Project policy/archive: [Verification Policy](../../VERIFICATION-POLICY.md), [v1.48 Requirements Archive](../../milestones/v1.48-REQUIREMENTS.md), [Phase 242 Safety Closeout](../../milestones/v1.48-phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-SAFETY-CLOSEOUT.md), [mix.exs](../../../mix.exs), [CHANGELOG.md](../../../CHANGELOG.md), [.release-please-manifest.json](../../../.release-please-manifest.json), [release-please workflow](../../../.github/workflows/release-please.yml).
- External sources aggregated by the reports: [Hex publishing](https://hex.pm/docs/publish), [Hex usage](https://hex.pm/docs/usage), [Hex retirement task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html), [Hex FAQ](https://hex.pm/docs/faq), [HexDocs](https://hexdocs.pm/), [Sigra versions](https://hex.pm/packages/sigra/versions), [Semantic Versioning](https://semver.org/), [Release Please Action](https://github.com/googleapis/release-please-action), [GitHub Actions concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency), [GitHub secure use](https://docs.github.com/en/actions/reference/security/secure-use), [Ecto changelog](https://github.com/elixir-ecto/ecto/blob/master/CHANGELOG.md), [Plug changelog](https://github.com/elixir-plug/plug/blob/main/CHANGELOG.md), [Phoenix changelog](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
