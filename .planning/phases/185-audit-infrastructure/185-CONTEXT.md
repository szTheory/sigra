# Phase 185: Audit Infrastructure - Context

**Gathered:** 2026-06-14 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the **audit instruments** for the v1.39 DS-COHERENCE fractal sweep — the tooling that
lets phases 186-192 grade and harden the admin design system without regressing. Specifically:

1. An **example-only `/admin/_design` gallery** LiveView that renders every admin component (13)
   and every meta-component group in every state, importing the real `Sigra.Admin.Components`
   (never bespoke markup), wrapped in the real admin shell.
2. An **`admin-design-{chromium,mobile,dark}` Playwright board-snapshot lane** (one
   element-scoped composite board PNG per component/group) + a second **empty
   `snapshot-allowlist-design`** + a designated **gallery canary board** + **axe**
   (`wcag2a`+`wcag2aa`, 0 violations) paired to each board.
3. A **quality-tier ledger** (`guides/reference/admin-quality-ledger.md`) + a merge-blocking
   **monotonic guard** (`scripts/ci/quality-ledger-monotonic.sh`).
4. The **ratified fractal scorecard rubric** (D1–D11 + level add-ons) committed as the
   re-evaluation instrument.

**In scope:** INFRA-01..06 — the gallery, the snapshot lane + allowlist/canary + axe, the
ledger + monotonic guard, the rubric. This phase builds *instruments*, not audit *findings*.

**Out of scope:** Actually auditing/improving tokens, components, groups, pages, or flows
(phases 186-191); changing any token *values* (reserved for Phase 186); new admin
features/screens/nav; adding a `phx_storybook` dependency; touching the generated auth UI.
Distribution/parity of `sigra_admin.css` was completed in Phase 184.
</domain>

<decisions>
## Implementation Decisions

### Gallery construction & route (INFRA-01)
- **D-01:** Build `/admin/_design` as a single **example-only** LiveView at
  `test/example/lib/example_web/live/admin/design_gallery_live.ex`, mounted in a **dev-only
  router scope** (mirror `ExampleWeb.Demo.CredentialsLive`'s `Application.compile_env(:example,
  :dev_routes)` gating so it compiles out in prod/test), wrapped in the real
  `{ExampleWeb.Layouts, :admin}` shell so the gallery is audited inside true chrome + theme
  toggle.
- **D-02:** The gallery **`import Sigra.Admin.Components`** and renders all 13 public component
  functions (`stat`, `stat_link`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`,
  `page_back`, `scope_ribbon`, `notice`, `notice_link`, `field_help`, `skeleton`, `audit_row`)
  plus each meta-component group, **never bespoke markup** — so the gallery cannot drift from
  what ships. Data-driven by assigns lists.
- **D-03:** Each component/group renders inside an **element-scoped board wrapper with a stable
  `id`** (e.g. `id="board-notice"`, `id="board-summary_chip"`) so Playwright captures
  element-scoped (not full-page) board PNGs.
- **D-04:** CONTRACT GUARD — the gallery LiveView + its route live **ONLY under `test/example/`**
  and are **never** added to `priv/templates/sigra.install/`. Add a guard (e.g. an ExUnit/CI
  check) asserting no `_design`/`design_gallery` artifact leaks into the installer template tree.

### Snapshot lane extension (INFRA-02)
- **D-05:** Add three projects `admin-design-{chromium,mobile,dark}` to
  `test/example/priv/playwright/playwright.config.ts`, cloning the existing
  `admin-checkpoints-{chromium,mobile,dark}` project shape (chromium = Desktop Chrome,
  mobile = iPhone 13, dark = Desktop Chrome + `colorScheme:'dark'`), matched to a new
  `tests/admin-design.spec.ts` via a spec regex and excluded from the `chromium`/`mobile`
  projects via `testIgnore`.
- **D-06:** Capture **one element-scoped composite "state-matrix board" PNG per
  component/group** via `expect(locator).toHaveScreenshot('<board>-...png', {...})` — NOT one
  PNG per state (keeps baselines bounded ~50 PNGs, diffs human-meaningful). Boards land at
  `admin-design.spec.ts-snapshots/<board>-admin-design-<project>.png` per the existing snapshot
  path template.
- **D-07:** Pair each board with the **already-wired** axe gate
  (`@axe-core/playwright` → `AxeBuilder({page}).withTags(['wcag2a','wcag2aa']).analyze()`,
  0 violations) — reuse the `assertNoAxeViolations` helper from `admin-checkpoints.spec.ts`.

### Allowlist / canary discipline (INFRA-03)
- **D-08:** Create a **second committed manifest** `test/example/priv/playwright/snapshot-allowlist-design`
  in steady-state **empty** (comments-only), same one-slug-per-line format as the existing
  `snapshot-allowlist`.
- **D-09:** Extend `scripts/ci/snapshot-canary-guard.sh` to recognize `-admin-design-*` slugs.
  The "one-line sed" claim is accurate: current `slug_of()` is a single
  `sed -E 's/-admin-checkpoints-(chromium|mobile|dark)\.png$//'`; add the design-suffix strip
  `s/-admin-design-(chromium|mobile|dark)\.png$//`. The guard already accepts
  `--base`/`--allowlist`/`--canary`/`SNAP_DIR`.
- **D-10:** Designate **one stable gallery board as the design canary** (analogous to the
  hardcoded `impersonation-banner` default canary on the checkpoints lane). The
  `snapshot_drift_guard` CI job and `snapshot-recapture-gate.sh` must both learn the design lane.

### Quality ledger format (INFRA-04)
- **D-11:** Author `guides/reference/admin-quality-ledger.md` as a **committed Markdown table**,
  one row per fractal-level item (each of 13 components = L1, each MG group = L2, each page = L3,
  each flow = L4), with columns: **item id · fractal level · achieved tier · evidence link**.
- **D-12:** Tier vocabulary (fixed by ROADMAP): **0 Drift** (fails axis) / **1 Ratified**
  (v1.34 contract bar) / **2 Award-grade** (emilkowal.ski-level micro-interaction, coherent copy,
  pixel-considered spacing). The tier cell MUST be a **machine-parseable fixed-column integer**
  (0/1/2) so the monotonic guard can extract old-vs-new tiers reliably. A re-run reads the
  current tier as the **floor** and re-scores.
- **D-13:** Place beside the existing `guides/reference/admin-ui-principles.md` and
  `admin-design-contract.md` (no existing ledger/scorecard file — net-new).

### Monotonic guard script (INFRA-05)
- **D-14:** Write `scripts/ci/quality-ledger-monotonic.sh` mirroring `snapshot-canary-guard.sh`
  conventions: `set -euo pipefail`, `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"`,
  a `--base` flag, a `fail()` helper, exit 1 on violation / exit 2 on usage error.
- **D-15:** It compares the ledger's **per-cell tier integers** between the base ref
  (`git -C "$ROOT" show "$BASE:guides/reference/admin-quality-ledger.md"`) and the working tree,
  failing if **any cell's tier decreased**. Compare per-cell — NOT whole-file text (else benign
  evidence-link edits trip it, or a reordered-table regression slips through).
- **D-16:** Wire as a new **`quality_ledger_monotonic`** CI job added to the `ci-gate`
  aggregator's `needs:` list + lane loop (+ matching env var), reusing the existing base-ref
  resolution pattern (PR → `origin/${base_ref}`, push → `HEAD~1`). Merge-blocking.

### Scorecard rubric artifact (INFRA-06)
- **D-17:** Commit the ratified fractal scorecard rubric as a **standalone** file
  `guides/reference/admin-fractal-scorecard.md` (NOT embedded in the ledger or contract) so
  phases 187-192 re-runs have one fixed grading anchor.
- **D-18:** Content is fixed by the kickoff plan / ROADMAP — shared **D1–D11** dimensions
  (each scored Pass/Fail/N-A with one-line evidence) + per-level add-ons (Component / Group /
  Page / Flow). D1 Brand color · D2 Brand type · D3 Spacing/radius/shadow · D4 Light/Dark/System
  · D5 Contrast (WCAG AA) · D6 Motion quality · D7 Interaction states · D8 Mobile-first
  responsive · D9 IA/least-surprise · D10 Microcopy · D11 A11y semantics. Cross-reference
  `admin-design-contract.md` for dimension definitions where they already exist.

### Claude's Discretion (planner resolves — both below escalation threshold)
- **MG-N catalog → real-markup mapping.** The meta-component catalog (MG-1 metric/summary strip,
  MG-2 filter panel + applied-chip row + clear-all, MG-3 task-card grid, MG-4 alarm notice band,
  MG-5 audit feed + pagination + desktop-table/mobile-card swap, …) is named in the kickoff plan
  but the groups are **defined for the first time in this gallery** by mirroring composed markup
  from the real lib-owned admin pages (`Sigra.Admin.Live.IndexLive`, `OrganizationLive`,
  `UsersIndexLive`, `UserShowLive`, `AuditIndexLive`, `AuditUserLive`). The exact
  MG-N → page-region mapping is the planner's call.
- **Guard refactor vs. second invocation.** Whether to (a) parameterize
  `snapshot-canary-guard.sh` to loop over both lanes, or (b) invoke it a second time with
  `SNAP_DIR`/`--allowlist`/`--canary` overrides + the suffix-pattern generalization. Pure
  implementation detail.
- Exact spec/board naming, board count per component, and which board is the design canary.
- Exact ExUnit/CI mechanism for the D-04 "no gallery in installer template" contract guard.

### Folded Todos
None — `todo.match-phase 185` returned 0 matches.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

Kickoff + milestone:
- `~/.claude/plans/design-system-stress-test-serialized-candy.md` — approved milestone plan;
  sections B (gallery), C (idempotency model), D (gallery snapshot strategy), "The fractal
  scorecard rubric" (D1–D11 + add-ons + tiers), and the meta-component catalog (MG-1..MG-N)
- `.planning/ROADMAP.md` — Phase 185 detail + success criteria; fractal-level phase map (186-192)
- `.planning/REQUIREMENTS.md` — INFRA-01..06
- `.planning/METHODOLOGY.md` — Decisive Defaulting / escalation threshold lenses
- `.planning/phases/184-distribution-parity/184-CONTEXT.md` — upstream `sg-*` CSS distribution
  decisions (the gallery renders styled because Phase 184 shipped `sigra_admin.css`)

Reusable harness assets (verified to exist):
- `scripts/ci/snapshot-canary-guard.sh` — empty-allowlist visual idempotency guard;
  `slug_of()` sed at ~lines 53-55; flags `--base`/`--allowlist`/`--allow`/`--canary`/`--require-all`;
  `SNAP_DIR` env-overridable (~line 17); default canary `impersonation-banner` (~line 20)
- `scripts/ci/snapshot-recapture-gate.sh` — deliberate baseline recapture gate (must learn design lane)
- `test/example/priv/playwright/snapshot-allowlist` — existing empty allowlist (format reference)
- `test/example/priv/playwright/playwright.config.ts` — project defs (`admin-checkpoints-*` at
  ~lines 131-138 for dark/`colorScheme`), snapshot path template (~lines 60-61)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — board/element-scoping pattern,
  axe wiring (`@axe-core/playwright` import + `assertNoAxeViolations` ~lines 2,114-126),
  viewport-only capture convention (~lines 139-147)

Gallery import target + contract anchor:
- `lib/sigra/admin/components.ex` — the 13 public component functions (stat_link/stat/task_card/
  summary_chip/applied_chip/empty_state/page_back/scope_ribbon/notice/notice_link/field_help/
  skeleton/audit_row)
- `test/sigra/admin/components_test.exs` — byte-golden ExUnit (11 strict literal-string goldens;
  "D-13: NO mneme/snapshot library"); the contract anchor the gallery must NOT become a second
  source of truth for
- `test/example/lib/example_web/live/demo/credentials_live.ex` — example-only dev-gated LiveView
  precedent for D-01
- `test/example/lib/example_web/router.ex` — admin routes (~lines 250-294), `dev_routes` scope
- Lib-owned admin pages for MG mapping: `Sigra.Admin.Live.IndexLive`, `OrganizationLive`,
  `UsersIndexLive`, `UserShowLive`, `AuditIndexLive`, `AuditUserLive`

CI:
- `.github/workflows/ci.yml` — `snapshot_drift_guard` job (~lines 1095-1114), base-ref resolution
  (~lines 1102-1112), `generated_admin_playwright_smoke`, the `ci-gate` aggregator (`needs:`
  ~lines 1119-1128, lane loop ~lines 1145-1154), Playwright run step (~lines 806-822)

Ledger/rubric home:
- `guides/reference/admin-design-contract.md`, `guides/reference/admin-ui-principles.md` — siblings
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The entire `admin-checkpoints-{chromium,mobile,dark}` Playwright project trio + axe wiring +
  element-scoped board capture is the direct, proven template for the `admin-design-*` lane.
- `snapshot-canary-guard.sh` already supports `--base`/`--allowlist`/`--canary`/`SNAP_DIR` — the
  design lane is an extension (one sed suffix + a second allowlist/invocation), not a rebuild.
- `snapshot-recapture-gate.sh` already exists for deliberate baseline recapture.
- `Sigra.Admin.Components` (13 functions) is stable and byte-golden-guarded by
  `components_test.exs` — the gallery imports it directly so it can never drift.
- `ExampleWeb.Demo.CredentialsLive` is the example-only dev-gated LiveView precedent (compiles
  out of prod/test) for the gallery route.

### Established Patterns
- Snapshot path template `{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}` →
  boards become `<board>-admin-design-<project>.png`.
- Empty-allowlist discipline: steady-state allowlist is comments-only; intended visual deltas
  declare their slug; the canary board guards the harness itself.
- Merge-blocking guards follow the `snapshot-canary-guard.sh` shape: `set -euo pipefail`, `ROOT`
  derivation, `--base` flag, `git show "$BASE:<path>"` vs working tree, exit 1/2.
- The `ci-gate` aggregator job is the single merge-blocking gate; new lanes register in its
  `needs:` + loop + env.
- Admin pages are lib-owned (`Sigra.Admin.Live.*`); example-only audit surfaces are example-owned
  and dev-gated.

### Integration Points
- `playwright.config.ts` — add 3 projects + spec regex + `testIgnore`.
- `snapshot-canary-guard.sh` — `slug_of()` design-suffix strip; design-lane invocation.
- `snapshot-recapture-gate.sh` — learn the design snapshot dir/slugs.
- `ci.yml` — add design board run step + `quality_ledger_monotonic` lane to `ci-gate`.
- `test/example/.../router.ex` — dev-only `/admin/_design` route.
- `guides/reference/` — new `admin-quality-ledger.md` + `admin-fractal-scorecard.md`.
- `scripts/ci/` — new `quality-ledger-monotonic.sh`.

### Integration Points — Contract anchors NOT to disturb
- `components_test.exs` byte-goldens stay the single source of truth for component markup; the
  gallery is an audit *view*, never a second contract.
</code_context>

<specifics>
## Specific Ideas

- "Only move forward, never regress" is the milestone's core promise — the ledger + monotonic
  guard is the qualitative analog of the pixel canary. Tier cells MUST be machine-parseable so a
  no-op re-run is auto-green and any tier decrease is structurally un-mergeable.
- Board strategy is deliberately **one composite state-matrix board per component/group**, not
  one PNG per state — bounds baselines (~50 PNGs, comparable to the existing 24) and keeps diffs
  human-meaningful.
- The gallery is rendered inside the **real `admin_shell`** (true chrome + theme toggle) so it's
  audited as it actually appears, not in a stripped harness.
</specifics>

<deferred>
## Deferred Ideas

- Actual fractal audits + quality improvements (tokens L0 → components L1 → groups L2 → pages L3
  → flows L4) — phases 186-191; this phase only builds the instruments.
- Retroactively byte-guarding/de-staling the example `sigra_auth.css` copy (the auth-side wart
  surfaced in Phase 184) — out of scope; future maintenance `/gsd-quick` if desired.

### Reviewed Todos (not folded)
None — `todo.match-phase 185` returned 0 matches.
</deferred>
