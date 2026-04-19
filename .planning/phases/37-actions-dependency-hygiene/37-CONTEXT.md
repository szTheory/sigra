# Phase 37: Actions & dependency hygiene — Context

**Gathered:** 2026-04-17  
**Status:** Ready for planning  
**Source:** Roadmap + REQUIREMENTS.md (no separate discuss-phase; operational phase)

<domain>

## Phase boundary

Close backlog **999.2** by triaging and landing **first-party `actions/*` major upgrades** called out in `.planning/MILESTONES.md` (checkout, setup-node, upload-artifact), keeping **full 40-character SHA pins** with inline `# vX.Y.Z` comments as today. No application feature work.

</domain>

<decisions>

## Implementation decisions

- **D-37-01:** Pin format stays `uses: actions/NAME@FULLSHA  # vX.Y.Z` (same style as existing workflows).
- **D-37-02:** Target majors for this phase: `actions/checkout` **v6.0.2** (`de0fac2e4500dabe0009e67214ff5f5447ce83dd`), `actions/setup-node` **v6.0.0** (`2028fbc5c25fe9cf00d9f06a71cc4710d4507903`), `actions/upload-artifact` **v6.0.0** (`b7c566a772e6b6bfb58ed0dc250532a479d7789f`) — SHAs resolved from `https://api.github.com/repos/{owner}/{repo}/git/refs/tags/{tag}` on 2026-04-17; executor MUST re-resolve if Dependabot proposes newer patch on same major line.
- **D-37-03:** Scope is `.github/workflows/ci.yml` and `.github/workflows/playwright-github-pages.yml` for those three actions; `erlef/setup-beam`, `actions/cache`, and `peaceiris/actions-gh-pages` stay on current pins unless a separate Dependabot PR already targets them (then fold into same merge window).
- **D-37-04:** `actions/upload-artifact` v4→v6: read upstream release notes before merge; adjust `with:` only if a breaking change applies (retention-days, compression-level, merge-multiple, etc.).

</decisions>

<canonical_refs>

## Canonical references

- `.planning/REQUIREMENTS.md` — CI-01..CI-03
- `.planning/ROADMAP.md` — Phase 37 row
- `.planning/MILESTONES.md` — 999.2 / Dependabot intent
- `.planning/phases/999.2-dependabot-major-version-bumps/999.2-VALIDATION.md` — supersession pointer to Phase 37
- `.github/workflows/ci.yml` — primary CI surface
- `.github/workflows/playwright-github-pages.yml` — secondary workflow

</canonical_refs>
