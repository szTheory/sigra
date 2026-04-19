# Phase 40 — Pattern map

Analogs for planners/executors when touching docs and CI.

## GitHub Actions (SHA pins)

**Reference:** `.github/workflows/ci.yml` (first ~80 lines).

- `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2`
- `erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93  # v1.24.0`

**Rule:** New third-party actions use **full commit SHA** + trailing **comment** with upstream version tag.

## Maintainer vs contributor docs

**Reference:** `CONTRIBUTING.md` — Postgres, CI jobs, Playwright artifact review; no Hex secrets.

**Pattern:** One short “Maintainers → see `MAINTAINING.md`” pointer near top or end; **do not** embed `HEX_API_KEY` / publish steps in `CONTRIBUTING.md`.

## ExDoc extras

**Reference:** `mix.exs` → `defp docs do` → `extras: [...]`.

**Pattern:** Add root-level `.md` files alongside `README.md` / `CONTRIBUTING.md`; optional `groups_for_extras` regex if grouping is needed (Phase 40 may rely on default ungrouped listing like existing README extra).

## Plan document shape

**Reference:** `.planning/phases/39-audit-trail-completeness/39-01-PLAN.md`.

- YAML frontmatter: `phase`, `plan`, `type`, `wave`, `depends_on`, `files_modified`, `autonomous`, `requirements`, `must_haves`, `nyquist_compliant`
- Blocks: `<objective>`, `<threat_model>`, `<context>`, `<tasks>` with `<read_first>`, `<action>`, `<acceptance_criteria>`, `<verify>`, `<done>`

## PATTERN MAPPING COMPLETE
