# Phase 205: Foundation - Context

**Gathered:** 2026-06-28 (assumptions mode + deep per-area research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the **judge instrument, gallery configurations, and stress fixtures** so every
downstream v1.42 phase (206–211) can run the rubric and render realistic states — without
elevating any actual cell to Tier-2 yet. This is the v1.42 analog of v1.41's Phase 199:
the "measuring instrument + stress data" phase.

In scope (INSTR-01, INSTR-02, INSTR-03, FIXT-01):
- Author `guides/reference/admin-persona-jtbd-rubric.md` — the adversarial persona/JTBD
  judge instrument (3 lenses, 3 verdict questions, keep/tighten/kill scale, fixed output
  schema), cross-referenced from the fractal scorecard + quality ledger.
- Add `board-cfg-*` real-page composite boards to the `/admin/_design` gallery, registered
  in `admin-design.spec.ts`, snapshot-clean across chromium/mobile/dark.
- Commit `.planning/v1.42-IA-DIAGNOSTIC.md` — an up-front, **advisory** persona-panel read
  across all 8 admin pages + a prioritized disposition list sequencing the 206–210 work.
- Close the remaining FIXT-01 edge-state gaps in the `@demo.tasklane.test` demo cohort
  (empty-entity states + i18n/RTL overflow) without touching the golden-path `mix test` fixture.

Out of scope (later phases): any award-grade component/group/page elevation (206–210);
terminal ratification / allowlist reset / Tier-2 cell flips (211); the desktop↔mobile
content-equivalence assertions and award-grade composite cleanup (Phase 208 / GROUP-02);
the *scored* per-surface remediation panel (Phase 209, distinct from this phase's advisory
diagnostic). This phase makes Tier-2 **judgeable and demonstrable**; it does not move any cell.
</domain>

<decisions>
## Implementation Decisions

### INSTR-01 — Persona-JTBD Judge Rubric

- **D-01:** Author `guides/reference/admin-persona-jtbd-rubric.md` as a **sibling reference doc
  mirroring the structure of `admin-fractal-scorecard.md`** (tier-vocabulary-style framing →
  fixed dimensions → cross-references). Add a bidirectional pointer block into BOTH the
  scorecard (near the L4 Flow add-on, ~lines 104–121) and the quality ledger (near the L4
  `flow-*` rows, ~lines 93–95). The rubric formalizes existing artifacts; it does **not** invent
  new personas or a competing tier system.
- **D-02:** Bind the 3 lenses 1:1 to existing seed personas + L4 flow cells, each defined by
  **entry point + intent** (not credentials — investigator and platform-admin share the `admin`
  login):
  - **Platform admin** → `admin` persona, posture **triage** ("what needs attention, where next?") → `flow-platform-admin`
  - **Support investigator** → `admin` acting *on a target* (`dave` locked / `frank`·`grace` deletion / `carol` OAuth), posture **investigate** (find→audit→impersonate→return-with-banner) → `flow-support-investigator`
  - **Org admin** → `morgan` (`org_admin: :acme`, **non-platform**), posture **bound** (tenant-only; clean 403 on overreach) → `flow-org-admin`
  The rubric must explicitly state these are *admin lenses* bound to **demo** personas, distinct
  from the *integrator* personas (A–E) in the JTBD prompt, so reviewers don't conflate them.
- **D-03:** Three fixed verdict questions, each phrased as a **refutation prompt** mapped 1:1 to
  the milestone's named failure modes:
  1. **Earning its place?** (verbosity / info-dump) — "name one element NOT earning its place for this lens; if none, say so explicitly."
  2. **Is the IA muddy?** (IA) — "where does general→specific hierarchy break, or the next action is not obvious? point to the exact element."
  3. **Redundant / coherent / least-surprising?** (redundancy) — "name one place this says the same thing twice, diverges from a sibling surface doing the same job, or would surprise the operator."
- **D-04:** **Adversarial anti-rubber-stamp framing is mandatory and load-bearing.** Standing
  rubric instruction: "find the strongest case *against* this surface for this lens; a `keep`
  with zero findings is valid only after you actively tried and failed to find a fault, and you
  must state what you searched for." Enforce a **forced-finding floor**: every (lens × question)
  cell holds either a cited element *or* the literal token `NONE — searched for: <what>`. Every
  finding must **cite a concrete DOM/section anchor**, never a vibe.
- **D-05:** Ordinal scale = **`keep` / `tighten` / `kill`** (3-point — highest inter-rater
  agreement; maps directly to dispositions remove/edit/leave). Each level anchored with a
  one-line definition + worked example (mirroring how the scorecard defines Tier 0/1/2).
  Element disposition = **worst verdict across the 3 lenses** (a `kill` from any lens is a kill).
  Rejected: Nielsen 0–4 (noisy middle), numeric 1–10/Likert (center-collapse), MoSCoW (wrong domain).
- **D-06:** Fixed output schema = **YAML frontmatter (machine-rollup-able) + Markdown body
  (human-auditable refutation log)**. Frontmatter carries `surface`, `ledger_cell`,
  `rubric_version`, `disposition` (`clean`/`actionable`/`blocked` = worst across cells), a
  9-key `verdicts` map (lens × question), and a `findings` list (only non-`keep` cells get an
  actionable row with `element` + `refutation` + `disposition_action`). Body = per-lens
  refutation log. This is the template Phase 209's 8 per-surface docs instantiate.
- **D-07 (ANTI-COLLISION — critical):** The new rubric/panel docs use `keep/tighten/kill` +
  `clean/actionable/blocked` vocab and **must never place a bare `0`/`1`/`2` integer in a table
  column-4**, so the quality-ledger's positional `awk -F'|'` monotonic guard can never
  false-match them. State this explicitly in the rubric's "relationship to the quality ledger"
  section. The roll-up index (`v1.42-PERSONA-JTBD-PANEL.md`, a Phase 209 artifact) is a plain
  table (`surface | disposition | kill-count | tighten-count | links`), deliberately NOT the
  ledger's integer-parse format.

### INSTR-02 — `board-cfg-*` Real-Page Composites

- **D-08:** Composites are **purely additive** (zero `board-cfg` occurrences in code today).
  Scope to the **4 documented page archetypes** from `admin-design-contract.md`:
  `board-cfg-overview`, `board-cfg-users-list`, `board-cfg-user-detail`, `board-cfg-audit`.
  **Defer a Branding composite** (single-instance workbench, low composition risk). Reject a
  mega "kitchen-sink" board (non-localizable diffs) and per-variant explosion (snapshot bloat).
  The 11 isolated `board-mg-N` boards stay untouched.
- **D-09 (rendering — confirmed fork):** **Duplicate static archetype markup in
  `design_gallery_live.ex`** from `sg-*` primitives + existing `Sigra.Admin.Components`,
  with **static literal assigns** (no DB, no `Query` imports, no scope/session/Repo coupling,
  no `now`-derived timestamps). This matches how MG-1…MG-11 already work and respects 205's
  "scaffold + snapshot-clean" charter — the real admin LiveViews expose only *component*-level
  shared functions (never section/page-level) and bind live data, so they can't be cheaply
  called from a static gallery. Add a **lightweight per-composite structural assertion**
  (mirroring the existing "group boards expose catalog states" test + the `.sg-card .sg-card`
  nesting guard) as cheap anti-drift insurance. Each composite carries an in-LiveView comment
  pointing at its source archetype + real LiveView file.
- **D-10:** Register via a **new `CONFIG_BOARDS` array** beside `COMPONENT_BOARDS`/`GROUP_BOARDS`
  in `admin-design.spec.ts`, folded into the existing element-scoped screenshot loop + the
  responsive/overflow loop. Each composite `id="board-cfg-{archetype}"`, **element-scoped
  captures only — no full-page captures** (keeps the admin shell out of every diff). Inherit
  the gallery's existing determinism stack: `waitForLiveViewReady` + `fonts.check('Space
  Grotesk')` font-stability gate, element-scoping. Set composite `maxDiffPixels`/
  `maxDiffPixelRatio` **slightly above** the MG-board values (larger surfaces). Exclude
  motion/loading states from the populated composite (show the loaded page).
- **D-11 (snapshot discipline, Phase-199 D-12…D-15 method):** Composites are **net-new slugs →
  capture-only, not recapture**. The `impersonation-banner` and `board-notice` canaries stay
  **byte-stable and untouched**; **both allowlists empty at phase close**. New ids cannot
  regress the monotonic guard.

### INSTR-03 — IA Diagnostic

- **D-12:** `.planning/v1.42-IA-DIAGNOSTIC.md` is a **net-new, advisory** top-level planning doc
  (no prior IA-diagnostic/persona-panel precedent). Structure: (1) **inventory** — the 8 admin
  pages × archetype × the L0/L1/L2 building blocks each composes (so 206–208 component/group
  work traces back to page findings); (2) **persona-panel pass** — the 9-cell matrix per page at
  *diagnostic depth* (one pass, headline findings — NOT the full Phase 209 evidence docs);
  (3) **prioritized disposition list** feeding 206–210.
- **D-13 (gating — confirmed fork):** The diagnostic's prioritized list is **ADVISORY**
  (early-warning + sequencing input only). The **Phase 209 per-surface panel is the single
  binding gate** (commit-diff-or-waiver per `actionable` verdict). This avoids double-gating,
  keeps the up-front pass cheap, and lets late-discovered issues surface in 209 without a
  roadmap edit.
- **D-14:** Prioritization = **coarse Impact×Effort, 3 bins each (High/Med/Low)** — NOT RICE
  (n=8 doesn't warrant person-month precision; Reach is ~constant, Confidence is noise).
  Impact = #lenses flagging + worst verdict; Effort = surface area touched (L1 component vs
  whole-page recompose). A `kill` from any lens **auto-promotes to ≥P2**. Disposition table
  columns: `Surface | Worst verdict | Lenses flagging | Impact | Effort | Priority | Feeds phase`.

### FIXT-01 — Edge/Boundary/Empty Fixtures (mostly inherited from Phase 199)

- **D-15 (reframe):** The `/admin/_design` gallery's empty/zero boards are **already static
  inline markup** (`<.empty_state>` in `design_gallery_live.ex`) — **no seed work is needed for
  the gallery**. The real FIXT-01 "empty" gap is on **live admin pages** (`/admin/users`,
  `/admin/users/:id`, `/admin/audit`), which today have no navigable true zero-state because
  every seeded entity is populated.
- **D-16:** Add exactly **two net-new real-but-empty entities** (prefer "real but empty" over
  "filter-to-nothing", which only exercises the zero-*results* path, not the empty-*entity*
  first-run surface):
  - **Empty organization** (`ghost-org`: zero members, zero invitations, zero enterprise
    connection, zero audit) — seeded in `seed_organizations/0` via the same idempotent
    `upsert_organization/3`, deliberately given **no** `seed_memberships` entry. **NOT a persona.**
  - **Zero-state persona** (`zoe@demo.tasklane.test`: confirmed, no MFA/passkey/identity/org/
    sessions/audit) — drives the empty `<.empty_state>` branch on all four `user_show_live`
    panels at once; the cleanest persona-panel review target.
- **D-17 (SSoT lockstep):** `zoe` goes **IN `Personas.all/0`** (she's a credentialed login-able
  demo identity → belongs on `/demo/credentials`) and must be threaded through **all SSoT
  touchpoints together**: `Personas.all/0`, `feature_map/0`, the `print_credentials` loop, and
  the `demo_users == length(Personas.all())` + per-state assertions in `seeds_test.exs`. Add a
  `seeds_test.exs` test asserting `zoe` has zero sessions/identities/orgs/audit and the empty
  org has zero memberships, so the empty invariants can't silently regress. The `loadtest-`
  cohort stays OUT of the catalog (unchanged, Phase-199 D-09).
- **D-18 (i18n/RTL — confirmed fork):** Add **one i18n/RTL overflow user** to the `loadtest-`
  cohort (multi-byte CJK + RTL Arabic/Hebrew + combining diacritics + emoji in display name) —
  the one genuinely-uncovered overflow class (all current fixtures are ASCII/LTR), table-stakes
  for mature admin products. Stays in the cohort (out of catalog).
- **D-19 (determinism contract, carried forward verbatim):** All additions live behind the
  `priv/repo/seeds.exs` `MIX_ENV == :test` raise-guard in the `@demo.tasklane.test` cohort;
  idempotent check-then-insert / `on_conflict`; **no `faker`, no randomness, no
  `DateTime.utc_now()`** in seeded values — derive from `@seed_reference_ts` + deterministic
  hashes. The golden-path `mix test` CI fixture stays **byte-unmodified**. Audit vocab stays
  fixed (`success`/`failure`/`error`; no severity column; no new schema columns).
- **D-20 (blast radius):** Seed additions are **NOT snapshot-neutral** (`zoe` adds a
  `/demo/credentials` row + an `/admin/users` row → 46 total, still 2 pages @ limit 25; the
  empty org appears on org-scoped panels; the i18n user shifts list rendering). Recapture only
  the affected non-canary slugs through `snapshot-recapture-gate.sh`; canaries byte-stable;
  allowlists empty at close.

### Folded Todos
- **`2026-06-25-phase199-code-review-info-hardening`** — folded; these harden the exact
  instrument/fixture substrate this phase ships:
  - **IN-04** (`admin-quality-ledger.md` Terminal-Ratification prose hardcodes "Phases 200-204",
    now actively rotting since 205–211 are live) → fix to a dated note / ROADMAP pointer as part
    of the INSTR-01 ledger cross-reference edit.
  - **IN-02** (`@bulk_cohort_size 36` duplicated in `seeds.ex` + `seeds_test.exs`) → expose
    `Seeds.bulk_cohort_size/0`, have the test reference it (folds into FIXT-01, mirroring how
    `Personas.all/0` is the single source for the persona count).
  - **IN-05** (`quality-ledger-monotonic.test.sh` only covers 2→1 + no-change) → add **Test C**
    (`1→2` increase exits 0 — the exact op Phases 206–211 perform) + optional **Test D**
    (decorated column-4 e.g. `2*` false-pass guard).
  - **IN-01** (clarifying comment on the `seed_bulk_users/0` confirm-branch) and **IN-03**
    (extract `@seconds_per_day 86_400`) — done opportunistically while in `seeds.ex`.

### Claude's Discretion
- Exact archetype markup of each `board-cfg-*` composite (which MG groups to assemble per page,
  ordering) — mirror the real admin page's section flow; keep representative populated state.
- Precise rubric prose, worked-example anchors, and the exact frontmatter key names (keep them
  `yq`/grep-friendly).
- Exact i18n/RTL fixture string values and `zoe`/`ghost-org` field values (deterministic,
  non-time, non-random).
- Whether the guard self-test additions (IN-05) are new test cases in the existing
  `quality-ledger-monotonic.test.sh` or a sibling — pick lowest-friction consistent with the
  existing self-test shape.
- Exact composite `maxDiffPixels` budgets (calibrate above MG-board values, smallest that's
  stable across the 3 projects).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `guides/reference/admin-fractal-scorecard.md` — grading rubric to mirror structurally; per-level add-on block pattern; L4 Flow add-on (~lines 104–121) is the cross-ref insertion point; column-4 integer-parse constraint to respect.
- `guides/reference/admin-quality-ledger.md` — machine-parseable ledger; L4 `flow-*` rows (~93–95) for cross-ref + lens binding; Terminal-Ratification prose (~106–113) hardcodes stale "200-204" (IN-04 fix); the `awk -F'|'` monotonic-guard parse the new docs must never collide with.
- `guides/reference/admin-ui-principles.md` — the 3 Product-Frame personas (platform admin / support investigator / org admin) the lenses formalize; GOV.UK service-thinking framing for the IA question.
- `guides/reference/admin-design-contract.md` — page archetypes (the IA-diagnostic inventory axis + the 4 composite targets); "same job → same component"; the D-04 "Confirmed pill" kill exemplar.
- `test/example/lib/example/demo/personas.ex` — concrete lens binding: `admin` (platform), `morgan` (`org_admin: :acme`, non-platform → org-admin lens / 403), investigator target rows (`dave`/`frank`/`grace`/`carol`); `Personas.all/0` SSoT (~line 51); `feature_map/0`. `zoe` to be added here.
- `test/example/lib/example/demo/seeds.ex` — bulk `loadtest-` cohort (`@bulk_cohort_size`, `seed_bulk_users/0`, overflow values), `@audit_actions` ≥25-event actor, `maybe_lock`/`scheduled_deletion` status, `seed_organizations/0` + `upsert_organization/3` (empty-org insertion point), `MIX_ENV=test` raise guard, idempotent upserts, `@seed_reference_ts`.
- `test/example/test/example/demo/seeds_test.exs` — invariants: `demo_users == length(Personas.all())`, bulk-cohort count (`@bulk_cohort_size 36` at ~line 43 → switch to `Seeds.bulk_cohort_size()`), idempotency; add empty-entity invariants.
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — gallery LiveView; MG-1…MG-11 boards are hand-authored static archetype fragments (the pattern composites follow); existing static `<.empty_state>` boards confirm gallery empty-state coverage is data-independent.
- `test/example/priv/playwright/tests/admin-design.spec.ts` — board registration arrays (`COMPONENT_BOARDS`/`GROUP_BOARDS`) + element-scoped capture loop + responsive/overflow loop; `assertBoardScreenshot`; `board-notice` canary; add `CONFIG_BOARDS` + structural assertions here.
- `lib/sigra/admin/components.ex` — component-level `sg-*` primitives the composites reuse (`task_card`, `summary_chip`, `audit_table_row`, `empty_state`, etc.).
- `lib/sigra/admin/live/{index,organization,users_index,user_show,user_sessions,audit_index,audit_user,branding}_live.ex` — the 8 admin pages (IA-diagnostic inventory; archetype sources for composites).
- `scripts/ci/quality-ledger-monotonic.test.sh` — guard self-test (IN-05: add 1→2 + decorated-column tests); guard itself `scripts/ci/quality-ledger-monotonic.sh`.
- `.planning/milestones/v1.41-phases/199-foundation-tier-2-scorecard-stress-fixtures/199-CONTEXT.md` — direct precedent for fixture/snapshot/canary/allowlist discipline (D-08…D-15).
- `.planning/todos/pending/2026-06-25-phase199-code-review-info-hardening.md` — the folded INFO hardening items (IN-01…IN-05).
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — JTBD/persona framing; note these are *integrator* personas (A–E), distinct from the admin lenses — the rubric must say so.
- Recapture/canary lanes + monotonic-guard wiring: `.github/workflows/ci.yml` (guard `--base origin/main`; recapture-gate lanes / canary-allowlist semantics).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The fractal scorecard's per-level add-on block is the exact authoring template for the new
  persona-JTBD rubric (sibling instrument; cross-reference, don't compete).
- The gallery already renders hand-authored static archetype fragments (MG-1…MG-11) from
  `sg-*` primitives — composites extend this proven pattern; no new abstraction needed.
- `admin-design.spec.ts` already drives snapshots off declarative board arrays through one
  element-scoped capture loop — `CONFIG_BOARDS` slots in with minimal friction.
- `seeds.ex` already implements idempotent count-threshold/`on_conflict` upserts, a
  `MIX_ENV=test` raise guard, deterministic `@seed_reference_ts`, the `loadtest-` cohort, and
  `upsert_organization/3` — all reused verbatim for the empty org + i18n user.
- The monotonic guard is already Tier-agnostic numeric; the new rubric is a separate
  human/LLM instrument and intentionally does not feed it.

### Established Patterns
- `Personas.all/0` is a closed SSoT catalog driving `/demo/credentials`, `feature_map`, and the
  `demo_users == length(Personas.all())` seed assertion — adding `zoe` requires moving every
  touchpoint in lockstep; `loadtest-`/i18n stress users stay OUT of the catalog.
- Quality-ledger column-4 = single `[012]` integer parsed positionally by `awk -F'|'`; the new
  rubric docs must avoid that shape entirely (D-07).
- Snapshot lanes use byte-stable canaries (`impersonation-banner`, `board-notice`) + per-slug
  allowlists; net-new slugs are capture-only; recapture goes through `snapshot-recapture-gate.sh`;
  allowlists end empty (Phase 192 / 199 precedent).
- Gallery determinism = static assigns + `Space Grotesk` font-stability gate + element-scoping;
  composites inherit this for free.

### Integration Points
- Rubric ↔ scorecard ↔ quality ledger (cross-references); rubric → Phase 209 per-surface docs →
  `v1.42-PERSONA-JTBD-PANEL.md` roll-up.
- `board-cfg-*` composites ↔ `design_gallery_live.ex` + `admin-design.spec.ts` + the 4 real
  page archetypes (anti-drift structural assertions).
- Seed fixtures ↔ `/admin/users`, `/admin/users/:id`, `/admin/audit`, `/demo/credentials`,
  org-scoped panels (row counts, empty branches, pagination).
- IA diagnostic → sequences 206–210 (advisory); Phase 209 panel is the binding gate.
</code_context>

<specifics>
## Specific Ideas

- The org-admin lens (`morgan`, non-platform) is the most adversarially valuable by construction:
  she's refutation-shaped, so any global-scope leak, un-takeable action, or unclean 403 is an
  automatic finding — lean on her for the sharpest IA/redundancy verdicts.
- The forced-finding floor (`NONE — searched for: <what>`) + cited DOM anchors are the specific
  devices that make this rubric low-variance across human AND LLM reviewers — this is what the
  heuristic-eval/LLM-judge literature says prevents rubber-stamping.
- "Real but empty" (an actual zero-member org / zero-everything user) is a distinct UX surface
  from "filter to nothing" — the design system must render the empty-*entity* first-run state,
  not just the zero-*results* state.
- Composites catch composition-level bugs isolated boards structurally cannot: spacing rhythm,
  card-in-card nesting, header→notice→grid flow, cross-MG visual conflict (the Atomic-Design
  template/page-story argument).
</specifics>

<deferred>
## Deferred Ideas

- **Shared section/page-level component extraction (R2):** the long-term "same job → same
  component" answer — re-architect the 4 production admin LiveViews so the gallery composite and
  the real page share section-level components, structurally killing composite↔page drift. This
  is a multi-LiveView production refactor beyond Phase 205's "scaffold + snapshot-clean" charter;
  the duplicate+structural-assertion guard (D-09) buys most of the anti-drift value now. Surface
  as a candidate future phase if drift becomes a real maintenance cost.
- **Branding-workbench composite** (`board-cfg-branding`) — deferred (single-instance workbench,
  low composition risk); add later if the Branding page accrues composition complexity.
- Award-grade composite cleanup + MG-5/MG-6 desktop↔mobile content-equivalence assertions —
  Phase 208 (GROUP-02).
- The *scored* per-surface persona-JTBD remediation docs + binding actionable-verdict gate —
  Phase 209 (PAGE-01/PAGE-02), distinct from this phase's advisory diagnostic.

### Reviewed Todos (not folded)
- `2026-06-18-token-reference-completeness-ci-guard` (admin-token-reference completeness CI guard) —
  not folded; belongs to COMP-03 / Phase 207 (token-layer + `admin-token-reference.md` refresh).
- `2026-06-20-playwright-parallelization-per-shard-db` (CI perf, per-shard DB isolation) — not
  folded; CI-perf concern, out of this design-system phase's scope.
- `2026-06-20-runtime-auth-prefix-override`, `2026-06-20-mix-sigra-migrate-schema-helper`,
  `2026-06-21-app-css-comment-corruption-cleanup`, `2026-06-25-phase200-code-review-deferred`,
  `2026-06-19-uat-demo-dx-polish-nits`, OAuth-email/Oban todos — low relevance (installer /
  config / CSS / admin-session / DX / email), out of phase scope.
</deferred>
