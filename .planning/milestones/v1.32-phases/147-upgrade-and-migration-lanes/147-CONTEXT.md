# Phase 147: Upgrade And Migration Lanes - Context

**Gathered:** 2026-05-31 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 147 gives existing and migrating teams executable guidance before the adoption push. It covers UPGRADE-01, UPGRADE-02, MIGRATE-01, and MIGRATE-02: the `0.3.x` to `1.0.0` upgrade guide, automated consumer upgrade smoke, `phx.gen.auth` migration lane, and Pow/Guardian/Ueberauth migration lane.

This phase does not change Sigra's public 1.0 contract, release gate/runbook truth, evaluator demo funnel, launch announcement package, generated-host UI, or auth primitive surface. Phase 145 owns the public contract and release truth. Phase 146 owns the release gates and maintainer runbook. Phase 148 owns evaluator funnel polish. Phase 149 owns launch evidence and announcement materials.
</domain>

<decisions>
## Implementation Decisions

### Upgrade Guide Shape And Location
- **D-01:** Add a new public guide at `guides/introduction/upgrading-to-v1.0.md`.
- **D-02:** Follow the existing operational upgrade-guide style: branch/backup preflight, exact dependency update steps, generated-file review strategy, migration/schema impact, rollback notes, and verification commands.
- **D-03:** Treat the guide as the adopter-facing truth for upgrading from latest published `0.3.x` to the selected direct Hex `1.0.0` line. Keep the planning-milestone-vs-Hex-version distinction from Phase 145 intact.

### Consumer Upgrade Smoke Contract
- **D-04:** Add a dedicated consumer-upgrade smoke lane that starts from the latest published `0.3.x` posture and then points the consumer app at the local `1.0.0` candidate source.
- **D-05:** The smoke must prove the upgraded consumer app can fetch deps, compile, migrate, and run at least a minimal runtime/boot check without unexpected regressions.
- **D-06:** Do not rely on existing fresh-install smoke or existing upgrade tests alone for UPGRADE-02. Those remain useful adjacent evidence, but they do not exercise the published-consumer-to-candidate path.

### Migration Lanes
- **D-07:** Make the `phx.gen.auth` migration lane comparative and boundary-first: when to migrate, when not to migrate, how Phoenix 1.8 scopes/session/token/magic-link/sudo-mode concepts map to Sigra, and what generated-host review is required.
- **D-08:** Make the Pow/Guardian/Ueberauth lane comparative and boundary-first: cutover options, session/token/OAuth ownership differences, migration risk, and explicit non-goals.
- **D-09:** Do not add new auth primitives, compatibility shims, or library-owned migration engines for these ecosystems in Phase 147. The deliverable is executable guidance plus smoke proof, not feature expansion.

### Linking And Discovery
- **D-10:** Wire the upgrade and migration docs into README navigation, ExDoc extras/groups, release/evidence routing docs, and `doc/llms.txt`.
- **D-11:** Keep migration docs discoverable from the same public entry surfaces that evaluators and AI-consumption tools already use, rather than burying them as standalone guides.

### the agent's Discretion

Planning agents may choose exact file names for migration guides, whether to use one combined migration guide or separate ecosystem-specific guides, and exact CI/script naming for the consumer upgrade smoke. Prefer small, reproducible scripts and clear docs over a broad new workflow unless the existing CI structure cannot host the required evidence.

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
- `.planning/phases/146-release-gate-and-maintainer-runbook/146-CONTEXT.md`
- `.planning/research/SUMMARY.md`
- `.planning/research/ADOPTION-DX.md`
- `.planning/research/ECOSYSTEM-BENCHMARKS.md`
- `README.md`
- `CHANGELOG.md`
- `mix.exs`
- `guides/introduction/contract.md`
- `guides/introduction/installation.md`
- `guides/introduction/getting-started.md`
- `guides/introduction/upgrading-to-v1.1.md`
- `guides/introduction/upgrading-to-v1.7.md`
- `guides/introduction/upgrading-to-v1.8.md`
- `guides/reference/generator-options.md`
- `docs/release-runbook-v1-0.md`
- `docs/ga-evidence.md`
- `docs/uat-ci-coverage.md`
- `doc/llms.txt`
- `.github/workflows/ci.yml`
- `scripts/ci/install-smoke.sh`
- `test/sigra/install/golden_diff_test.exs`
- `test/sigra/install/idempotency_test.exs`
- `test/upgrade_test.exs`
- `https://hexdocs.pm/phoenix/mix_phx_gen_auth.html`
- `https://hexdocs.pm/guardian/introduction-overview.html`
- `https://github.com/ueberauth/ueberauth`
- `https://powauth.com/`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `guides/introduction/upgrading-to-v1.1.md` provides the closest local template for operational upgrade docs: preflight, dependency bump, upgrade task, migration/compile, generated changes, verification, and manual smoke.
- `mix.exs` curates ExDoc extras and already includes the existing upgrade-guide family, so new Phase 147 docs must be added there for HexDocs visibility.
- `README.md` already has upgrade-note navigation and public 1.0 package-line framing that can route users to the new guide.
- `doc/llms.txt` already exists as an AI-consumption table of contents and currently reflects the generated docs surface.
- `.github/workflows/ci.yml` already has install, install-matrix, example, docs, and release-ref guard patterns that can host or inform the consumer-upgrade smoke.
- `scripts/ci/install-smoke.sh` is the closest script pattern for creating a temporary Phoenix app, patching the Sigra dependency, fetching deps, compiling, migrating, and checking generated output.
- `test/sigra/install/golden_diff_test.exs` and `test/sigra/install/idempotency_test.exs` prove installer output stability, but they are not a substitute for a published-consumer upgrade smoke.

### Established Patterns

- Sigra documentation distinguishes library-owned package behavior from generated-host-owned code and host product policy.
- Release/adoption docs favor exact commands, truth-preserving caveats, and evidence links over marketing claims.
- Existing upgrade docs avoid promising more than the repo proves and tell users to work on a branch, preserve rollback options, and verify with the same paths Sigra exercises.
- Public docs must preserve Phase 145's version-axis decision: `0.3.x` is the latest published pre-release line, while `1.0.0` is the selected direct Hex release target.
- Migration guidance should be honest about when staying on existing generated/auth stack code is better than migrating.

### Integration Points

- Public docs integration: `README.md`, `guides/introduction/*`, `guides/reference/generator-options.md`, `CHANGELOG.md`, `docs/ga-evidence.md`, and `doc/llms.txt`.
- ExDoc integration: `mix.exs` `docs/0` extras and grouping.
- CI integration: `.github/workflows/ci.yml`, a new or extended `scripts/ci/*` smoke harness, and existing install/test jobs.
- Upgrade smoke integration: published latest `0.3.x` dependency posture, local path/source override to the candidate checkout, `mix deps.get`, `mix compile --warnings-as-errors`, `mix ecto.migrate`, and a minimal boot/runtime check.
- Migration comparison integration: Phoenix `phx.gen.auth` docs, Guardian docs, Ueberauth docs, Pow docs, and Sigra's 1.0 contract/ownership boundary docs.
</code_context>

<specifics>
## Specific Ideas

- The consumer upgrade smoke should be separate from `install-smoke.sh` so failures clearly mean "published consumer upgrade regression" rather than "fresh install regression."
- The `phx.gen.auth` lane should account for Phoenix 1.8's scopes, magic links, and sudo mode, and explain where Sigra's generated `current_scope`, sessions, tokens, MFA/passkeys, and audit surfaces differ.
- The Guardian lane should frame Guardian as token-auth focused; Sigra's JWT/API token surfaces are not a drop-in replacement for every Guardian usage without host review.
- The Ueberauth lane should frame Ueberauth as challenge/provider-oriented; Sigra uses Assent-backed OAuth surfaces and still leaves provider cutover and identity linking review to the host.
- The Pow lane should explain the risk of migrating from a library-owned Phoenix/Plug auth stack to Sigra's hybrid library+generated-host model, especially generated file ownership and session/token semantics.
- Link migration docs from release/evidence routing without turning Phase 147 into Phase 149's launch announcement package.
</specifics>

<deferred>
## Deferred Ideas

None -- analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</deferred>
