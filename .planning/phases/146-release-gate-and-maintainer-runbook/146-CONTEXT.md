# Phase 146: Release Gate And Maintainer Runbook - Context

**Gathered:** 2026-05-31 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 146 makes the 1.0 publish path deterministic, evidence-backed, and recoverable. It covers REL1-02 and REL1-03: release gate matrix, dry-run/package inspection, release-ref checks, Hex publish/docs visibility, post-publish checks, recovery branches, and first-14-day hotfix triage policy.

This phase does not change Sigra's public 1.0 contract, add new auth primitives, redesign generated-host UI, create migration/adoption lanes, or package launch announcement assets. Phase 145 owns the public contract and release truth. Phase 147 owns upgrade and migration lanes. Phase 148 owns evaluator funnel polish. Phase 149 owns launch evidence and announcement materials.
</domain>

<decisions>
## Implementation Decisions

### Release Ref Truth
- **D-01:** Release gates must run against the immutable release ref wherever automation can do so: `v*` tag or exact release SHA, not a floating `main` checkout.
- **D-02:** The release runbook must cross-check `mix.exs @version`, Release Please outputs, `.release-please-manifest.json`, GitHub release/tag, Hex version, and HexDocs `source_ref` so the package, docs, and source links all point at the same release.
- **D-03:** Any gate that cannot run against the release ref must be explicitly labeled manual or pre-merge, with required evidence captured in the runbook.

### Release Gate Matrix
- **D-04:** Reuse existing CI contracts as the canonical gate evidence instead of inventing a parallel release-only test stack.
- **D-05:** The gate matrix must cover, at minimum, library tests, install golden/idempotency, fresh install smoke, example/browser smoke, dep-off lane, docs warnings, Hex dry-run, package inspection, post-publish Hex visibility, and HexDocs/source-link checks.
- **D-06:** Release-time instructions should point maintainers to the specific existing jobs, scripts, commands, and evidence links they need to inspect or rerun.

### Hex Publish And Recovery
- **D-07:** Failed dry-run or publish recovery should standardize on the existing `Hex publish (manual recovery)` workflow with tag/SHA and expected version inputs as the primary no-invention recovery path.
- **D-08:** Local trusted-machine publish is fallback only, not the default recovery path, and must preserve the same release-ref/version checks as automation.
- **D-09:** Recovery wording must reflect Hex's current package semantics: docs are automatically published with the package and can be republished later; public package replacement/revert has tight time windows, so the runbook must tell maintainers when to replace/revert versus cut a follow-up patch.

### Dedicated Runbook Surface
- **D-10:** Create a dedicated Phase 146 release-runbook/policy doc as the canonical home for the release gate matrix, dry-run/package inspection, recovery branches, post-publish checks, and first-14-day hotfix triage policy.
- **D-11:** Keep `MAINTAINING.md` as the stable maintainer entry point and pointer to the dedicated runbook; do not duplicate the full release gate matrix there.

### First 14 Days
- **D-12:** Add a concrete first-14-day post-1.0 hotfix policy before publish, including severity/triage expectations, patch decision boundaries, evidence expectations, and communication posture.
- **D-13:** The hotfix policy should prioritize release-blocking and adopter-blocking regressions in install, compile, docs/source links, generated-host boot, security-sensitive auth behavior, and package metadata truth. It should not reopen deferred feature scope.

### Release Please Cleanup
- **D-14:** Treat cleanup of the one-time `release-as: "1.0.0"` override as a release-gate/runbook item. After the 1.0 Release PR merges and cuts the release, remove or update that override so future releases return to conventional-commit-derived SemVer.

### the agent's Discretion

Planning agents may choose exact file names, section ordering, whether to add helper scripts, and whether to tighten GitHub workflow steps, provided the output keeps the runbook deterministic and evidence-backed. Prefer documentation plus narrow automation improvements over a broad new workflow unless existing CI cannot satisfy a required gate.

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
- `.planning/phases/145-1-0-contract-and-release-truth/145-CONTEXT.md`
- `.planning/research/SUMMARY.md`
- `.planning/research/RELEASE-MECHANICS.md`
- `.planning/research/ADOPTION-DX.md`
- `.planning/research/ECOSYSTEM-BENCHMARKS.md`
- `.planning/research/LOCAL-PROMPT-SYNTHESIS.md`
- `MAINTAINING.md`
- `docs/NEXT-STEPS-MANUAL.md`
- `docs/ga-evidence.md`
- `docs/uat-ci-coverage.md`
- `.github/workflows/release-please.yml`
- `.github/workflows/hex-publish.yml`
- `.github/workflows/ci.yml`
- `mix.exs`
- `.release-please-manifest.json`
- `release-please-config.json`
- `CHANGELOG.md`
- `README.md`
- `SECURITY.md`
- `scripts/ci/install-smoke.sh`
- `scripts/ci/http-smoke.sh`
- `scripts/ci/admin-acceptance-smoke.sh`
- `test/sigra/install/golden_diff_test.exs`
- `test/sigra/install/idempotency_test.exs`
- `test/example/priv/playwright/playwright.config.ts`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts`
- `https://hex.pm/docs/publish`
- `https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html`
- `https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `.github/workflows/release-please.yml` already checks out the Release Please tag, verifies `mix.exs @version`, runs compile/tests, performs `mix hex.publish --dry-run --yes`, publishes with `HEX_API_KEY`, and polls Hex.pm visibility.
- `.github/workflows/hex-publish.yml` already provides manual recovery from a chosen tag/SHA and expected version string, with compile, tests, dry-run, and publish.
- `.github/workflows/ci.yml` already contains the required evidence lanes: library tests, docs warnings, dep-off, install golden/idempotency, fresh install smoke, example HTTP smoke, example Playwright smoke, generated admin smoke, and related install matrix coverage.
- `mix.exs` already sets `docs/0` `source_ref: "v#{@version}"`, making tag/source-link verification a concrete release gate.
- `MAINTAINING.md` already documents Release Please, Hex publish mechanics, secrets, Release Please token fallback, one-time `release-as: "1.0.0"`, manual recovery, source-link hygiene, and notes that Phase 146 owns the detailed gate/runbook work.
- `docs/NEXT-STEPS-MANUAL.md` already routes maintainers to Release Please and manual Hex recovery.

### Established Patterns

- Sigra keeps release truth explicit and evidence-backed, with public claims tied to docs, CI, verification artifacts, and package metadata rather than broad launch language.
- Maintainer docs should be deterministic under pressure: exact commands, exact workflows, exact evidence, and clear recovery branches.
- Existing CI is the truth surface for merge and release confidence; duplicated release-only gates should be avoided unless they remove a concrete evidence gap.
- The repository distinguishes public-package SemVer from internal planning milestone labels; release docs must preserve that distinction.
- Optional integrations and generated-host behavior should remain standalone-safe and truthfully scoped.

### Integration Points

- Release automation: `.github/workflows/release-please.yml`, `.github/workflows/hex-publish.yml`, `release-please-config.json`, `.release-please-manifest.json`, `mix.exs`, GitHub Releases/tags, Hex.pm, and HexDocs.
- Gate evidence: `.github/workflows/ci.yml`, install golden/idempotency tests, install smoke scripts, example HTTP/browser smoke, dep-off lane, docs warnings, Hex dry-run, and package inspection.
- Maintainer-facing docs: `MAINTAINING.md`, `docs/NEXT-STEPS-MANUAL.md`, any new release-runbook/policy doc, `docs/ga-evidence.md`, and `docs/uat-ci-coverage.md`.
- Post-publish proof: Hex.pm release API/page, HexDocs versioned docs, source links, package contents, and fresh consumer/example smoke.
</code_context>

<specifics>
## Specific Ideas

- Use `mix hex.build --unpack` before publish for package contents inspection, paired with `mix hex.publish --dry-run --yes`.
- Document Hex recovery windows plainly: public packages can be replaced/reverted only within Hex's allowed time window; documentation can be republished independently later.
- Make the first-14-day policy severity-driven: security-sensitive regressions, install/compile blockers, generated-host boot failures, docs/source-link/package metadata breakage, and severe demo/evaluator regressions get immediate patch consideration.
- Include Release Please `release-as` cleanup in the post-publish checklist so the 1.0 override cannot accidentally affect the next release.
- Prefer a dedicated runbook file linked from `MAINTAINING.md` over expanding `MAINTAINING.md` into a large release matrix.
</specifics>

<deferred>
## Deferred Ideas

None -- analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</deferred>
