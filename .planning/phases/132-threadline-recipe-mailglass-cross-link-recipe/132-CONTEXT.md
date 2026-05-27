# Phase 132: Threadline Recipe + Mailglass Cross-Link Recipe - Context

**Gathered:** 2026-05-27 (assumptions mode, `minimal_decisive` calibration)
**Status:** Ready for planning

<domain>
## Phase Boundary

Publish two new docs under `guides/recipes/companion-libs/` (a NEW subdirectory) plus
the surgical `mix.exs` `extras:` + `groups_for_extras:` edit that registers them under
a new "Companion Libraries" ExDoc group:

1. **`guides/recipes/companion-libs/threadline.md` (RC-01)** — canary recipe. Adopters
   paste the literal `forwarders:` block Phase 131 froze, add
   `{:threadline, "~> 0.5"}`, run `mix deps.get`, and audit events materialize in
   their Threadline instance with NO library code edits beyond Phase 131.
2. **`guides/recipes/companion-libs/mailglass.md` (RC-02)** — 1-page recipe wiring
   Mailglass `~> 1.2` behind the existing `Sigra.Mailer` behaviour from the host app.
   Sigra ships NO library-resident Mailglass adapter and NO `--with-mailglass` flag.

**Hard scope anchors (from ROADMAP.md / REQUIREMENTS.md / STATE.md / Phase 131
CONTEXT.md, NOT re-litigated here):**

- Path is `guides/recipes/companion-libs/` (new subdir, not flat `guides/recipes/`).
- New ExDoc group name is "Companion Libraries".
- The Threadline recipe pins LITERALLY the config block Phase 131 froze
  (`lib/sigra/audit/forwarders/threadline.ex`, `lib/sigra/config.ex:793-820, 944-1000`).
- Mailglass is recipe-only — no library code edits, no `--with-mailglass` flag, no
  re-landing the orphaned Phase 111/114 adapter (STATE.md scope; STACK.md:14-23).
- Both recipes carry: `validated_against:` + `last_validated:` metadata, `mix.exs`
  snippet, "Failure modes" section, "Non-goals" section, "Sigra works fully standalone"
  banner.
- Banned marketing phrases: "seamlessly," "just works," "production-ready out of the
  box," "the recommended way."
- Phase 132 is DOCS-ONLY for the `lib/` tree EXCEPT for the surgical `mix.exs` edit.
  No new library modules. No new tests in `test/sigra/`. (Phase 136 verification will
  add a `mix docs --warnings-as-errors` gate over the new pages.)
</domain>

<decisions>
## Implementation Decisions

### Recipe Content Scope & Shape (RC-01, RC-02 success criterion #3)

- **D-01:** Both recipes follow the existing `guides/recipes/companion-oauth-provider.md`
  template, augmented with the four contract sections RC-01/RC-02 mandate. Section
  order: (1) banner ("Sigra works fully standalone"), (2) "What this is" + role/scope
  table, (3) Prerequisites, (4) `mix.exs` snippet, (5) Sigra-side config block
  (Threadline) OR Sigra-side mailer module (Mailglass), (6) Failure modes, (7)
  Non-goals, (8) See also (cross-links).
- **D-02:** Threadline recipe target length: ~150–220 lines (canary recipe, carries
  literal config block + idempotency/dispatch detail). Mailglass recipe target length:
  ~80–120 lines (1-page per ROADMAP.md:93 and STACK.md:186).

### Frontmatter Format

- **D-03:** Ship `validated_against:` + `last_validated:` as an HTML-comment block at
  the very top of each file, e.g.:
  ```html
  <!-- validated_against: threadline ~> 0.5 -->
  <!-- last_validated: 2026-05-27 -->
  ```
  Plus a human-visible "Validated against: `threadline ~> 0.5` as of 2026-05-27" line
  directly under the H1 so readers (not just bots / future Phase 134 recipe-contract
  fixtures) see it.
- **D-04:** Do NOT use YAML `---` frontmatter. ex_doc 0.40.1 uses Earmark, which does
  NOT strip YAML — `---` renders as a horizontal rule and `key: value` lines render as
  ugly paragraphs at the top of the rendered HTML. Zero existing guides under
  `guides/` use YAML frontmatter (grep-verified).

### Threadline Recipe — What the Recipe Shows on the Threadline Side (RC-01)

- **D-05:** Recipe shows the Sigra-side `forwarders:` config block PLUS the minimum
  Threadline-side bootstrap a fresh Threadline adopter must run themselves
  (`mix threadline.install` + `mix ecto.migrate` per Threadline 0.5.0 README) as
  PREREQUISITES.
- **D-06:** Recipe does NOT include `Threadline.record_action/2` call-site examples,
  `Threadline.Plug` wiring, or trigger generation (`mix threadline.gen.triggers`) —
  Sigra's forwarder owns `record_action/2` invocation
  (`lib/sigra/audit/forwarders/threadline.ex:290-307`). Showing it would duplicate
  Threadline's own docs and would violate the "Sigra does not claim sister-lib
  features in Sigra docs" Non-Goal (STACK.md:122).
- **D-07:** Recipe pins call-signature contract via prose, NOT via copied code:
  "Sigra invokes `Threadline.record_action/2` per
  `lib/sigra/audit/forwarders/threadline.ex:290-307`, verified against Threadline
  0.5.0." This keeps the recipe honest if Threadline rev's its API — recipe's
  `validated_against:` pin makes the version contract explicit.

### Mailglass Recipe — Wiring Pattern Shown (RC-02)

- **D-08:** Recipe demonstrates the host implementing `Sigra.Mailer`
  (`lib/sigra/mailer.ex:1-31`, `@callback deliver(to, subject, body)`) by delegating
  into a host-owned `MyApp.SigraAuthMailer` module that does
  `use Mailglass.Mailable, stream: :transactional` and pipes to `Mailglass.deliver/2`.
- **D-09:** Recipe is EXPLICIT that Mailglass sits ABOVE Swoosh (it is NOT a Swoosh
  adapter) — verified against `deps/mailglass/lib/mailglass.ex:7-11`. Recipe cross-links
  to existing v1.25 EMAIL-RAILS docs (`guides/flows/audit-logging.md` and the
  generated-host mailer override seam) so readers see Sigra's existing email rails
  posture is unchanged.
- **D-10:** Recipe REQUIRES `stream: :transactional`, NOT `:bulk`. Mailglass enforces
  `NoTrackingOnAuthStream` at compile time on `:transactional`
  (`deps/mailglass/lib/mailglass/mailable.ex:30-33`). This is the privacy/security-
  correct default for auth emails (password reset, confirmation, etc.) and aligns with
  CLAUDE.md's OWASP posture. Calling this out inoculates adopters against the worst
  failure mode (open/click pixels in password-reset emails).

### `mix.exs` ExDoc Registration — Surgical Edit Shape

- **D-11:** Three-block edit to `mix.exs:169-214`:
  1. Append two `extras:` entries: `"guides/recipes/companion-libs/threadline.md"` and
     `"guides/recipes/companion-libs/mailglass.md"`.
  2. Tighten the existing `Recipes: ~r{guides/recipes/.?}` regex (line 213) to
     `Recipes: ~r{guides/recipes/[^/]+\.md$}` so it does NOT greedy-match the new
     subdir files.
  3. Add a new `"Companion Libraries": ~r{guides/recipes/companion-libs/.?}` entry to
     `groups_for_extras:` (line 209-215). Place BEFORE the (now-tightened) `Recipes:`
     entry as belt-and-suspenders (ExDoc evaluates `groups_for_extras` regexes in
     declaration order; first match wins).
- **D-12:** `mix docs --warnings-as-errors` MUST pass on the final commit — this is
  the gate that nearly blocked v1.28 PROOF-01 (per STATE.md context). Phase 132's
  final step runs it as a pre-commit verification, even though Phase 136 PROOF-01
  re-runs it at milestone close.

### Failure Modes & Non-Goals Content (RC-01, RC-02 success criterion #3)

- **D-13:** **Threadline recipe — Failure Modes** (in this order):
  1. Threadline dep missing → `Sigra.Application.maybe_warn_missing_forwarder_deps/0`
     emits one-shot `Logger.warning` + zero forwarding (`lib/sigra/application.ex`
     boot helper added in Phase 131).
  2. `:async` dispatch + Oban absent at boot → raise (D-26 in Phase 131; explicit by
     design — silent degradation to `:sync` would mask misconfiguration).
  3. Threadline returns `{:error, %Ecto.Changeset{}}` → `[:sigra, :audit, :forward,
     :error]` telemetry with `reason: :schema_mismatch` (Threadline shipped breaking
     change, non-retryable per D-16 in Phase 131).
  4. Network / transient failure on `:async` path → bounded Oban retries
     (max_attempts: 5, exponential backoff) then permanent fail with telemetry.
  5. Operator caution: handler MUST NEVER raise to `:telemetry` (D-20 in Phase 131
     auto-detach landmine). Recipe surfaces this as an operator note, not adopter
     action.
- **D-14:** **Threadline recipe — Non-Goals:**
  1. Threadline does NOT replace the Sigra audit DB — Sigra audit row remains
     source-of-truth (D-21 in Phase 131); rolled-back transactions never forward.
  2. No `--with-threadline` install flag (zero precedent; per Phase 131 D-25, D-27).
  3. No recipe-shipped Threadline-side custom queries, dashboards, or trigger
     definitions — link to Threadline docs instead.
  4. No SLA on forwarder delivery — forwarder failures never roll back the originating
     auth operation; Threadline downtime never blocks login.
- **D-15:** **Mailglass recipe — Failure Modes:**
  1. Mailable wired on wrong stream (e.g. `:bulk`) → Mailglass `NoTrackingOnAuthStream`
     compile-time error (privacy guard).
  2. Mailglass adapter unconfigured / API key missing → `Sigra.Mailer.deliver/3`
     returns `{:error, _}` and the calling auth flow returns an error to the user
     (NOT silent failure).
  3. Mailglass + Oban backpressure → emails queue, auth flow returns success (Mailglass
     owns retry semantics; Sigra's email-rails async-delivery telemetry from v1.25
     EMAIL-RAILS still applies).
- **D-16:** **Mailglass recipe — Non-Goals:**
  1. Sigra does NOT ship a library-resident Mailglass adapter — orphaned Phase 111/114
     code is NOT recovered (per STATE.md deferred items + STACK.md:14-23). Cross-link
     to Phase 136 DOC-01 corrigendum once it lands.
  2. No `--with-mailglass` install flag.
  3. No Sigra-owned mailable templates for Mailglass — host owns rendering.

### Sequencing Within Phase

- **D-17:** Single sequential plan, three internal steps:
  1. Write `guides/recipes/companion-libs/threadline.md` (canary recipe — surfaces any
     block-shape drift from Phase 131 first).
  2. Write `guides/recipes/companion-libs/mailglass.md`.
  3. Apply the `mix.exs` registration edit (D-11) + run `mix docs --warnings-as-errors`
     as the verification gate (D-12) + commit.
- **D-18:** Do NOT parallelize via two plans — the `mix.exs` edit is one 3-block
  change that touches the registration for both recipes; parallel plans would race
  the same file. Throughput gain is zero on a docs-only phase.

### Claude's Discretion

- Exact prose voice within each section (within the banned-phrase guardrails). Mirror
  the existing `companion-oauth-provider.md` register: pragmatic, role-table-led,
  prerequisites-first.
- Whether the Threadline recipe includes an inline "How dispatch picks `:auto` vs
  `:async` vs `:sync`" callout box or just a sentence + link to the
  `Sigra.Audit.Forwarders` moduledoc. Planner picks based on how dense the page reads
  after the config block.
- Whether the Mailglass recipe shows ONE complete `MyApp.SigraAuthMailer` module or
  splits it into "behaviour impl" + "mailable" snippets. Pick whichever reads cleaner.
- Whether to add an "ASCII flow diagram" to the Threadline recipe (host audit event →
  Sigra telemetry → forwarder → Threadline row). The suite-narrative diagram lands in
  Phase 133 NX-01; deciding whether the Threadline recipe needs its own mini-diagram
  is a planner call. Default: skip — Phase 133 owns the diagram.
- Exact ExDoc `Recipes:` regex form. D-11's `~r{guides/recipes/[^/]+\.md$}` is the
  default; planner may pick a different precise form (e.g. negative lookahead) if
  Earmark/ExDoc behaves unexpectedly during `mix docs --warnings-as-errors`.

### Folded Todos

None — the two todos directly relevant to Phase 132
(`2026-05-08-write-threadline-integration-recipe.md` → RC-01, and Mailglass cross-link)
were already promoted into RC-01/RC-02 by the gsd-roadmapper at milestone open
(STATE.md "Deferred Items" table). No outstanding loose-notes todos crossed Phase 132's
scope window.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or
implementing.**

### Repo files — precedents Phase 132 must mirror and code Phase 132 pins against

- `/Users/jon/projects/sigra/guides/recipes/companion-oauth-provider.md` — template
  recipe (lines 1-52); section ordering and voice register.
- `/Users/jon/projects/sigra/guides/recipes/passkeys.md`,
  `/Users/jon/projects/sigra/guides/recipes/multi-tenant.md`,
  `/Users/jon/projects/sigra/guides/recipes/testing.md` — general recipe-style
  reference.
- `/Users/jon/projects/sigra/lib/sigra/audit/forwarders/threadline.ex` — Sigra-side
  Threadline forwarder shipped in Phase 131; recipe pins call-signature contract here
  (lines 290-307 for the `Threadline.record_action/2` call site).
- `/Users/jon/projects/sigra/lib/sigra/audit/forwarders.ex` — shared dispatcher and
  routing logic; recipe references `:auto`/`:async`/`:sync` semantics.
- `/Users/jon/projects/sigra/lib/sigra/audit/forwarder.ex` — `Sigra.Audit.Forwarder`
  behaviour (`@callback attach/1`); recipe mentions the custom-forwarder seam.
- `/Users/jon/projects/sigra/lib/sigra/audit/forwarders/noop.ex` — Noop fallback.
- `/Users/jon/projects/sigra/lib/sigra/workers/audit_forward.ex` — Oban worker shape;
  recipe references max_attempts and backoff curve.
- `/Users/jon/projects/sigra/lib/sigra/config.ex` — `audit: [forwarders: [...]]`
  schema (lines 793-820, `validate_forwarders/1` lines 944-1000). Recipe's literal
  config block MUST validate against this schema.
- `/Users/jon/projects/sigra/lib/sigra/application.ex` — `attach_forwarders/0` +
  `maybe_warn_missing_forwarder_deps/0` boot helpers added in Phase 131; recipe's
  Failure Modes section references these.
- `/Users/jon/projects/sigra/lib/sigra/audit.ex` — extended `[:sigra, :audit, :log]`
  metadata (`id` + `occurred_at` per D-31 in Phase 131); idempotency-key reference.
- `/Users/jon/projects/sigra/lib/sigra/mailer.ex` — `@callback deliver(to, subject,
  body)` shape Mailglass recipe wires against (lines 1-31).
- `/Users/jon/projects/sigra/lib/sigra/delivery.ex`,
  `/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex` — existing email-rails
  precedent the Mailglass recipe cross-links (v1.25 EMAIL-RAILS).
- `/Users/jon/projects/sigra/mix.exs` — `extras:` (lines 169-208) + `groups_for_extras:`
  (lines 209-215) for the surgical D-11 edit; `no_warn_undefined` (lines 65-87) already
  carries Threadline atoms from Phase 131.
- `/Users/jon/projects/sigra/deps/threadline/lib/threadline.ex` — Threadline 0.5.0
  `record_action/2` API surface (lines 13-62); recipe pins `validated_against:
  threadline ~> 0.5`.
- `/Users/jon/projects/sigra/deps/mailglass/lib/mailglass.ex` — Mailglass 1.0.x public
  surface; confirms Mailglass-above-Swoosh framing (lines 7-11).
- `/Users/jon/projects/sigra/deps/mailglass/lib/mailglass/mailable.ex` —
  `use Mailglass.Mailable, stream: :transactional` + `NoTrackingOnAuthStream`
  compile-time guard (lines 30-33).

### Planning artifacts

- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` — RC-01, RC-02 (lines 31-32)
  + Out-of-Scope section (lines 65-73).
- `/Users/jon/projects/sigra/.planning/ROADMAP.md` — Phase 132 Goal + Depends-on +
  Success Criteria (lines 84-96).
- `/Users/jon/projects/sigra/.planning/STATE.md` — milestone v1.29 status, deferred
  items table promoting todos into RC-01/RC-02, locked decisions block.
- `/Users/jon/projects/sigra/.planning/PROJECT.md` — v1.29 milestone Goal +
  Non-Goals + GSD preference (decisive defaulting).
- `/Users/jon/projects/sigra/.planning/METHODOLOGY.md` — Decisive Defaulting +
  Escalation Threshold + Discuss-Phase Default lenses applied in this CONTEXT.
- `/Users/jon/projects/sigra/.planning/research/SUMMARY.md` — locked decisions,
  Mailglass posture, recipe-only verdict (lines 31-37).
- `/Users/jon/projects/sigra/.planning/research/ARCHITECTURE.md` — Phase 132 detail
  (lines 162-280); ExDoc registration plan (lines 179-182); template framing for
  Mailglass cross-link (line 186).
- `/Users/jon/projects/sigra/.planning/research/STACK.md` — Mailglass honest-correction
  (lines 14-23), recipe table (lines 110-130), Hex versions verified 2026-05-27.
- `/Users/jon/projects/sigra/.planning/research/PITFALLS.md` — banned-marketing-phrase
  rationale, idempotency Pitfall 4.
- `/Users/jon/projects/sigra/.planning/phases/131-forwarder-behaviour-threadline-forwarder-library-scaffolding/131-CONTEXT.md`
  — LOCKED decisions Phase 132 inherits: D-05/D-06 forwarders config shape, D-26
  `:async`+no-Oban raise, D-21 source-of-truth doctrine, D-31 telemetry metadata
  extension.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Recipe template:** `guides/recipes/companion-oauth-provider.md` is the only
  existing companion-lib recipe; section ordering, role-table framing, "When not to
  use this pattern" pattern carry directly.
- **Recipe register:** `guides/recipes/*.md` set the prevailing voice — pragmatic,
  prerequisites-first, role tables, code blocks paired with bullet rationale, "See
  also" cross-links to flows + introduction guides.
- **Sigra-side forwarder code (Phase 131 shipped):** the entire
  `lib/sigra/audit/forwarders/` tree + `Sigra.Workers.AuditForward` +
  `Sigra.Application` boot helpers + `Sigra.Config` `:forwarders` schema validation —
  the Threadline recipe pins literally against this code.
- **`Sigra.Mailer` behaviour:** `lib/sigra/mailer.ex` is a 1-callback contract with
  zero Swoosh coupling — the Mailglass recipe wires against this exact shape, NOT
  against Swoosh's adapter contract.
- **ExDoc `groups_for_extras`:** `mix.exs:209-215` already groups Introduction /
  Reference / Flows / Recipes / Docs — Phase 132 surgically adds one "Companion
  Libraries" entry and tightens the existing `Recipes:` regex.

### Established Patterns

- **No YAML frontmatter in guides:** every existing file under `guides/` opens with a
  Markdown H1 directly, no `---` block. ex_doc 0.40.1 + Earmark do not strip YAML
  cleanly. Phase 132 carries `validated_against:` + `last_validated:` as HTML
  comments + a human-readable line under the H1.
- **Cross-link style:** existing recipes link via relative paths
  (`../flows/oauth.html`, `../introduction/upgrading-to-v1.8.html`). Companion-libs
  recipes follow the same `../flows/` and `../introduction/` style; cross-link to
  each other via `./threadline.html` / `./mailglass.html`.
- **Failure-mode framing:** Phase 131 telemetry shape
  (`[:sigra, :audit, :forward, :ok | :error]`) and worker cancel taxonomy (D-16) give
  the recipe concrete, observable failure paths to enumerate — not hypotheticals.

### Integration Points

- **`mix.exs:169-208` `extras:` list** — Phase 132 appends two entries.
- **`mix.exs:209-215` `groups_for_extras:` block** — Phase 132 tightens `Recipes:`
  regex and adds `"Companion Libraries":` entry.
- **`guides/recipes/` directory** — Phase 132 creates new
  `guides/recipes/companion-libs/` subdirectory and the two `.md` files within.
- **`mix docs --warnings-as-errors`** — verification gate at end of Phase 132's plan;
  Phase 136 PROOF-01 re-runs it at milestone close.
- **Phase 135 dependency:** the Threadline recipe's `forwarders:` block becomes the
  literal source the example app pins against in `test/example/lib/example/accounts.ex`.
- **Phase 136 dependency:** the Mailglass recipe pairs with DOC-01 corrigendum (v1.25
  EMAIL-RAILS narrative correction) — they cross-link, but DOC-01 is Phase 136 scope,
  not Phase 132.
</code_context>

<specifics>
## Specific Ideas

- **Banner text:** "**Sigra works fully standalone.** Threadline (or Mailglass) is an
  optional integration; Sigra ships without it, and removing the entry below returns
  Sigra to standalone operation with no further changes." Mirror this exact framing in
  both recipes for consistency with the suite-narrative banner Phase 133 will ship.
- **`validated_against:` pin form:** `threadline ~> 0.5` and `mailglass ~> 1.2` —
  matches the hex.pm-verified pins in `mix.exs` (Threadline already in
  `no_warn_undefined`) and STACK.md table (lines 110-130). `last_validated:` =
  ISO date of recipe authoring (e.g. `2026-05-27`).
- **Threadline recipe literal config block** — paste the canonical example from Phase
  131 CONTEXT.md (lines 51-65), updated only with realistic env-var names if needed:
  ```elixir
  audit: [
    audit_schema: MyApp.Accounts.AuditEvent,
    retention_days: 90,
    forwarders: [
      [
        module: Sigra.Audit.Forwarders.Threadline,
        dispatch: :auto,
        id: :default,
        endpoint: System.get_env("THREADLINE_ENDPOINT"),
        api_key: System.get_env("THREADLINE_API_KEY")
      ]
    ]
  ]
  ```
- **Mailglass recipe canonical shape** — host implements `Sigra.Mailer` by delegating
  to a `use Mailglass.Mailable, stream: :transactional` module. Explicit reminder that
  `:transactional` (not `:bulk`) is required for auth emails — Mailglass's
  `NoTrackingOnAuthStream` compile-time guard inoculates against the
  open/click-pixel-in-password-reset failure mode.
- **Cross-link target list:** Threadline recipe → `../flows/audit-logging.html`,
  Mailglass recipe → `../flows/oauth.html` / `../introduction/installation.html` and
  (once Phase 133 lands) `../introduction/suite-integration.html`. Phase 132 ships
  the cross-link list as-is; Phase 133's suite-narrative landing page is added
  reciprocally there, not retro-patched here.
- **Custom-forwarder seam mention:** Threadline recipe ends with a 2-sentence
  "Custom forwarders" subsection pointing at `Sigra.Audit.Forwarder` behaviour with
  the one-liner mention of Mox testing — mirrors the seam Phase 131 D-04 already
  documents.
</specifics>

<deferred>
## Deferred Ideas

- **Recipe-contract test fixtures** (walks `guides/recipes/companion-libs/*.md` and
  asserts required section headings + version pins + banner). v1.29 future
  requirements item — Phase 134 budget-permitting per STATE.md / REQUIREMENTS.md
  Future Requirements; otherwise post-v1.29.
- **Suite-narrative landing page** (`guides/introduction/suite-integration.md` + ASCII
  ecosystem diagram + fan-out matrix). NX-01, Phase 133 scope. The Threadline /
  Mailglass recipes will cross-link to it once it lands; Phase 132 does NOT block on
  its existence.
- **The other four companion-lib recipes** (Accrue, Lockspire, Relyra, Rulestead).
  RC-03..06, Phase 134 scope. They will pin against the template Phase 132 establishes.
- **DOC-01 corrigendum** (MILESTONES.md + PROJECT.md v1.25 EMAIL-RAILS narrative
  correction + CHANGELOG [Unreleased] entry). Phase 136 scope. Mailglass recipe
  cross-links to it but does not block.
- **Reference example wiring** (`test/example/lib/example/accounts.ex` adds the
  literal `forwarders:` block + the `test/example/test/example_web/threadline_forwarder_test.exs`).
  EX-01, Phase 135 scope. Pins literally against Phase 132's Threadline recipe.
- **`mix sigra.doctor` adopter-facing diagnostic** — referenced in v1.21 HARD-02
  narrative but never shipped. Out of v1.29 per STATE.md; would let the Mailglass
  recipe link to an adopter-runnable health-check command someday.
- **Library-resident Mailglass adapter recovery from orphaned wip branches** — STATE.md
  deferred item; current call is drop. Mailglass recipe Non-Goals explicitly states
  this.
- **An ASCII flow diagram inside the Threadline recipe.** Default decision: SKIP —
  Phase 133 NX-01 owns the suite-wide ecosystem diagram. Reopen only if planner finds
  the recipe reads dense without one.
- **A separate `sigra_threadline` Hex glue package** — ADR 001 deferred. Recipe
  Non-Goals references this only if/when it surfaces in adopter questions; Phase 132
  does not litigate it.

### Reviewed Todos (not folded)

None reviewed this round — todos relevant to Phase 132 were already promoted into
RC-01/RC-02 by gsd-roadmapper at milestone open (per STATE.md "Deferred Items" table).
</deferred>
