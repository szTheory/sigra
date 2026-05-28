# Phase 134: Recipe-Only Companion Libraries - Context

**Gathered:** 2026-05-28 (assumptions mode, `minimal_decisive` calibration)
**Status:** Ready for planning

<domain>
## Phase Boundary

Publish exactly **four** recipe-only companion-lib docs under
`guides/recipes/companion-libs/` so the suite-narrative cross-links (shipped in Phase 133)
land on real recipes, plus the symmetric `mix.exs` cleanup of the four
`skip_undefined_reference_warnings_on:` entries Phase 133 pre-registered:

1. **`guides/recipes/companion-libs/accrue.md` (RC-03)** — seat-limit gating + lifecycle
   integration via the existing Sigra hook seams against the `Accrue.Auth` behaviour.
   Sigra owns NO seat-limit logic.
2. **`guides/recipes/companion-libs/lockspire.md` (RC-04)** — concrete recipe (mix.exs
   deps + AccountResolver stub + walkthrough) that respects ADR 001 (NO `sigra_lockspire`
   glue Hex package) and cross-references the existing
   `guides/recipes/companion-oauth-provider.md` architectural framing.
3. **`guides/recipes/companion-libs/relyra.md` (RC-05)** — SAML 2.0 SP wiring guidance
   citing the v1.27 ENT-SSO OIDC-vs-SAML decision matrix; explicit that Sigra does NOT
   own SAML metadata storage.
4. **`guides/recipes/companion-libs/rulestead.md` (RC-06)** — `Rulestead.enabled?` from a
   Sigra-protected controller + a `RulesteadPolicy` derived from `current_scope`. Sigra
   ships NO opinionated authorization.

**Hard scope anchors (from ROADMAP.md / REQUIREMENTS.md / STATE.md / Phase 131-133
CONTEXTs, NOT re-litigated here):**

- Path is `guides/recipes/companion-libs/` (the subdir Phase 132 created); all four files
  land under the existing `"Companion Libraries"` ExDoc group whose regex
  (`~r{guides/recipes/companion-libs/.?}` at `mix.exs:233`) already absorbs them — NO
  `groups_for_extras:` edits (Phase 132 D-11 LOCKED).
- All four recipes match the Phase 132 LOCKED template: HTML-comment `validated_against:`
  + `last_validated:` block + visible "Validated against: ... as of <date>" line under
  the H1; "Sigra works fully standalone" banner (full at top + reminder echo at bottom);
  `mix.exs` snippet; **Failure modes** section; **Non-goals** section; **See also**
  cross-links. NO YAML frontmatter (Earmark renders it as a horizontal rule — Phase 132
  D-04).
- Banner exact text mirrors `threadline.md:7` / `mailglass.md:7`; generalized per-lib
  ("X is an optional integration; Sigra ships without it, and removing the entry below
  returns Sigra to standalone operation with no further changes.").
- Banned marketing phrases (whole-page grep guard): "seamlessly," "just works,"
  "production-ready out of the box," "the recommended way."
- Recipes pin contract by line-range reference, NOT by copying sister-lib code
  (Phase 132 D-07). `validated_against:` pins to the hex.pm-verified line from
  STACK.md:31-36 (2026-05-27): `accrue ~> 1.2`, `lockspire ~> 1.2`, `relyra ~> 1.2`,
  `rulestead ~> 0.1`.
- Phase 134 is DOCS-ONLY for the `lib/` tree. The only non-`guides/` edit is the surgical
  two-block `mix.exs` change (add four `extras:` entries; remove four
  `skip_undefined_reference_warnings_on:` entries + their Phase 133 comment header).
- `mix docs --warnings-as-errors` MUST pass at end of phase — the gate that nearly blocked
  v1.28 PROOF-01 (Phase 132 D-12, Phase 133 D-18). Phase 136 PROOF-01 re-runs it at close.
- No library-resident adapters, no `--with-*` install flags, no glue Hex packages
  (Diminishing Returns Wall; REQUIREMENTS.md Out-of-Scope lines 65-73).
</domain>

<decisions>
## Implementation Decisions

### Per-Recipe Content Scope & Shape (RC-03..RC-06; Phase 132 D-07 pin-by-line-range pattern)

#### Accrue — `accrue.md` (RC-03)

- **D-01:** Pin the contract by line-range reference to BOTH Sigra seams:
  1. `lib/sigra/organizations/callbacks.ex:17-18, 38-48` — the `before_add_member/4` +
     `after_member_remove/2` behaviour, the ACTUAL seat-limit gating seam (the callbacks
     table at the top of that file literally lists `before_add_member/4` as "Check seat
     limits").
  2. `lib/sigra/hooks.ex:1-103` — the user-lifecycle registry
     (`on_register / on_password_change / on_email_change / on_delete`), the
     lifecycle-integration seam REQUIREMENTS.md RC-03 names by path.
  Recipe makes the split explicit: organizations callbacks = seat gating on membership
  add/remove; user-lifecycle hooks = subscription cleanup on user delete.
- **D-02:** Host implements the `Accrue.Auth` behaviour once
  (`/Users/jon/projects/accrue/accrue/lib/accrue/auth.ex:41-49` — 5 required + 2 optional
  callbacks: `current_user/1`, `require_admin_plug/0`, `user_schema/0`, `log_audit/2`,
  `actor_id/1`, optional `step_up_challenge/2`, `verify_step_up/3`), configured via
  `config :accrue, :auth_adapter, MyApp.Accrue.Auth`. Seat-gating example wired through
  the `before_add_member/4` callback the generated host module overrides.
- **D-03:** The `log_audit/2` case cross-links to `lib/sigra/audit.ex` and the existing
  `threadline.md` recipe — Sigra's `AuditEvent` row stays source-of-truth; Accrue's
  `log_audit/2` is a consumer of identity-event side-effects, NOT a destination swap.
- **D-04:** Recipe does NOT invent Accrue-shaped webhook payloads. Per FEATURES.md AF-07,
  v1.22 webhooks ship the canonical Sigra event contract; Accrue subscribes to that.
  Recipe links to `guides/flows/audit-logging.html` and shows event-type filtering on
  existing webhook subscriptions, not a bespoke Accrue webhook shape.

#### Lockspire — `lockspire.md` (RC-04)

- **D-05:** Concrete paste-and-go recipe that COMPLEMENTS (does not duplicate) the
  architectural `guides/recipes/companion-oauth-provider.md` (52 lines, v1.7). Shows:
  (1) `{:lockspire, "~> 1.2"}` in host `mix.exs` (host-only — NOT in Sigra's deps),
  (2) `mix lockspire.install --sigra-host` to generate the AccountResolver stub (already
  named in `companion-oauth-provider.md:38`), (3) the AccountResolver behaviour contract,
  (4) the Sigra-side field the stub reads.
- **D-06:** Pin the AccountResolver contract by line-range reference to
  `/Users/jon/projects/lockspire/lib/lockspire/host/account_resolver.ex:14-39` — 5 required
  callbacks (`resolve_current_account/2`, `resolve_account/2`, `build_claims/2`,
  `redirect_for_login/2`, `verify_backchannel_user_code/3`) + 1 optional
  (`redirect_for_logout/2`). Planner verifies the exact callback list against the
  installed Lockspire `~> 1.2` surface before writing (it post-dates the v1.7 recipe).
- **D-07:** Pin the Sigra scope read to `conn.assigns.current_scope.user` per
  `lib/sigra/scope.ex:18-25` (the `Sigra.Scope.build/3` shape). Lockspire docs already
  cite "Sigra-shaped account resolution" as canonical (STACK.md:32).
- **D-08:** Non-goals section quotes the ADR 001 deferral trigger from
  `.planning/decisions/001-defer-sigra-lockspire-glue-package.md` (no `sigra_lockspire`
  glue package until both APIs stable AND a real adopter trigger fires). Cross-links to
  `companion-oauth-provider.md` for the architecture-level framing.

#### Relyra — `relyra.md` (RC-05)

- **D-09:** **Pin the Sigra session-mint to `Sigra.Auth.create_session/4`
  (`lib/sigra/auth.ex:1284`) — NOT `Sigra.Session.create_session/3`.** STACK.md:111
  misnames the function; `lib/sigra/session.ex` has no `create_session` at all
  (grep-verified). This is the single most consequential pin in the phase: the wrong
  reference ships an `UndefinedFunctionError` to adopters and would fail
  `mix docs --warnings-as-errors`.
- **D-10:** Pin the Relyra hand-off contract by reference: `Relyra.start_login/3` +
  `Relyra.consume_response/3` (`/Users/jon/projects/relyra/lib/relyra.ex:28-29` + moduledoc
  lines 9-11). After the ACS callback returns the authenticated subject, the host mints a
  Sigra session via D-09's `Sigra.Auth.create_session/4`.
- **D-11:** Inline-quote the OIDC-vs-SAML decision matrix — rephrased for adopter voice,
  NOT copied with planning vocabulary (Phase 133 D-08). The canonical matrix is in
  FEATURES.md:48 ("Relyra = SAML 2.0 SP; complements ENT-SSO's OIDC-first enterprise
  login") + AF-02:76. Cross-link the v1.27 ENT-SSO OIDC-via-Assent surface
  (`lib/sigra/enterprise_connections.ex`, `lib/sigra/enterprise_routing.ex`,
  `lib/sigra/oauth/enterprise_reconciliation.ex`) and contrast it with Relyra's SAML path.
- **D-12:** Non-goals enumerate what stays with Relyra: SAML metadata storage, signing
  keys, IdP-initiated SLO, certificate rotation (AF-02). Sigra owns only the org-scoped
  session it issues after the assertion. `validated_against: relyra ~> 1.2` (STACK.md:33,
  hex.pm-verified 2026-05-27 — trumps any sister-repo local README that may be ahead of
  Hex).

#### Rulestead — `rulestead.md` (RC-06)

- **D-13:** Pin `validated_against: rulestead ~> 0.1` (the actual published Hex line per
  STACK.md:34 + `/Users/jon/projects/rulestead/README.md:97`). Surface the
  `1.0.0 narrative GA vs ~> 0.1 Hex line` mismatch as ONE neutral Prerequisites sentence —
  not dramatized.
- **D-14:** Show `Rulestead.enabled?` invoked from a Sigra-protected controller +
  `MyApp.RulesteadPolicy` derived from `current_scope`, with the
  `rulestead_admin "/admin/flags", policy: MyApp.RulesteadPolicy` mount per README:111.
  **Planner must verify which Rulestead surface matches adopter expectations before
  writing:** the low-level `@spec enabled?(map(), Context.t() | keyword() | map())` at
  `/Users/jon/projects/rulestead/rulestead/lib/rulestead.ex:1189-1192` vs the README
  convenience example `Rulestead.enabled?("flag", conn)` at line ~111. Pin whichever is
  the canonical adopter entry point; cite both line ranges so the recipe is honest about
  the layering.
- **D-15:** Pin the `current_scope` fields a `RulesteadPolicy` reads to FEATURES.md:26
  (`:user`, `:active_organization`, `:active_organization_id`, `:membership`, `:role`,
  `:auth_method`, `:impersonating_from`, `:token_id`, `:id`) AND the `Sigra.Scope.build/3`
  shape at `lib/sigra/scope.ex:16-25`. Reference the Rulestead `Admin.Authorizer` contract
  (`/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/authorizer.ex`) for the
  policy callback shape. Non-goals: Sigra does not own flag storage, evaluator, or admin
  UI (AF-03).

### `mix.exs` Sequencing — Atomic Add + Remove in One Commit

- **D-16:** ONE atomic `mix.exs` two-block edit lands with the four recipes:
  1. Append four `extras:` entries after `"guides/recipes/companion-libs/mailglass.md"`
     (`mix.exs:227`): `accrue.md`, `lockspire.md`, `relyra.md`, `rulestead.md`.
  2. Remove the four `skip_undefined_reference_warnings_on:` entries Phase 133 added at
     `mix.exs:176-179` AND their Phase 133 comment header at `mix.exs:174-175` (no orphan
     comment).
  ZERO `groups_for_extras:` edits — the `"Companion Libraries"` regex at `mix.exs:233`
  already absorbs the four files (Phase 132 D-11 LOCKED).
- **D-17:** The add+remove MUST be atomic (one commit, or a commit set where no
  intermediate state ships). Phase 133 D-06/D-07 mandated this: splitting opens a
  `mix docs --warnings-as-errors` failure window — recipes cross-link each other
  (`./accrue.html`, etc.), so ExDoc only resolves them cleanly once all four exist AND the
  suppressions are removed.

### Sequencing Within Phase

- **D-18:** Single sequential plan, six internal steps: (1) write `accrue.md` (natural
  canary — most Sigra-side surface to verify), (2) write `lockspire.md`, (3) write
  `relyra.md`, (4) write `rulestead.md`, (5) apply the `mix.exs` two-block edit (D-16),
  (6) run `mix docs --warnings-as-errors` + the banned-phrase grep as pre-commit gates.
- **D-19:** Do NOT parallelize into four plans. The four recipes are independent files but
  the `mix.exs` edit is one block change touching the registration for all four; parallel
  plans would race the same file with zero throughput gain on a docs-only phase (Phase 132
  D-18, Phase 133 D-21 both LOCKED this shape).
- **D-20:** Banned-phrase grep guard (pre-commit, MUST return zero matches):
  ```bash
  rg -i "seamlessly|just works|production-ready out of the box|the recommended way" \
    guides/recipes/companion-libs/accrue.md \
    guides/recipes/companion-libs/lockspire.md \
    guides/recipes/companion-libs/relyra.md \
    guides/recipes/companion-libs/rulestead.md
  ```

### Claude's Discretion

- Exact prose voice within each section (within the banned-phrase guardrails). Mirror the
  `threadline.md` / `mailglass.md` / `companion-oauth-provider.md` register: pragmatic,
  role-table-led, prerequisites-first.
- Per-recipe length envelope. `threadline.md` is 158 lines (the most code-deep recipe);
  `mailglass.md` is 130; `companion-oauth-provider.md` is 52. The four Phase 134 recipes
  are recipe-tier, not canary-tier — target ~100-160 lines each; the planner sets exact
  length per how much contract each recipe must pin.
- Whether each recipe opens with a "What this is" role table (like `threadline.md` /
  `mailglass.md`) or a short orientation paragraph. Default: role table for consistency.
- For Rulestead (D-14): which of the two Rulestead surfaces is canonical — this is a
  verify-at-write-time call, not a pre-decided fork. Cite both; pin the adopter-facing one.
- Whether the Relyra recipe includes a small "OIDC vs SAML: which path" callout box or a
  prose paragraph + table. Default: a compact 2-row decision table (OIDC-via-Assent in
  Sigra / SAML-via-Relyra out-of-Sigra).
- Cross-link target lists per recipe (each recipe → `../introduction/suite-integration.html`
  + its sibling recipes + the relevant `../flows/` page). Planner sets the exact "See also"
  list; the suite narrative already cross-links TO these four (Phase 133 D-07).

### Folded Todos

The four todos directly relevant to Phase 134
(`2026-05-08-write-accrue-integration-recipe.md` → RC-03,
`2026-05-08-write-lockspire-integration-recipe.md` → RC-04,
`2026-05-08-write-relyra-integration-recipe.md` → RC-05,
`2026-05-08-write-rulestead-integration-recipe.md` → RC-06) were already promoted into
RC-03..RC-06 by the gsd-roadmapper at milestone open (STATE.md "Deferred Items" table,
lines 49-52). `gsd-sdk query todo.match-phase 134` returns empty — no outstanding
loose-notes todos cross Phase 134's scope window.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or
implementing.**

### Repo files — Sigra seams the four recipes pin against

- `/Users/jon/projects/sigra/guides/recipes/companion-libs/threadline.md` (158 lines) —
  Phase 132 canary recipe; the LOCKED template shape (banner line 7, validated-against
  HTML-comment form lines 1-2 + visible line 5, section ordering, Failure modes /
  Non-goals / See also). Mirror EXACTLY for stylistic consistency.
- `/Users/jon/projects/sigra/guides/recipes/companion-libs/mailglass.md` (130 lines) —
  Phase 132 companion recipe; identical banner shape; the "Sigra ships no library-resident
  adapter" framing the recipe-only posture reinforces.
- `/Users/jon/projects/sigra/guides/recipes/companion-oauth-provider.md` (52 lines) — v1.7
  Lockspire ARCHITECTURAL recipe; `lockspire.md` cross-links to this and does NOT duplicate
  it. Names `mix lockspire.install --sigra-host` + the AccountResolver seam.
- `/Users/jon/projects/sigra/guides/introduction/suite-integration.md` — Phase 133 suite
  narrative; the role-table cells the four recipes mirror; cross-links TO all four recipes.
- `/Users/jon/projects/sigra/lib/sigra/organizations/callbacks.ex:17-18, 38-48` — Accrue
  seat-limit gating seam (`before_add_member/4` + `after_member_remove/2`).
- `/Users/jon/projects/sigra/lib/sigra/organizations.ex:730-865` — the `before_add_member`
  fire-site (membership lifecycle).
- `/Users/jon/projects/sigra/lib/sigra/hooks.ex:1-103` — user-lifecycle hook registry
  (`on_register / on_password_change / on_email_change / on_delete`); Accrue cleanup seam.
- `/Users/jon/projects/sigra/lib/sigra/audit.ex` — `AuditEvent` source-of-truth + audit
  telemetry; Accrue `log_audit/2` bridge reference.
- `/Users/jon/projects/sigra/lib/sigra/scope.ex:16-25` — `Sigra.Scope.build/3`; the
  `current_scope` fields Lockspire (`.user`) and Rulestead (`RulesteadPolicy`) read.
- `/Users/jon/projects/sigra/lib/sigra/auth.ex:1284` — `Sigra.Auth.create_session/4`
  (`config, user, metadata, opts \\ []`); the session-mint seam the Relyra recipe pins to.
  **STACK.md:111's `Sigra.Session.create_session/3` is WRONG — `lib/sigra/session.ex` has
  no such function.**
- `/Users/jon/projects/sigra/lib/sigra/enterprise_connections.ex`,
  `/Users/jon/projects/sigra/lib/sigra/enterprise_routing.ex`,
  `/Users/jon/projects/sigra/lib/sigra/oauth/enterprise_reconciliation.ex` — v1.27 ENT-SSO
  OIDC-via-Assent surface the Relyra recipe contrasts against SAML.
- `/Users/jon/projects/sigra/mix.exs:160-179` — `skip_undefined_reference_warnings_on:`
  block; remove the four Phase 134 entries (lines 176-179) + the Phase 133 comment header
  (lines 174-175).
- `/Users/jon/projects/sigra/mix.exs:225-236` — `extras:` (append four entries after line
  227) + `groups_for_extras:` (line 233 `"Companion Libraries"` regex — read-only, NO
  edits).

### Sister-repo behaviour contracts (local checkouts — pin by line-range reference)

- `/Users/jon/projects/accrue/accrue/lib/accrue/auth.ex:41-49` — `Accrue.Auth` behaviour
  (5 required + 2 optional callbacks).
- `/Users/jon/projects/lockspire/lib/lockspire/host/account_resolver.ex:14-39` —
  Lockspire AccountResolver behaviour (5 required + 1 optional). Planner re-verifies the
  callback list against the installed `~> 1.2` surface.
- `/Users/jon/projects/relyra/lib/relyra.ex:9-11, 28-29` — `Relyra.start_login/3` +
  `Relyra.consume_response/3` ACS hand-off contract.
- `/Users/jon/projects/rulestead/rulestead/lib/rulestead.ex:1189-1192` — `enabled?/2`
  `@spec`; `/Users/jon/projects/rulestead/README.md:90-150` — `~> 0.1` Hex pin +
  `RulesteadPolicy` mount example;
  `/Users/jon/projects/rulestead/rulestead/lib/rulestead/admin/authorizer.ex` — policy
  callback shape.

### Planning artifacts

- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` — RC-03..RC-06 (lines 33-36) +
  Out-of-Scope (lines 65-73) + Future Requirements recipe-contract test fixture (lines
  59-60).
- `/Users/jon/projects/sigra/.planning/ROADMAP.md` — Phase 134 Goal + Depends-on +
  Success Criteria (lines 116-130); 133‖134 parallelism note (line 163).
- `/Users/jon/projects/sigra/.planning/STATE.md` — locked decisions block (lines 66-77,
  incl. ADR 001 deferral and recipe-only Mailglass posture); deferred-items todo promotion
  table (lines 49-52).
- `/Users/jon/projects/sigra/.planning/PROJECT.md` — v1.29 milestone Goal + Non-Goals +
  GSD decisive-defaulting preference.
- `/Users/jon/projects/sigra/.planning/METHODOLOGY.md` — Decisive Defaulting +
  Discuss-Phase Default lenses applied in this CONTEXT.
- `/Users/jon/projects/sigra/.planning/decisions/001-defer-sigra-lockspire-glue-package.md`
  — ADR 001; Lockspire recipe quotes the deferral trigger in Non-goals.
- `/Users/jon/projects/sigra/.planning/research/STACK.md:31-36, 108-131` — companion-lib
  row table + recipe table + Hex pins (verified hex.pm 2026-05-27). NOTE: line 111 misnames
  the Sigra session function — use `Sigra.Auth.create_session/4` (D-09).
- `/Users/jon/projects/sigra/.planning/research/ARCHITECTURE.md:162-187, 286-291` — recipes
  for non-adapter companion libs; Lockspire concrete-vs-architectural split.
- `/Users/jon/projects/sigra/.planning/research/FEATURES.md:26, 46-49, 75-78` — `current_scope`
  field bus, F-RC-02..F-RC-05 recipe scopes, AF-01..AF-03 anti-features + non-goals.
- `/Users/jon/projects/sigra/.planning/research/PITFALLS.md` — banned-marketing-phrase
  rationale; recipe-rot mitigation (validated-against pins).
- `/Users/jon/projects/sigra/.planning/phases/132-threadline-recipe-mailglass-cross-link-recipe/132-CONTEXT.md`
  — LOCKED template decisions Phase 134 inherits: D-01 section order, D-03/D-04 frontmatter
  form, D-07 pin-by-line-range, D-11 ExDoc `Companion Libraries` group, D-12
  `mix docs --warnings-as-errors` gate.
- `/Users/jon/projects/sigra/.planning/phases/133-suite-narrative-ecosystem-diagram/133-CONTEXT.md`
  — LOCKED decisions Phase 134 inherits: D-06 (the four `skip_undefined_reference_warnings_on:`
  entries Phase 134 removes), D-07 (atomic removal in the same commit that lands the
  recipes), D-16 (banner exact text), D-19 (banned-phrase grep command).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Recipe template (Phase 132 shipped):** `guides/recipes/companion-libs/threadline.md`
  + `mailglass.md` are the canonical shape — banner at line 7, validated-against HTML
  comments at lines 1-2 + visible line 5, "What this is" role table, Prerequisites,
  `mix.exs` snippet, contract pinned by prose reference, Failure modes, Non-goals, See
  also. The four Phase 134 recipes are structural copies with companion-specific content.
- **Lockspire architectural recipe (v1.7 shipped):** `guides/recipes/companion-oauth-provider.md`
  (52 lines) already covers Lockspire at the pattern level and names the install task +
  AccountResolver seam — the new `lockspire.md` extends it concretely, cross-links back,
  does NOT duplicate.
- **Sigra hook seams (already designed for Accrue):** `lib/sigra/organizations/callbacks.ex`
  (`before_add_member/4` seat gating) + `lib/sigra/hooks.ex` (user-lifecycle) — Phase 13
  D-04/D-05 designed these with Accrue interop as a validation case (STACK.md:108).
- **`Sigra.Scope` extraction:** `lib/sigra/scope.ex` — the shared `current_scope` bus
  across the Lockspire (`.user`) and Rulestead (`RulesteadPolicy`) recipes.
- **`Sigra.Auth.create_session/4`:** `lib/sigra/auth.ex:1284` — the existing session-mint
  function the Relyra recipe hands off to after a SAML ACS round-trip.
- **ExDoc `Companion Libraries` group:** `mix.exs:233` regex already matches anything under
  `guides/recipes/companion-libs/` — Phase 134 only appends `extras:` entries; no group
  edits.
- **Local sister-repo checkouts:** `/Users/jon/projects/{accrue,lockspire,relyra,rulestead}/`
  are present and answer all four behaviour-contract questions without external research.

### Established Patterns

- **No YAML frontmatter in guides** (Phase 132 D-03/D-04 LOCKED): every `guides/` file opens
  with a Markdown H1; validated-against ships as HTML comments + a human-readable line.
- **Pin contract by line-range reference, not by copying sister-lib code** (Phase 132 D-07):
  keeps the recipe honest when a sister lib revs its API; the `validated_against:` pin makes
  the version contract explicit.
- **No `.planning/` cross-links from adopter docs** (Phase 133 D-08/D-14): the planning tree
  is maintainer-private. The OIDC-vs-SAML matrix (FEATURES.md) is rephrased into adopter
  voice, not linked.
- **Pre-commit `mix docs --warnings-as-errors` + banned-phrase grep gates** (Phase 132 D-12,
  Phase 133 D-18/D-19): reused as Phase 134's verification step.
- **Atomic recipe-land + suppression-remove** (Phase 133 D-06/D-07): the four
  `skip_undefined_reference_warnings_on:` entries exist only to bridge the 133→134 window;
  they're removed in the same commit the recipes land.

### Integration Points

- **`guides/recipes/companion-libs/`** — Phase 134 creates four new `.md` files here.
- **`mix.exs:225-228` `extras:`** — Phase 134 appends four entries after `mailglass.md`.
- **`mix.exs:174-179` `skip_undefined_reference_warnings_on:`** — Phase 134 removes the
  four entries + Phase 133 comment header.
- **`guides/introduction/suite-integration.md` (Phase 133)** — its role table + "Where to
  next" already cross-link TO the four recipes; Phase 134 lands the link targets and (per
  Phase 133 D-07) the executor removes the four suppressions in the same commit.
- **Phase 136 PROOF-01 dependency:** re-runs `mix docs --warnings-as-errors` + may
  grep-assert the four recipes carry the banner / Failure modes / Non-goals sections (the
  deferred recipe-contract test fixture, REQUIREMENTS.md lines 59-60).
</code_context>

<specifics>
## Specific Ideas

- **Banner exact text per recipe** (generalize Phase 132's framing):
  "**Sigra works fully standalone.** <Lib> is an optional integration; Sigra ships without
  it, and removing the wiring below returns Sigra to standalone operation with no further
  changes." Plus the bottom reminder echo Phase 133 D-15 established for multi-integration
  pages where it reads as "you need all of these."
- **`validated_against:` pins** (HTML comment + visible line, dated to authoring day):
  `accrue ~> 1.2`, `lockspire ~> 1.2`, `relyra ~> 1.2`, `rulestead ~> 0.1`.
- **Relyra session-mint correction (D-09) — the load-bearing pin:** recipe says
  "after Relyra completes the SAML ACS round-trip and hands back the authenticated subject,
  mint a Sigra session with `Sigra.Auth.create_session/4`
  (`lib/sigra/auth.ex:1284`)." NOT `Sigra.Session.create_session/3`.
- **Rulestead version caveat (D-13):** one Prerequisites sentence — e.g. "Rulestead's
  published Hex line is `~> 0.1` even though its narrative GA is 1.0.0; pin `~> 0.1` in your
  `mix.exs`." Neutral, no drama.
- **Lockspire ADR 001 quote (D-08):** Non-goals quotes the deferral trigger so adopters
  understand why there's no `sigra_lockspire` glue package and what would change that.
- **mix.exs extras append (D-16) exact position** — after
  `"guides/recipes/companion-libs/mailglass.md"` (`mix.exs:227`):
  ```elixir
  "guides/recipes/companion-libs/accrue.md",
  "guides/recipes/companion-libs/lockspire.md",
  "guides/recipes/companion-libs/relyra.md",
  "guides/recipes/companion-libs/rulestead.md"
  ```
  (and the existing `mailglass.md` line gains a trailing comma).
- **mix.exs skip-warnings removal (D-16) exact target** — delete `mix.exs:174-179` (the
  `# Phase 133:` comment header lines 174-175 + the four entries lines 176-179).
</specifics>

<deferred>
## Deferred Ideas

- **Recipe-contract test fixtures** — walks `guides/recipes/companion-libs/*.md` and
  asserts the required section headings ("Failure modes," "Non-goals," banner, version
  pins). v1.29 Future Requirement (REQUIREMENTS.md lines 59-60). Phase 134 ships uniform
  sections by hand; Phase 136 PROOF-01 may grep-assert. Build the fixture only if Phase 134
  has budget; otherwise post-v1.29.
- **Sigra-managed billing / SAML metadata / feature-flag storage** — Diminishing Returns
  Wall; owned by Accrue / Relyra / Rulestead respectively. Recipes state these as Non-goals.
- **`sigra_lockspire` glue Hex package** — ADR 001 deferred until both APIs stable + a real
  adopter trigger. Lockspire recipe references this in Non-goals; Phase 134 does not
  litigate it.
- **`--with-accrue` / `--with-relyra` / etc. install flags** — zero `--with-*` precedent
  (REQUIREMENTS.md Out-of-Scope line 65). Recipes are pure host-side wiring.
- **Touch-up rewrite of `companion-oauth-provider.md`** — FEATURES.md F-RC-03 framed
  Lockspire as a "touch-up" of the v1.7 recipe, but RC-04 / ROADMAP.md:125 scope it as a
  NEW concrete recipe that cross-links back. Phase 134 writes the new `lockspire.md`; any
  rewrite of the v1.7 architectural recipe beyond a reciprocal "See also" back-link is
  out of scope (escalate if the v1.7 recipe is substantively wrong against Lockspire `~> 1.2`).

### Reviewed Todos (not folded)

None reviewed this round — the four Phase 134 todos were already promoted into RC-03..RC-06
by gsd-roadmapper at milestone open (STATE.md lines 49-52). `gsd-sdk query todo.match-phase
134` returns empty.
</deferred>
