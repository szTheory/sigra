# Phase 144: README Evaluator Lane & Docs/Proof - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver three documentation artifacts that complete the v1.31 DEMO-SHOWCASE milestone:

1. **DOC-01** — Replace `test/example/README.md` with an evaluator "Try it locally" lane
   (prerequisites, Docker one-liner, one-command spin-up, credentials table with all 6
   personas, rough-edge callouts for dave/frank, /demo/credentials and /dev/mailbox links).

2. **DOC-02** — Write `guides/introduction/demo-showcase.md` with 4 embedded screenshots
   from Phase 143, feature-organized sections, wired into ExDoc extras via `mix.exs` assets
   config + extras list. Requires creating `guides/assets/` and adding `:assets` to docs config.

3. **DOC-03** — File `144-VERIFICATION.md` with 6 proof gates: full test suite, dep-off CI
   lane, `mix setup` from clean state (explicit ecto.drop), screenshots committed, screenshots
   referenced in guide, `mix docs --warnings-as-errors`. Also add one pointer line to
   `docs/ga-evidence.md` under "Where to read next".

**In scope:** `test/example/README.md`, `guides/introduction/demo-showcase.md`, `guides/assets/`
(new dir + 4 PNG copies), `mix.exs` docs config (`:assets` key + extras list entry),
`docs/ga-evidence.md` (one pointer line), `144-VERIFICATION.md`.

**Out of scope:** Any changes to `lib/sigra/`, new LiveView code, test code, seeds, Playwright specs.
</domain>

<decisions>
## Implementation Decisions

### README — test/example/README.md (DOC-01)

- **D-01:** **Replace entirely** — the Phoenix scaffold boilerplate ("Ready to run in
  production? Check our deployment guides", "Learn more: Official website...") signals
  "generic unfinished template", actively undermining Sigra's positioning. No top auth
  library retains scaffold boilerplate in their example apps. Remove it all.

- **D-02:** **Three-sentence framing at top** — answer "what is this and why should I care"
  before any setup steps. Pattern: (1) Vaultr is a showcase Phoenix app demonstrating Sigra's
  auth features — link `[Sigra](https://hexdocs.pm/sigra)` in the framing; (2) list the 6
  feature categories briefly; (3) one sentence on the one-command spin-up.

- **D-03:** **Docker one-liner included** as an alternative to a local Postgres install.
  Postgres is the #1 silent abandonment cause for evaluators — the one-liner removes the
  blocker without requiring explanation of how to install Postgres.

- **D-04:** **Credentials table in the README itself** (not just at /demo/credentials).
  Evaluators read the README before running anything. The in-app cheat-sheet is a
  convenience reference; the README table is the discovery surface. Both must exist.
  Credentials table uses actual passwords from `personas.ex` (public-by-design):

  | Email | Password | Feature demonstrated |
  | admin@demo.sigra.dev | DemoAdmin1!SecurePass | Platform admin, TOTP MFA, passkey, multi-org |
  | alice@demo.sigra.dev | AliceDemoPass1! | Standard confirmed user |
  | bob@demo.sigra.dev | BobDemoPass1!Beta | TOTP MFA, org owner |
  | carol@demo.sigra.dev | CarolDemoPass1!Github | OAuth / GitHub identity |
  | dave@demo.sigra.dev | DaveDemoPass1!Locked | Locked account |
  | frank@demo.sigra.dev | FrankDemoPass1!Deleted | Scheduled deletion pending |

- **D-05:** **Rough-edge callouts include explicit trigger instructions** — not just "Dave is
  locked." The callout must tell the evaluator HOW to see the behavior:
  - Dave: explain failed login count is at the limit; try wrong password to see
    enumeration-resistant response; unlock via /admin/users as admin
  - Frank: explain scheduled_deletion_at is set; account is still active; inspect via
    /admin/users as admin

- **D-06:** **Two Sigra hexdocs links**: one in the framing block at the top (inline link on
  "Sigra"), and a "Learn more about Sigra" section at the bottom (replaces Phoenix "Learn more").
  The bottom section links to Getting Started guide, full documentation hexdocs, and the
  demo-showcase guide. This is the conversion path from "I saw the demo" to "I want this."

- **D-07:** **/dev/mailbox and /demo/credentials mentioned explicitly** in a "Dev tools" section
  with full localhost URLs. Email flows (confirmation, password reset, magic links) appear
  broken to evaluators if /dev/mailbox isn't mentioned.

### Guide — guides/introduction/demo-showcase.md (DOC-02)

- **D-08:** **All 4 screenshots embedded** — each shows a categorically different UI surface:
  - `demo-credentials-demo-showcase-chromium.png` — the evaluator's entry point / cheat-sheet
  - `admin-user-detail-demo-showcase-chromium.png` — MFA + passkey detail for admin persona
  - `admin-user-list-demo-showcase-chromium.png` — all 6 personas visible in admin panel
  - `audit-explorer-demo-showcase-chromium.png` — audit log with ≥6 distinct event types
  
  Total is ~385KB — negligible. Dropping any two would eliminate either the cheat-sheet
  entry point or the audit log (Sigra's differentiating feature).

- **D-09:** **Feature-organized sections (not step-by-step numbered tutorial)** — the guide is
  a guided tour for evaluators who want to see Sigra in action, not a recipe for building
  something. Numbered steps across 6 sections punish non-linear readers who skip to what
  they care about (e.g., "does it handle locked accounts?"). Feature sections enable this.
  Numbered steps WITHIN each section are fine.

- **D-10:** **Screenshot leads each section** (payoff before explanation). The screenshot
  anchors the reader visually before the prose explanation — matches the Phoenix "Up and
  Running" pattern where the screenshot is the payoff, not a mid-explanation interruption.

- **D-11:** **Section structure** (canonical):
  ```
  # Demo Showcase — Vaultr Example App
  [2-sentence orientation: Vaultr is Sigra's seeded showcase; what you'll see]

  ## Running the Demo
  [cd test/example && mix setup && mix phx.server; link to README for prerequisites]

  ## Credentials Cheat-Sheet
  [SCREENSHOT: demo-credentials] — /demo/credentials as the evaluator's reference tab

  ## Admin: Platform-Admin View
  [SCREENSHOT: admin-user-detail] — TOTP + passkey detail
  [SCREENSHOT: admin-user-list] — 6 personas in admin users list

  ## Audit Log
  [SCREENSHOT: audit-explorer] — /admin/audit, ≥6 event types

  ## Rough Edges: Locked and Scheduled-Deletion Accounts
  Dave (lockout, enumeration-resistant) + Frank (scheduled deletion countdown)

  ## OAuth Identity
  Carol's seeded GitHub identity row (honest: live flow needs real GitHub credentials)

  ## What's Next
  [Links: Installation, Getting Started, MFA guide]
  ```

- **D-12:** **ExDoc image path solution** — ExDoc cannot serve images from paths outside
  the build tree without explicit configuration. Use the `:assets` map config:
  1. Create `guides/assets/` directory
  2. Copy the 4 PNG screenshots there (committed in git — no alias needed for this milestone)
  3. Add `assets: %{"guides/assets" => "assets"}` to the `docs/0` function in `mix.exs`
  4. Reference in guide markdown as `assets/filename.png` (no leading slash, no relative `../`)
  5. Always include descriptive alt text (ExDoc renders HTML + Markdown formatters)

- **D-13:** **`guides/introduction/demo-showcase.md` added to `extras` list in `mix.exs`**,
  positioned at the end of the Introduction section entries (after `suite-integration.md`).
  The existing `groups_for_extras` regex `~r{guides/introduction/.?}` already covers it —
  no new group needed.

- **D-14:** **Carol's OAuth section is honest** — the seeded GitHub identity row is display-only
  (visible in admin detail); the live OAuth flow requires real GitHub credentials. Say so
  explicitly. Never imply the OAuth flow works end-to-end in the demo.

- **D-15:** **Persona coverage** — feature all 6 but not equally:
  - Admin: full section (happy-path + admin features + MFA + passkey)
  - Alice: briefly mentioned as the "standard confirmed user" baseline (may be implicit in Alice's note)
  - Bob: covered implicitly via TOTP discussion (TOTP is also demonstrated by admin)
  - Carol: brief callout section (OAuth, honest about live credentials)
  - Dave + Frank: grouped "Rough Edges" section with explicit trigger instructions

### Proof Bundle — 144-VERIFICATION.md (DOC-03)

- **D-16:** **New `144-VERIFICATION.md` as primary artifact** (Option A), following Phase
  140/136 format with YAML frontmatter (`phase / verified / status / score / overrides_applied`).
  The file lives in `.planning/phases/144-readme-evaluator-lane-docs-proof/` (planning-internal,
  not shipped to Hexdocs). Verbatim gate output recorded, no assumed-green results.

- **D-17:** **Six gates for DOC-03**:
  1. **Full suite** — `mix test` exits 0 with 0 failures (record test count verbatim)
  2. **Dep-off lane** — `mix deps.unlock/clean threadline` → compile `--warnings-as-errors`
     → `mix test --exclude requires_threadline --no-deps-check` → restore lock (record all
     sub-steps; must exit 0 with `requires_threadline` tests excluded, 0 non-excluded failures)
  3. **Clean-state `mix setup`** — `cd test/example && mix ecto.drop && mix ecto.create
     && mix ecto.migrate && mix run priv/repo/seeds.exs` (explicit `ecto.drop` first — clean
     state cannot be proven without dropping existing tables; record each sub-step separately)
  4. **Screenshots committed** — `ls -la test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/*.png`
     (4 PNGs must exist; record file listing verbatim)
  5. **Screenshots referenced in guide** — `grep -r "demo-showcase-chromium" guides/introduction/demo-showcase.md`
     (must match all 4 image references; separate from file existence gate)
  6. **ExDoc clean** — `mix docs --warnings-as-errors` exits 0 (guide wired in extras,
     no broken image refs or undefined references; record exit code verbatim)

- **D-18:** **`docs/ga-evidence.md` gets one pointer line** under the existing "Where to read
  next" section — e.g., `- [v1.31 DEMO-SHOWCASE proof bundle (planning-internal)](path-to-144-VERIFICATION.md)`.
  No new section header, no verbatim gate output, no milestone summary. `ga-evidence.md` is
  a public-facing Hexdocs router; maintainer gate logs belong in the planning-internal artifact.

### Claude's Discretion

- Exact prose wording in the guide sections — the section structure (D-11) is locked but
  the explanatory sentences within sections are Claude's call
- Whether Alice's "standard confirmed user" gets an explicit subsection or is handled via
  an intro paragraph before the Admin section
- Ordering of the "What's Next" links in both README and guide
- Minor table/markup formatting choices within the README credentials table
- Whether the `mix.exs` docs alias approach (copy screenshots before `mix docs`) is added
  as a convenience, or just committed copies are used (D-12 says committed copies for
  simplicity — alias is optional)
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope
- `.planning/ROADMAP.md` — Phase 144 goal + Success Criteria (SC#1–SC#3); DOC-01/DOC-02/DOC-03
- `.planning/REQUIREMENTS.md` — DOC-01, DOC-02, DOC-03 acceptance criteria (lines covering Phase 144)

### Persona data (credentials table and guide content)
- `test/example/lib/example/demo/personas.ex` — `Personas.all/0` with all 6 persona maps
  including confirmed emails and public-by-design passwords; single source of truth for
  credentials table content

### ExDoc configuration (guide wiring)
- `mix.exs` (`:156-243`) — `docs/0` function: `extras` list, `groups_for_extras`, `formatters`;
  add `assets: %{"guides/assets" => "assets"}` and `"guides/introduction/demo-showcase.md"` to extras
- `guides/introduction/` — existing guide pages; `demo-showcase.md` goes at the end of this dir

### Screenshots (DOC-02 guide content)
- `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/demo-credentials-demo-showcase-chromium.png`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-detail-demo-showcase-chromium.png`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-list-demo-showcase-chromium.png`
- `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/audit-explorer-demo-showcase-chromium.png`

### Proof bundle precedents (DOC-03 VERIFICATION.md format)
- `.planning/phases/140-deprecation-hygiene-verification-docs-close/140-VERIFICATION.md` — canonical
  format: YAML frontmatter, numbered gate rows with verbatim output
- `.planning/phases/140-deprecation-hygiene-verification-docs-close/140-03-PLAN.md` — gate
  command patterns for full suite, dep-off lane, `mix docs --warnings-as-errors`

### ga-evidence.md (pointer line only)
- `docs/ga-evidence.md` — "Where to read next" section gets one new pointer line; no other changes

### Prior phase context
- `.planning/phases/143-playwright-demo-spec-screenshots/143-CONTEXT.md` — screenshot decisions
  (D-08 through D-10: slugs, tolerances, snapshot dir naming convention)
- `.planning/phases/142-dev-credentials-page-app-framing/142-CONTEXT.md` — D-08 (app name
  "Vaultr"), D-03 (testid contract with email-local-part key)
- `.planning/phases/141-seed-data-layer/141-CONTEXT.md` — D-10 (API-token surface deferred),
  persona idempotency decisions, `@demo.sigra.dev` domain invariant
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Example.Demo.Personas.all/0` — all 6 persona maps with `:email` and `:password` fields;
  credentials table in README must be read from this source (do not invent or paraphrase passwords)
- Phase 143 screenshot baselines — all 4 PNGs already committed and verified against CI
- Phase 140 `140-VERIFICATION.md` — copy-paste the YAML frontmatter schema and gate table format

### Established Patterns
- ExDoc extras must be registered in `mix.exs` `extras` list AND `groups_for_extras` — adding
  just the file to guides/ without registering it means it silently won't appear on Hexdocs
  (D-10 from Phase 140 documents this footgun explicitly)
- `groups_for_extras: [Introduction: ~r{guides/introduction/.?}]` already captures
  `guides/introduction/demo-showcase.md` — no new group needed
- VERIFICATION.md format: `phase` / `verified` / `status` / `score` / `overrides_applied` YAML
  frontmatter; gate rows are "Gate N — [name]: [command] → [verbatim output] → PASS/FAIL"
- Dep-off lane gate: unlock → clean → compile `--warnings-as-errors` → test `--exclude requires_threadline --no-deps-check` → restore; all sub-steps in order

### Integration Points
- `mix.exs` docs config: add `assets: %{"guides/assets" => "assets"}` key and new extras entry
- `guides/assets/` (new): receives copied screenshots; 4 PNG files committed in git
- `docs/ga-evidence.md` "Where to read next": one new bullet line pointing to 144-VERIFICATION.md
- `test/example/README.md`: full replacement (not append)
</code_context>

<specifics>
## Specific Ideas

- README framing line 1 must link `[Sigra](https://hexdocs.pm/sigra)` inline — the conversion
  path from demo to library starts with that link
- Docker one-liner container name: `vaultr-postgres` (matches the app name, avoids colliding
  with the existing `sigra-test-postgres` container documented in CLAUDE.md)
- VERIFICATION.md Gate 3 must explicitly `mix ecto.drop` before `mix ecto.create` — running
  `mix setup` on an already-migrated DB does not prove clean-state; the gate only counts if
  tables are dropped first
- Guide alt text pattern: describe what the screenshot shows ("Credentials cheat-sheet showing
  all six demo persona emails and passwords") — ExDoc renders HTML + Markdown formatters
- Screenshot in guide referenced as `assets/filename.png` (no leading slash) — this is the
  ExDoc `:assets` copy convention; `../guides/assets/filename.png` or absolute paths do not work
</specifics>

<deferred>
## Deferred Ideas

- `mix docs` pre-step alias to copy screenshots from snapshot dir to `guides/assets/` — D-12
  says committed copies are simpler for this milestone; the alias is a nice-to-have for future
  maintainability (avoids stale committed copies) but is out of scope here
- Mobile/dark variants of demo-showcase screenshots — Phase 143 only captured chromium desktop
  baselines; mobile variants are post-milestone polish
- Alice's explicit narrative section — if agent finds it cleaner to fold Alice's baseline into
  the orientation paragraph, that's acceptable; a full "## Happy Path: Alice" section is nice
  but not required by success criteria
</deferred>

---

*Phase: 144-README Evaluator Lane & Docs/Proof*
*Context gathered: 2026-05-30*
