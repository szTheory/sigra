# Phase 222: Release-Lane Hardening (No Silent Rot) - Context

**Gathered:** 2026-07-10 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the release lane unable to silently strand a release. Two things must become
un-silenceable: (1) the PR-invisible `Upgrade smoke` gate can no longer rot unnoticed, and
(2) release-please auto-publish can no longer stall/fail silently. Land the hardening + document
the operator recovery path.

Requirements in scope: **HARD-01, HARD-02**.

**Explicitly out of scope** (do NOT pull in):
- Retiring the stray Hex `1.20.0` (PUB-04) — deferred (Hex 2.5 blocks programmatic retire; orthogonal
  to the gate). Adopter-currency work is Phase 223 (PUB-05, PROOF-01).
- Playwright per-shard-DB perf (PERF-01 / SEED-005) — deferred by design.
- The admin `impersonation-banner` canary-recapture-lane noise — a different lane, not the release lane.
- Publishing v1.2.0/v1.3.0 — already shipped in Phase 221 via the manual `hex-publish.yml` path.
</domain>

<decisions>
## Implementation Decisions

### HARD-01 — Rot-visibility + retire the D-13 stopgap pin

- **D-01:** Keep `upgrade_smoke` on its **nightly/push-to-main cadence** — do **NOT** make it
  PR-visible. Making it run on `pull_request` would reverse the deliberate, documented D-07 perf
  tradeoff (MAINTAINING.md:146: accepted residual, "no per-PR behavioral proxy," moved to nightly in
  Phase 196/198 to cut PR wall-clock). HARD-01's requirement is an explicit **OR** ("PR-visible **OR**
  loud red-main signal"), so the OR-branch honors that residual.
- **D-02:** Satisfy HARD-01 via a **loud red-main signal**: a `push:main`-gated notify step that
  **opens/updates a tracking GitHub Issue** when `upgrade_smoke` (or the `ci-gate` aggregate)
  concludes non-success. Reuse the in-repo precedent — `release-please.yml` already holds
  `issues: write` (release-please.yml:22); the `nightly_probe` forced-failure self-test (ci.yml:2181)
  and `::error::` annotation (ci.yml:1238) prove the nightly/main lane can report red loudly.
  Prefer **issue-open/update** over a "new required aggregate that only runs on push:main" — a
  push-only required context risks stranding PR merges under ruleset 14941512 (the matrix-orphans-a-
  required-context class of bug already bit this repo; see ci.yml:400-406). Annotation-only is
  acceptable as a secondary, but the durable, discoverable signal is the issue.
- **D-03:** **Replace the D-13 stopgap env pin** (`SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"`,
  ci.yml:643) with the **durable retired-filter** ("Option 4b", explicitly deferred here by
  221-CONTEXT D-13) in `scripts/ci/upgrade-smoke.sh` version resolution: drop `(retired)` rows from
  the `mix hex.info` candidate list **before** `sort -V | tail -1` (:52). The current `sed` at
  `upgrade-smoke.sh:45` strips the `(retired)` marker along with the tail, so retired releases stay in
  the candidate set and the stray `1.20.0` out-sorts the real GA. Keep the
  `SIGRA_UPGRADE_SMOKE_START_VERSION` override (validated, published-only, :56-77) as an **escape
  hatch only** — the resolver's default behavior must no longer depend on a hand-maintained floor.
  The pin is itself a rot vector (goes stale every release, masks rather than filters the stray).
- **D-04:** The exact `mix hex.info sigra` retired-marker string (e.g. `(retired)` suffix vs a
  separate line) must be verified against **live Hex** before writing the filter grep — it is
  network-dependent and not determinable from the repo. Planner/researcher confirms the format at
  implementation time (`mix hex.info sigra` or `curl -s https://hex.pm/api/packages/sigra`).

### HARD-02 — Prove auto-publish readiness + concrete "fails loudly"

- **D-05 [informational]:** Operator-truth (confirmed, decisive) — v1.2.0 and v1.3.0 were published via the **manual
  `hex-publish.yml` `workflow_dispatch`** path (three successful runs 2026-07-10: 16:49 v1.2.0
  dry-run, 17:03 v1.2.0 real, 18:00 v1.3.0 real) — **NOT** via release-please auto-publish.
  release-please auto-publish is therefore **unproven end-to-end**; worse, it is **proven to stall
  silently** — the `Release Please` runs at **31m14s (#74)** and **31m7s (#66)** are the
  `gate-ci-green` job timing out (~30 min, release-please.yml:119-169) against the then-red gate,
  then failing with no alert. This is the exact silent-rot failure mode HARD-02 targets, and it is
  real, not hypothetical.
- **D-06:** Do **NOT** cut a throwaway version bump to force a live green auto-publish (chosen by Jon
  over a live `release-as` v1.3.1 proof, 2026-07-10). Satisfy HARD-02's explicit **OR**
  ("fire end-to-end **OR** fail loudly") via the buildable-now branch:
  1. **Prove the publish path is green** by running `hex-publish.yml` with `dry_run=true` against the
     current shipped tag (compile + test + package + provenance, no Hex write — honors the
     operator-gated-Hex-writes decision; idempotency-guarded at release-please.yml:279-285).
  2. **Treat as readiness evidence** the now-green `ci-gate` on main + the wiring trace
     (`release_created` → `gate-ci-green` → `publish-hex` needs-chain, release-please.yml:96-174)
     + the already-shipped v1.3.0. The next real release exercises auto-publish live.
  3. **Build the "fails loudly" mechanism** — a **failure-notify step on `publish-hex` and
     `gate-ci-green`** that opens/updates a GitHub Issue (same Issue-open pattern as D-02), so the
     next real release either auto-publishes or fails **loudly** instead of the silent 31-min stall.
     This is the core, provable deliverable of HARD-02.
- **D-07:** Unify the loud-signal mechanism across HARD-01 and HARD-02 — one shared notify-on-failure
  pattern (issue open/update) covers both the red-main `upgrade_smoke`/`ci-gate` (D-02) and the
  `publish-hex`/`gate-ci-green` failure surfaces (D-06.3). Minimal, single mechanism, two consumers.

### HARD-02 — Recovery / manual-dispatch runbook

- **D-08:** The recovery runbook lives in **`MAINTAINING.md`** as a new subsection near the existing
  "Recovery / one-off publish" area (MAINTAINING.md:266-276). It documents: the `hex-publish.yml`
  manual `workflow_dispatch` inputs (`tag` + `release_version` + `dry_run`); when to use it vs
  release-please auto-publish; how to read a `gate-ci-green` timeout; and how to red-probe the new
  loud signal. **Cross-reference** `docs/release-runbook-v1-0.md` (the canonical release runbook,
  MAINTAINING.md:262) rather than duplicate it. Do **NOT** create a new top-level doc — follow the
  "Forced-failure probe runbook (D-14)" precedent (MAINTAINING.md:178-198, copy-paste
  `gh workflow run` commands) and the file's own anti-duplication guidance (:31,:33).

### Claude's Discretion
- Exact notify implementation (composite action vs inline step; `actions/github-script` vs `gh issue`),
  issue title/label convention, and whether the annotation is added alongside the issue (D-02).
- Retired-filter grep/awk shape once the live `mix hex.info` marker format is confirmed (D-03/D-04).
- Whether the dry-run proof is a one-shot operator step or wired as a re-runnable checkpoint (D-06.1).
- Exact runbook subsection heading and ordering within MAINTAINING.md (D-08).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.github/workflows/ci.yml` — `upgrade_smoke` job (PR-invisible trigger `:636`; stopgap pin
  `SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"` `:643`); `ci-gate` aggregate (`needs` incl.
  upgrade_smoke `:1465`; treats `skipped` as pass `:1498`); `::error::` annotation precedent `:1238`;
  `nightly_probe` forced-failure self-test `:2181`; matrix/required-context hazard note `:400-406`
- `.github/workflows/release-please.yml` — auto-publish chain (`release_created` → `gate-ci-green`
  `:96-174`, ~30-min timeout `:119-169`); `publish-hex` job + idempotency guard `:279-285`, dry-run
  step `:287`; already holds `issues: write` `:22`
- `.github/workflows/hex-publish.yml` — manual `workflow_dispatch` recovery path
  (`tag` + `release_version` + `dry_run` inputs `:20-24`)
- `scripts/ci/upgrade-smoke.sh` — version resolution `resolve_latest_sigra_source` (`:40-53`,
  `sed` marker-strip `:45`, `sort -V | tail -1` `:52`); `SIGRA_UPGRADE_SMOKE_START_VERSION` override
  (published-only, `:56-77`)
- `MAINTAINING.md` — maintainer entry-point index (`:264`); enforced-required-checks list (`:106-110`,
  ci-gate NOT enforced `:112`); D-07 upgrade_smoke accepted-residual (`:146`); "Forced-failure probe
  runbook (D-14)" precedent (`:178-198`); "Recovery / one-off publish" area (`:266-276`); canonical
  release runbook pointer `docs/release-runbook-v1-0.md` (`:262`); anti-duplication guidance (`:31,:33`)
- `release-please-config.json`, `.release-please-manifest.json` — release config + version manifest
- `.planning/phases/221-unblock-the-gate-ship-honest-generated-host-debt/221-CONTEXT.md` — D-13
  (stopgap pin + Option 4b deferral to this phase), D-16 (Hex writes operator-gated), the gate-green
  proof context
- `.planning/REQUIREMENTS.md` — HARD-01, HARD-02 acceptance text
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Loud-signal precedent already in-repo:** `release-please.yml` has `issues: write` (`:22`);
  `nightly_probe` self-test (ci.yml:2181) + `::error::` annotation (ci.yml:1238) prove the
  nightly/main lane can report red loudly. One shared notify-on-failure step serves both HARD-01 and
  HARD-02 (D-07).
- **Runbook precedent:** the "Forced-failure probe runbook (D-14)" subsection (MAINTAINING.md:178-198)
  is the exact shape for the D-08 recovery runbook — copy-paste `gh workflow run` commands.
- **Dry-run escape hatch:** `hex-publish.yml` `dry_run` input (`:20-24`) + `publish-hex` idempotency
  guard (release-please.yml:279-285) make re-exercising the publish path safe (cannot double-publish).

### Established Patterns
- **PR-invisible-by-design smoke:** `upgrade_smoke` is `if: github.event_name != 'pull_request'`
  (ci.yml:636) — a *deliberate* Phase 196/198 perf decision (MAINTAINING.md:146), not an accident.
  HARD-01 must not silently reverse it; the OR-branch (loud red-main signal) is the sanctioned path.
- **ci-gate is soft:** `ci-gate` treats `skipped` as pass (ci.yml:1498) and is **not** an enforced
  required check (MAINTAINING.md:112). The 5 enforced checks (MAINTAINING.md:106-110) exclude
  `upgrade_smoke`. So a red `upgrade_smoke` on main today has **no** automated loud consumer except
  the release-please `gate-ci-green` timeout — which is itself silent (a 31-min stall).
- **Operator-gated Hex writes:** CI `HEX_API_KEY` context is used by auto-publish; interactive
  write-key operations stay operator-run (221-CONTEXT D-16). The dry-run proof (D-06.1) respects this.

### Integration Points
- `ci-gate` ← `upgrade_smoke` (push/schedule-only, PR-invisible) — the HARD-01 surface.
- release-please `gate-ci-green` (polls ci-gate, ~30-min timeout) → `publish-hex` — the HARD-02
  silent-stall surface confirmed via Actions history (D-05).
- `hex-publish.yml` `workflow_dispatch` — the operator recovery path the D-08 runbook documents.
</code_context>

<specifics>
## Specific Ideas

- **Confirmed the silent failure is real:** `gh run list --workflow release-please.yml` shows
  auto-publish stalled at 31m14s (#74) and 31m7s (#66) — the `gate-ci-green` timeout against the
  red gate. This is the concrete thing HARD-02's "fail loudly" must replace.
- HARD-01 signal = **GitHub Issue open/update**, not a new push-only required aggregate (merge-strand
  risk under ruleset 14941512).
- The D-13 stopgap pin is not just tech debt — it is itself a silent-rot vector, so retiring it
  (durable retired-filter) is squarely in HARD-01's "no silent rot" charter, not scope creep.
</specifics>

<deferred>
## Deferred Ideas

- **Live green auto-publish proof via throwaway v1.3.1 bump** — considered for HARD-02; declined by
  Jon (2026-07-10). The OR-branch (loud-failure backstop + dry-run) satisfies the requirement without
  churning a real Hex version. Could be revisited at the next natural release.
- **PUB-04 retire stray 1.20.0 / PUB-05 adopter `~> 1.0` proof / PROOF-01 trust bundle** → Phase 223
  (or deferred, per REQUIREMENTS PUB-04 note). Not this phase.

### Reviewed Todos (not folded)
- `2026-07-03-hex-retire-stray-1-20-0.md` — release-area match, but PUB-04 (deferred; Hex 2.5 blocks
  it) and orthogonal to lane-hardening. Phase 223 / pending.
- `2026-06-20-playwright-parallelization-per-shard-db.md` — ci-area match, but PERF-01/SEED-005,
  deferred by design (PROJECT.md). Not lane-hardening.
- `2026-07-10-canary-recapture-lane-excludes-canary.md` — ci-area match, but the admin canary
  recapture PR lane is a **different lane** than the release lane; not HARD-01/02.
- `2026-07-10-upgrade-smoke-button-type-hex-publish.md` — PUB-01, already resolved in Phase 221.
- `2026-07-02-app-css-corruption-guard-blind-spot.md`, `2026-07-09-218-rereview-followups.md`,
  `2026-07-10-installer-context-impersonation-guard-gap.md`, `2026-06-20-mix-sigra-migrate-schema-helper.md`,
  `2026-06-20-runtime-auth-prefix-override.md` — keyword matches only; unrelated to release-lane
  hardening. Left pending.
</deferred>
