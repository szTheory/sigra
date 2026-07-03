# Phase 208: L2 Meta-Component Group Elevation - Context

**Gathered:** 2026-06-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Elevate all **11 L2 meta-component groups** (`mg-1`…`mg-11`) to Tier-2 on **both** their
**isolated gallery boards** (`board-mg-*`) and their **real-page composite configurations**
(`board-cfg-*`) — completing the L0/L1/L2 building-block stack so the page judgment pass
(Phase 209) can run on an all-Tier-2 foundation. Award-grade at the group level means:
axe-clean per board across chromium/mobile/dark (0 violations); **no card-in-card nesting**;
**intra-group single-tier rhythm**; **right-component-for-job**; **defined zero/loading/error
states** for each group that can enter them; **byte-coherent reuse** across groups; and
**MG-5/MG-6 desktop↔mobile content-equivalence** (table+mobile-card swap) proven green.

This is **group-board work only**. The groups are L1-component *compositions* exercised on the
**example-only** design gallery (`test/example/lib/example_web/live/admin/design_gallery_live.ex`)
— NOT a host-shipped surface. Page composition, cross-page placement coherence, and the
adversarial persona/JTBD panel over real pages are **out of scope** — they belong to **Phase
209** (Judgment-Level Page Pass). The `user-sessions` page + 3 persona flows are **Phase 210**;
terminal ratification is **Phase 211**. Requirements: **GROUP-01, GROUP-02**.
</domain>

<decisions>
## Implementation Decisions

### Scope boundary (group boards only; page findings → Phase 209)

- **D-01 (group-board scope; stale-diagnostic numbering):** Phase 208 modifies only the 11
  `board-mg-*` isolated boards and the 4 `board-cfg-*` composites in `design_gallery_live.ex`,
  plus any underlying `sg-*` CSS those compositions depend on. `.planning/v1.42-IA-DIAGNOSTIC.md`
  was authored in Phase 205 using **v1.41-era page-centric numbering** — its "feeds 208" tags
  (`organization-live` empty-state bare `<p>` vs `<.empty_state>` ~:248; `index-live` alarm
  "All clear" verbosity ~:252; org invite-CTA dead-end ~:253; Total-users redundancy ~:260; the
  cross-ref line ~:282 "Phase 208: Overview pages (Global + Org) elevation") are **page-
  composition** concerns. The **authoritative v1.42 ROADMAP** defines 208 = L2 group elevation
  (gallery boards) and **209 = Judgment-Level Page Pass over all 8 pages** (which includes the
  Overviews). All those diagnostic page findings route to **Phase 209**. This is the identical
  ruling 207-CONTEXT D-01 made for the diagnostic's stale "feeds 207" tags. Do **not** pull
  Overview page-recompose work into 208 — it collides with 209 and double-churns page baselines.

### Elevation mechanic (mirror 206/207 verbatim — audit, not refactor)

- **D-02 (audit → cite → narrow-gap-fix → flip → recapture):** Apply the proven 206/207 method
  identically. The 11 group boards are **already structurally Tier-2** — right components, single-
  tier `sg-stack` rhythm, no card-in-card, all four states rendered. Elevation is primarily
  **citing the already-wired gates** and flipping ledger rows, with at most cosmetic narrow CSS
  fixes surfaced by audit. This is **not** a relocation/restructure of group compositions.
- **D-03 (edit source, not copy):** Any `sg-*` CSS change lands in
  `priv/templates/sigra.install/admin/sigra_admin.css` (the host-shipped source); the generated
  `test/example/` copy and `test/fixtures/install_golden/` tree must stay **byte-coherent** or
  golden-diff/install tests fail and host apps never receive the elevation. **Note:** the group
  *board markup* itself lives example-only in `design_gallery_live.ex` (a grading surface, not in
  installer templates) — only underlying `sg-*` CSS touches need source-side editing.

### Criterion-1 gates (isolated boards) — reuse, don't rebuild

- **D-04 (cite the already-wired L2 gate stack):** Per-board axe + screenshot across 3 projects
  (`admin-design.spec.ts` `assertBoardScreenshot`, GROUP_BOARDS ~:104, loop ~:257), the
  `.sg-card .sg-card` card-in-card check (~:349, live on all 11 — no board carries the
  `data-sg-card-nesting-audit-only` escape hatch), and per-group catalog-state markers
  (`GROUP_STATE_MARKERS` ~:120-131; "group boards expose catalog states" test ~:318-362 enforces
  each marker visible + exact component counts) are **already wired and green** per committed
  baselines. 208's job is to keep them 0-violation/clean through any change and **cite them** as
  ledger evidence. Add a state-variant board only if audit surfaces a genuine gap.

### Criterion-2 — board-cfg-* composites (fold the Phase-205 baseline debt)

- **D-05 (capture the 4 cfg baselines CI-native):** There are **0 committed `board-cfg-*` PNG
  baselines** (vs 33 `board-mg-*`). **Fold the pending todo**
  `2026-06-28-phase205-debt-ci-native-board-baselines.md` into this phase: capture the **4
  existing cfg composites** (`board-cfg-overview`, `board-cfg-users-list`, `board-cfg-user-detail`,
  `board-cfg-audit`) → **12 PNGs (4×3)** **CI-native via the `admin_design_recapture` ubuntu
  job** (ci.yml ~:1379). **Never capture on darwin** — those get reverted (proven at `43f5a3e4`)
  and the hard-gating `design_gallery` PR job (ci.yml ~:1044) fails on missing/mismatched
  snapshots. This is criterion-2's load-bearing proof.
- **D-06 (MG-7/MG-8 isolated-board-only — USER-RATIFIED):** There is **no `board-cfg-org`**
  composite, so MG-7 (org-member-roster) and MG-8 (pending-invitations) appear only on their
  isolated `board-mg-7`/`board-mg-8` boards. **Decision (user-confirmed): isolated-board coverage
  is sufficient** for these two groups — do **NOT** author a net-new `board-cfg-org` surface
  (honors the milestone's "no net-new surfaces" posture). Criterion 2 reads as "every group that
  *has* a cfg composite passes." **Document this ruling explicitly in the MG-7/MG-8 ledger
  evidence strings** so the absence of a cfg-org composite reads as intentional, not an oversight.
- **D-07 (MG-5/MG-6 content-equivalence):** The desktop↔mobile content-equivalence proxy applies
  to **mg-5 and mg-6 only** (the table+mobile-card swap groups) via
  `assertUserResultEquivalence`/`assertAuditResultEquivalence` (~:162-207) and the equivalence
  test (~:364-383) — must be **green**. All other groups carry `content-equivalence: N/A` in the
  ledger.

### Criterion-3 — state coverage + byte-coherent reuse

- **D-08 (deliberate "state N/A" is acceptable; make it explicit):** mg-3/mg-9/mg-11 use
  intentional "state-not-applicable **notes**" rather than fabricated zero/loading states
  (e.g. `mg-3-zero-note`, `mg-3-loading-note`). Do **not** fabricate meaningless states. The
  ledger evidence for those groups must **say so explicitly** so it reads as a deliberate "N/A"
  ruling, not a missing state. Zero/loading/error variants that *do* exist (mg-7/mg-8 already use
  `<.empty_state>` for zero ~:947-951, ~:977-983; mg-4 alarm zero-state exists) are cited as-is.

### Criterion-4 — ledger flip + snapshot discipline (v1.41 method)

- **D-09 (flip 11 L2 rows to bare `2`):** Flip exactly the **11 `mg-*` rows** in
  `guides/reference/admin-quality-ledger.md` (~:74-84) from `1` → **bare `2`** — **never `2*`**
  (a decorated integer breaks the `awk -F'|'` monotonic parse). Use the rich semicolon-delimited
  evidence shape mirroring the freshly-flipped L1 rows (~:61-73): 3-project axe+screenshot
  citation; card-in-card / single-tier-rhythm / right-component proxies; zero/loading/error state
  evidence (with explicit "N/A" notes per D-08); content-equivalence for mg-5/mg-6 only (`N/A`
  elsewhere, per D-07); the MG-7/MG-8 isolated-only ruling (per D-06). At close, **all 11 L2 cells
  + all 13 L1 cells + the L0 cell read `2`**.
- **D-10 (snapshot discipline):** Surgically recapture **only** baselines for boards whose pixels
  actually change, **plus** the net-new 12 cfg PNGs (D-05). `board-notice`/`impersonation-banner`
  canaries stay **byte-stable and untouched**; **both allowlists empty at phase close**;
  `scripts/ci/quality-ledger-monotonic.sh --base origin/main` exits 0.

### Folded Todos

- **`2026-06-28-phase205-debt-ci-native-board-baselines.md`** (kind: debt, area: admin-design
  playwright baselines / CI) — folded as the criterion-2 cfg-baseline proof (D-05). Item #1
  (missing `board-cfg-*` baselines) is **directly in 208 scope**. Items #2 (local `main` behind
  `origin/main` — merge/rebase before PR) and #3 (~12 Phase-205 behavioral failures) are handled
  during execution as needed; if any behavioral failure is non-208 infra it may re-defer to 211,
  but criterion-2's cfg-composite/MG-5/6-equivalence requirements make most of #3 load-bearing now.

### Claude's Discretion

- Exact per-group audit findings and which (if any) genuinely need a CSS fix vs already-present
  (expected: minimal — markup is structurally sound).
- Precise wording of each ledger evidence string (keep `awk -F'|'` monotonic-safe — bare `2`).
- Plan decomposition (e.g. waves by group cluster vs single audit+flip plan + a cfg-baseline plan).
- Whether any Phase-205 debt item #3 behavioral failure is in-scope vs re-deferred to 211.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/phases/207-l1-component-elevation-wave-b-l0-token-layer/207-CONTEXT.md` — **the
  template**; D-01…D-09 are the proven L1 method this phase mirrors at the L2-group level
- `.planning/phases/206-l1-component-elevation-wave-a/206-CONTEXT.md` — original Wave-A method
- `.planning/ROADMAP.md` — Phase 208 success criteria (~:116-129) are authoritative scope
  (group boards: isolated `board-mg-*` + `board-cfg-*` composites); Phase 209 (~:131-144) owns
  the page judgment pass over all 8 pages
- `.planning/v1.42-IA-DIAGNOSTIC.md` — **advisory**; its "feeds 208" page-composition tags use
  stale v1.41 page-centric numbering and route to **209**, NOT 208 (see D-01)
- `guides/reference/admin-quality-ledger.md` — the 11 `mg-*` L2 rows to flip (~:74-84); Tier-2
  evidence exemplar = the freshly-flipped L1 rows (~:61-73)
- `guides/reference/admin-fractal-scorecard.md` — L2 tier vocabulary + L2 proxies (~:61-79)
- `guides/reference/admin-design-contract.md` — archetype compositions + same-job→same-component
- `guides/reference/admin-ui-principles.md` — design-system governance
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — **example-only** grading
  surface (1371 lines): 11 `board-mg-*` groups (~:455-1177) + 4 `board-cfg-*` composites
  (~:1182-1371). Group state markers/components per group documented inline.
- `test/example/priv/playwright/tests/admin-design.spec.ts` — GROUP_BOARDS (~:104), CONFIG_BOARDS
  (~:118), GROUP_STATE_MARKERS (~:120-131), card-in-card check (~:349), MG-5/6 equivalence
  (~:162-207, test ~:364-383), catalog-state test (~:318-362), board loop (~:257)
- `priv/templates/sigra.install/admin/sigra_admin.css` — canonical `sg-*` styling **source**
  (edit here; the `test/example/` copy is generated and must stay byte-coherent)
- `scripts/ci/quality-ledger-monotonic.sh` — monotonic guard (must exit 0 vs origin/main)
- `.github/workflows/ci.yml` — `admin_design_recapture` job (~:1379) for **CI-native** cfg
  baseline capture; hard-gating `design_gallery` PR job (~:1044)
- `.planning/todos/pending/2026-06-28-phase205-debt-ci-native-board-baselines.md` — folded
  cfg-baseline + branch-divergence debt (D-05)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Full L2 gate stack already wired** in `admin-design.spec.ts`: per-board axe+screenshot ×3
  projects, card-in-card check (live on all 11), per-group catalog-state markers/counts, and
  MG-5/MG-6 content-equivalence assertions — criterion 1 is structurally satisfied today.
- **11 `board-mg-*` boards already render all four states** (populated + zero/zero-note +
  loading/loading-note + error via `notice tone={:risk}`); mg-7/mg-8 zero-states already use
  `<.empty_state>`; 33 committed mg baselines (11×3).
- **4 `board-cfg-*` composites already authored** (overview/users-list/user-detail/audit) — but
  **0 committed baselines** (the Phase-205 debt this phase folds in).
- **Right-component / single-tier rhythm already present**: mg-3/mg-5 are `<section>` (not
  `sg-card`; mg-3 test asserts `not.toHaveClass(sg-card)`); mg-6's `sg-card` wrapper holds
  `sg-table-panel`/`sg-list` inner results (not nested `sg-card`), so the nesting check passes.

### Established Patterns
- v1.41 snapshot-recapture-gate + monotonic-ledger methodology (Phases 199-204), reapplied in
  206/207 — apply verbatim: edit source CSS → recapture only changed board PNGs → canaries
  byte-stable → allowlists empty at close → monotonic guard green.
- Ledger Tier-2 evidence = long semicolon-delimited string; tier column is **bare `2`**.
- **admin-design baselines are CI-native (ubuntu)** — never recapture board PNGs on darwin.

### Integration Points
- `priv/templates/sigra.install/` CSS source → generated `test/example/` copy +
  `test/fixtures/install_golden/` tree (keep byte-coherent). Group board markup is example-only.
- cfg-baseline capture runs through the `admin_design_recapture` CI job, not locally.
- Local `main` may be behind `origin/main` (debt todo #2) — fetch + reconcile before opening PR
  so board baselines compare against current ubuntu recaptures.
</code_context>

<specifics>
## Specific Ideas

- Criterion 2's "every group's cfg composite" applies only to groups that *have* one; MG-7/MG-8
  are isolated-board-only by design (D-06, user-ratified) — make this explicit in their ledger
  evidence so it doesn't read as a coverage hole.
- mg-3/mg-9/mg-11 "state N/A note" pattern is deliberate (D-08) — cite it explicitly; don't
  fabricate zero/loading states to satisfy a literal four-state reading.
- The cfg baselines are the net-new pixels this phase introduces; everything else is keep-clean +
  flip.
</specifics>

<deferred>
## Deferred Ideas

- **Overview page-composition findings** the IA-diagnostic tags "feeds 208" (org-overview
  empty-state bare `<p>` vs `<.empty_state>`, index "All clear" alarm verbosity, org invite-CTA
  dead-end, total-users redundancy) — page-level, deferred to **Phase 209** (Judgment-Level Page
  Pass), per D-01.
- **A `board-cfg-org` composite for MG-7/MG-8** — explicitly **not** built (D-06, user-ratified):
  net-new gallery surface against the milestone's "no net-new surfaces" posture.
- **Phase-205 debt todo items #2/#3** — branch reconcile is a pre-PR mechanic; any #3 behavioral
  failure that proves to be non-208 infra may re-defer to Phase 211 ratification.

### Reviewed Todos (not folded)
- `2026-06-20-runtime-auth-prefix-override.md` (score 0.7) — auth-schema config, not DS work.
- `2026-06-20-playwright-parallelization-per-shard-db.md` (0.6) — CI-perf infra, not group DS.
- `2026-06-19-uat-demo-dx-polish-nits.md` (0.4) — demo DX, unrelated.
- Remaining matches (score ≤0.4) — unrelated.
</deferred>
