# Phase 198: Contributor DX & Acceptance Gate - Context

**Gathered:** 2026-06-20
**Status:** Ready for planning
**Source:** Research-then-plan path (gsd-plan-phase, no discuss-phase) + 1 user decision

<domain>
## Phase Boundary

Final closeout phase of the v1.40 CI-PERF milestone (phases 193–197 Complete). Two jobs:
1. **DX-01** — Ship a single documented local command (`mix ci`) that mirrors the PR-fast required gate so a contributor can reproduce a red PR check locally, documented in CONTRIBUTING.md.
2. **GATE-01 / GATE-02** — Produce committed before/after acceptance evidence (wall-clock + p95 + flake) proving the PR path is meaningfully faster than the Phase 193 baseline with equal-or-greater quality signal, and confirm no flake / no correctness-critical coverage dropped / required-check names stable / SEED-004 (phx_new 1.8.7) respected / snapshot determinism preserved.

This is a CI/DX/process phase. No external packages, no security domain, no library code.
</domain>

<decisions>
## Implementation Decisions

### D-01 — Local CI mirror is a `mix ci` alias (not make/just)
Add a `mix ci` alias to `mix.exs` `aliases/0`, in the existing `ci.*` namespace. Idiomatic Elixir, no new dependency. (Open Decision 3 — confirmed.)

### D-02 — `mix ci` chains only the locally-faithful PR-gate legs
`mix ci` chains `compile --warnings-as-errors` + `mix test` + `ci.install_golden` + `sigra.dep_off` — each leg byte-mirrors a real PR-gate command. It must NOT be stricter than the gate. (Open Decision 4 — keep it fast.)

### D-03 — Exclude format/credo/dialyzer from `mix ci`
`format --check-formatted`, `credo --strict`, and `dialyzer` are NOT in the PR gate today (grep-verified). Adding them would make `mix ci` stricter than CI (local red where CI is green), contradicting DX-01. Exclude them; document them separately in CONTRIBUTING as optional "additional local hygiene", not part of the gate mirror. (Open Decision 2 — confirmed.)

### D-04 — CI-only / heavy lanes documented, not folded into `mix ci`
Ubuntu-baselined Playwright snapshot lanes and the heavy generated-host scaffold smokes (`install_smoke`, `example_http_smoke`) are intentionally NOT in the default `mix ci`. CONTRIBUTING must document (a) which PR-gate lanes are CI/ubuntu-only and why they're excluded, and (b) the exact commands for the heavy scaffold smokes as an optional deeper local check. Contributors must also be steered to the phx_new 1.8.7 archive (SEED-004) and the Postgres prerequisite, and warned about the known non-regression local `mix test` failures.

### D-05 — Acceptance evidence is a committed `198-ACCEPTANCE.md`
Author `198-ACCEPTANCE.md` in the phase dir, mirroring the `193-BASELINE.md` table shape. It diffs REAL post-197 CI run timings (via `gh run view --json jobs` — not estimates) against the 193 baseline, asserts the 5 enforced required-check names unchanged (via `gh api` against ruleset 14941512), records the flake check, and demonstrates equal-or-greater quality signal concretely. Add an ADD-only pointer from MAINTAINING.md.

### D-06 — Hard re-gate the design-gallery soft-gate in 198 (USER-CONFIRMED)
Remove `continue-on-error: true` at `ci.yml:1047` and restore `design_gallery` to the aggregator loop, gated behind a confirm-green step against the new ubuntu baselines (PR #60 merged; OQ3 cross-lane clean). Serves GATE-02 and makes the "equal-or-greater quality signal" claim honest. Confirm the lane is green against the new baselines before removing the soft gate.

### D-07 — Close the already-resolved stale Phase51 ci-contract todo
`2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md` describes a contract test that is already fixed (the test no longer asserts the removed job key). Close it as already-resolved during this phase's hygiene; do NOT re-fix.

### Claude's Discretion
Plan/wave structure, exact CONTRIBUTING prose, exact acceptance-table columns (must at least cover wall-clock, p95, flake-rate per the verification mechanism), and how the confirm-green step for D-06 is implemented.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research + baseline
- `.planning/phases/198-contributor-dx-acceptance-gate/198-RESEARCH.md` — full PR-gate enumeration, `mix ci` composition, acceptance method, landmines
- `.planning/phases/193-*/193-BASELINE.md` — the before-baseline (~38m wall-clock, 22m Playwright pole) and the exact `gh run view --json jobs` measurement method
- `.planning/phases/196-*` and `197-*` artifacts — PR-fast vs nightly-broad trigger model; Playwright lanes; design-gallery re-gate history

### CI surface
- `.github/workflows/ci.yml` — current PR-path vs nightly jobs; the `continue-on-error: true` at line ~1047 (D-06 target)
- `mix.exs` — existing `ci.audit_45`, `ci.install_golden`, `sigra.dep_off`, `test.db` aliases to extend (D-01/D-02)
- `MAINTAINING.md` — the 5 enforced required-check names (ruleset 14941512); ADD-only acceptance pointer (D-05)
- `CONTRIBUTING.md` — where DX-01 documentation lands
- `scripts/ci/` — snapshot-canary-guard, acceptance/install/http smokes
</canonical_refs>

<specifics>
## Specific Ideas

- Required-check stability target = the **5 enforced ruleset names**, NOT the internal `ci-gate` aggregator.
- "After" numbers must come from real post-197 CI runs, captured honestly.
- phx_new 1.8.7 pin (SEED-004) and snapshot/baseline determinism are hard constraints, not goals.
</specifics>

<deferred>
## Deferred Ideas

- Adding format/credo/dialyzer as new mandatory PR gates — OUT OF SCOPE (REQUIREMENTS.md forbids new mandatory gates; CI-PERF is about speed/trust of existing gates).
</deferred>

---

*Phase: 198-contributor-dx-acceptance-gate*
*Context gathered: 2026-06-20 via research-then-plan path*
