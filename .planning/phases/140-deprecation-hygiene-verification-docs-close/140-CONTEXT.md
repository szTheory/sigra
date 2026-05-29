# Phase 140: Deprecation Hygiene + Verification & Docs Close - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Milestone-close phase of v1.30 TRUST-HARDENING. Three bounded jobs, no new feature surface:

1. **Deprecation hygiene** — give the 2 live `@deprecated` public functions real removal target versions + migration notes.
2. **Verification proof** — prove the whole milestone's claims green via the established Phase-136 proof-bundle pattern, including exercising `mix sigra.doctor` against `test/example/`.
3. **Docs close** — update guides/docs so they reflect everything shipped this milestone (doctor usage, OptionalDeps maintainer note, deprecation-timeline notes, recipe-contract-testing note) and reconcile the stale ROADMAP Phase-137 progress entries.

Scope anchor: this phase verifies and documents already-shipped substrate (137/138/139). It does NOT add capabilities, change runtime behavior, or actually delete the deprecated functions now — it *schedules* their removal.
</domain>

<decisions>
## Implementation Decisions

### Versioning anchor (governs all removal-target language)
- **D-01:** Removal targets are expressed in **Hex SemVer `0.x` minors**, never in internal `v1.x` planning-milestone labels. The Hex package is `0.3.0` (mix.exs:4); `v1.x` labels are planning tranches only, and the repo stays `0.x` on Hex until an explicit `1.0.0` API-stability cut (CHANGELOG.md:10, MAINTAINING.md:216-220). Per pre-1.0 policy, `0.y` minors are the unit for removing supported public API.

### Deprecation hygiene (DEPR-01 / DEPR-02)
- **D-02:** `Sigra.MFA.Trust.cookie_opts/0` (the already-removed raising `no_return()` stub at `lib/sigra/mfa/trust.ex:42-57`) is scheduled for **full deletion of the stub in `0.4.0`** — the next minor. It already raises and carries a migration note; only the removal target is added.
- **D-03:** `Sigra.Account.audit_forced_password_change/2` (still-functional soft-deprecation at `lib/sigra/account.ex:542-556`) is scheduled for **removal in `0.5.0`** — one minor of soft-deprecation grace beyond the next release, since it still works and migration off it is non-trivial. Migration note already points to `clear_password_change_requirement/3`.
- **D-04:** The removal target version is baked into the `@deprecated` string (and `@doc deprecated:` where present) for each function, AND recorded as a deprecation-removal-timeline note in docs (see D-09). Do not weaken or remove the existing migration guidance — append the target version to it.

### Verification proof (PROOF-01)
- **D-05:** Reuse the **Phase 136 six-gate proof-bundle pattern verbatim**. Template/precedent: `.planning/phases/136-.../136-VERIFICATION.md`. File a single `140-VERIFICATION.md` with the canonical dash-prefix name and YAML frontmatter (`phase / verified / status / score / overrides_applied`).
- **D-06:** Proof gates (all must be green): (1) full suite `mix test`; (2) audit subtree `test/sigra/audit/`; (3) dep-off lane (`mix deps.unlock/clean threadline` + `--exclude requires_threadline --no-deps-check`, matching ci.yml:171-219); (4) `test/example/` lane (`cd test/example && mix test --include example_app`); (5) `mix docs --warnings-as-errors` exit 0; (6) **`mix sigra.doctor` exercised against `test/example/`** (new gate this phase — confirm it runs and its exit-code gate behaves).
- **D-07:** Add a gate/check that the two deprecation removal-timeline notes **actually render in `mix docs`** (not just live in source), so PROOF-01 proves DEPR-01/DEPR-02 landed in published docs.
- **D-08:** Credo `--strict` advisory issues remain a **recorded non-blocking advisory** (consistent with prior milestone-close phases; not CI-enforced). Per-phase `*-VERIFICATION.md` artifacts are filed for the milestone's phases as needed.

### Docs close (DOC-01)
- **D-09:** Placement:
  - `mix sigra.doctor` **usage** → new `## Operator diagnostics` (or equivalent) section in `guides/recipes/deployment.md` (operator/production-checklist audience).
  - `Sigra.OptionalDeps` **maintainer** note + **recipe-contract-testing** note + **deprecation-removal-timeline** note → new `##` sections in `MAINTAINING.md` (maintainer audience; matches existing "Installer golden CI contract" / "Semver pre-1.0" section precedent).
- **D-10:** Any new or newly-referenced guide/extra MUST be registered in mix.exs `extras` and the correct `groups_for_extras` bucket (mix.exs:184-234) — otherwise it silently won't surface on hexdocs. The empty `guides/upgrading/.keep` is NOT the home for these notes.
- **D-11:** The recipe-contract-testing note documents the fixture at `test/sigra/recipes/companion_lib_contract_test.exs` as a maintainer-internal drift guard (not a Hex-facing recipe).

### Stale-state reconciliation
- **D-12:** Fixing the stale ROADMAP Phase-137 entries is **in scope** for this DOC-01 close: flip `[ ]`→`[x]` on ROADMAP.md lines 45 / 70 / 71 and reconcile the "1/3" progress-table row (line ~135) to reflect 137 complete (optional_deps.ex + both summaries prove it). STATE.md drift and the stale `v1.28-data-lifecycle` branch name are **deferred to `/gsd-complete-milestone`** — out of this phase's lane.

### Claude's Discretion
- Exact section titles/wording of the new MAINTAINING.md and deployment.md sections.
- Whether `mix docs` deprecation-rendering check (D-07) is a grep assertion vs. a manual proof step — planner's call, as long as it proves the notes are published.
- Internal modularization of any verification helper / test shape.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 140 success criteria; lines 45/70/71/135 (stale 137 entries to reconcile per D-12)
- `.planning/REQUIREMENTS.md` — DEPR-01, DEPR-02, PROOF-01, DOC-01 (lines 31-37, 82-85)
- `.planning/phases/136-verification-proof-bundle-narrative-honesty-corrigendum/136-VERIFICATION.md` — proof-bundle template (D-05/D-06)
- `lib/sigra/account.ex:542-556` — DEPR-01 target (`audit_forced_password_change/2`)
- `lib/sigra/mfa/trust.ex:42-57` — DEPR-02 target (`cookie_opts/0` raising stub)
- `MAINTAINING.md:216-244` — pre-1.0 SemVer policy + section precedent for DOC-01 notes
- `CHANGELOG.md:10` — planning-vs-Hex versioning convention
- `mix.exs:4,180-234` — `@version "0.3.0"`, `extras`, `groups_for_extras` (D-10)
- `.github/workflows/ci.yml:171-219` — dep-off lane definition (D-06)
- `test/sigra/recipes/companion_lib_contract_test.exs` — recipe-contract fixture (D-11)
- `lib/sigra/optional_deps.ex`, `lib/sigra/doctor.ex`, `lib/mix/tasks/sigra.doctor.ex` — 137/138 substrate being verified
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Phase 137 fully landed:** `lib/sigra/optional_deps.ex` exposes all 9 `*_available?/0` predicates + `encryption_active?/1`. 137-02/03 summaries filed (`completed: 2026-05-29`). The ROADMAP checkbox/progress drift is cosmetic only.
- **Phase 138 fully landed:** `mix sigra.doctor` exists (`lib/mix/tasks/sigra.doctor.ex` + `lib/sigra/doctor.ex`), exits non-zero on misconfig (138-VERIFICATION.md) — usable as a CI/proof gate.
- **Phase 136 proof-bundle pattern** is the verbatim template for PROOF-01 (exact commands documented there).
- **`test/example/` app** is runnable (`app: :example`, 236 tests) — the target for the `mix sigra.doctor` exercise gate.

### Established Patterns
- Pre-1.0 SemVer policy (MAINTAINING.md:216): `0.y` minors are potentially breaking and are the unit for removing public API; no 1.0.0 jump without explicit API-stability declaration.
- Remaining raw `Code.ensure_loaded?` sites in `lib/` are the documented out-of-scope category (compile-time `defmodule` wrappers, dynamic host-schema atoms, boot-warning `cond`, doctor's dynamic-forwarder exception) — NOT a 137 gap. The DOC-01 OptionalDeps note must scope its "single source of truth" claim to runtime guards accordingly.
- ExDoc surfacing requires registration in mix.exs `extras` + `groups_for_extras`.

### Integration Points
- DEPR edits: in-place edits to two existing public functions (string + docs only; no behavior change).
- PROOF: read-only verification across existing test lanes + a `mix sigra.doctor` run.
- DOC: appends to existing `MAINTAINING.md` and `guides/recipes/deployment.md`; ROADMAP edits.
</code_context>

<specifics>
## Specific Ideas

- Removal schedule explicitly chosen by user: `cookie_opts/0` stub → **0.4.0**; `audit_forced_password_change/2` → **0.5.0** (staggered, SemVer-clean, one minor of grace for the still-working function).
</specifics>

<deferred>
## Deferred Ideas

- STATE.md drift reconciliation and the stale `v1.28-data-lifecycle` branch name → `/gsd-complete-milestone` (not this phase).
- Actually deleting the deprecated functions → future `0.4.0` / `0.5.0` releases (this phase only schedules + documents).

### Reviewed Todos (not folded)
None — `todo.match-phase 140` returned no matches.
</deferred>
