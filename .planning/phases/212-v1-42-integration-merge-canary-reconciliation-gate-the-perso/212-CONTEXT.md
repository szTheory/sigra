# Phase 212: v1.42 integration merge — canary reconciliation + gate the persona flows + un-skip generated-host smoke; drive PR #63 green and merge - Context

**Gathered:** 2026-07-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the three integration gaps the v1.42 aggregate milestone audit found (GATE-01,
FLOW-01, GATE-02), then merge PR #63 (`ship/v1.42-ci-gate-remediation` → `main`) and
only then flip ROADMAP v1.42 → shipped. This is an **integration/merge** phase — it
wires, reconciles, and merges existing work; it does NOT add features. Scope anchor:
`.planning/v1.42-MILESTONE-AUDIT.md` "Recommended Closure" (one integration phase).
</domain>

<decisions>
## Implementation Decisions

### GATE-01 — Canary reconciliation (`snapshot-canary-guard.sh --base origin/main` must exit 0)

- **D-01 (canary — HUMAN CALL, ratified):** The `impersonation-banner` **mobile** canary
  is **re-baselined + re-designated with a documented rationale** that preserves the
  Phase 204-03 WCAG contrast fix (commit `c96749fa`). Use the sanctioned
  `scripts/ci/snapshot-recapture-gate.sh` machinery and the PR-body precedent language
  at `.github/workflows/ci.yml:1852` ("intentional re-baseline — the gate is human visual
  review of these PNG diffs"). The canary stays **armed** on the new mobile bytes going
  forward. Only the mobile project drifted — `chromium` and `dark` are byte-stable and
  must remain untouched.
  - Rejected: revert-to-origin-bytes (reopens the 204-03 mobile status-pill WCAG AA
    contrast regression); one-time `--canary` waiver (sets a "canary can be waived"
    precedent, weakens the tripwire).
- **D-02 (allowlist the 4 legit drifts):** Add one slug line each for `audit-explorer`,
  `user-audit`, `global-user-index`, `org-scoped-admin` to
  `test/example/priv/playwright/snapshot-allowlist` **in the same PR diff**. These are
  cumulative v1.41 backlog deltas (phases 200–204; commits `af735d75`/`e7c5b0c7`/
  `4c3ce3cf`), not v1.42 regressions — exactly what the allowlist encodes. One line
  covers all three projects per slug.
- **D-03 (steady-state reset):** Per the guard's steady-state-empty discipline, reset the
  allowlist back to empty after merge (post-merge cleanup, tracked so the next PR's real
  drift on those slugs can't pass silently).
- **D-04 (exit condition):** The GATE-01 acceptance is `scripts/ci/snapshot-canary-guard.sh
  --base origin/main` exiting 0 — verify both the `fast_checks` "Snapshot drift guard
  (canary allowlist)" step AND the design-lane step (`ci.yml:100-108`) are green.

### FLOW-01 — Gate the 3 persona flows

- **D-05 (wire into existing job, not new/waiver):** Append
  `tests/admin-flow-platform-admin.spec.ts`, `tests/admin-flow-support-investigator.spec.ts`,
  and `tests/admin-flow-org-admin.spec.ts` to the explicit chromium spec list in the
  EXISTING `example_playwright_smoke` "admin behavior browser truth" step at
  `.github/workflows/ci.yml:991-997`. Reuses the already-booted example app + seeded demo
  personas (alice/dave/frank/morgan) at near-zero marginal cost.
  - Rejected: a dedicated new job (duplicates the expensive boot+seed); a written waiver
    (contradicts the milestone's "proven in Playwright" acceptance clause).
- **D-06 (project correctness):** Keep them on the `chromium` project — they already match
  `ADMIN_BEHAVIOR_SPECS` (`playwright.config.ts:24-25`) and are excluded from `mobile`
  (`playwright.config.ts:98-99`). Do NOT add them to the `mobile` list (the `testIgnore`
  regex would silently skip them — "wired but running nowhere").
- **D-07 (aggregator-safe):** Appending to the `admin_behavior` step is covered by the
  existing outcome aggregator (`ci.yml:1102-1107`), so a flow-spec failure fails the job —
  no silent-green risk. Ledger flow-* citations become execution-backed, not
  existence-backed.

### GATE-02 — Un-skip generated-host runtime smoke

- **D-08 (scope to the integration branch):** Relax `generated_admin_playwright_smoke`'s
  PR-skip (`ci.yml:1209: if: github.event_name != 'pull_request'`) so it RUNS on the
  integration PR, but **scoped to the ship/integration branch** (e.g. gate on
  `github.head_ref == 'ship/v1.42-ci-gate-remediation'`, or an equivalent
  label / `workflow_dispatch` gate) — NOT un-skipped on all PRs.
  - Rationale: proves runtime parity on PR #63 now, without adding the ~30-60m cold
    `phx.new`+compile+Playwright wall-clock (`timeout-minutes: 60`, `ci.yml:1213`) to
    every future PR (a known CI-PERF pole).
  - Rejected: un-skip-all-PRs (30-60m on every PR indefinitely); accept-post-merge-push
    (parity proven AFTER merge, not ON the integration PR — weaker vs GATE-02 wording).
- **D-09 (exit condition):** GATE-02 is satisfied when the "Generated admin Playwright
  smoke" job RUNS (not `skipping`) and PASSES on PR #63, via
  `scripts/ci/admin-acceptance-smoke.sh --test all` (`ci.yml:1258`). The installer↔example
  byte-parity golden test (`golden_diff_test.exs`) stays green.

### SC-4 — Merge + honest status

- **D-10 (ordering — merge before shipped flag):** Sequence is: land the three gates green
  → push local `main` (385 commits ahead of `origin/main`, unpushed) → take PR #63 out of
  DRAFT → drive `fast_checks` + `ci-gate` green → merge to `origin/main` → **only then**
  flip ROADMAP v1.42 → shipped and reconcile STATE. Do NOT flip "shipped" before the merge
  lands (the premature-flag mistake the audit calls out at §81/§158).
- **D-11 (bookkeeping sweeps):** Delete the stale
  `.planning/todos/pending/2026-06-28-phase205-debt-ci-native-board-baselines.md` (its
  board-cfg PNGs now exist — 84 board files present). Optionally backfill a Phase 208
  VERIFICATION.md traceability pointer (its work is covered by 208.1 + 210-02 — a pointer,
  not re-verification).

### Claude's Discretion

- Exact allowlist file syntax/ordering (D-02), the precise `if:` expression shape for the
  branch-scoped smoke gate (D-08), and the mechanical recapture invocation for the mobile
  canary re-baseline (D-01) are left to the planner/executor, provided the exit conditions
  (D-04, D-09) and the human-ratified canary policy (D-01) are honored.
- The NoopTest shard-2 log-capture flake (addendum in the drift todo) is an accepted/known
  flake per Phase 211 D-05 — re-run the job alone if it flares; optional cleanup
  (`async: false` / scoped `CaptureLog`) is a nice-to-have, not a gate.

### Folded Todos

- `2026-06-30-v142-integration-snapshot-canary-drift.md` — folded verbatim as the GATE-01
  work item (canary decision D-01 + allowlist D-02/D-03).
- `2026-06-28-phase205-debt-ci-native-board-baselines.md` — folded as the D-11 close-out
  sweep (delete-as-resolved).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/v1.42-MILESTONE-AUDIT.md` — authoritative gap definitions (GATE-01/FLOW-01/
  GATE-02), root causes, and "Recommended Closure" (this phase's spec).
- `.planning/milestones/v1.42-MILESTONE-AUDIT.md` — companion 211-04 adversarial RATIFY
  audit (GATE-02 SC-4 evidence).
- `.planning/todos/pending/2026-06-30-v142-integration-snapshot-canary-drift.md` — GATE-01
  drift breakdown + canary policy tension + NoopTest flake addendum.
- `scripts/ci/snapshot-canary-guard.sh` — canary/allowlist mechanism (line 104 canary
  forbid; 42-48 + 106-111 allowlist load/pass).
- `scripts/ci/snapshot-recapture-gate.sh` — sanctioned human-reviewed re-baseline path
  (D-01).
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host runtime parity smoke (D-08/D-09).
- `.github/workflows/ci.yml` — `fast_checks` snapshot steps (100-108); `example_playwright_smoke`
  (877-1112; seeds 936; admin-behavior spec list 991-997; aggregator 1102-1107);
  `generated_admin_playwright_smoke` (1206-1325; PR-skip 1209; smoke run 1258); `ci-gate`
  (1327-1365); sanctioned re-baseline PR-body precedent (1852).
- `test/example/priv/playwright/snapshot-allowlist` — steady-state-empty checkpoint
  allowlist (D-02).
- `test/example/priv/playwright/snapshot-allowlist-design` — separate design-lane allowlist.
- `test/example/priv/playwright/playwright.config.ts` — `ADMIN_BEHAVIOR_SPECS` regex
  (24-25) includes `admin-flow-`; chromium/mobile project defs (88-99).
- `test/example/priv/playwright/tests/admin-flow-{platform-admin,support-investigator,org-admin}.spec.ts`
  — the 3 persona flow specs (persona deps: alice/dave/frank/morgan@demo.tasklane.test).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Canary/allowlist guard** (`snapshot-canary-guard.sh`) — already supports `--base`,
  `--allow`, `--canary`, per-slug allowlist manifest (one line covers all 3 projects).
- **Re-baseline machinery** (`snapshot-recapture-gate.sh`) — the sanctioned human-reviewed
  recapture path for D-01; PR-body precedent language already exists at `ci.yml:1852`.
- **Booted-app + seeded Playwright job** (`example_playwright_smoke`) — already boots the
  example app and runs `seeds.exs` (the personas the flow specs need); FLOW-01 is a
  one-line-list append into its existing "admin behavior" step.
- **Runtime parity smoke** (`admin-acceptance-smoke.sh --test all`) — already invoked by
  `generated_admin_playwright_smoke`; only its `if:` gating needs relaxing (D-08).
- **Outcome aggregator** (`ci.yml:1102-1107`) — makes appended specs fail-closed with no
  extra wiring.

### Established Patterns

- **Steady-state-empty allowlist** = "zero re-records is the proof"; intended deltas are
  declared in the same PR diff and reset after merge (D-02/D-03).
- **Canary = tripwire that forbids ANY change** — a canary change is a deliberate,
  human-reviewed, documented act, never a silent one (D-01).
- **Explicit spec lists per CI Playwright step** — specs run in CI ONLY if named in a
  step's list; project regex (`playwright.config.ts`) governs which project actually runs
  them (D-05/D-06).
- **`ci-gate` treats skipped `needs` as not-failed** — a skipping job silently satisfies
  the gate, which is exactly why GATE-02's runtime claim was never green on the PR (D-08).

### Integration Points

- `snapshot-allowlist` ← 4 new slug lines (D-02); reset post-merge (D-03).
- `ci.yml:991-997` ← 3 new spec paths appended (D-05).
- `ci.yml:1209` ← PR-skip condition relaxed to branch-scoped run (D-08).
- `impersonation-banner-*-mobile.png` baseline ← re-captured new bytes (D-01); chromium +
  dark untouched.
- ROADMAP.md v1.42 status + STATE.md ← flipped/reconciled ONLY after merge lands (D-10).
- `.planning/todos/pending/` ← delete stale phase-205 baseline-debt todo (D-11).
</code_context>

<specifics>
## Specific Ideas

- The canary re-baseline (D-01) must preserve the 204-03 WCAG contrast fix — verify the
  new mobile PNG still reflects the ≥4.5:1 `.vt-status-pill` contrast, not a revert.
- GATE-02 branch-scoped gate (D-08) should be written so it clearly runs on PR #63's head
  branch and is trivially removable/generalizable later without leaving dead config.
</specifics>

<deferred>
## Deferred Ideas

- NoopTest shard-2 log-capture flake hardening (`async: false` / scoped `CaptureLog`) —
  accepted-known per Phase 211 D-05; optional cleanup, not a v1.42 gate.
- Phase 200 WR-01 (token-scoped revocation, `delete_session/3`) — carried v1.41
  defense-in-depth gap, out of ADMIN-DS-ELEVATION scope; tracked in
  `2026-06-25-phase200-code-review-deferred.md`.
- Phase 209 deferred code-review nits (`2026-07-01-phase209-code-review-deferred.md`) —
  not part of the integration/merge gate.
- Broader CI-PERF audit (SEED-005 / MILESTONE-ARC CI-PERF) — the GATE-02 scope decision
  (D-08) is a deliberately narrow, integration-only relaxation, not the perf overhaul.

### Reviewed Todos (not folded)

- `2026-06-25-phase200-code-review-deferred.md` — out of scope (needs its own lib API
  design pass).
- `2026-07-01-phase209-code-review-deferred.md` — out of scope for the merge gate.
</deferred>
</content>
</invoke>
