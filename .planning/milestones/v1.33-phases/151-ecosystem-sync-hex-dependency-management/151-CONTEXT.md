# Phase 151: Ecosystem Sync & Hex Dependency Management - Context

**Gathered:** 2026-06-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Verify compatibility with latest Elixir/Phoenix, zero deprecation warnings on latest OTP, bump Hex dependencies safely, confirm supply-chain security via passing CI suite.
</domain>

<decisions>
## Implementation Decisions

### Hex Dependency Automation Strategy
- **D-01:** Hex dependency updates will be performed manually (`mix deps.update --all`) without expanding Dependabot configuration.

### OTP/Elixir Compatibility CI Matrix
- **D-02:** CI compatibility verification will rely strictly on updating `.tool-versions` to the target Elixir/OTP rather than introducing a multi-version build matrix.

### Deprecation Warning Remediation
- **D-03:** Any deprecation warnings from dependencies or core Elixir will be fixed via code changes rather than compiler suppression.

### Dependency Range Upgrades
- **D-04:** Dependency bumps will remain within the existing `~>` constraints in `mix.exs` unless a major bump is explicitly required to clear OTP deprecations.

### Claude's Discretion
None
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

.planning/ROADMAP.md
.planning/REQUIREMENTS.md
mix.exs
.github/workflows/ci.yml
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/ci.yml` strictly enforces single `.tool-versions`
- `mix.exs` controls all `~>` bounds and `elixirc_options`

### Established Patterns
- Strict single-version CI pipeline instead of multi-version matrix.
- `mix compile --warnings-as-errors` enforced across both example apps and library paths.

### Integration Points
- Dependabot config in `.github/dependabot.yml`
- Erlang/Elixir setup in `.github/workflows/ci.yml` via `erlef/setup-beam`
</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches
</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope
</deferred>