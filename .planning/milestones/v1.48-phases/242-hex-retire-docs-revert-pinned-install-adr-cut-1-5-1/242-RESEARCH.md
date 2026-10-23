# Phase 242: Hex Retire + Docs Revert + Pinned-Install ADR + Cut 1.5.1 - Research

**Researched:** 2026-09-20
**Domain:** Hex package remediation, release automation, and adopter-facing Elixir dependency guidance
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)

- Broad release-lane refactors, release-label repair, dependency updates, and unrelated
  release-keyword todos belong to Phase 243 or their own owning work; Phase 242 only uses the
  existing release path plus the bounded remediation lane.
- UI/brand work and generated authentication changes are outside this maintenance/release
  phase.
- A package-tarball revert is not merely deferred: Hex's allowed window is closed, so it must
  never be attempted as a fallback.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| REL-03 | Retire `1.20.0` via `workflow_dispatch` and prove it through the Hex API. | A fixed-scope, read-before/write/read-after workflow with `HEX_API_KEY` only on the mutation step and a public JSON allowlist. |
| REL-04 | Revert only `1.20.0` documentation and show the HexDocs root serves current docs. | Hex's docs-only revert is the supported unlimited-time operation; root HTML must be measured after that independent mutation. |
| REL-05 | Record safe install guidance and the non-effect of retirement on resolver/latest behavior. | Elixir's documented pessimistic bounds and a fresh resolver proof require `~> 1.5.0`, not the superseded two-segment shorthand. |
| REL-06 | Cut 1.5.1 from an observed green gate with the Unreleased block folded beforehand. | Existing Release Please already waits for the exact release SHA, validates tag/version/package/docs, and records post-publish evidence. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- This phase is non-UI; the `sg-*`, Rail Accent, color-mode, and Playwright admin rules do not apply. [VERIFIED: AGENTS.md:3-10]
- Replace human UAT with deterministic tests, browser automation where applicable, CI polling, and committed machine-readable evidence; never mark unproven evidence as passed. [VERIFIED: AGENTS.md:12-16]
- Keep exactly one CI watcher per workflow run; use the 60-second compact watcher interval, inspect rate limit before a long watch, and treat HTTP 403/429 as a hard stop. [VERIFIED: AGENTS.md:18-23]

## Summary

Use one dedicated, least-privilege remediation workflow for exactly `sigra` `1.20.0`. It must write three sanitized API snapshots around two distinct mutations, make the retire call with an API-write key, and then make only the HexDocs revert. Hex officially specifies that retirement leaves a release resolvable but warns users, while documentation can be reverted independently after the package-revert window. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]

The adopter repair is twofold: show one plain supported dependency line, `{:sigra, "~> 1.5.0"}`, and prove it in an isolated resolver project with a brand-new `HEX_HOME`. Elixir documents `~> X.Y` as bounded only by the next major and `~> X.Y.Z` as bounded by the next minor; the local Elixir 1.19.5 probe returned `broad_1_20_0: true`, `safe_1_20_0: false`, and `safe_1_5_1: true`. [CITED: https://elixir.hexdocs.pm/1.18.4/Version.html] [VERIFIED: Elixir 1.19.5 runtime probe]

The release comes last. Existing Release Please creates the tag and explicitly gates Hex publication on a successful exact-SHA `ci-gate`; its post-publish verifier waits with bounded retries for the release and a source link to the released tag. Preserve that path rather than creating another publisher. [VERIFIED: .github/workflows/release-please.yml:96-134, 236-290] [VERIFIED: scripts/ci/release-post-publish-verify.sh:80-157]

**Primary recommendation:** Plan four ordered units: deterministic remediation/evidence tooling, live remediation proof, adopter docs plus ADR 005 and index/changelog maintenance, then a normal Release Please `1.5.1` release with its existing exact-SHA and post-publish gates.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Hex retirement and docs revert | CI / external package registry | — | The mutation needs a short-lived Actions secret boundary and changes Hex-owned state. |
| API and fresh-resolver evidence | CI / external package registry | Local ephemeral filesystem | The public API is the observed external state; each resolver case needs an unpolluted local Hex cache. |
| Safe installation guidance and ADR | Repository docs | HexDocs static publication | Source docs explain the supported copy/paste line; HexDocs exposes their published surface. |
| Version release | Release Please CI | Hex registry / HexDocs | Release Please owns version/tag/provenance, then invokes the established publisher after the exact SHA gate. |

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|---|---:|---|---|
| Hex Mix tasks | Hex v2.5.1 docs | Retire the phantom and revert only its docs. | The official CLI owns those registry operations; no custom HTTP write client. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |
| Elixir version requirements | Elixir 1.18.4 docs | Define and demonstrate safe dependency bounds. | `Version` is Mix's requirement semantics source, not a hand-written SemVer interpretation. [CITED: https://elixir.hexdocs.pm/1.18.4/Version.html] |
| Release Please workflow | existing pinned action | Tag/version/publish provenance for `1.5.1`. | Existing flow asserts tag/version agreement, green gate, package inspection, and post-publish checks. [VERIFIED: .github/workflows/release-please.yml:96-290] |

### Supporting

| Tool | Version | Purpose | When to Use |
|---|---:|---|---|
| `curl` + `jq` | local `jq-1.7.1` | Fetch and project public Hex API / HexDocs observations. | Only for non-secret GET data, with an explicit JSON allowlist. [VERIFIED: local environment probe] |
| `mix deps.get` | Mix 1.19.5 | Execute each fresh consumer resolver proof. | One temporary project per requirement case, each with its own fresh `HEX_HOME`. [VERIFIED: local environment probe] |
| `scripts/ci/release-post-publish-verify.sh` | existing | Bounded release visibility + tagged source-link proof. | Reuse after 1.5.1 publication; do not duplicate its polling contract. [VERIFIED: scripts/ci/release-post-publish-verify.sh:80-157] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Dedicated remediation lane | Add retire/revert switches to `hex-publish.yml` | Rejected by D-01: it expands a recovery publisher's input/mutation surface and weakens causal evidence. |
| `~> 1.5.0` | `~> 1.5` | Rejected: the latter admits `1.20.0`; it conflicts with D-05 and the documented bounds. [CITED: https://elixir.hexdocs.pm/1.18.4/Version.html] |
| Docs-only revert | Package `--revert` | Rejected: package reverts are time-bounded, while docs are independently mutable; D-04 forbids it. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |

**Installation:** No dependencies are added in this phase. Therefore no package-legitimacy audit is required. [VERIFIED: .planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-CONTEXT.md:99-102]

## Architecture Patterns

### System Architecture Diagram

```text
workflow_dispatch (fixed package/version)
        |
        v
public GET /api/packages/sigra --project allowlisted fields--> BEFORE.json
        |
        v
HEX_API_KEY only on: mix hex.retire sigra 1.20.0 invalid --message <truthful <=140 chars>
        |
        v
public GET /api/packages/sigra ------------------------------> AFTER_RETIRE.json
        |
        v
HEX_API_KEY only on: mix hex.publish docs --revert 1.20.0
        |
        +--> public GET /api/packages/sigra -----------------> AFTER_DOCS_REVERT.json
        +--> public GET https://hexdocs.pm/sigra/ -----------> root title/source observation
        +--> fresh HEX_HOME resolver project ---------------> broad warning + safe clean receipts
        |
        v
commit sanitized evidence + docs/ADR/changelog/index -> merge main -> Release Please
        |
        v
exact release SHA ci-gate -> tagged publish -> existing post-publish verifier
```

### Recommended Project Structure

```text
.github/workflows/
└── hex-remediate-phantom.yml       # new fixed-target workflow_dispatch lane
scripts/ci/
└── hex-remediation-verify.sh       # pure/read-only capture + resolver proof helper and self-test
.planning/phases/242-.../
└── 242-HEX-REMEDIATION-EVIDENCE.md # committed sanitized before/after observations
.planning/decisions/
└── 005-hex-retirement-and-safe-install-constraints.md
```

### Pattern 1: Separate causal boundaries, then project public evidence

**What:** Read the same public package endpoint before mutation, after retirement, and after the docs-only revert. Project only fields needed to prove the phase (`name`, `latest_version`, `latest_stable_version`, `retirements`, selected release `version`/`has_docs`) into deterministic JSON before committing it. [VERIFIED: live Hex API query, 2026-09-20]

**When to use:** Whenever multiple registry operations can affect overlapping public presentation, particularly when the API's undocumented default-selection behavior must not be inferred.

**Example:**

```bash
# All inputs are fixed literals inside the workflow; this emits no credentials.
curl --fail-with-body --silent --show-error https://hex.pm/api/packages/sigra \
  | jq '{name, latest_version, latest_stable_version, retirements,
         releases: [.releases[] | select(.version == "1.20.0" or .version == "1.5.0")
                   | {version, has_docs}]}'
```

### Pattern 2: Narrow secret scope and fail-closed mutations

**What:** Give the remediation workflow `contents: read`; no checkout is needed for public reads. Bind `secrets.HEX_API_KEY` only through the environment of the two Mix mutation steps, never as an input, command interpolation, artifact, or diagnostic. Existing release lanes set `HEX_API_KEY` only on Hex dry-run/publish steps and use `contents: read` for their publish job. [VERIFIED: .github/workflows/hex-publish.yml:26-28, 177-187] [VERIFIED: .github/workflows/release-please.yml:128-134, 244-254]

**When to use:** External, authenticated operations whose result can be verified via public read-only endpoints.

**Example:**

```yaml
- name: Retire only the fixed phantom release
  env:
    HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
  run: >-
    mix hex.retire sigra 1.20.0 invalid
    --message "Published in error; use a supported 1.5.x release."
```

The workflow must preflight that `HEX_API_KEY` is non-empty without printing it, then fail on a nonzero retire/docs command. Hex documents `invalid` as a retirement reason and requires a message of at most 140 characters. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html]

### Pattern 3: Fresh resolver proof, not a lockfile or cache proof

**What:** Generate two tiny temporary Mix projects with independent temporary `HEX_HOME` and `MIX_HOME`, ensure `HEX_IGNORE_RETIREMENTS` is absent, run `mix deps.get`, then record selected `mix.lock` version plus stderr/stdout warning facts. Use a broad `~> 1.0` case and the safe `~> 1.5.0` case; a pre-existing `mix.lock`, local cache, or an ignored retirement warning invalidates the result. [CITED: https://hex.pm/docs/faq]

**When to use:** Consumer-facing package selection claims, especially after any registry-side advisory mutation.

**Example:**

```bash
env -u HEX_IGNORE_RETIREMENTS \
  HEX_HOME="$case_dir/hex" MIX_HOME="$case_dir/mix" \
  mix deps.get
# Assert from mix.lock: broad selects 1.20.0; safe selects a 1.5.x release.
# Assert broad logs contain the retirement warning; safe logs do not.
```

### Anti-Patterns to Avoid

- **One final snapshot:** cannot distinguish retirement effects from a docs revert; commit three ordered boundary observations.
- **Raw API artifacts:** response fields may change and can include irrelevant data; project and sort a whitelist before committing.
- **A local lockfile proof:** proves its own pin/cache, not what a new adopter resolves.
- **Retrying a write on any error:** do not retry mutations blindly. Re-read public state after a failure; retry only when the intended state is absent and the error is demonstrably transient.
- **A second release publisher:** do not add a manual tag/publish path; ADR 003 assigns release-derived publishing to Release Please.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Package retirement | Custom Hex API POST client | `mix hex.retire` | Hex owns auth and retirement semantics; the official task exposes reason/message validation. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html] |
| Docs removal | Delete/redirect documentation files or infer root routing | `mix hex.publish docs --revert 1.20.0` plus a live root observation | Docs are Hex-managed and independently reversible. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |
| Release/tag/provenance | New tag-triggered or direct publish workflow | Existing Release Please → `gate-ci-green` → `publish-hex` | The established lane proves version/tag/manifest/source-ref consistency and emits post-publish evidence. [VERIFIED: .github/workflows/release-please.yml:96-290] |
| SemVer range logic | String comparisons or a prose interpretation | Elixir/Mix requirement resolver | Pessimistic requirement arity changes the upper bound. [CITED: https://elixir.hexdocs.pm/1.18.4/Version.html] |

**Key insight:** registry state, docs hosting, and Mix selection are three different observable systems. The phase succeeds only if it records each system's actual outcome rather than treating one mutation as a universal repair.

## Runtime State Inventory

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | Hex's public package record currently reports `latest_stable_version: "1.20.0"` and `retirements: {}`. | External data mutation: retire the fixed version, then commit read-only snapshots; do not claim expected post-state in advance. [VERIFIED: live `https://hex.pm/api/packages/sigra` query, 2026-09-20] |
| Live service config | GitHub Actions secret `HEX_API_KEY` is consumed by existing publish steps; it must be reused only at the new mutation steps. | Code edit only: new least-privilege workflow; no secret rename or rotation is scoped. [VERIFIED: .github/workflows/hex-publish.yml:5, 177-187] |
| OS-registered state | None discovered relevant to package/docs remediation. | None. The workflow is cloud-hosted, not a launchd/systemd/pm2 registration. [ASSUMED] |
| Secrets/env vars | `HEX_API_KEY` is required for writes; `HEX_IGNORE_RETIREMENTS` must be absent for the resolver proof. | Workflow environment scoping and explicit `env -u`; never record secret values. [VERIFIED: .github/workflows/release-please.yml:244-254] |
| Build artifacts / installed packages | Existing HexDocs for 1.20.0 are external hosted artifacts; locally cached registry/lock data would taint an adopter proof. | Docs mutation for hosted docs; create new temporary homes and project directories for each resolver case. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |

## Common Pitfalls

### Pitfall 1: Treating retirement as deletion

**What goes wrong:** Documentation or ADR prose says the retire fixes broad resolution or `latest_stable_version`.

**Why it happens:** Retirement is a recommendation marker, not unpublish. Hex states a retired package stays resolvable/fetchable and displays a warning. [CITED: https://hex.pm/docs/faq]

**How to avoid:** Prove a broad fresh resolution still chooses `1.20.0` with `RETIRED!`; describe API/default fields only from the captured observation.

**Warning signs:** Any `~> 1.0` success is reported as proof of safety, or a document says retire “restores latest.”

### Pitfall 2: Using a two-segment safe pin

**What goes wrong:** `~> 1.5` is presented as the supported line.

**Why it happens:** Two-segment pessimistic requirements allow all later minors below the next major.

**How to avoid:** Standardize on the three-segment exact source text `{:sigra, "~> 1.5.0"}` and assert both resolver directions.

**Warning signs:** A docs search finds `{:sigra, "~> 1.5"}` or narrative claims “1.5.x only” without the third segment.

### Pitfall 3: Letting docs remediation hide its own effect

**What goes wrong:** A successful Docs revert is mistaken for proof about the package API or default-doc routing.

**Why it happens:** Hex's package and docs operations are related in the user journey but are independently mutable.

**How to avoid:** Require `AFTER_RETIRE` before docs mutation, `AFTER_DOCS_REVERT` after it, and separately fetch the root HTML/title/source link.

### Pitfall 4: A secret leaks through evidence or shell tracing

**What goes wrong:** A raw key, request, or shell-expanded command appears in an artifact or log.

**How to avoid:** Never use `set -x`; inject the secret only as step env; upload/copy only public GET projections; write explicit tests that reject `HEX_API_KEY=`, token-shaped text, and unprojected response dumps in committed evidence. [VERIFIED: scripts/ci/wait-for-ci-gate.sh:26-35]

### Pitfall 5: Releasing before remediation is proven

**What goes wrong:** 1.5.1 ships without corrective docs/evidence, or an ad-hoc publisher breaks tag provenance.

**How to avoid:** Merge remediation/docs first, observe the green gate at its final SHA, then let Release Please create/tag/publish `1.5.1`. [VERIFIED: .github/workflows/release-please.yml:96-131]

## Code Examples

### Safe requirement semantics

```elixir
# Expected adoption line; test it against a fresh registry state.
{:sigra, "~> 1.5.0"}
```

Elixir's official table defines `~> 2.0` as `>= 2.0.0 and < 3.0.0` and `~> 2.0.0` as `>= 2.0.0 and < 2.1.0`; applying that documented rule makes the equivalent 1.5 three-segment form the required safe constraint. [CITED: https://elixir.hexdocs.pm/1.18.4/Version.html]

### Bounded post-publish polling

```bash
# Reuse the existing verifier rather than adding a second implementation.
scripts/ci/release-post-publish-verify.sh \
  --package sigra --version "$VERSION" --tag "v$VERSION" \
  --evidence-file release-post-publish-evidence.json
```

The existing script defaults to 36 attempts and 10-second waits, fails on timeout, then verifies a HexDocs source link contains the released tag. [VERIFIED: scripts/ci/release-post-publish-verify.sh:4-10, 104-157]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Deferred interactive operator runbook claiming retirement fixes latest selection | Dedicated noninteractive CI remediation + measured public/adopter outcomes | This phase | Removes the unprovable claim and supplies an auditable, least-privilege path. [VERIFIED: .planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md:49-75] |
| Broad/minor-only install prose | Three-segment supported constraint | This phase, D-05 | Prevents future `1.x` minor releases such as `1.20.0` from matching the documented safe line. [CITED: https://elixir.hexdocs.pm/1.18.4/Version.html] |
| Unbounded/duplicated release checks | Existing bounded post-publish verifier and exact-SHA gate | Existing repository pattern | A failure has a durable error and the workflow does not report a green with no observed run. [VERIFIED: scripts/ci/wait-for-ci-gate.sh:5-30] |

**Deprecated/outdated:** The pending retire todo's assertion that retirement should move `latest_stable_version` and make `~> 1.0` select a real GA is contradicted by the phase's locked D-06 and must be reconciled as actionable current documentation, not repeated. [VERIFIED: .planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md:64-75]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | No OS-level registered state participates in this cloud-only remediation. | Runtime State Inventory | A hidden scheduled local workflow could retain obsolete manual instructions. |
| A2 | The supported noninteractive contract is an API-write key in `HEX_API_KEY` plus the documented `mix hex.retire ... invalid --message ...` form; the protected key's actual authorization remains a fail-closed runtime assertion, never an interactive fallback. | Architecture Patterns | A permission or client-auth change blocks the one authorized run without permitting redispatch. |

## Open Questions (resolved for execution)

1. **(RESOLVED) Does the existing `HEX_API_KEY` complete both current Hex mutations without an OTP/device-flow prompt?**
   - Established contract: Hex documents API-write keys through `HEX_API_KEY` for noninteractive CI, and the supported retirement form is `mix hex.retire sigra 1.20.0 invalid --message MESSAGE`; neither official task requires an interactive confirmation flag on that API-key path. [CITED: https://hex.pm/docs/publish] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html]
   - Historical evidence: run `35554955828` reached the protected retirement step with the key present and masked, then stopped because the client rejected the unsupported `--yes` option before any mutation. The landed correction at `907d875f` uses the documented `--message` form and its p22 assertion passed; this proves the command shape, not that the live protected key has permission for both writes. [VERIFIED: `ee61cfb3:.../242-03-SUMMARY.md`] [VERIFIED: `907d875f:.github/workflows/hex-remediate-phantom.yml`] [VERIFIED: `907d875f:scripts/ci/prohibitions/p22-hex-remediation.test.mjs`]
   - Resolution and runtime gate: no design choice remains. Plan 10 first proves the corrected command and p22 contract from freshly fetched `origin/main`, then its one authorized dispatch tests the protected credential in situ. Any authorization error, OTP/device-flow prompt, or other nonzero mutation outcome is classified and halts with no interactive fallback, no evidence promotion, and no redispatch. Success may be claimed only from the validated public receipt.

2. **(RESOLVED) What does HexDocs root routing do after the docs-only revert, and does the package API field change?**
   - Established contract: Hex supports reverting hosted documentation independently with `mix hex.publish docs --revert 1.20.0`; this is distinct from the expired package-tarball revert. Hex does not document a guaranteed root-routing or package-metadata transition from that docs operation, so neither outcome is assumed. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]
   - Historical evidence: run `35554955828` failed before AFTER_RETIRE, the docs revert, root classification, and final package observation, so it establishes no post-docs outcome. The corrected workflow instead records AFTER_RETIRE before the docs write, AFTER_DOCS_REVERT afterward, and a separate root classification. [VERIFIED: `ee61cfb3:.../242-03-SUMMARY.md`] [VERIFIED: `907d875f:.github/workflows/hex-remediate-phantom.yml`]
   - Resolution and runtime gate: the behavior is intentionally an output of the one authorized dispatch, not an unresolved implementation decision or a pre-observed fact. Completion requires a schema-valid causal receipt whose root class is `current_1_5`, whose package projection retains the invalid `1.20.0` retirement, and whose observed `latest_stable_version` values are reported verbatim. An ambiguous root, missing/changed projection, validator disagreement, or failed independent public re-read halts without evidence promotion, inference, or redispatch.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Elixir / Mix | resolver proof and Hex tasks | ✓ | Mix 1.19.5 / OTP 28 | — |
| `jq` | deterministic public JSON projection | ✓ | 1.7.1 | Node/Elixir JSON projection only if CI image lacks jq |
| `gh` | existing exact-SHA gate and release observability | ✓ | 2.101.0 | Existing workflow's GitHub CLI installation on runner |
| Public Hex API | pre/post observations | ✓ | live GET returned package JSON | Fail closed; do not fabricate observations |
| `HEX_API_KEY` | registry mutations | not inspectable | secret | No fallback; failure blocks remediation |

**Missing dependencies with no fallback:** protected `HEX_API_KEY` authorization for retirement/docs revert is intentionally not inspectable during research and must be proven by the workflow.

**Missing dependencies with fallback:** none.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit plus Bash/Node hermetic script self-tests [VERIFIED: mix.exs:143-173] |
| Config file | `mix.exs` aliases and `test/test_helper.exs` |
| Quick run command | `MIX_ENV=test mix test test/sigra/planning/phase_146_release_validation_test.exs test/sigra/planning/phase_222_release_lane_hardening_test.exs` |
| Full suite command | `MIX_ENV=test mix ci` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| REL-03 | Workflow is dispatch-only, fixed target, minimal permissions, secret only on mutation steps, and evidence JSON is sanitized. | Structural + hermetic | `node --test scripts/ci/prohibitions/p*-hex-remediation*.test.mjs` | ❌ Wave 0 |
| REL-03 | Live API captures prove ordered retire effects. | Live workflow evidence | dispatch once; inspect one completed run and committed artifacts | ❌ Wave 0 |
| REL-04 | Workflow invokes docs-only revert and root docs observation is captured. | Structural + live | structural Node test; post-dispatch root GET assertion | ❌ Wave 0 |
| REL-05 | Broad and safe fresh consumers select/assert opposite expected outcomes without ignored retirements. | Integration script | `bash scripts/ci/hex-remediation-verify.test.sh` then live helper | ❌ Wave 0 |
| REL-06 | 1.5.1 goes through existing release checks and post-publish verifier. | Existing structural + live release workflow | existing Phase 146 test; Release Please run's exact-SHA receipt | ✅ / live receipt pending |

### Sampling Rate

- **Per task commit:** relevant hermetic structural/self-test plus the affected docs/index contract.
- **Per wave merge:** `MIX_ENV=test mix ci` and the relevant `node --test` prohibition suite.
- **Phase gate:** one public external Hex API observation and one exact 1.5.1 Release Please publish receipt at the committed release SHA; no grep/count-only acceptance.

### Wave 0 Gaps

- [ ] `scripts/ci/hex-remediation-verify.sh` and hermetic self-test — explicit input validation, JSON projection, fresh-home lifecycle, warning/lock assertions, and no-secret-output checks.
- [ ] A focused structural test for the remediation workflow and a known-bad fixture proving it rejects broadened target/permissions/secret scope.
- [ ] A committed evidence schema/readme that requires `BEFORE`, `AFTER_RETIRE`, `AFTER_DOCS_REVERT`, root-doc observation, and both resolver-case receipts.
- [ ] A docs-index assertion/update path covering every changed adopter-facing install source.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | Yes | `HEX_API_KEY` is a protected CI secret scoped to only authenticated mutations. |
| V3 Session Management | No | No user session is introduced or changed. |
| V4 Access Control | Yes | `workflow_dispatch`, fixed constants, `contents: read`, and no evidence-writing token authority. |
| V5 Input Validation | Yes | Do not expose package/version as arbitrary dispatch inputs; validate any non-secret message length/content in a hermetic test. |
| V6 Cryptography | Yes | GitHub Actions secret storage and Hex API-key authentication; never log, transform, or hand-roll credential handling. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Secret disclosure via shell expansion/artifact | Information disclosure | Step-scoped env, no `set -x`, sanitized projections only, artifact/content scan. |
| User-dispatch input broadens a destructive mutation | Tampering / elevation of privilege | No arbitrary package/version input; hard-code fixed target and assert it structurally. |
| Misleading public outcome from merged observations | Repudiation | Ordered before/after evidence slots, timestamps, source URLs, and root docs fetch. |
| Blind transient retry duplicates a mutation | Tampering | Read state after failure; retry only a demonstrated transient read, never write blindly. |
| Publishing from an unproven SHA | Tampering / repudiation | Existing `gate-ci-green` waits on Release Please's emitted release SHA before `publish-hex`. [VERIFIED: .github/workflows/release-please.yml:96-131] |

## Sources

### Primary (HIGH confidence)

- [Hex `mix hex.retire`](https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html) — syntax, supported reasons, required <=140-character message, advisory/resolvable behavior.
- [Hex `mix hex.publish`](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html) — documentation publication, docs-only revert, package/docs reversibility bounds.
- [Elixir `Version`](https://elixir.hexdocs.pm/1.18.4/Version.html) — documented pessimistic-requirement translations.
- [Hex FAQ](https://hex.pm/docs/faq) — immutable packages, retirement warnings, retained resolver/fetch behavior.
- [Hex publishing guide](https://hex.pm/docs/publish) — CI API-write key and `HEX_API_KEY` handling.
- Live `https://hex.pm/api/packages/sigra` read on 2026-09-20 — current package fields before remediation.

### Secondary (MEDIUM confidence)

- `.github/workflows/hex-publish.yml`, `.github/workflows/release-please.yml`, `scripts/ci/release-post-publish-verify.sh`, and `scripts/ci/wait-for-ci-gate.sh` — project-owned authorization, bounded polling, and evidence patterns.

### Tertiary (LOW confidence)

- None used for a recommendation. The protected key's exact runtime/OTP behavior remains an explicit confirmation checkpoint.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — official Hex/Elixir documentation plus inspected established release workflows.
- Architecture: HIGH — locked decisions match project-owned workflows and official separation of package/docs operations.
- Pitfalls: HIGH — official retirement semantics, official range semantics, and current live API state support the critical risks.

**Research date:** 2026-09-20
**Valid until:** 2026-09-27 (registry/client behavior and live package state are fast-moving)
