# Phase 211: Terminal Ratification - Context

**Gathered:** 2026-07-01 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Terminal ratification of milestone **v1.42 ADMIN-DS-ELEVATION** (phases 205-211). The
milestone closes honestly and auditably: **every** ledger cell already reads bare `2`
(Phase 210 flipped the last 15), so this phase does **ZERO flips** — it verifies, locks,
proves generated-host parity, reconciles the snapshot/canary drift, runs the adversarial
milestone audit, and performs milestone-close housekeeping.

**Covers:** GATE-01, GATE-02.

**This is a closing/lock phase, not a feature phase** — the direct analog of the completed
Phase 204 (v1.41 Terminal Ratification). It introduces **no new admin surfaces and no new
Tier-2 ratchets**; scope-creep into new elevation work belongs to a future milestone. Same
ratification mechanics as v1.41 Phase 204 and v1.39 Phase 192.
</domain>

<decisions>
## Implementation Decisions

### Scope — zero flips, verify + lock only

- **D-01 (no flips; verify + lock — 204 D-11 precedent):** Phase 210 already flipped every
  L0/L1/L2/L3/L4 cell in `guides/reference/admin-quality-ledger.md` to bare `2`, and
  `scripts/ci/quality-ledger-monotonic.sh --base origin/main` already **exits 0** (36 cells,
  confirmed live this session). 211 **verifies** the terminal all-`2` state and the forward-only
  lock; it authors **no** new Tier-2 ratchets and flips **no** cells. Both allowlists
  (`snapshot-allowlist`, `snapshot-allowlist-design`) are currently empty and must stay empty at
  steady state.

### Canary / snapshot reconciliation — automated, no human review (USER-RATIFIED)

- **D-02 (automated re-baseline into `main`, all-green == approval, NO human visual review —
  USER-RATIFIED):** `scripts/ci/snapshot-canary-guard.sh --base origin/main` currently **FAILS**
  on 5 slugs: 4 allowlistable checkpoint recaptures (`audit-explorer`, `user-audit`,
  `global-user-index`, `org-scoped-admin`) + the **`impersonation-banner` canary** (deliberately
  changed by 204-03's WCAG `.vt-status-pill` contrast fix; the guard **hard-forbids** any canary
  *modify* at `snapshot-canary-guard.sh:104` and it is **not allowlistable**). This is cumulative
  baseline drift from phases 200-204 vs the stale `origin/main` (local `main` is 366 commits
  ahead). **Resolution (user-ratified):** drive the canary re-baseline (preserving the 204-03 WCAG
  fix) + the 4 checkpoint recaptures through the **automated** `scripts/ci/snapshot-recapture-gate.sh`
  path (all-green == approval, no human eyeball) — mirroring Phase 204 D-01/D-02 and the
  zero-human-UAT default. **Reject** the ci.yml:1852 human-visual-PNG-review recapture-PR path.
  **Reject** reverting the canary (that re-opens the WCAG AA failure). The 204-03 WCAG-preservation
  rationale is documented in the phase + milestone audit.
- **D-02a (OPEN MECHANICAL QUESTION for the researcher — NOT a user decision):** The canary guard
  runs `--base origin/main` (CI computes `base=origin/${{github.base_ref}}` for PRs,
  `ci.yml:70-74`). Re-baselining into local `main` alone does **not** turn `fast_checks` green
  vs `origin/main` until `origin/main` itself carries the WCAG-fixed canary bytes. Research must
  determine the exact green-path: (i) a direct-to-`origin/main` recapture PR that publishes the
  new canary/checkpoint bytes so subsequent PRs see them byte-stable, vs (ii) proving terminal
  idempotency vs `HEAD` in-phase and treating origin/main-green as the publish-time reconciliation
  owned by the integration merge. The **policy** (automated, no human review, preserve the WCAG
  fix) is locked by D-02; only the plumbing is open.

### Terminal idempotency proof (GATE-01)

- **D-03 (compare-mode zero PNG drift; allowlists empty at steady state — 204 D-01/D-02):** After
  the D-02 recapture, re-run all 6 Playwright projects (admin-checkpoints + admin-design ×
  chromium / mobile / dark) in **compare mode** and confirm **0 diffs** (idempotency proven).
  Both allowlists return to **empty** (comments only) at steady state. Drive approval through
  `snapshot-recapture-gate.sh` (all-green == approval, no human review). This is GATE-01's
  "compare-mode re-render shows zero PNG drift" leg.

### Generated-host parity (GATE-02)

- **D-04 (run the existing harness; do NOT build new — 204 D-12):** Prove GATE-02 runtime parity
  by executing the *existing* `scripts/ci/admin-acceptance-smoke.sh` (fresh `mix phx.new` →
  local `{:sigra, path:}` → `mix sigra.install` → seed → boot on `PORT=4017` → HTTP parity probes
  → filtered `admin-generated.spec.ts`) **plus** install-golden byte-diff staying green under the
  **phx_new 1.8.7** pin (a newer archive injects a `root_tag_attribute` config block → spurious
  diff; do NOT regenerate the fixture to "fix" it — SEED-004). Run via the `RUN_PARITY` lane.
  **If** the smoke surfaces a real installer-template-drift regression (an elevated `sg-*` selector
  shipped in `test/example/` but not propagated to `priv/templates/sigra.install/`, per the known
  drift pattern), that is a **fix commit**, not just a verification tick — the milestone cannot
  close honestly otherwise.

### Clean `mix test` for the terminal gate

- **D-05 (accept known/env failures; do NOT fix — 204 D-09):** The terminal gate treats as
  **accepted known/env failures**, NOT blockers: (a) the 3 `Sigra.UpgradeIntegrationTest`
  env-DB failures (`test/upgrade_test.exs`, `seed_users!/2` / `run_data_migrations!` need a live
  per-fixture DB), and (b) the `Sigra.Audit.Forwarders.NoopTest` "does NOT emit any Logger output
  — D-23" parallel-shard log-capture flake (passes 3/3 in isolation). **Before** accepting (b),
  run the NoopTest file in isolation once to confirm it is a shard race, not a deterministic
  branch regression. 204 D-08's stale-contract fixes (`Phase192KnownFailureContractTest`,
  `Phase148...` Vaultr→Tasklane) are already resolved on this branch — **re-confirm green, do NOT
  re-fix**. Assert no *new* real regression exists beyond this known set.

### Adversarial milestone audit (GATE-02 SC-4)

- **D-06 (`v1.42-MILESTONE-AUDIT.md` via `gsd-audit-milestone`; cite persona verdicts, do NOT
  re-run — 204 D-10):** Produce `.planning/milestones/v1.42-MILESTONE-AUDIT.md` via the
  `gsd-audit-milestone` skill (same frontmatter/body shape as the on-disk `v1.41-MILESTONE-AUDIT.md`
  / `v1.40-MILESTONE-AUDIT.md`). Satisfy GATE-02's "record the persona-JTBD verdicts as Tier-2
  evidence" by **citing the already-committed** `.planning/v1.42-PERSONA-JTBD-PANEL.md` roll-up +
  the 8 per-surface docs under `.planning/uat-evidence/v1.42-persona-jtbd/` — do **not** re-run the
  persona review. Include the four RATIFY-style adversarial checks (204 D-10): (a) usability
  improved for the operator JTBD, not just prettier; (b) no generated-host-contract friction
  (host extension seams intact); (c) no broken dark/mobile/keyboard/reduced-motion paths;
  (d) no screenshot-only quality (interactions work, not just static captures).
- **D-07 (fix the stale PRE-FIX panel status — staleness trap):** `v1.42-PERSONA-JTBD-PANEL.md:6`
  header still reads `Status: PRE-FIX — captures live DOM defect state before Wave-2 remediation`,
  but **all** Wave-2 remediations (209-03..209-05: All-clear kills, empty-state swaps,
  H1/scope-copy/revoke-copy fixes) landed **after** the panel was authored. Update the panel status
  line to POST-FIX (and/or state remediation-landed in the audit) so an auditor cannot misread the
  milestone as shipping un-remediated `tighten` findings.

### Milestone-close housekeeping (204 D-13)

- **D-08 (close-out ticks):**
  1. **Mark Phase 208 complete** despite its "2/3 In Progress" ROADMAP row — 208-03 (GROUP-02,
     the 11 mg-* L2 flips) was **folded into and executed as Phase 210 plan 02** (ROADMAP:205);
     GROUP-02 already reads Complete in the REQUIREMENTS traceability table. Left "In Progress,"
     `gsd-complete-milestone` would flag an incomplete phase.
  2. **Flip GATE-01 / GATE-02 `[ ] → [x]`** in `REQUIREMENTS.md` (lines 44-45) and their coverage
     rows (lines 86-87 → Complete/Satisfied).
  3. **Correct `STATE.md` `milestone_name`** from the stale `CI-Gate Remediation` (inherited from
     inserted Phase 208.1) → **`ADMIN-DS-ELEVATION`** (authoritative per PROJECT.md:35,
     ROADMAP.md:4/8, REQUIREMENTS.md:1).
  4. **Flip ROADMAP** milestone status / progress lines from "in progress" → complete.

### Guardrails

- **D-09 (no milestone git tag):** Do NOT create a `v1.42` milestone git tag — milestone tags
  were dropped after v1.35 (collision risk with the Hex package version). Milestone close is
  ROADMAP/REQUIREMENTS/STATE edits + the audit doc, not a tag.
- **D-10 (no scope creep):** No new admin surfaces, no new Tier-2 ratchets, no product-behavior
  changes. This phase locks the v1.42 bar; new elevation work is a future milestone.

### Claude's Discretion

- Plan decomposition (single ratification plan vs split verify / parity / audit / housekeeping).
- Exact adversarial-check phrasing in the audit doc (bounded by the 204 D-10 / v1.41 audit shape).
- Whether `NoopTest` gets a cheap determinism fix (`async: false` / scoped capture) or stays
  documented-known — both satisfy the gate; lean documented-known unless the isolation run shows
  the fix is trivial and risk-free.
- Exact commit grouping for the D-02 recapture (subject to the canary + its recaptured PNGs being
  a coherent, reviewable diff — 204 D-05 same-commit discipline for the canary rebase).

### Folded Todos

- `.planning/todos/pending/2026-06-30-v142-integration-snapshot-canary-drift.md` → **D-02 / D-03**
  (canary + 4-slug reconciliation, automated path) and its **NoopTest addendum → D-05**. This is
  the flagged "can v1.42 merge cleanly" integration gate; Phase 211 is its ratified home.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/milestones/v1.41-phases/204-terminal-ratification/204-CONTEXT.md` — the **direct
  precedent**; D-01/D-02 (recapture via automated gate), D-09 (accepted env failures), D-10
  (adversarial audit), D-12 (generated-host parity), D-13 (close-out housekeeping). Read first.
- `.planning/ROADMAP.md` — Phase 211 detail (~line 209) + v1.42 milestone overview (line 4/8);
  Phase 208 "2/3 In Progress" (~230) folded via 210-02 (line 205).
- `.planning/REQUIREMENTS.md` — GATE-01/GATE-02 (lines 44-45), coverage rows (lines 86-87).
- `guides/reference/admin-quality-ledger.md` — the terminal all-`2` ledger (verify, do not flip);
  monotonic parse rules.
- `scripts/ci/quality-ledger-monotonic.sh` (+ `.test.sh`) — `--base origin/main` forward-only
  guard; already exits 0 (D-01).
- `scripts/ci/snapshot-canary-guard.sh` — canary tripwire; `CANARY="impersonation-banner"` (line
  20), canary-modify hard-forbidden (line 104), not allowlistable; design-lane canary is
  `board-notice`. Currently FAILS vs origin/main (D-02).
- `scripts/ci/snapshot-recapture-gate.sh` — the **automated** recapture approval path (all-green
  == approval, no human review) chosen by D-02.
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host runtime parity (`PORT=4017`,
  `admin-generated.spec.ts`); the GATE-02 `RUN_PARITY` proof (D-04).
- `.github/workflows/ci.yml` — fast_checks base calc (~70-74, `base=origin/${{github.base_ref}}`);
  the canary auto-recapture-PR / human-visual-review mechanism (~1840-1856) that D-02 **rejects**
  in favor of the automated gate.
- `.planning/v1.42-PERSONA-JTBD-PANEL.md` — persona-JTBD roll-up (all 8 surfaces `actionable`);
  **stale `Status: PRE-FIX` header at line 6** (D-07). Plus the 8 per-surface docs under
  `.planning/uat-evidence/v1.42-persona-jtbd/*.md` — the Tier-2 evidence the audit cites (D-06).
- `.planning/milestones/v1.41-MILESTONE-AUDIT.md` (+ `v1.40-MILESTONE-AUDIT.md`) — audit-doc
  template shape; `v1.42-MILESTONE-AUDIT.md` does NOT yet exist (D-06).
- `test/upgrade_test.exs` (~line 212) + `test/sigra/audit/forwarders/noop_test.exs` — the accepted
  known/env + shard-flake failures (D-05).
- `.planning/todos/pending/2026-06-30-v142-integration-snapshot-canary-drift.md` — the folded
  integration reconciliation todo (D-02/D-03/D-05).
- `.planning/STATE.md` — stale `milestone_name: CI-Gate Remediation` → fix to ADMIN-DS-ELEVATION
  (D-08).
- CLAUDE.md — phx_new 1.8.7 pin (SEED-004), `app.css` comment-corruption + Vaultr→Tasklane notes.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Full gate toolchain already exists and is the approval mechanism (no human review):**
  `snapshot-recapture-gate.sh`, `snapshot-canary-guard.sh`, `quality-ledger-monotonic.sh`,
  `admin-acceptance-smoke.sh`. This phase *runs* them; it builds none.
- `gsd-audit-milestone` skill + `v1.41-/v1.40-MILESTONE-AUDIT.md` templates for the GATE-02 review.
- Phase 204 (v1.41 terminal phase) is the direct precedent for the entire ratification flow,
  including "compare-mode zero-drift, not force-recapture" and the automated recapture gate.

### Established Patterns
- Ledger cells ratchet forward only; the closing phase **locks**, it does not flip new cells.
- Allowlists are empty at steady state; a deliberate recapture adds slug(s) in the same diff for
  reviewability, then resets to empty. The `impersonation-banner` (checkpoints) / `board-notice`
  (design) canaries are NEVER allowlistable — a canary change is a re-baseline, not an allowlist.
- `admin-checkpoints.spec.ts` runs all checkpoints as one linear test per project — an early axe
  failure aborts downstream captures (the mechanism behind the 204-03 pill fix / mobile recapture).

### Integration Points
- **The canary reconciliation is the one non-trivial gate:** the guard runs `--base origin/main`;
  local `main` is 366 commits ahead and never pushed. The green-path plumbing is D-02a (open for
  research); the policy (automated, no human review) is locked (D-02).
- Generated-host parity connects the example proof to a freshly generated phx_new 1.8.7 host via
  the install-golden fixture + `admin-acceptance-smoke.sh`.
- Boot note for local recapture: example dev server on an alt PORT (4000 collides with Rulestead
  Docker); pre-compile before launch to avoid the code-reload crash; set `SIGRA_EXAMPLE_URL`.
</code_context>

<specifics>
## Specific Ideas

- The **automated** recapture gate (no human eyeball) is the ratified path for the canary
  re-baseline (D-02) — reject the ci.yml:1852 human-visual-review PR path.
- **Preserve** the 204-03 WCAG `.vt-status-pill` contrast fix — never revert the canary to
  origin/main's pre-fix bytes.
- The persona-JTBD verdicts already exist and are `actionable`/remediated — the audit **cites**
  them; it does not re-run the review. Fix the panel's stale `PRE-FIX` header (D-07) so the
  evidence reads honestly.
- Milestone close = ROADMAP/REQUIREMENTS/STATE edits + the audit doc, **no git tag** (D-09).
</specifics>

<deferred>
## Deferred Ideas

None net-new — analysis stayed within the terminal-ratification boundary. No new admin surfaces
or Tier-2 ratchets (that belongs to a future milestone).

### Reviewed Todos (not folded)
- `2026-06-19-uat-demo-dx-polish-nits.md`, `2026-06-20-*` (migrate-schema helper, playwright
  per-shard DB, runtime-auth-prefix), `2026-06-21-app-css-comment-corruption-cleanup.md`,
  `2026-06-22-*` (vaultr rebrand residuals, white-label email theming),
  `2026-06-24-oban-enqueue-unguarded...`, `2026-06-25-phase200-code-review-deferred.md`,
  `2026-06-28-phase205-debt-ci-native-board-baselines.md`,
  `2026-07-01-phase209-code-review-deferred.md` — all product-hardening / cleanup outside the
  terminal-ratification boundary. Defer to backlog / future milestones.
</deferred>
