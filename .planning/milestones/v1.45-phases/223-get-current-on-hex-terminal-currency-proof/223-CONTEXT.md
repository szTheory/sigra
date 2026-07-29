# Phase 223: Get Current on Hex + Terminal Currency Proof - Context

**Gathered:** 2026-07-10 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Terminal phase of the **v1.45 RELEASE-CURRENCY** milestone. Scope is release-ops
verification + trust-artifact capture, NOT code implementation. Two scoped
requirements remain:

- **PUB-05** — prove a clean adopter resolution: `{:sigra, "~> 1.0"}` / `mix deps.update`
  resolves to the current GA (`1.3.0`), not the stray `1.20.0` nor the stale `1.1.0`.
- **PROOF-01** — record the release-currency proof bundle (the milestone's trust
  artifact): `ci-gate` green on `main`, Hex `latest_stable_version = 1.3.0`, adopter
  `~> 1.0` resolution verified, full library + example suites green.

**Live reality at discuss time (confirmed via `curl https://hex.pm/api/packages/sigra`):**
`latest_stable_version: 1.20.0`, `latest_version: 1.20.0`, `retirements: {}`, releases
`[1.20.0, 1.3.0, 1.2.0, 1.1.0, 1.0.0, …]`. v1.2.0 + v1.3.0 were published in Phase 221;
the stray **1.20.0 is unretired**, so `~> 1.0` resolves to it TODAY. **PUB-05 and PROOF-01
are literally unsatisfiable until 1.20.0 is retired.**

Out of scope: publishing new versions (v1.2.0/v1.3.0 already live), gate/lane changes
(Phases 221/222 owned those), any code changes.
</domain>

<decisions>
## Implementation Decisions

### Retire & Currency — the crux (Area 1)
- **D-01:** Phase 223 **UN-DEFERS PUB-04** — the retire of stray `1.20.0` is executed
  in-phase (operator chose "Retire now (real green)" over the deferred-execution shape).
  Operator mints a **web-dashboard** Hex API write key (https://hex.pm/dashboard/keys,
  API/write permission — Hex 2.5 has no CLI key-gen) and runs
  `HEX_API_KEY=<key> mix hex.retire sigra 1.20.0 invalid --message "Published in error during dev cycle; not a real release — use 1.3.0+"`.
  This is an `autonomous: false` operator checkpoint (interactive Hex write-auth — cannot
  be automated). The Hex 2.5 **device-flow** token blocker does NOT apply to a
  dashboard-minted write key (that path was untried at 221 close; expected to work).
- **D-02:** The retire is a **HARD prerequisite** for BOTH PUB-05 and PROOF-01 — it must
  land AND be verified (`latest_stable_version` drops to `1.3.0`; `1.20.0` appears in
  `retirements`) **before** the adopter-resolution proof and the proof bundle are captured.
  Re-query live Hex immediately before executing and after retiring:
  `curl -s https://hex.pm/api/packages/sigra | jq '.latest_stable_version, .retirements'`
  (state can change; per 221 D-16).
- **D-03:** Reversible fallback documented in the plan/bundle —
  `mix hex.retire sigra 1.20.0 --unretire` if ever needed.

### PUB-05 — Adopter resolution proof (Area 2)
- **D-04:** Prove `{:sigra, "~> 1.0"}` resolution via a **throwaway scratch mix project**
  declaring the dep + `mix deps.get`, asserting `mix.lock` locks **`1.3.0`** (not `1.20.0`,
  not `1.1.0`). Runs **after** the retire (D-02). A full `mix phx.new` scaffold is not
  required — a minimal mix project suffices.
- **D-05:** Do **NOT** reuse `scripts/ci/lib/resolve-sigra-source.sh` for this proof — it
  hardcodes `exclude="${SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS:-1.20.0}"` (`:44`), artificially
  filtering the stray before it resolves. Using it would **false-green** (216 SC-5 / D-13
  overclaim trap): it would claim adopter resolution is clean while a real `mix deps.get`
  still locks `1.20.0`. The proof MUST reflect real, unfiltered adopter behavior.

### PROOF-01 — Trust bundle (Area 3)
- **D-06:** Emit a **standalone `223-PROOF.md`** in the phase dir (the ROADMAP-named
  "release-currency proof bundle" / "milestone's trust artifact"), using the 215/220
  VERIFICATION observable-truths evidence format — a table of claims, each backed by a
  **verbatim command + observed output**. Complements, does not replace, the standard
  `223-VERIFICATION.md`.
- **D-07:** The bundle records all four PROOF-01 sub-claims with live evidence:
  (1) `ci-gate` green on `main` (`gh run list` / `gh pr checks --required` against `main`
  HEAD); (2) Hex `latest_stable_version = 1.3.0` (`curl … | jq`); (3) adopter `~> 1.0`
  → `1.3.0` (scratch-project `mix.lock`, per D-04); (4) full library + example suites green
  (verbatim counts, per D-08).

### Suite-green evidence capture (Area 4)
- **D-08:** Capture the library suite (`mix test` → verbatim "N tests, 0 failures"), the
  example suite (verbatim count), and the 5 required CI checks (`gh pr checks <PR> --required`)
  as **literal text** per the 215 D-03 convention. Never record "it passed" without command
  + counts (215 prohibition table). Live-Postgres + `tmp/db.env` is the sanctioned local run
  path (see CLAUDE.md prerequisites).

### Folded Todos
- **`.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md`** (score 0.9,
  `resolves_phase: 223`) — **folded into scope**. It IS the PUB-04 retire step central to
  PUB-05/PROOF-01. Its runbook (dashboard-write-key path, `:39-52`) is the execution
  reference for D-01. Move `pending/ → done/` at phase close once retire is verified.

### Claude's Discretion
- Exact placement/tooling of the scratch resolution project (throwaway dir, whether to
  wrap in a `scripts/ci/` helper or run ad-hoc) — planner's discretion, subject to D-04/D-05.
- Whether the ci-gate-green-on-`main` evidence comes from an existing green run or a fresh
  observation — either is acceptable if it reflects current `main` HEAD.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md` — retire runbook + the
  untried dashboard-write-key path (execution reference for D-01)
- `scripts/ci/lib/resolve-sigra-source.sh` — the stray-exclusion resolver (CI-lane only;
  **do NOT use for the PUB-05 proof**, per D-05)
- `scripts/ci/upgrade-smoke.sh` (lines 43-65) — reusable app-scaffold + `~> N` patch +
  `mix_deps_get_with_retry` machinery (reference for D-04)
- `scripts/ci/release-post-publish-verify.sh` — existing Hex-API `curl` + JSON-evidence pattern
- `.planning/milestones/v1.43-phases/215-terminal-ratification/215-VERIFICATION.md` — closest
  proof-bundle precedent (suite-green + verbatim counts + `gh pr checks --required`; D-03 convention)
- `.planning/milestones/v1.44-phases/220-terminal-ratification/220-VERIFICATION.md` — evidence-format
  precedent (deferred-execution shape NOT used here, but format retained)
- `.planning/phases/221-unblock-the-gate-ship-honest-generated-host-debt/221-CONTEXT.md` — D-12..D-16
  (publish/pin history; D-16 "re-query live Hex before executing")
- `.planning/ROADMAP.md` (Phase 223 details) + `.planning/REQUIREMENTS.md` (PUB-05, PROOF-01)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/ci/upgrade-smoke.sh` (lines 43-65) — scaffolds an app, patches
  `{:sigra, "~> ${SIGRA_START_VERSION}"}`, runs `mix_deps_get_with_retry`. Its scaffold +
  deps-get machinery is the closest analog for the PUB-05 scratch-project proof, but it
  feeds the resolver/override version — not a raw `~> 1.0` — so D-04 uses a minimal
  standalone project instead of driving this harness.
- `scripts/ci/release-post-publish-verify.sh` — already curls the Hex API and writes JSON
  evidence for a specific version; the pattern (not the exact script) informs the
  `latest_stable_version` capture in PROOF-01.
- 215/220 VERIFICATION.md observable-truths tables — the established evidence shape for
  release/trust artifacts in this repo.

### Established Patterns
- **Verbatim-counts convention (215 D-03):** release-signal artifacts record the exact
  command + "N tests, 0 failures" string, never a bare "it passed."
- **Live-Hex re-query before write (221 D-16):** always `curl` the package API immediately
  before any Hex write/verify — registry state drifts.
- **Overclaim guard (216 SC-5 / D-13):** a locally-filtered or pre-commit "green" is a
  preview, not proof; the authoritative signal is the real, unfiltered end state.

### Integration Points
- Hex.pm registry (`latest_stable_version`, `retirements`) — the source of truth for
  PUB-05/PROOF-01; changed only by the operator retire (D-01).
- The terminal-PR `ci-gate` / 5 required checks on `main` HEAD — the CI-side half of PROOF-01.
- `resolve-sigra-source.sh` stray-exclusion (Phase 222 HARD-01) is the CI **gate's**
  workaround for the un-retired stray; the retire (D-01) makes that workaround no longer
  load-bearing for adopters (it stays for the gate's sort determinism).
</code_context>

<specifics>
## Specific Ideas

- Retire message text (D-01): `"Published in error during dev cycle; not a real release — use 1.3.0+"`,
  reason `invalid` — matching the runbook.
- PUB-05 assertion target: `mix.lock` entry for `:sigra` == `1.3.0` (exact), proving the
  stray and the stale versions are both out-resolved.
</specifics>

<deferred>
## Deferred Ideas

None new — the previously-deferred retire (PUB-04) is now **un-deferred** into this phase (D-01).

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db.md` (CI perf) — keyword-matched only;
  out of scope for a release-currency proof phase.
- `2026-06-20-runtime-auth-prefix-override.md` (config feature) — unrelated capability; own phase.
- `2026-07-10-canary-recapture-lane-excludes-canary.md` (admin-CI noise) — unrelated to Hex currency.
</deferred>
