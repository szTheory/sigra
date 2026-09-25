# Phase 234: Hygiene, Supply Chain, and Contributor DX - Context

**Gathered:** 2026-07-31 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the post-reshape PR gate reproducible through one local `mix ci` command, stop silent drift in third-party action and dependency update coverage, account for every Playwright spec in a named CI lane, and close SEED-006 against current live evidence. This phase implements DX-01, DX-02, DX-03, DX-04, and DX-06 only; it does not reopen required-check policy, visual-canary policy, release-note conventions, or general network-retry policy.

</domain>

<decisions>
## Implementation Decisions

### Local gate parity (DX-01)

- **D-01:** `mix ci` is the single contributor-facing local mirror of the PR-fast library gate, and a PR CI lane MUST invoke that alias directly. Maintaining separate commands that merely resemble the alias is not acceptable proof of parity.
- **D-02:** Extend the alias to include `format --check-formatted`, `deps.get --check-locked`, and `deps.unlock --check-unused` alongside its existing warnings-as-errors compile, library tests, installer-golden tests, and dependency-off coverage.
- **D-03:** Replace the Phase 198 contract that forbids formatting in `mix ci` with a fail-closed parity contract that asserts the required alias legs and the real CI invocation. Credo, Dialyzer, and `mix_audit` remain out of scope and MUST NOT be pulled in as new gates.
- **D-04:** The one-time formatting cleanup MUST narrow `.formatter.exs` so `test/fixtures/install_golden/tree/**` is excluded from formatter inputs before formatting the tree. Generated golden fixture bytes remain owned by `golden_diff_test`, not by the formatter.

### Immutable actions and dependency update coverage (DX-02/DX-03)

- **D-05:** Replace `googleapis/release-please-action@v5` with the dereferenced immutable commit `googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0`. The annotated `v5` tag object SHA (`0dfd8538845b8e92600d271a895a5372865d4062`) MUST NOT be used.
- **D-06:** Add a fail-closed repository policy/contract that inventories release-critical third-party `uses:` references and requires a 40-character commit SHA plus trailing version comment. Do not treat the one known line replacement as sufficient protection against future drift.
- **D-07:** Extend `.github/dependabot.yml` with weekly `mix` updates at `/` and weekly `npm` updates at `/test/example/priv/playwright`, preserving the existing `github-actions` entry. Offline validation must cover YAML shape, documented ecosystem identifiers, directories, and manifest/lockfile existence; authoritative semantic proof comes from GitHub's per-ecosystem update-job logs after the config reaches the default branch, with an update PR retained when an update exists. Absence of a PR alone is not proof because dependencies may already be current.

### Playwright inventory and SEED-006 closure (DX-04/DX-06)

- **D-08:** Produce one committed, machine-readable or mechanically checked inventory mapping every `test/example/priv/playwright/tests/*.spec.ts` file to the named CI lane(s), event(s), and invocation/config seam that execute it. The inventory MUST fail closed when a spec or lane is added, removed, or becomes unowned, and it is the direct Phase 235 GATE-05 input.
- **D-09:** Current analysis identifies `admin-coherence-sweep.spec.ts` and `admin-theme.spec.ts` as having no CI invocation. Each must be deliberately wired into an appropriate existing lane or deleted with evidence that it is obsolete; no file may remain ambiguously present-but-unexecuted. Preserve useful coverage by default rather than deleting for convenience.
- **D-10:** Close SEED-006 as delivered, not as a new gallery-remediation project. The closeout must cite the corrected Phase 197 root cause/remediation and a current real gallery-lane receipt, including Phase 232 run `30659282026` where the shared-boot `admin_design_recapture` consumer passed 126 design tests. If current execution contradicts that evidence, file the residual as a tracked defect rather than weakening or restating the claim.

### Pending todo boundaries

- **D-11:** Fold none of the four reviewed pending todos into Phase 234. They are adjacent but each changes a separate policy boundary not owned by DX-01/02/03/04/06.
- **D-12:** Do not add retry machinery for the transient Hex/rebar mirror incident unless new live evidence shows it blocks clean-checkout `mix ci` or a required gate. The recorded failure is currently a one-off Tier-A recapture failure, and the milestone explicitly forbids masking flakes with retries.

### the agent's Discretion

- Exact plan decomposition and the name/location of new structural guards and the Playwright inventory artifact.
- Which existing PR lane invokes `mix ci`, provided the alias itself is what runs and required check-name/aggregator contracts remain intact.
- Dependabot grouping and commit-message labels, provided all three ecosystems remain covered at the locked directories and update-job evidence is captured.
- Whether each of the two orphan Playwright specs is wired or deleted, based on code intent and non-duplicative coverage evidence.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and methodology

- `.planning/ROADMAP.md` — Phase 234 goal, five success criteria, proof discipline, and fixed out-of-scope boundary.
- `.planning/REQUIREMENTS.md` — DX-01, DX-02, DX-03, DX-04, and DX-06 requirement text and traceability.
- `.planning/PROJECT.md` — v1.47 CI-EFFICIENCY thesis, North Star, maintenance posture, and no-trust-loss constraint.
- `.planning/METHODOLOGY.md` — decisive defaulting, escalation threshold, and proof/truth-claim lenses.

### Prior CI decisions and evidence

- `.planning/phases/230-tier-1-critical-path-reclamation/230-CONTEXT.md` — required-check, hard-fail, action-cache, and measurement constraints.
- `.planning/phases/231-gate-honesty-nightly-revival/231-CONTEXT.md` — honest-skip and required-check boundaries; explicit deferral of the `example_unit_smoke` aggregate gap.
- `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-CONTEXT.md` — exhaustive Playwright seam and shared-boot decisions.
- `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md` — live PR/non-PR shard and shared-boot receipts, including run `30659282026`.
- `.planning/phases/233-library-suite-economics/233-CONTEXT.md` — fail-closed live-universe reconciliation pattern for exhaustive inventories.

### Audit and seed sources

- `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` — original DX recommendations for static checks, `mix ci`, action pinning, Dependabot, and Playwright inventory.
- `.planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md` — original gallery issue, corrected root cause, Phase 197 remediation, and acceptance criteria.

### External supply-chain references

- `https://github.com/googleapis/release-please-action/releases/tag/v5.0.0` — release corresponding to the locked dereferenced commit.
- `https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories` — supported Dependabot ecosystem identifiers and SHA-pinned action comment behavior.
- `https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference` — Dependabot `package-ecosystem` and `directory` semantics.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `mix.exs` `ci`, `ci.install_golden`, and `sigra.dep_off` aliases provide the existing local command seam; extend rather than replace them.
- `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` is the existing offline DX-01 contract and should be revised into the parity ratchet.
- `.github/actions/example-playwright-boot/action.yml` is the Phase 232 sole reusable example Playwright boot prelude; inventory consumers through this seam rather than creating another boot definition.
- Phase 232's evidence ledger and the repository's planning contract tests provide established formats for live receipts plus hermetic structural proof.

### Established Patterns

- Third-party actions use full commit SHAs with same-line version comments throughout current workflows; Release Please is the remaining mutable exception.
- Exhaustive inventories fail closed against the live universe, following Phase 233's shard ownership reconciliation rather than a hand-maintained list with no drift check.
- Live-run evidence proves CI behavior; source inspection and schema validation prove structure but cannot substitute for a GitHub-processed Dependabot job or executed gallery lane.
- Required check names, skip semantics, terminal aggregators, `--retries=0`, and no-`continue-on-error` trust boundaries from Phases 230-233 remain binding.

### Integration Points

- `mix.exs`, `.formatter.exs`, `.github/workflows/ci.yml`, and `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` for DX-01.
- `.github/workflows/release-please.yml`, other release-critical workflow files, and a new/existing planning prohibition test for DX-02.
- `.github/dependabot.yml`, root `mix.exs`/`mix.lock`, and `test/example/priv/playwright/package.json`/`package-lock.json` for DX-03.
- `test/example/priv/playwright/tests/`, `test/example/priv/playwright/playwright.config.ts`, `.github/workflows/ci.yml`, `.github/workflows/playwright-github-pages.yml`, and `scripts/ci/` for DX-04.
- `.planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md` and Phase 232 live evidence for DX-06.

</code_context>

<specifics>
## Specific Ideas

- The user delegated implementation-level grouping to researched recommendations; no broad option menu should be reopened during research or planning.
- Treat the Playwright inventory as Phase 235 input, not disposable Phase 234 prose.
- Preserve the exact release action pin: `googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0`.

</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)

- `.planning/todos/pending/2026-07-10-canary-recapture-lane-excludes-canary.md` — changes frozen-canary/recapture policy; separate trust-boundary work.
- `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` — requires a public release-note convention and release control decision, not action pinning.
- `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` — required-check/DAG honesty work explicitly deferred by Phase 231; not owned by current DX requirements.
- `.planning/todos/pending/2026-07-30-recapture-job-transient-hexpm-mirror-failure.md` — one-off non-gating network failure; no retry without evidence it affects local/required-gate reproducibility.

</deferred>

---

*Phase: 234-hygiene-supply-chain-and-contributor-dx*
*Context gathered: 2026-07-31*
