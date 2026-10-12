# Phase 247: Release Candidate and Repository Readiness - Pattern Map

**Mapped:** 2026-10-06
**Files analyzed:** 6 anticipated/modified artifacts
**Analogs found:** 6 / 6

This map covers the concrete artifacts in RESEARCH.md's Recommended Project Structure and Wave 0 Gaps, plus the package metadata file required by READY-01. The inventory artifact's filename and format remain delegated to planning. Release Please config/workflows are existing seams to reuse; neither CONTEXT.md nor RESEARCH.md directs changes to them. A dedicated acceptance checker is only suggested conditionally in RESEARCH.md, so no new checker path is assumed here.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.planning/phases/247-release-candidate-and-repository-readiness/<inventory-ledger>` (new; name/format TBD) | documentation / evidence ledger | batch | `.planning/research/v1.49-release-scope/REPO-STATE.md` | role-match |
| `guides/introduction/upgrading-to-v1.6.md` (new) | documentation / adopter guide | request-response (reader action path) | `guides/introduction/upgrading-to-v1.5.md` | exact |
| `README.md` | documentation / navigation | request-response (reader routing) | `README.md` upgrade row | exact |
| `CHANGELOG.md` | documentation / release notes | batch | `CHANGELOG.md` v1.5.0 section | exact |
| `mix.exs` | config / package and docs metadata | transform (version/config drives package and docs output) | `mix.exs` existing `project/0` and `docs/0` entries | exact |
| `.release-please-manifest.json` (candidate-generated metadata, if refreshed in the reviewed source) | config / release version anchor | batch | `.release-please-manifest.json` | exact |

All named analog paths were verified as tracked with `git ls-files`. The new ledger path is intentionally a placeholder because context delegates its exact name/shape. No source-code controller, service, or UI work is in this phase.

## Pattern Assignments

### `.planning/phases/247-release-candidate-and-repository-readiness/<inventory-ledger>` (documentation/evidence, batch)

**Analog:** `.planning/research/v1.49-release-scope/REPO-STATE.md` (tracked historical report; use its organization, not its stale facts or conclusions).

**Snapshot and provenance pattern** (`REPO-STATE.md`, lines 1-3):

```markdown
# Repository State and Release Scope: Proposed v1.49

**Repository snapshot:** branch `phase-244-playwright-measurement`, HEAD `94051d8c`; read-only inspection only. No tests or CI were run for this report.
```

**Inventory pattern** (`REPO-STATE.md`, lines 22-35): it groups paths, states observed purpose/relevance, then distinguishes direct relevance from conditional relevance. The phase ledger must go further: record trusted base and candidate SHA, every committed delta and dirty/untracked path, every open PR, an individual disposition/reason, and preservation location as required by READY-02. Refresh all observations when executing; do not copy this report's dated branch, version recommendation, or path inventory.

### `guides/introduction/upgrading-to-v1.6.md` (documentation, adopter action flow)

**Analog:** `guides/introduction/upgrading-to-v1.5.md`.

**Opening and ownership pattern** (lines 1-3):

```markdown
# Upgrading generated hosts for v1.5 auth capability gates

Sigra v1.5 adds runtime capability gates to newly generated authentication surfaces. All three switches default to `true`, so updating the dependency preserves existing behavior. Generated files belong to the host and are never overwritten automatically.
```

**Existing-host adoption pattern** (lines 28-39): tell readers not to force-overwrite customized generated files, describe selective adoption, and end with concrete host checks. Adapt its detailed steps only to generated changes proven present in the final 1.6.0 source. Include supported package constraints and verified CI matrix separately, then give the exact `~> 1.6.0` dependency update/check commands after confirming them against final metadata. Explain migration and `mix sigra.upgrade` status only after inspecting the reviewed source. Keep troubleshooting symptom-led per D-07.

### `README.md` (documentation, navigation)

**Analog:** `README.md` itself, tracked.

**Reader routing pattern** (lines 17-25):

```markdown
## Pick your lane

| You are… | Do this first |
|----------|----------------|
| **Existing Sigra app / upgrade** | Follow [Upgrading to v1.0](guides/introduction/upgrading-to-v1.0.md) for the operational preflight, generated-host review, and rollback path. |
```

Add the v1.6 guide to the existing upgrade row/path, keeping the README → guide → versioned changelog route. Preserve the table's audience-first, action-oriented phrasing and existing upgrade links.

### `CHANGELOG.md` (documentation, release-note batch)

**Analog:** `CHANGELOG.md` v1.5.0 section.

**Versioned release-summary shape** (lines 22-36):

```markdown
## [1.5.0](https://github.com/szTheory/sigra/compare/v1.4.0...v1.5.0) (2026-08-31)

### Added

- Generated hosts now support independent, default-on `mfa.enabled`, `passkeys.enabled`, and `enterprise.enabled` capability switches.

### Upgrade notes

- Generated host files remain host-owned and are not overwritten. Existing apps can adopt the new runtime config reads ... There is no database migration for these switches.
```

Follow the actual Release Please `## [1.6.0]` heading with concise, reader-facing Added/Changed/Upgrade notes only for reviewed shipped behavior. Keep internal phase IDs out of the product summary; useful commit traceability may remain in generated detail. Verify no candidate-specific summary is stranded in `Unreleased` (the warning at lines 12-20 explains why).

### `mix.exs` (package/docs configuration)

**Analog:** `mix.exs`, tracked.

**Version and package constraints** (lines 4-12, 99-109):

```elixir
@version "1.5.0"
...
version: @version,
elixir: "~> 1.18",
...
{:phoenix, "~> 1.8"},
{:phoenix_live_view, "~> 1.1"},
```

Treat `@version` and dependency constraints as package metadata and state constraints separately from CI-tested versions. Do not infer a tested compatibility matrix from `~>` constraints.

**ExDoc source and extras pattern** (lines 207-209, 215-240):

```elixir
# Hex/ExDoc: before mix hex.publish, ensure git tag v#{@version} exists or "View source" on hexdocs returns 404.
source_ref: "v#{@version}",
source_url: @source_url,
...
extras: [
  "README.md",
  ...
  "guides/introduction/upgrading-to-v1.5.md",
```

Add the new guide to `extras` adjacent to the existing versioned upgrade guides. Keep `source_ref` tied to `@version`; reconcile it with the selected tag/source only when the final candidate source is known.

### `.release-please-manifest.json` (release metadata, batch)

**Analog:** `.release-please-manifest.json` (tracked).

Its current compact content is the release anchor (`{".": "1.5.0"}` at lines 1-3). Release Please owns updating this value as part of PR #224; use the configured generator and review the resulting value alongside `mix.exs` and the changelog. Do not hand-roll an independent version/history mechanism.

## Shared Patterns

### Candidate metadata consistency

**Sources:** `mix.exs` lines 4-11, 207-209; `.release-please-manifest.json`; `CHANGELOG.md` lines 12-22; `release-please-config.json` lines 1-10.

Use Release Please for version/history generation, then review the manifest version, `mix.exs` package version, `## [1.6.0]` section, planned `v1.6.0` source reference/tag, and docs/package build as one candidate. The workflows and Release Please config are context/source-of-truth seams, not planned changes in this phase.

### Adopter claims must follow source ownership

**Sources:** `README.md` lines 7-13; `guides/introduction/upgrading-to-v1.5.md` lines 28-43.

State separately what a dependency update delivers and which already-generated, host-owned files require selective adoption. Fresh generated hosts use current templates. Never claim a migration is unnecessary until the reviewed candidate's schema/migration diff and upgrade task are checked.

### Evidence must carry time and source identity

**Source:** `.planning/research/v1.49-release-scope/REPO-STATE.md` lines 1-3, 22-35.

Record when and against which base/head each GitHub/Git inventory was collected. Historical inventory reports are useful for layout, but live PR and checkout facts expire; the ledger must cover every object/path individually rather than copy a historical summary.

## No Analog Found

No exact analog exists yet for a Phase 247-specific READY-01/READY-02 acceptance checker. RESEARCH.md calls such a checker conditional and leaves its exact path undecided. If planning creates one, first identify its scope and language, then reuse the repository's nearest contract-test or evidence-validator pattern; do not imply a checker is already specified.

## Metadata

**Analog search scope:** phase context/research, README and introduction guides, release metadata/configuration, workflow seams, and tracked planning inventory reports.
**Files scanned:** 8 principal sources; no parallel search beyond the needed analogs.
**Pattern extraction date:** 2026-10-06
