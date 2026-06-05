# Phase 145: 1.0 Contract And Release Truth - Pattern Map

**Mapped:** 2026-05-31  
**Files analyzed:** 12 planned new/modified files  
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/introduction/contract.md` | public guide | docs entry point | `guides/introduction/first-hour.md`, `guides/introduction/suite-integration.md` | role-match |
| `README.md` | public router | docs entry point | Existing README topic-map and security posture sections | exact |
| `SECURITY.md` | security policy + invariants | public contract | Existing disclosure policy plus README security posture | role-match |
| `CHANGELOG.md` | release history | version-axis truth | Existing "Planning milestones vs Hex releases" section | exact |
| `MAINTAINING.md` | maintainer runbook | release process | Existing "Release automation" and "Semver for Sigra" sections | exact |
| `mix.exs` | package/docs metadata | config | Existing `docs/0` extras and `source_ref: "v#{@version}"` | exact |
| `release-please-config.json` | release automation config | config | Existing Release Please manifest-mode package config | exact |
| `.release-please-manifest.json` | release automation state | config | Existing manifest last-shipped version | exact |
| `guides/introduction/installation.md` | install guide | docs first path | Existing dependency block | exact |
| `guides/introduction/getting-started.md` | first-use guide | docs first path | Existing dependency prerequisite | exact |
| `guides/introduction/first-hour.md` | evaluator guide | docs first path | Existing dependency checklist | exact |
| `guides/recipes/companion-libs/*.md` | companion recipes | docs examples | Existing recipe dependency blocks | exact |

## Pattern Assignments

### `guides/introduction/contract.md`

Use the concise guide pattern from introduction docs:

- Start with a one-paragraph statement of what the page decides.
- Prefer tables for compatibility, ownership, security invariants, and non-goals.
- Link to implementation/detail surfaces instead of duplicating large bodies.
- Keep claims adopter-facing; avoid `.planning/`-only internal jargon except when explaining planning milestone labels.

Required anchors:

- `# Sigra 1.0 Contract`
- `## Version Axes`
- `## Supported Stack`
- `## Ownership Boundaries`
- `## SemVer And Deprecation Policy`
- `## Security Invariants`
- `## Non-Goals`

### `README.md`

Preserve the current router style:

- "Pick your lane" remains the top-level navigation surface.
- "Prerequisites" stays compact.
- "Security posture" remains a headline table, with the canonical contract linked for detail.
- Dependency examples should use `{:sigra, "~> 1.0"}` once this phase locks the selected 1.0 package path.

### `SECURITY.md`

Extend the existing disclosure policy instead of replacing it. Add product security invariants and non-goals under the private vulnerability reporting section or after it. Keep wording clear that Sigra does not certify host deployments.

### `CHANGELOG.md`

Modify only the dual-axis explainer and current Unreleased area as needed. Do not rewrite old release entries. Keep Keep-a-Changelog and SemVer references intact.

### `MAINTAINING.md`

Add a 1.0-specific release path near "Release automation (default)" so maintainers see it before manual release recovery. Keep Phase 146-owned gate/runbook details as forward references, not full implementation.

### `release-please-config.json` and `.release-please-manifest.json`

Add `release-as: "1.0.0"` to the package config. Keep `.release-please-manifest.json` at `0.3.0` before the release PR because the manifest records last shipped version until Release Please records the new release.

### `mix.exs`

Add `guides/introduction/contract.md` to ExDoc extras and Introduction grouping. Do not manually bump `@version` in Phase 145 unless execution is intentionally inside the Release Please release PR.

## Implementation Notes

- Prefer one canonical contract page and top-level pointers over spreading the full matrix across README, SECURITY, MAINTAINING, and guide pages.
- Use source assertions to prevent accidental drift: Release Please override, manifest last-shipped value, ExDoc extras entry, and presence of boundary language.
- Companion recipe examples may be updated mechanically from `~> 0.2` to `~> 1.0` if they are public first-path examples; preserve sister library version pins.

