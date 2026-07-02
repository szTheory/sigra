# Phase 209: Judgment-Level Page Pass - Context

**Gathered:** 2026-06-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Run the **adversarial persona/JTBD rubric** (`guides/reference/admin-persona-jtbd-rubric.md`)
at **full binding-gate depth** over **all 8 admin pages** (Global Overview, Org Overview,
Users List, User Detail, User Sessions, Audit Index, Per-User Audit, Branding), producing one
scored review doc per surface plus a roll-up index. Then **remediate every `actionable`
verdict** — kill info-dump / redundancy / verbosity, tighten IA — with a committed diff or an
explicit written waiver. All remediations land **in-place** in the existing 8 page LiveViews
and the shared `Sigra.Admin.Components`/`components.ex`; the monotonic guard stays green (no
Tier-2 page regresses), and page Playwright baselines recapture under allowlist→clear
discipline.

This is **page-judgment + page-remediation work**. It is the **single binding gate** for the
8-page persona panel (the Phase-205 `v1.42-IA-DIAGNOSTIC.md` was *advisory only*). Building-
block work (L0/L1 components, L2 gallery groups) is **done** (Phases 206/207/208). The
`user-sessions` page elevation to Tier-2 + the 3 persona flows are **Phase 210**; terminal
ratification is **Phase 211**. Requirements: **PAGE-01, PAGE-02**.

**User-ratified scope addition:** this phase is also the **binding gate for the v1.42
milestone-integration snapshot-canary drift** (Phases 200–204 cumulative + the
`impersonation-banner` canary re-designation) — see D-10.
</domain>

<decisions>
## Implementation Decisions

### Panel execution (fresh re-run; diagnostic is advisory only)

- **D-01 (re-run the rubric fresh; do NOT transcribe the diagnostic):** Phase 209 instantiates
  the rubric output schema (`admin-persona-jtbd-rubric.md` §Output Schema) **fresh against
  current source** for all 8 pages. `.planning/v1.42-IA-DIAGNOSTIC.md` is **advisory input
  only** — a sequencing aid, not a pre-scored panel to copy forward. Each per-surface doc carries
  YAML frontmatter (`surface`, `ledger_cell`, `rubric_version: "1.0"`, `disposition`, all 9
  `verdicts` keys, `findings[]`) + a markdown body with one section per lens, every (lens ×
  question) cell holding a DOM-anchored finding **or** the literal `NONE — searched for: <what>`
  token (forced-finding floor — partial compliance invalidates the review).
- **D-02 (8 docs + roll-up, exact paths):** Author
  `.planning/uat-evidence/v1.42-persona-jtbd/<surface>.md` for each of the 8 surfaces
  (`<surface>` = the ledger row key exactly, e.g. `users-index-live`, `audit-index-live`) and the
  roll-up `.planning/v1.42-PERSONA-JTBD-PANEL.md` (plain summary table: `surface | disposition |
  kill-count | tighten-count | links`). **Column-4 integer prohibition (rubric D-07):** never
  place a bare `0`/`1`/`2` in the 4th pipe column of any table in these docs — it false-matches
  the ledger `awk -F'|'` monotonic guard. Use `keep`/`tighten`/`kill`/`clean`/`actionable`/
  `blocked`/lens-names instead.

### Live remediation scope (the page LiveViews were NEVER touched by 206/207/208)

- **D-03 (decisive scope correction — page findings are STILL LIVE):** Phases 206/207/208 edited
  **zero** admin page LiveViews — they were gallery-board / `sg-*` CSS / CI-gate work. The 8 page
  LiveViews were last edited in Phases **200–203** (v1.41), which **predate** the Phase-205 IA
  diagnostic. The 208-CONTEXT "IA findings route through 206/207/208" ruling applied to *non-page*
  (gallery/CSS/CI) concerns — the diagnostic's **page** findings were never remediated and are
  the live Phase-209 worklist. **Do not assume earlier phases fixed page-level findings; the
  panel must verify current source.**
- **D-04 (still-live findings — anchored in current `lib/sigra/admin/live/*.ex`):** The
  remediation worklist is dominated by live findings (file:line in current source):
  - `index_live.ex` — alarm renders bare "All clear" on zero-risk (:52); "Total users" duplicated
    Overview (:88) ↔ Users-List metric strip (:188).
  - `organization_live.ex` — empty-states use bare `<p class="sg-section-copy">` (:95, :117)
    instead of `<.empty_state>` (`components.ex:410`); members empty-state (:96) is a dead-end with
    no invite link.
  - `user_show_live.ex` — sessions count duplicated header `<dl class="sg-summary-facts">` (:57) ↔
    Sessions panel sub-heading (:84); "Manage sessions" surfaced as easily-missed secondary button
    (:86); 4 separately-worded `<.empty_state>` copies (zoe zero-state, :115/:146/:182/:202);
    terse kicker "User" (:47).
  - `user_sessions_live.ex` — `<h1>Sessions` heading-hierarchy divergence from sibling detail
    pages that use the entity-name H1 (:108); revoke copy "They can sign in again" (:206, :209)
    may undermine the security-remediation posture. **NOTE:** remediate copy/IA only — do **not**
    ratchet this page to Tier-2 (D-08); Tier-2 elevation is Phase 210.
  - Cross-page composition asymmetry — applied-chips render **inside** the `<form>` on
    `users_index_live.ex` (:107-114) but **outside** on `audit_index_live.ex` (:142-149) and
    `audit_user_live.ex` (:163-172); `scope_ribbon` renders **below** the header on
    `audit_index_live.ex` (:56) — the lone outlier vs siblings that render it above.
  - `branding_live.ex` — `<.scope_ribbon copy="Global auth/email profile" />` hardcoded literal
    (:106) instead of the computed `scope_copy/1` helper used on every other page.
- **D-05 (already-resolved / waiver-track items — do NOT re-touch):** Some diagnostic findings are
  already fixed and must not generate needless baseline churn: audit pages already use semantic
  `<details>` disclosure (`audit_index_live.ex:82`, `audit_user_live.ex:105`) — the lone
  `phx-click`/`aria-expanded` disclosure on `users_index_live.ex` (:121-128) is acceptable
  divergence; the `<.notice>` alarm component on `index_live` is correct. The per-user-audit
  "Effective user" filter absence (present on global `audit_index_live.ex:91`) is **defensible**
  (per-user audit is already subject-scoped) → **waiver, not fix**.

### Remediation discipline & guardrails

- **D-06 (in-place only; NO net-new surfaces):** All remediations land inside the existing 8 page
  LiveViews and the shared `Sigra.Admin.Components` (`components.ex`). **No net-new admin surfaces,
  routes, or pages** (honors the milestone's "no net-new surfaces" + "same job → same component"
  posture). Edit **source** (`priv/templates/sigra.install/...` for the host-shipped admin /
  CSS / components) so the generated `test/example/` copy + `test/fixtures/install_golden/` tree
  stay byte-coherent; confirm the canonical source path for the library-owned admin LiveViews
  during planning (research target).
- **D-07 (every actionable verdict → diff OR written waiver):** SC-2 is satisfied only when each
  non-`keep` verdict resolves to a committed remediation diff **or** an explicit written waiver +
  rationale in the per-surface doc. Waivers are reserved for **intentional, documented
  asymmetries** — e.g. per-user-audit "Effective user" absence (D-05); `scope_ribbon` intentionally
  omitted on the two Overview pages (documented at `organization_live.ex:60`). No unresolved
  actionable verdict may remain.
- **D-08 (monotonic guard green; do NOT ratchet user-sessions):** `scripts/ci/quality-ledger-
  monotonic.sh --base origin/main` exits 0 after all remediations. The 7 currently-Tier-2 pages
  keep Tier-2; **`user-sessions` (lone Tier-1) must NOT be ratcheted in this phase** — its Tier-2
  elevation is Phase 210. A remediation must not lower any page's Tier-2 evidence (e.g. don't
  delete a content-equivalence pattern or a checkpoint slug).

### Baseline recapture & canary discipline

- **D-09 (CI-native ubuntu recapture; allowlist→clear):** Page (checkpoint) baselines recapture
  **CI-native on ubuntu** — NOT darwin (the Playwright `pathTemplate` has no OS token, so baselines
  are platform-pinned; a darwin recapture byte-fails ubuntu CI). The guard reads **two** allowlists
  (`test/example/priv/playwright/snapshot-allowlist` checkpoint + `...snapshot-allowlist-design`);
  discipline is: add intended page slug(s) → recapture on CI → **clear both allowlists before phase
  close**. **Branding has NO checkpoint slug** (9 checkpoint slugs exist: `audit-explorer`,
  `global-overview`, `global-user-index`, `impersonation-banner`, `org-overview`,
  `org-scoped-admin`, `user-audit`, `user-detail`, `user-sessions`) — branding's Tier-2 evidence
  is its modal-interaction spec, not a screenshot, so SC-4 has no branding baseline to recapture.

### Folded scope — milestone-integration snapshot-canary drift (USER-RATIFIED binding gate)

- **D-10 (Phase 209 IS the binding gate for the 200–204 canary drift — user-ratified):** Per
  STATE's "strong candidate binding gate" intent and the user's explicit ratification, Phase 209
  **absorbs** resolution of the cross-phase milestone-integration snapshot-canary drift folded
  from `2026-06-30-v142-integration-snapshot-canary-drift.md`. Two parts:
  1. **Allowlist the legitimate drifted slugs** — `audit-explorer`, `user-audit`,
     `global-user-index`, `org-scoped-admin` (cumulative Phases 200–204 recaptures vs the stale
     `origin/main`) so `snapshot-canary-guard.sh --base origin/main` reads them as intended, not
     "drift" (plus the design board-* baselines if the design-lane guard needs it).
  2. **Make the `impersonation-banner` canary-policy decision** — Phase 204-03 intentionally
     modified `impersonation-banner-mobile` as part of a WCAG ≥4.5:1 contrast fix, which collides
     with the "canary must stay byte-green" rule. Resolve by **re-designating / re-baselining the
     canary with a documented rationale** (the contrast fix is legitimate and shipped), NOT by
     reverting the WCAG fix and NOT by guess-fixing. Document the canary re-designation rationale
     in the phase artifacts.
  **Net effect:** the v1.42 backlog integration PR (#63) `fast_checks` snapshot-canary lane goes
  green via Phase 209. The phase's **own** page remediations still close with both allowlists empty
  and the (re-designated) canary byte-stable relative to phase HEAD; the 200–204 allowlisting is
  the integration-base reconciliation layered on top.

### Claude's Discretion

- Exact per-surface verdicts the fresh adversarial panel produces (the live worklist in D-04 is the
  expected floor, not a ceiling — the forced-finding floor may surface additional findings).
- Which specific actionable verdicts resolve as in-place diffs vs documented waivers (within the
  D-07 boundary).
- Whether to run the panel via per-page/per-lens adversarial subagents or direct authoring against
  live DOM (either satisfies the rubric provided the forced-finding floor + DOM anchors hold).
- Plan decomposition (e.g. panel-authoring plan(s) → remediation plan(s) by page cluster →
  baseline-recapture + canary/allowlist-integration plan).
- The exact wording of the canary re-designation rationale (D-10 part 2).

### Folded Todos

- **`2026-06-30-v142-integration-snapshot-canary-drift.md`** (MILESTONE-INTEGRATION; canary drift
  + impersonation-banner policy) — **folded** as the D-10 binding-gate scope (user-ratified). Its
  Addendum (Library shard-2 `NoopTest` log-capture flake) is a **separate milestone-cleanup** item,
  NOT folded here — it is a parallel-shard flake unrelated to the page pass (re-defer; see
  `<deferred>`).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `guides/reference/admin-persona-jtbd-rubric.md` — **the instrument**: 3 lenses, 3 verdict
  questions, forced-finding floor, adversarial framing (must follow verbatim), YAML+markdown
  output schema, column-4 integer prohibition, roll-up index format.
- `.planning/v1.42-IA-DIAGNOSTIC.md` — **advisory** persona-panel pass + prioritized disposition
  list (sequencing input only; NOT a pre-scored panel — re-run fresh per D-01).
- `.planning/ROADMAP.md` — Phase 209 success criteria (~:167-180) are authoritative scope; Phase
  210 (~:182-195) owns user-sessions elevation + 3 persona flows; Phase 211 (~:197-209) terminal.
- `guides/reference/admin-quality-ledger.md` — current tier state (7 pages Tier-2, `user-sessions`
  Tier-1 ~:85-92; branding's evidence is modal-interaction, no checkpoint slug); monotonic-guard
  parse target (column-4 `^[012]$`).
- `guides/reference/admin-design-contract.md` — archetype compositions + same-job→same-component
  principle (the contract the cross-page asymmetries in D-04 violate).
- `guides/reference/admin-ui-principles.md` — design-system governance.
- `lib/sigra/admin/...` admin page LiveViews — the 8 surfaces to judge + remediate (confirm exact
  canonical source path during planning; the analyzer read them under `lib/sigra/admin/live/`).
  Findings anchored per D-04: `index_live.ex`, `organization_live.ex`, `users_index_live.ex`,
  `user_show_live.ex`, `user_sessions_live.ex`, `audit_index_live.ex`, `audit_user_live.ex`,
  `branding_live.ex`; shared `components.ex` (`<.empty_state>` :410, `<.scope_ribbon>`).
- `priv/templates/sigra.install/...` — host-shipped admin source (edit here; `test/example/` copy
  + `test/fixtures/install_golden/` must stay byte-coherent per D-06).
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (+ `-snapshots/`) — the 9 page
  checkpoint slugs + `impersonation-banner` canary capture (~:301-302).
- `test/example/priv/playwright/playwright.config.ts` — `pathTemplate` (no OS token → baselines
  platform-pinned ubuntu; D-09).
- `scripts/ci/snapshot-canary-guard.sh` — canary guard (canary slug ~:21, default `BASE=HEAD`
  ~:19, canary-not-allowlistable ~:99, byte-green rule ~:104); two allowlists.
- `scripts/ci/quality-ledger-monotonic.sh` — monotonic guard (must exit 0 vs `origin/main`; D-08).
- `.github/workflows/ci.yml` — ubuntu checkpoint job (~:999-1016) + design lane (`SNAP_DIR`
  override ~:104-105); `fast_checks` snapshot-canary lane (the #63 red lane D-10 turns green).
- `.planning/todos/pending/2026-06-30-v142-integration-snapshot-canary-drift.md` — folded D-10
  scope (canary drift + impersonation-banner policy); its Addendum (NoopTest flake) is NOT folded.
- `.planning/phases/208-l2-meta-component-group-elevation/208-CONTEXT.md` — prior phase; note its
  "feeds 209" deferrals (Overview empty-state, alarm verbosity, invite-CTA, total-users) are the
  D-04 live worklist.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **The rubric instrument is authored and ratified** (`admin-persona-jtbd-rubric.md`, Phase 205) —
  fixed lenses/questions/schema; the panel just instantiates it 8×.
- **`<.empty_state>` component already exists** (`components.ex:410`) — the organization_live bare
  `<p>` remediation (D-04) is a swap to an existing component, not a new build.
- **`scope_copy/1` helper pattern** is used on every page except branding's hardcoded literal
  (D-04) — branding remediation routes through the existing helper.
- **The full checkpoint/canary gate stack is wired**: `admin-checkpoints.spec.ts` (9 slugs +
  canary), `snapshot-canary-guard.sh`, two allowlists, monotonic guard — recapture is cite +
  allowlist→clear, not new infrastructure.

### Established Patterns
- v1.41 snapshot-recapture-gate + monotonic-ledger methodology (Phases 199-204), reapplied in
  206/207/208 — apply verbatim: edit source → recapture only changed baselines CI-native on
  ubuntu → canary byte-stable → allowlists empty at close → monotonic guard green.
- Adversarial forced-finding floor (rubric standing instruction): every (lens × question) cell
  carries a DOM-anchored finding or `NONE — searched for: <what>`; vibe-level assertions fail.
- "Same job → same component" — the cross-page asymmetries (chips inside/outside form; scope_ribbon
  above/below header) are design-contract violations, the prime D-04 remediation targets.

### Integration Points
- `priv/templates/sigra.install/` admin source → generated `test/example/` copy +
  `test/fixtures/install_golden/` tree (keep byte-coherent; D-06).
- Page baselines recapture through the CI ubuntu checkpoint job, NOT locally on darwin (D-09).
- The D-10 allowlisting reconciles against the stale `origin/main` integration base; the phase's
  own page recaptures reconcile against phase HEAD — two distinct base comparisons in one phase.

</code_context>

<specifics>
## Specific Ideas

- The IA diagnostic's "feeds 208" page deferrals (org-overview empty-state, index "All clear"
  verbosity, invite-CTA dead-end, total-users redundancy) are **Phase 209 live work** (D-03/D-04),
  not done — 208 was gallery/CSS only.
- Per-user-audit "Effective user" absence and the two Overview pages' omitted scope_ribbon are
  **intentional asymmetries** → resolve as documented **waivers** (D-05/D-07), not fixes.
- The canary re-designation (D-10 part 2) keeps the shipped WCAG ≥4.5:1 contrast fix — re-baseline
  + rationale, never revert the accessibility fix.
- `user-sessions` gets copy/IA remediation only this phase; its Tier-2 elevation is Phase 210 — do
  not pull it forward (D-08).

</specifics>

<deferred>
## Deferred Ideas

- **`user-sessions` Tier-2 elevation + the 3 persona flows** — explicitly **Phase 210** (PAGE-03,
  FLOW-01); 209 only does copy/IA remediation on the user-sessions page, not the tier ratchet.
- **Terminal ratification** (every cell `2`, idempotent recapture, generated-host parity,
  adversarial milestone audit) — **Phase 211** (GATE-01, GATE-02).
- **Library shard-2 `NoopTest` log-capture flake** (Addendum of the folded canary todo) — a
  parallel-shard flake unrelated to the page pass; **milestone cleanup**, not folded into 209
  (re-isolate the test via `async: false` / `ExUnit.CaptureLog` scoping at integration time).
- **Net-new admin surfaces** (e.g. a `board-cfg-org` composite, a dedicated invite-flow page) —
  forbidden by the "no net-new surfaces" posture (D-06); the org invite-CTA dead-end is remediated
  in-place (link to existing flow / `<.empty_state>` action), not by a new page.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db.md` (score 0.9) — CI-perf infra (per-shard
  DB isolation); not page-judgment work. Belongs to the CI-PERF milestone arc, not 209.
- `2026-06-19-uat-demo-dx-polish-nits.md` (0.6) — demo DX nits; unrelated to admin page pass.
- `2026-06-25-phase200-code-review-deferred.md` (0.6) — token-scoped session revocation hardening
  / admin session-helper de-dupe; a Phase-200 code-review carry, not UX page judgment.
- `2026-06-28-phase205-debt-ci-native-board-baselines.md` (0.6) — already folded into Phase 208.
- Remaining matches (≤0.4) — installer/config/css-cleanup, unrelated.
</deferred>
