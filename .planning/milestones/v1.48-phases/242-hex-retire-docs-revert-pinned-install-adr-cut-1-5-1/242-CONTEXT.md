# Phase 242: Hex Retire + Docs Revert + Pinned-Install ADR + Cut 1.5.1 - Context

**Gathered:** 2026-09-20 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Correct the public release experience around the stray `sigra` `1.20.0`: retire that
release through a trusted CI path, remove only its outdated HexDocs, document the real
resolver behavior and safe installation constraint, then publish `1.5.1` from proven-green
provenance. This phase does not add authentication features, alter generated-host behavior,
or attempt an expired package-tarball revert.
</domain>

<decisions>
## Implementation Decisions

### Hex remediation and public evidence

- **D-01:** Build a dedicated, narrowly scoped `workflow_dispatch` remediation lane for the
  fixed target `sigra 1.20.0`; do not overload the ordinary Hex publish recovery workflow.
  The existing `secrets.HEX_API_KEY` is available only to the mutation steps. The workflow
  itself does not commit evidence or receive unnecessary repository-write authority.
- **D-02:** Capture and commit sanitized, machine-readable public observations at three
  boundaries: before retirement, after retirement/before the docs revert, and after the docs
  revert. Also capture isolated clean-resolver output. This separates effects rather than
  attributing an observed final state to the wrong mutation.
- **D-03:** Retire `1.20.0` with Hex's `invalid` reason and a concise truthful message; use
  the current noninteractive CLI/API-key path and validate its exact secret/OTP behavior in
  the workflow. No secret, raw key, or sensitive request material may appear in logs,
  artifacts, plans, evidence, or commit messages.
- **D-04:** Run `mix hex.publish docs --revert 1.20.0` only. Never attempt the release-tarball
  revert, whose allowed window is closed. Verify the HexDocs root live after the docs change.
  Whether the docs operation affects package metadata or root-doc routing is measured and
  reported, never inferred.

### Resolver-safe adopter documentation

- **D-05:** Correct the requirement's shorthand from `{:sigra, "~> 1.5"}` to
  `{:sigra, "~> 1.5.0"}` everywhere the supported installation line is presented. This is a
  required correctness repair: two-segment `~> 1.5` permits `1.20.0`; three-segment
  `~> 1.5.0` admits the 1.5 line only.
- **D-06:** Prove, in a fresh `HEX_HOME` without `HEX_IGNORE_RETIREMENTS`, both consumer
  paths: `~> 1.0` selects the retired phantom release and emits the retirement warning, while
  `~> 1.5.0` selects a real 1.5.x release cleanly. Retirement remains advisory: it does not
  make a version unresolvable. `latest_stable_version` is observed in pre/post API artifacts,
  not promised from undocumented behavior.
- **D-07:** Create **ADR 005**, preserving ADR 003's ownership of tag-derived publishing and
  ADR 004's existing number. ADR 005 records the safe pin, retirement's non-effect on
  resolver eligibility, immutable-package versus independently reversible-docs boundaries,
  and the measured docs-revert outcome. Reconcile current, actionable project records that
  still say retirement restores resolver/latest behavior; leave archival history historical.

### 1.5.1 release provenance and shipped truth

- **D-08:** Cut `1.5.1` only through the established Release Please/publish path after the
  remediation and documentation changes land. The exact release SHA must have an observed
  green gate; retain the existing tagged-source-link and published-release verification.
- **D-09:** Fold the hand-written `## Unreleased` material into the `1.5.1` release section
  before release PR #224 merges. Refresh the tracked documentation index as part of the version
  change, and preserve Phase 241's packaged-docs bookkeeping ratchet.

### the agent's Discretion

- Exact workflow, script, artifact, and ADR prose structure, provided the mutation authority
  remains least-privileged, evidence remains secret-free, and the separate causal boundaries
  above are mechanically provable.
- The concise public retirement message, bounded by Hex's current CLI requirements and the
  truth that valid installation requires a three-segment 1.5 pin.

### Folded Todos

- `.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md` — resolved by the retirement,
  API evidence, and honest resolver proof; its stale claim that retirement fixes latest
  resolution is corrected rather than repeated.
- `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` — resolved
  by folding the block before the immutable 1.5.1 release is cut.
- `.planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md` — resolved
  by refreshing the tracked documentation index with the 1.5.1 version change.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and durable decisions

- `.planning/ROADMAP.md` §Phase 242 — fixed scope, dependencies, and five success criteria.
- `.planning/REQUIREMENTS.md` §REL-03 through §REL-06 — requirement wording; REL-05's literal
  two-segment pin is superseded by D-05 because it fails its own safety goal.
- `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md` — prior Hex/tag
  history and the release-namespace guard that must not be weakened.
- `.planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md` — ADR 004 already
  exists; the new decision record is ADR 005.
- `.planning/phases/238-tag-guard-then-tag-deletion/238-CONTEXT.md` — live tag-guard behavior
  and release-tag compatibility.
- `.planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-CONTEXT.md` —
  packaged-docs ratchet and CHANGELOG ownership boundary.

### Release, package, and documentation seams

- `.github/workflows/hex-publish.yml` — existing trusted manual publish lane, secret handling,
  package checks, and post-publish hook.
- `.github/workflows/release-please.yml` — release PR, tag, and green-gate publication path.
- `scripts/ci/release-post-publish-verify.sh` — bounded published-release and tagged HexDocs
  source-link verification pattern.
- `mix.exs` — package contents and version-derived documentation source links.
- `CHANGELOG.md` — mandatory hand-folding warning for the Unreleased block.
- `README.md`, `guides/introduction/installation.md`,
  `guides/introduction/troubleshooting-install.md` — adopter-facing install and recovery prose.

### Research authority

- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — repo-aligned release,
  secret-scope, and package-verification practices.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — library-DX and
  documentation-as-product principles.
- `https://elixir.hexdocs.pm/1.18.4/Version.html` — authoritative pessimistic requirement
  semantics for D-05.
- `https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html` and
  `https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html` — authoritative Hex mutation syntax and
  package/docs reversibility limits.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `.github/workflows/hex-publish.yml` already provides strict ref/version validation, pinned
  actions, `contents: read`, package inspection, and narrowly scoped Hex-key use.
- `scripts/ci/release-post-publish-verify.sh` provides bounded propagation polling and
  machine-readable post-publish evidence; extend its proof style rather than inventing an
  unbounded manual check.
- `scripts/ci/wait-for-ci-gate.sh` and the Release Please workflow establish the exact-SHA,
  fail-closed green-gate proof expected before a release is published.

### Established Patterns

- Public operational truth is committed as sanitized, reproducible evidence rather than as an
  assertion in a plan or a screenshot.
- Release automation is manual-dispatch or trusted-main only, pins third-party actions, and
  avoids allowing secrets on PR/fork paths.
- Packaged documentation is product surface: `README.md` and `CHANGELOG.md` ship in the Hex
  tarball, and `mix.exs` ties HexDocs source links to the release tag.

### Integration Points

- Hex package API and HexDocs are the external truth sources for retirement, release, and
  default-doc behavior.
- `mix.exs`, the README/guides, CHANGELOG, Release Please, and the post-publish verifier must
  agree on the same released version and safe installation instruction.
- The three folded todos close only when their evidence, release content, and maintained docs
  actually satisfy these decisions.
</code_context>

<specifics>
## Specific Ideas

- Optimize for the adopter's first job: copy a supported dependency line, resolve a real
  maintained release, and see documentation that matches that release. Do not expose Hex's
  internal remediation mechanics in ordinary installation instructions.
- Follow the ecosystem's immutable-release model: repair discoverability and documentation,
  warn truthfully about the invalid version, and make the safe alternative explicit rather
  than implying that a retirement silently repairs every existing constraint or lockfile.
</specifics>

<deferred>
## Deferred Ideas

- Broad release-lane refactors, release-label repair, dependency updates, and unrelated
  release-keyword todos belong to Phase 243 or their own owning work; Phase 242 only uses the
  existing release path plus the bounded remediation lane.
- UI/brand work and generated authentication changes are outside this maintenance/release
  phase.
- A package-tarball revert is not merely deferred: Hex's allowed window is closed, so it must
  never be attempted as a fallback.
</deferred>

---

*Phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1*
*Context gathered: 2026-09-20*
