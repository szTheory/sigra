# Phase 145: 1.0 Contract And Release Truth - Research

**Researched:** 2026-05-31  
**Phase:** 145 - 1.0 Contract And Release Truth  
**Requirements:** REL1-01, REL1-04, CONTRACT-01, CONTRACT-02, CONTRACT-03, CONTRACT-04

## Research Complete

Phase 145 is a release-contract and documentation truth pass. It should not publish, tag, or run the release gate. The implementation should make the selected direct Hex `1.0.0` path explicit, align public docs around a single contract surface, and leave Phase 146 with unambiguous release metadata and runbook inputs.

## Current State

### Release Metadata

- `mix.exs` currently declares `@version "0.3.0"` and uses `source_ref: "v#{@version}"`, so HexDocs source links will follow the package version once the release PR changes `@version`.
- `.release-please-manifest.json` currently records `"." : "0.3.0"`, which is the correct last-shipped Release Please manifest value before a release PR.
- `release-please-config.json` uses the `elixir` release type, `include-v-in-tag: true`, and pre-1.0 bump settings. It does not yet force the one-time `1.0.0` jump.
- `CHANGELOG.md` already has a "Planning milestones vs Hex releases" explainer, but it still frames the repo as remaining `0.x` until a future `1.0.0`.
- `README.md`, `guides/introduction/installation.md`, `guides/introduction/getting-started.md`, `guides/introduction/first-hour.md`, and companion recipes still show `{:sigra, "~> 0.2"}` examples.

### Public Contract Surfaces

- `README.md` already contains the best public entry points: "Where code lives", "Prerequisites", "What ships in the box", "Security posture", and release evidence links.
- `SECURITY.md` is currently only a disclosure policy. It does not state product security invariants, host responsibilities, or non-goals.
- `MAINTAINING.md` contains release automation, Release Please, Hex publish, pre-1.0 SemVer, optional dependency SOT, and dual-axis deprecation notes. It needs a 1.0-specific release path instead of only pre-1.0 policy.
- `lib/sigra.ex`, `Sigra.OptionalDeps`, `Sigra.Doctor`, and `mix sigra.doctor` are the operational anchors for the library/generator split and optional-dependency posture.

## External Facts Checked

- Release Please manifest mode supports source-controlled `release-please-config.json` plus `.release-please-manifest.json`; `release-as` is a supported manual next-version override and should be removed or changed after the release PR merges. Source: https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md
- Elixir 1.18 documentation states the compatibility/support policy and OTP compatibility table; Sigra's package-level Elixir contract should start from its own `mix.exs` `~> 1.18` requirement, not Phoenix's lower floor. Source: https://hexdocs.pm/elixir/1.18/compatibility-and-deprecations.html
- Phoenix 1.8 has its own Elixir floor, but Sigra's public contract should use the stricter Sigra package floor and state Phoenix 1.8.x as the target baseline. Source: https://github.com/phoenixframework/phoenix
- Postgrex advertises broad historical PostgreSQL support, but Sigra should not inherit that as its public support promise. State Sigra's tested/supported Postgres posture and link detailed gates forward to Phase 146. Source: https://github.com/elixir-ecto/postgrex

## Recommended Implementation Shape

### 1. Canonical Contract Page

Create a single public contract page, preferably `guides/introduction/contract.md`, and add it to ExDoc extras in `mix.exs`. The page should be the canonical adopter-facing answer for:

- Hex package version axis versus GSD planning milestone axis.
- Supported stack: Elixir `~> 1.18`, OTP compatibility following Elixir 1.18, Phoenix 1.8.x, Ecto `~> 3.12`, Postgres tested/supported posture, and optional dependencies as feature-enabling host deps.
- Library-owned surfaces: crypto primitives, token verification/HMACs, MFA/passkey helpers, config/behaviours, doctor diagnostics, optional-dependency predicates, and versioned Hex updates.
- Generated-host-owned surfaces: schemas, migrations, contexts, routes, LiveViews/templates, mailer modules, product policy, authorization, deployment controls, and generated UI customization.
- Shared seams: mail, Oban/background jobs, OAuth providers, audit forwarding, optional companion libraries, host policy hooks.
- SemVer/deprecation policy: `1.0.0` means public API stability for documented supported library APIs and generated contracts, while private/experimental/internal surfaces remain outside the guarantee.
- Security invariants and non-goals: sessions, tokens, MFA/passkeys, audit durability boundaries, mail/Oban/OAuth responsibilities, host-owned authz/business policy, no hosted control plane, no compliance certification, no opinionated authorization engine.

### 2. Top-Level Public Pointers

Update `README.md` so an evaluator can find the contract before installing:

- Replace the dependency example with `{:sigra, "~> 1.0"}` once the selected release path is stated.
- Add the contract page to "Pick your lane" or "Prerequisites".
- Link the security invariants/non-goals table from "Security posture".
- Keep README concise and link depth to the contract page and SECURITY.md.

Update `CHANGELOG.md` so its dual-axis explainer says the project is preparing the real Hex `1.0.0` line and that GSD milestone labels remain planning labels, not installable versions.

Update old install examples that are in first-path docs or contract-adjacent recipes. Do not chase unrelated historical changelog entries or old upgrade guides whose whole purpose is historical context.

### 3. Release Please 1.0 Path

Use `release-as: "1.0.0"` in `release-please-config.json` for the one-time Release PR. Do not manually set `.release-please-manifest.json` to `1.0.0` before the release PR; manifest should represent the last shipped version until Release Please records the new shipped version.

The plan should explicitly require a post-release cleanup/removal note for `release-as`, but Phase 146 can own the release runbook and gate matrix.

### 4. Maintainer Contract Alignment

Update `MAINTAINING.md` so maintainers see:

- A "1.0 release path" section describing the direct Hex `1.0.0` cut from `main`.
- The one-time `release-as` override and cleanup requirement.
- That Phase 146 owns dry-run, publish gates, recovery, and first-14-day hotfix process.
- The old pre-1.0 SemVer section is either updated to historical/pre-1.0 context or followed by 1.0+ policy.

## Validation Architecture

Phase 145 is docs/config heavy, so validation should combine source assertions with docs build and targeted tests:

- `mix format --check-formatted` for touched Elixir/config formatting.
- `mix docs --warnings-as-errors` to prove ExDoc extras and links are warning-clean.
- `mix test test/sigra/recipes/companion_lib_contract_test.exs` if companion recipe examples are touched.
- `rg` assertions for:
  - `release-as.*1.0.0` in `release-please-config.json`.
  - `@version "0.3.0"` remains in `mix.exs` before the release PR unless the executor is intentionally inside the release PR.
  - `.release-please-manifest.json` remains `"0.3.0"` before the release PR.
  - `guides/introduction/contract.md` appears in `mix.exs` ExDoc extras.
  - README and CHANGELOG mention planning milestones versus Hex versions.
  - Contract/security docs include library-owned, generated-host-owned, shared seams, security invariants, non-goals, SemVer, and deprecation/removal policy.

## Planning Risks

- Do not confuse "lock the 1.0 path" with "publish 1.0 now". Phase 145 should prepare truth surfaces and config; Phase 146 owns deterministic gates/runbooks.
- Do not overclaim Postgres support by copying Postgrex's full historical range.
- Do not state OTP support as a hand-written standalone policy. Tie it to Elixir 1.18 compatibility.
- Do not make SECURITY.md sound like compliance certification or a host-deployment warranty.
- Do not update historical changelog entries or old upgrade pages in ways that rewrite history.

## Suggested Plan Split

- Plan 01: Create the canonical 1.0 contract surface and wire public docs to it.
- Plan 02: Align release metadata, maintainer policy, install examples, and verification assertions.

