# Phase 133: Suite Narrative + Ecosystem Diagram - Context

**Gathered:** 2026-05-27 (assumptions mode, `minimal_decisive` calibration)
**Status:** Ready for planning

<domain>
## Phase Boundary

Publish a single canonical narrative entry page that orients adopters to the szTheory
companion-library suite as a coherent picture, plus a discoverable README pointer and the
surgical `mix.exs` registration:

1. **`guides/introduction/suite-integration.md` (NX-01)** — canonical narrative entry
   point. ASCII ecosystem diagram + fan-out matrix (auth events × Sigra DB / telemetry /
   webhooks / Threadline forwarder / Mailglass) + "Sigra works fully standalone" banner
   + explicit Diminishing Returns Wall reference + cross-links to all six companion-lib
   recipes (Threadline, Mailglass, Accrue, Lockspire, Relyra, Rulestead).
2. **`README.md`** — one new row in the existing `## Topic map → guides` table at
   `README.md:139-160` pointing to the new narrative. No new H2 section.
3. **`mix.exs`** — register the new narrative under the existing `Introduction` group;
   add the four not-yet-shipped companion-lib basenames (`accrue.md`, `lockspire.md`,
   `relyra.md`, `rulestead.md`) to `skip_undefined_reference_warnings_on:` for the
   window between Phase 133 and Phase 134.

**Hard scope anchors (from ROADMAP.md / REQUIREMENTS.md / STATE.md / Phase 131-132
CONTEXTs, NOT re-litigated here):**

- Path is `guides/introduction/suite-integration.md` (in the existing `Introduction`
  ExDoc group, not the `Companion Libraries` group — see D-04).
- Banner text MUST match Phase 132's locked shape (`threadline.md:7`,
  `mailglass.md:7`) for stylistic consistency the user explicitly called out.
- Banned marketing phrases (apply across the whole page): "seamlessly," "just works,"
  "production-ready out of the box," "the recommended way."
- `validated_against:` + `last_validated:` shipped as HTML comments + a human-visible
  "Last validated:" line under the H1 (Phase 132 D-03/D-04 LOCKED — Earmark does not
  strip YAML, zero existing `guides/` files use YAML frontmatter).
- Phase 133 is **docs-only** except for the surgical `mix.exs` edit + the one-row
  `README.md` edit. No new library modules. No new tests.
- Diminishing Returns Wall is canonical in `.planning/MILESTONE-ARC.md:213-220`;
  adopter docs must NOT link into `.planning/`.
- Phase 134 ships the four missing recipes (Accrue, Lockspire, Relyra, Rulestead); the
  ROADMAP (line 161) explicitly permits 133‖134 parallelism.
- `mix docs --warnings-as-errors` MUST pass at end of phase — same gate that nearly
  blocked v1.28 PROOF-01 and that Phase 132 D-12 also locked.
</domain>

<decisions>
## Implementation Decisions

### Diagram Format & Layout (NX-01 success criterion #1)

- **D-01:** ASCII-only ecosystem diagram (no Mermaid alternative), using Unicode box
  glyphs (`┌─┐│└─┘` — NOT plain `+--+`) inside a fenced ```` ``` ```` code block. Ship
  a tightened version of the prototype already drafted in
  `.planning/research/ARCHITECTURE.md:204-222`. The README itself uses Mermaid for its
  hero diagrams (`README.md:39-54, 63-69`), but the narrative page lives downstream of
  the README and gets read in the `mix docs --formatters markdown` and llms.txt output
  surfaces where Mermaid renders as raw `graph TD` source.
- **D-02:** Caption the diagram with a one-sentence ARIA-flat description directly
  underneath (e.g. "Diagram: a host Phoenix app sits at the center; Sigra owns auth;
  Threadline / Mailglass / Accrue / Lockspire / Relyra / Rulestead are six optional
  satellites the host wires in.") so screen-reader users get equivalent semantics
  without parsing box glyphs.

### Fan-Out Matrix Shape (NX-01 success criterion #1)

- **D-03:** Rows = **curated representative subset of audit `action` strings**, NOT
  every `[:sigra, :*]` telemetry event and NOT every audit action. Specifically:
  - `auth.login.success`
  - `auth.login.failure`
  - `auth.password_reset.success`
  - `mfa.challenge.success`
  - `account.deletion_execute`
  - One "custom host-emitted" row: `billing.subscription.upgraded`
  Columns = `Sigra audit DB row` · `[:sigra, :audit, :log] telemetry` · `Sigra webhooks`
  · `Threadline forwarder` · `Mailglass`. Cells = ✓ / — / `(host)` / `n/a`. The
  `(host)` cell for Mailglass vs `auth.password_reset.success` captures the actual
  semantic — Mailglass receives the *email side-effect*, not the audit event itself —
  and inoculates against the common misread "Mailglass is an audit destination." The
  "custom host-emitted event" row demonstrates the matrix generalizes beyond Sigra's
  built-ins; that's the doctrinal point.

### ExDoc Group Placement & `mix.exs` Edit Shape

- **D-04:** Page lives at `guides/introduction/suite-integration.md` and slots into
  the existing **`Introduction`** group via the unchanged regex at `mix.exs:223`
  (`~r{guides/introduction/.?}`). NO `groups_for_extras:` edits. The
  `Companion Libraries` group at `mix.exs:226` is keyed on
  `guides/recipes/companion-libs/` and is correctly recipe-tier; the suite narrative
  is genuinely entry-tier (the *orientation* readers hit before diving into recipes).
- **D-05:** Single new `extras:` entry between current line 198 (last introduction
  cluster file) and line 199 (start of `flows/` cluster). Position-wise: append after
  the existing `upgrading-to-v1.1.md` entry, before the `flows/registration.md` entry.
- **D-06:** Add FOUR entries to `skip_undefined_reference_warnings_on:`
  (`mix.exs:160-174`) — `guides/recipes/companion-libs/accrue.md`, `lockspire.md`,
  `relyra.md`, `rulestead.md` — for the window between Phase 133 and Phase 134. The
  block already carries Phase 131 and Phase 132 transitional entries (lines 165-173);
  this precedent makes the addition zero-controversy. Phase 134's executor removes the
  four entries as part of landing the four recipes.

### Cross-Link Strategy for Not-Yet-Shipped Recipes

- **D-07:** Ship the narrative with LIVE relative cross-links to all six recipe pages
  including Accrue / Lockspire / Relyra / Rulestead (e.g.
  `../recipes/companion-libs/accrue.html`). Pair with D-06's
  `skip_undefined_reference_warnings_on:` entries to keep
  `mix docs --warnings-as-errors` green in the 133→134 window. Phase 134's executor
  removes the four suppressions in the same commit that lands the four recipes.
- **D-08:** Rejected alternatives and why:
  - "Coming in v1.29: see Phase 134" placeholders → leaks planning-artifact vocabulary
    into adopter docs (banned per PROJECT.md voice + Phase 132 voice register).
  - Defer 133 until 134 ships → loses the parallelism ROADMAP.md:161 explicitly
    permits.
  - Ship four stub recipe files → creates ghost files for Phase 134 to overwrite and
    risks them shipping to Hex if Phase 134 slips.

### README Pointer Shape

- **D-09:** ONE new row in the existing `## Topic map → guides` table at
  `README.md:139-160`, inserted as the **second row** (immediately below
  `First happy path`), framed as
  `| Companion library suite | [introduction/suite-integration.md](guides/introduction/suite-integration.md) |`.
  NO new H2 section, NO `Pick your lane` row addition, NO header-level change.
- **D-10:** Position-2 (above the existing 18 topic-map rows) is intentional —
  semantically the suite narrative is conceptual orientation, not topic-specific
  deep-dive; closer to "getting started" than to "registration." This satisfies
  ROADMAP.md:108 success criterion #1: "a reader landing on the README can follow a
  single link." Reverse risk (too quiet) is reversible with a one-line `Pick your
  lane` row addition in a follow-up commit.

### Page Length & Section Order

- **D-11:** Target length: **180–260 lines** (longer than Mailglass recipe ~130
  lines, shorter than `getting-started.md` ~318 lines). The narrative is broader than
  a recipe but should still respect the low-friction-on-the-happy-path principle.
- **D-12:** Section order (top to bottom):
  1. H1: `# Suite Integration`
  2. `<!-- last_validated: 2026-05-27 -->` HTML comment + visible "Last validated:"
     line directly under H1
  3. Standalone banner (full Phase 132 shape — see D-15)
  4. "What this is" — 2 paragraphs of orientation
  5. **ASCII ecosystem diagram** (D-01) + ARIA caption (D-02)
  6. "Who owns what" role table — 7 rows: Sigra core / Mailglass / Threadline /
     Accrue / Lockspire / Relyra / Rulestead. Each row links to its recipe page (D-07).
     This is the load-bearing section for ROADMAP.md:109 "no orphan pages."
  7. **Fan-out matrix** (D-03)
  8. "The Diminishing Returns Wall" subsection (D-13)
  9. "Where to next" — 6-bullet cross-links to the recipes
  10. Closing one-sentence banner echo (D-15)

### Diminishing Returns Wall Framing

- **D-13:** Quote `MILESTONE-ARC.md:215-220` **verbatim** as a 3-bullet `> blockquote`
  prefixed by ONE prose sentence ("Sigra owns identity, not policy, not billing, not
  aesthetics — see the **Diminishing Returns Wall**.") and followed by ONE prose
  sentence ("Each companion library above respects this boundary by owning the surface
  Sigra deliberately doesn't."). The 3 bullets to quote verbatim:
  - **Opinionated Authorization (RBAC / Zanzibar):** identity (`user_id`,
    `organization_id`) provided; the host owns *policy*.
  - **Billing & Subscription Integration:** webhook egress for identity-state sync,
    not billing logic.
  - **Frontend / UI Component Libraries:** functional HTML generated by
    `mix sigra.install`; no heavy CSS / React component library shipped.
- **D-14:** Do NOT link into `.planning/MILESTONE-ARC.md` from the narrative. The
  planning tree stays maintainer-private; the quoted text becomes first-class adopter
  content. Phase 136 verification MAY grep-assert byte-for-byte match against
  MILESTONE-ARC.md:215-220 if drift becomes a concern (cheap, deferrable).

### Standalone-Banner Placement

- **D-15:** **Full banner at top** (immediately under the validated-against HTML
  comment + H1 + last-validated line, mirroring `threadline.md:7` and `mailglass.md:7`
  EXACTLY — Phase 132 deliberately locked this shape "for consistency with the
  suite-narrative banner Phase 133 will ship") AND a **one-sentence echo at the very
  end of the page** ("**Reminder:** every integration above is opt-in; Sigra runs
  fully standalone without any of them."). NOT two full banners — top is doctrinal
  anchor, bottom is cognitive bookend. Without the end-echo, 200 lines describing 6
  integrations risks reading as "you need all six."
- **D-16:** Banner exact text (mirror of Phase 132): "**Sigra works fully standalone.**
  Threadline, Mailglass, Accrue, Lockspire, Relyra, and Rulestead are all optional
  integrations; Sigra ships without any of them, and removing the integration sections
  below returns Sigra to standalone operation with no further changes." Generalizes
  the Phase 132 "Threadline (or Mailglass) is an optional integration" framing to all
  six companions in the suite-narrative.

### `mix.exs` Surgical Edit Summary

- **D-17:** Three blocks of edits to `mix.exs`:
  1. ONE new `extras:` entry: `"guides/introduction/suite-integration.md"`, appended
     after line 198 (after `upgrading-to-v1.1.md`, before `flows/registration.md`).
  2. FOUR new `skip_undefined_reference_warnings_on:` entries (D-06) under a
     `# Phase 133: companion-lib recipes pending Phase 134` comment header for clarity.
  3. ZERO `groups_for_extras:` edits (D-04 — the existing `Introduction:` regex
     absorbs the new file).
- **D-18:** `mix docs --warnings-as-errors` MUST pass as the final pre-commit
  verification step. Mirrors Phase 132 D-12. Phase 136 PROOF-01 re-runs this at
  milestone close.

### Voice / Register / Banned-Phrase Discipline (NX-01 success criterion #3)

- **D-19:** Voice register: pragmatic + role-table-led + prerequisites-first (same
  register as `guides/recipes/companion-oauth-provider.md` and the Phase 132 recipes).
  Pre-commit grep-pass: `rg -i "seamlessly|just works|production-ready out of the box|the recommended way" guides/introduction/suite-integration.md`
  MUST return zero matches.

### Sequencing Within Phase

- **D-20:** Single sequential plan with four internal steps:
  1. Write `guides/introduction/suite-integration.md` end-to-end (banner → diagram →
     role-table → fan-out → DRW → cross-links → echo).
  2. Add the one row to `README.md:140` (Topic map table).
  3. Apply the three-block `mix.exs` edit (D-17).
  4. Run `mix docs --warnings-as-errors` + the banned-phrase grep (D-19) as the
     pre-commit verification gates. Commit.
- **D-21:** Do NOT parallelize via multiple plans — all four steps touch the same
  small file set (one new file + one README row + one mix.exs edit) and the
  verification gates run against the merged state. Throughput gain is zero on a
  docs-only phase; coordination cost would be nonzero.

### Claude's Discretion

- Exact prose voice within each section (within the banned-phrase guardrails). Mirror
  the existing `guides/introduction/getting-started.md` and `intermediate-production-path.md`
  register: declarative sentences, role-table summaries, code-block-paired bullet
  rationale.
- Whether the role-table is a 4-column (`Library` · `Owns` · `Optional` · `Recipe`)
  or a 3-column (`Library` · `Owns` · `Recipe`) — pick based on how it reads after
  the diagram.
- Whether the "What this is" section opens with a "TL;DR" callout box or just runs
  as plain prose. Pick whichever reads cleaner against the diagram immediately below.
- Exact phrasing of the role-table cells for each companion lib. Pin facts (e.g.
  "Threadline: audit row projection; idempotency by Sigra audit UUID + `occurred_at`")
  but voice is the planner's call.
- Whether the closing "Where to next" section is bullets or a small table. Default:
  bullets (lower visual weight after the role-table + fan-out matrix already
  established).
- The two prose sentences sandwiching the DRW blockquote (D-13) — the suggested
  framing is a starting point; reword for register without changing the load-bearing
  semantics.

### Folded Todos

None — no outstanding loose-notes todos crossed Phase 133's scope window. The
`SEED-011-ecosystem-integrations` seed backing v1.29 is already milestone-scoped
(STATE.md "Deferred Items" table line 54).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or
implementing.**

### Repo files — precedents Phase 133 must mirror and code Phase 133 pins against

- `/Users/jon/projects/sigra/guides/recipes/companion-libs/threadline.md` — Phase 132
  canary recipe; banner shape (line 7), validated-against HTML-comment form, section
  ordering — Phase 133 narrative must remain stylistically consistent.
- `/Users/jon/projects/sigra/guides/recipes/companion-libs/mailglass.md` — Phase 132
  companion recipe; identical banner shape (line 7); demonstrates the "Sigra ships
  no library-resident adapter" framing that the narrative reinforces.
- `/Users/jon/projects/sigra/guides/introduction/getting-started.md` — neighbor
  introduction-group page; voice register, section ordering, length envelope (318
  lines).
- `/Users/jon/projects/sigra/guides/introduction/intermediate-production-path.md` —
  neighbor introduction-group page; closest precedent for cross-linking from
  introduction into recipes + flows.
- `/Users/jon/projects/sigra/guides/introduction/installation.md` — neighbor
  introduction-group page; voice + table-of-prerequisites pattern.
- `/Users/jon/projects/sigra/guides/recipes/companion-oauth-provider.md` — template
  recipe (lines 1-52) — voice register and section ordering convention.
- `/Users/jon/projects/sigra/guides/flows/audit-logging.md` — canonical Sigra audit
  `action` strings (lines 36-51); fan-out matrix row labels pin against this list.
- `/Users/jon/projects/sigra/README.md` — Topic map table at lines 139-160; insertion
  point for the new pointer row (D-09).
- `/Users/jon/projects/sigra/mix.exs` — `skip_undefined_reference_warnings_on:` block
  (lines 160-174) for D-06 additions; `extras:` list (lines 180-221) for D-05 insertion
  after line 198; `groups_for_extras:` block (lines 222-229) — read-only confirmation
  D-04 needs no edits there.

### Planning artifacts

- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` — NX-01 (line 40); Out-of-Scope
  section (lines 65-73) — banned marketing phrases and "Sigra works fully standalone"
  banner mandate.
- `/Users/jon/projects/sigra/.planning/ROADMAP.md` — Phase 133 Goal + Depends-on +
  Success Criteria (lines 100-110); 133‖134 parallelism note (line 161).
- `/Users/jon/projects/sigra/.planning/MILESTONE-ARC.md` — Diminishing Returns Wall
  canonical text (lines 213-220) — D-13 quotes these three bullets verbatim.
- `/Users/jon/projects/sigra/.planning/STATE.md` — locked decisions block (lines
  66-77); `Adopted "extend test/example/"` framing for the role-table cell for
  reference example.
- `/Users/jon/projects/sigra/.planning/PROJECT.md` — v1.29 milestone Goal + Non-Goals
  + GSD preference (decisive defaulting).
- `/Users/jon/projects/sigra/.planning/METHODOLOGY.md` — Decisive Defaulting +
  Escalation Threshold + Discuss-Phase Default lenses applied in this CONTEXT.
- `/Users/jon/projects/sigra/.planning/research/ARCHITECTURE.md` — ASCII diagram
  prototype (lines 204-222) — D-01 ships a tightened version.
- `/Users/jon/projects/sigra/.planning/research/STACK.md` — Hex-version pins for the
  six companion libs (lines 110-130) verified 2026-05-27.
- `/Users/jon/projects/sigra/.planning/research/PITFALLS.md` — banned-marketing-phrase
  rationale.
- `/Users/jon/projects/sigra/.planning/phases/131-forwarder-behaviour-threadline-forwarder-library-scaffolding/131-CONTEXT.md`
  — LOCKED decisions Phase 133 inherits: forwarders config shape, source-of-truth
  doctrine (D-21), telemetry metadata extension (D-31).
- `/Users/jon/projects/sigra/.planning/phases/132-threadline-recipe-mailglass-cross-link-recipe/132-CONTEXT.md`
  — LOCKED decisions Phase 133 inherits: banner shape (D-08 / D-15-16 in 132), HTML-
  comment validated-against form (D-03/D-04 in 132), ExDoc `Companion Libraries` group
  (D-11 in 132), `skip_undefined_reference_warnings_on:` precedent (D-12 in 132 +
  mix.exs:170-173).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **ASCII diagram prototype:** `.planning/research/ARCHITECTURE.md:204-222` already
  drafts the canonical ecosystem diagram with Unicode box glyphs in a fenced code
  block — Phase 133 ships a tightened version, not a from-scratch redraw.
- **Banner template:** Phase 132's `threadline.md:7` and `mailglass.md:7` are the
  canonical banner shape; Phase 133 generalizes the "Threadline (or Mailglass) is an
  optional integration" framing to all six companions (D-16).
- **Recipe cross-link style:** Phase 132 established relative `../recipes/companion-libs/{name}.html`
  link form; the narrative's role-table + "Where to next" sections use the same form.
- **Audit action canonical list:** `guides/flows/audit-logging.md:36-51` publishes
  the canonical action-string list; D-03 fan-out matrix rows pin against this.
- **`skip_undefined_reference_warnings_on:` precedent:** `mix.exs:160-174` already
  carries Phase 131 hidden-helper entries (165-169) and Phase 132 recipe entries
  (172-173); D-06 adds four more for the 133→134 window.
- **README Topic map table:** `README.md:139-160` is the README's existing "everything
  else" surface; D-09 inserts ONE row at position 2.
- **ExDoc `Introduction:` regex:** `mix.exs:223` (`~r{guides/introduction/.?}`) already
  absorbs any new file under `guides/introduction/` — D-04 confirms zero group edits.

### Established Patterns

- **No YAML frontmatter in guides** (Phase 132 D-03/D-04 LOCKED): every existing file
  under `guides/` opens with a Markdown H1 directly. Phase 133 carries
  `validated_against:` + `last_validated:` as HTML comments + a human-readable
  "Last validated:" line under the H1.
- **No `.planning/` cross-links from adopter docs**: the planning tree is maintainer-
  private. D-14 quotes `MILESTONE-ARC.md:215-220` verbatim rather than linking. Phase
  132 followed the same discipline.
- **Pre-commit `mix docs --warnings-as-errors` verification gate**: Phase 132 D-12
  locked this pattern; nearly blocked v1.28 PROOF-01. D-18 reuses it.
- **Banned marketing phrase grep guard**: PITFALLS.md mandates pre-commit grep for
  the four banned phrases ("seamlessly," "just works," "production-ready out of the
  box," "the recommended way"). D-19 reuses it.

### Integration Points

- **`guides/introduction/suite-integration.md`** — Phase 133 creates this new file.
- **`README.md:140`** — Phase 133 inserts one new Topic map row.
- **`mix.exs:160-174`** — Phase 133 adds four `skip_undefined_reference_warnings_on:`
  entries (D-06).
- **`mix.exs:198-199`** — Phase 133 inserts one new `extras:` entry between
  `upgrading-to-v1.1.md` and `flows/registration.md`.
- **Phase 134 dependency:** Phase 133's narrative cross-links to four recipe files
  (Accrue/Lockspire/Relyra/Rulestead) that Phase 134 creates. Phase 134's executor
  removes the four `skip_undefined_reference_warnings_on:` entries (D-06) in the same
  commit that lands the four recipes.
- **Phase 132 dependency (already shipped):** Phase 133's role-table cells for
  Threadline and Mailglass cross-link to the Phase 132 recipes; the cross-links
  resolve today.
- **Phase 136 dependency:** Phase 136 PROOF-01 re-runs `mix docs --warnings-as-errors`
  at milestone close + may grep-assert MILESTONE-ARC.md:215-220 byte-for-byte match
  against the narrative's quoted DRW bullets (D-14).
</code_context>

<specifics>
## Specific Ideas

- **ASCII diagram tightening targets** (from `.planning/research/ARCHITECTURE.md:204-222`):
  - Keep the central Phoenix-app box visually distinct from the satellite boxes (heavier
    glyphs).
  - Label each satellite with its primary role in one word (e.g. "Threadline → audit",
    "Mailglass → email", "Accrue → seats", "Lockspire → OAuth-provider",
    "Relyra → SAML", "Rulestead → feature-flags").
  - Show the optional `[:sigra, :audit, :log]` telemetry tap as a labeled edge, not a
    separate box.
- **Role-table column shape (planner discretion within bounds):** 3-column
  (`Library` · `Owns` · `Recipe`) is the default; 4-column adds an `Optional` column.
  Default: 3-column — the banner already makes the optional point.
- **Role-table row order:** Sigra core (anchor row) → Threadline → Mailglass → Accrue
  → Lockspire → Relyra → Rulestead. Mirrors the order in REQUIREMENTS.md:31-36 +
  PROJECT.md:30-31 (Threadline first because it's the only library-code companion;
  Mailglass second because it's the only other already-shipped Phase 132 recipe).
- **Fan-out matrix cell legend** (place directly under the table):
  ```
  ✓     = Sigra fans this event into the named sink by default.
  (host) = Host code may opt into this sink (e.g. Mailglass receives email side-effects).
  —      = This sink does not receive this event.
  n/a    = This event is host-emitted; Sigra does not own it.
  ```
- **Banner exact text (D-16 final form):** "**Sigra works fully standalone.**
  Threadline, Mailglass, Accrue, Lockspire, Relyra, and Rulestead are all optional
  integrations; Sigra ships without any of them, and removing the integration sections
  below returns Sigra to standalone operation with no further changes."
- **End-echo exact text (D-15 final form):** "**Reminder:** every integration above
  is opt-in; Sigra runs fully standalone without any of them."
- **DRW prose sentences (D-13 default — planner may reword for register):**
  - Lead-in: "Sigra owns identity, not policy, not billing, not aesthetics — see the
    **Diminishing Returns Wall**."
  - Trailer: "Each companion library above respects this boundary by owning the
    surface Sigra deliberately doesn't."
- **README Topic map insertion (D-09 exact form):** new row 2 (between
  `First happy path` and `Upgrade notes`):
  ```markdown
  | Companion library suite | [introduction/suite-integration.md](guides/introduction/suite-integration.md) |
  ```
- **`mix.exs` extras insertion (D-05 exact position):** new line between current line
  198 (`"guides/introduction/upgrading-to-v1.1.md",`) and line 199
  (`"guides/flows/registration.md",`):
  ```elixir
  "guides/introduction/suite-integration.md",
  ```
- **`mix.exs` skip-warnings additions (D-06 exact entries):** appended to the block
  at lines 160-174 under a clear comment header:
  ```elixir
  # Phase 133: companion-lib recipes pending Phase 134 — remove these four
  # entries when accrue/lockspire/relyra/rulestead recipes land.
  "guides/recipes/companion-libs/accrue.md",
  "guides/recipes/companion-libs/lockspire.md",
  "guides/recipes/companion-libs/relyra.md",
  "guides/recipes/companion-libs/rulestead.md"
  ```
- **Pre-commit banned-phrase grep (D-19 exact command):**
  ```bash
  rg -i "seamlessly|just works|production-ready out of the box|the recommended way" guides/introduction/suite-integration.md
  ```
  MUST exit non-zero (no matches).
</specifics>

<deferred>
## Deferred Ideas

- **Mermaid version of the ecosystem diagram** — README's hero diagrams use Mermaid,
  but the narrative ships ASCII-only (D-01). Reopen only if a reviewer specifically
  asks for a Mermaid variant; cost of adding is one extra fenced block.
- **A `Pick your lane` row in README for the suite narrative** — D-09 picks the
  lighter-weight Topic map row. Escalation path: add a `Pick your lane` row in a
  follow-up commit if discoverability proves inadequate after release. One-line edit.
- **A dedicated "Suite Integration" ExDoc group** — D-04 rejects this (single-page
  groups read as broken nav). Reopen only if/when there's a second non-recipe suite-
  level doc; current count is one and projected to stay there for the rest of v1.29.
- **Cross-link from the narrative into `.planning/MILESTONE-ARC.md`** — explicitly
  rejected (D-14). The planning tree stays maintainer-private; quote the DRW bullets
  verbatim instead.
- **Recipe-contract test fixture** that walks `guides/introduction/suite-integration.md`
  + the six recipe files and asserts uniform section headings, banner presence, and
  banned-phrase absence — v1.29 future-requirements item (REQUIREMENTS.md lines 59-60);
  Phase 134 budget-permitting, otherwise post-v1.29. Phase 133 ships uniform sections
  by hand and Phase 136 PROOF-01 grep-asserts the banner text.
- **A grep-assert step in Phase 136 PROOF-01 that the DRW blockquote matches
  MILESTONE-ARC.md:215-220 byte-for-byte** — D-14 flags this as cheap and deferrable.
  Phase 133 does NOT add the assertion; Phase 136 may choose to.
- **Reciprocal cross-links from the Phase 132 recipes back to `suite-integration.html`**
  — `mailglass.md:129-130` already has a "See also" pointing up to
  `../introduction/suite-integration.html`; `threadline.md` does not yet. Phase 133
  MAY add a one-line "See also" addition to `threadline.md` as a same-PR touch-up;
  default is YES (low cost, completes the symmetry).
- **An expanded Diminishing Returns Wall section that walks each companion lib through
  its specific boundary** — D-13 keeps it to the canonical 3 bullets + 2 prose
  sentences. Reopen only if reviewers ask for more granularity; deferrable to a
  follow-up doc.
- **A "Roadmap" section in the narrative** showing the order companion-lib recipes
  landed — explicitly rejected; the narrative is timeless adopter orientation, not a
  release log. CHANGELOG.md owns the timeline.

### Reviewed Todos (not folded)

None reviewed this round — no outstanding loose-notes todos crossed Phase 133's
scope window (`gsd-sdk query list-todos` returns empty).
</deferred>
</content>
</invoke>