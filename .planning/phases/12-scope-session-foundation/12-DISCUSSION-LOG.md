# Phase 12: Scope + Session Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 12-scope-session-foundation
**Areas discussed:** Migration shape, Sigra.Session library struct, Scope constructor API, Reserved-field discipline

---

## Migration shape

Parallel subagent research (web + Context7) covered: Oban versioned migrations, Ecto/Dashbit guidance on editing released migrations, ash_postgres snapshot patterns, phx.gen.auth one-shot limitations, fly.io safe migrations guide.

| Option | Description | Selected |
|--------|-------------|----------|
| A. Extend `:primary` migration in place | Edit `migration.exs` `create table(:user_sessions)` block across all 3 DB-dialect branches. Fresh install emits 3 files. Rebaseline Phase 11 golden. | |
| B. New `:active_org_column` slot → separate ALTER migration | Add new slot in `Features.Core.migrations/1`; new template file with dialect-agnostic `alter table ... add`. Fresh install emits 4 files. Phase 11 files stay byte-identical. | ✓ |

**User's choice:** Option B.
**Notes:** User explicitly delegated ("okay sure option b i guess? idk even what the tradeoff is i trust u"). Research rationale was strong: Phase 18 upgrade reuses the same template verbatim, dialect-agnostic ALTER eliminates the 3-branch edit problem, Phase 11's byte-identity invariant stays clean, matches the idiomatic Oban / Dashbit pattern.

---

## Sigra.Session library struct

Initial research presented Option B (metadata map) as recommended based on an "org-unaware library" principle. User pushed back: v1.1 IS the organizations milestone, so that framing is stale. Rethink with the corrected frame flipped the rec to Option A.

| Option | Description | Selected |
|--------|-------------|----------|
| A. First-class `:active_organization_id` field on `%Sigra.Session{}` | Add field directly to the struct. 1:1 with DB column. Flat pattern matching, Dialyzer visible. | ✓ |
| B. Generic `:metadata` map (Oban `Job.meta` / Pow `:pow_session_metadata` pattern) | Add `metadata: %{}` field; nest `active_organization_id` inside. Library stays org-agnostic. | |
| C. Library struct unchanged | Field only on generated `UserSession` Ecto schema. | |

**User's choice:** Option A (after rethink).
**Notes:** Original rec was B under the assumption that `lib/sigra/` should stay org-unaware. User correctly pointed out that framing contradicts the v1.1 Organizations milestone. Wrote a project memory entry (`project_v1_1_org_aware.md`) documenting that the earlier framing is stale. Re-evaluated without the purity constraint: Option A wins on every axis — flat pattern matching, Dialyzer visibility, 1:1 mapping to the DB column and generated schema, principle of least surprise. v1.2 `:impersonating_from` will land the same way (additive struct field), which is normal Elixir struct evolution (Oban's `Job` struct has grown ~20 fields across versions).

---

## Scope constructor API

Subagent research covered: Phoenix 1.8 scopes guide, mix phx.gen.auth output, ElixirForum scope discussions, AshAuthentication session handling, Elixir community guidance on struct extension vs keyword opts.

| Option | Description | Selected |
|--------|-------------|----------|
| A. Pure additive defstruct, arity-1 `for_user/1` unchanged | Matches Phoenix 1.8 scopes guide verbatim; zero API change; `put_active_organization/2` lands in Phase 14. | ✓ |
| C. Arity-2 with keyword opts | Named construction via opts bag; Dialyzer can't type `keyword()`; diverges from Phoenix convention; CLAUDE.md flags "catch-all opts" as anti-pattern. | |
| D. Explicit `hydrate/2` builder in Phase 14 | Named seam for tests; compatible with A. Not a competing option — Phase 14's choice. | |

**User's choice:** Option A (recommended).
**Notes:** Phoenix 1.8's official scopes guide is the authoritative precedent. Sigra's "you own your code" philosophy means host apps that already generated `scope.ex` see a minimal diff. The `struct() | nil` typespec for `:active_organization` and `:membership` is honest in Phase 12 (Organization/Membership schemas don't exist until Phase 13) and will be tightened in Phase 13 as a one-line template edit.

---

## Reserved-field discipline for `:impersonating_from`

Initial research covered four options (doc comment, host-side test, library invariant test, golden-diff reliance). User asked for a deeper dive on belt-and-suspenders tradeoffs: "wouldn't belt and suspenders be fine whats the drawback really?" A second subagent produced a focused decision on the A+C+D vs A+C question.

| Option | Description | Selected |
|--------|-------------|----------|
| A. Doc comment only | Zero cost; 6-month silent breakage window until v1.2 reaches for the field. | Part of pick |
| B. Test shipped in host's generated suite | Host can delete test with field; adds noise to generated test code. | |
| C. Library-side invariant test (grep + compile-and-introspect) | Two assertions on the template source + rendered EEx output. Loud failure message naming UPGRADE-v1.2.md. ~30 LOC. | Part of pick |
| D. Phase 11 golden-diff reliance | Already exists; but "golden diff mismatch" is a review-dependent signal; contributor regenerating the golden would silently accept the deletion. | Deliberately excluded |

**User's choice:** A + C, skip D.
**Notes:** Second research subagent was decisive: D adds zero marginal signal over C (C fires first on the same mutation with a clear failure message), and creates "which test is authoritative?" confusion on failure. Belt-and-suspenders where the second belt adds cost without adding signal is the exact anti-pattern Sigra's simplicity principle targets. Keep the golden-diff in place for general drift detection — just don't rely on it for this specific invariant.

Also created `UPGRADE-v1.2.md` skeleton as part of Phase 12 (D-12) — the single referenced target from D-11's failure messages.

---

## Claude's Discretion

- `UPGRADE-v1.2.md` format — short markdown, two or three sections (CD-02).
- Test module naming — planner may rename `Sigra.Install.ScopeTemplateInvariantsTest` as long as location and invariant clarity are preserved (CD-03).
- Whether `SessionStore` test doubles need updating vs. real impls covering the round-trip (CD-04).

## Deferred Ideas

- `Sigra.Session.put_active_organization_id/2` setter — deferred to Phase 14 if three or more call sites benefit.
- `Scope.put_active_organization/2` helper — Phase 14 lands this following the Phoenix 1.8 `put_organization/2` precedent.
- Index on `user_sessions.active_organization_id` — Phase 14 or Phase 18 when the FK target exists.
- `:impersonating_from` field on `Sigra.Session` — v1.2 additively.
- Metadata map extensibility on `Sigra.Session` — revisit if a future phase needs host-extensible session state for non-auth concerns.
