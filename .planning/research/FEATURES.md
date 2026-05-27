# Feature Research — v1.29 SUITE-INTEGRATION

**Domain:** Companion-library integration recipes + first-class Threadline audit adapter for Sigra (Phoenix 1.8+ auth library)
**Researched:** 2026-05-27
**Confidence:** HIGH (verified against in-repo Sigra contracts, Threadline source at `/Users/jon/projects/threadline`, MILESTONE-ARC, MILESTONES.md narrative)

## Scope Recap (so categories make sense)

v1.29 is **not** about owning sister-library functionality. The milestone closes a documentation/seam gap: adopters who pick up Sigra should be able to compose it with Mailglass, Threadline, Accrue, Lockspire, Relyra, and Rulestead **today**, with one decisive code surface (Threadline reverse adapter) and a coherent narrative layer (recipes + ecosystem diagram + reference example).

The asymmetry that drives feature shape:

- **Threadline** already wires Sigra one way (`Threadline.Integrations.Sigra` reads `current_scope` to derive `ActorRef` + correlation ID). Sigra → Threadline does **not** yet exist. This is the only direction worth code.
- **Mailglass** was wired in v1.25 EMAIL-RAILS as `Sigra.Mailers.Adapters.Mailglass` + `--with-mailglass` installer flag. Cross-link, do not re-wire.
- **Accrue / Lockspire / Relyra / Rulestead** have no Sigra-side code surface to design. They consume Sigra outputs (`current_scope`, `organization_id`, audit events, webhooks). Recipes only.
- **Lockspire** already has a recipe (`guides/recipes/companion-oauth-provider.md`) shipped in v1.7. Audit it; don't duplicate.

## Existing Sigra Surfaces the Milestone Builds On (do not re-research)

| Sigra Surface | Used By | Notes |
|---------------|---------|-------|
| `Sigra.Audit.log_multi_safe/3` + `__log_internal__/3` | Threadline adapter | Internal library-owned audit events use reserved prefixes (`auth.`, `session.`, `mfa.`, `oauth.`, `api.`, `account.`, `sigra.`). Adapter rides telemetry, not internal hooks. |
| `[:sigra, :audit, :log]` telemetry event | Threadline adapter | Single canonical event; emitted exactly once per committed audit row. Metadata: `%{action, actor_id, outcome}`. |
| `Sigra.Mailer` behaviour | Mailglass cross-link | Host implements `deliver/3`. Mailglass already adapter-shaped. |
| `Sigra.Delivery` (`:async` / `:sync` / `:auto`) | Mailglass cross-link | Detects Oban; routes async via `Sigra.Workers.EmailDelivery`. |
| `current_scope` struct (`:user`, `:active_organization`, `:active_organization_id`, `:membership`, `:auth_method`, `:impersonating_from`, `:token_id`, `:id`) | Threadline adapter, Accrue recipe, Lockspire recipe, Rulestead recipe | The shared bus across every recipe. Recipe templates should reference these fields by exact name. |
| `Sigra.OptionalDeps` (HARD-02) + `mix sigra.doctor` | Threadline adapter, recipes | Optional-dep guards already exist for Oban/Bcrypt/EQRCode/etc. New Threadline guard should follow the same pattern. |
| Webhooks (v1.22) — signed outbound events | Accrue recipe (subscription state sync) | Adopters use existing webhook subscriptions; recipe shows event-type filters + payload mapping. |
| `Sigra.Organizations` + `:role` on memberships (B2B-02 v1.21) | Rulestead recipe, Accrue recipe | Recipes read org/role from scope; do not re-invent. |
| Generator template seams (`priv/templates/sigra.install/`) | Reference example | Sigra ships generated host code; reference example must use the generator output, not bespoke wiring. |

## Feature Landscape

### Table Stakes (Must Ship in v1.29)

Features without which the milestone "doesn't really make Sigra compose cleanly with the suite."

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **F-TL-01 — `Sigra.Audit.Adapters.Threadline` reverse adapter** | Threadline already wires Sigra one way; reverse is the only direction with adopter pull. SEED-006 referenced as canonical scope unlock. | MEDIUM | Library-owned module under `lib/sigra/audit/adapters/threadline.ex`. Subscribes to `[:sigra, :audit, :log]` telemetry, calls `Threadline.record_action/2` with derived `ActorRef`, `category`, `verb`, `correlation_id`. Optional-dep safe: compiles to no-op stubs when `Threadline` is not loaded (mirror `Sigra.Workers.AccountDeletion` optional-dep pattern via `no_warn_undefined` in `mix.exs`). |
| **F-TL-02 — Async dispatch with bounded backpressure** | Telemetry handlers run in the producer process; a slow Threadline insert would slow Sigra. | MEDIUM | Adapter must hand off to a `Task.Supervisor` or (when Oban present) an Oban job. Default to `Task.Supervisor` with a configurable pool; route to Oban only if explicitly configured. Never block the calling process. Mirrors `Sigra.Delivery` `:auto`/`:async`/`:sync` pattern. |
| **F-TL-03 — Retry semantics for adapter failures** | Threadline writes can fail (DB down, validation rejected, network for remote Threadline). Sigra audit row is already committed — adapter failure must not retroactively affect Sigra. | SMALL | Bounded retry (3 attempts, exponential backoff) inside the Task supervisor branch; on Oban path, use Oban's retry. On exhaust, emit `[:sigra, :audit, :adapter, :threadline, :failed]` telemetry + `Logger.warning`. **Adapter failures never raise out of `Sigra.Audit` callers.** |
| **F-TL-04 — Optional-dep guard + boot-time diagnostic** | HARD-02 set the pattern: missing optional dep should raise truthfully at boot if the feature is enabled, not silently degrade at runtime. | SMALL | Extend `Sigra.OptionalDeps` to validate Threadline when `audit_adapters: [Sigra.Audit.Adapters.Threadline]` is configured. `mix sigra.doctor` adds a Threadline-adapter row in its dep matrix. |
| **F-TL-05 — Telemetry parity with native audit path** | `[:sigra, :audit, :log]` fires once per committed row today; adapter must not silently drop or double-emit. | SMALL | Adapter emits its own `[:sigra, :audit, :adapter, :threadline, :forwarded]` event per successful Threadline write (separate event so native audit telemetry stays canonical). |
| **F-RC-01 — Threadline integration recipe** | Recipe is the doc surface the adapter ships behind. Doc-only file under `guides/recipes/threadline-audit-adapter.md`. | SMALL | Required sections: Prerequisites, Install (deps + config + supervisor), Integration code snippet (config example), Verification snippet (telemetry-attach proof or `mix sigra.doctor` line), Cross-link to `companion-oauth-provider.md` precedent, **Non-goals** (does not own Threadline retention/policy/triggers/operator surface). |
| **F-RC-02 — Accrue integration recipe** | Identified in deferred TODOs (`2026-05-08-write-accrue-integration-recipe.md`). Adopters need to know how Sigra identity feeds Stripe-webhook-backed Accrue. | SMALL | Doc-only. Sections: Prerequisites (Sigra orgs shipped), Architecture sketch (Sigra = identity / Accrue = billing state / Stripe webhooks → Accrue / Sigra reads `org.subscription_tier` for feature gates), Integration code snippet (scope-aware plug example), Verification (test plan stub), Non-goals (Sigra does not own billing, does not generate Stripe glue). |
| **F-RC-03 — Lockspire recipe audit + cross-link refresh** | v1.7 already shipped `companion-oauth-provider.md`. Confirm it still reflects the Lockspire posture; add **See also** linking to the v1.29 suite-narrative page. | TINY | Read-and-touch-up pass. Add the suite-narrative back-link. Do not rewrite. If Lockspire has shipped meaningful API changes since v1.7 that would invalidate the recipe, escalate (out-of-scope: rewriting from scratch). |
| **F-RC-04 — Relyra integration recipe** | Deferred TODO. Relyra = SAML 2.0 SP; complements ENT-SSO's OIDC-first enterprise login. | SMALL | Doc-only. Sections: Prerequisites (Sigra orgs + ENT-SSO shipped), When to use Relyra vs Sigra's OIDC connection (decision matrix), Integration sketch (Relyra issues identity assertion → host translates to Sigra session via JIT path), Verification, **Non-goals** (Sigra does not own SAML metadata, key rotation, or IdP-initiated SLO; those stay with Relyra). |
| **F-RC-05 — Rulestead integration recipe** | Deferred TODO. Rulestead = feature flags / typed remote config. | SMALL | Doc-only. Sections: Prerequisites, Use cases (staged rollout of Sigra auth methods — e.g. passkey-primary, MFA-required, SSO-required by org), Integration sketch (Rulestead context builder reads `current_scope` → returns evaluated flags), Verification, Non-goals (Sigra does not own flag storage, evaluator, or admin UI). |
| **F-RC-06 — Mailglass cross-link confirmation** | EMAIL-RAILS v1.25 already shipped the adapter. v1.29 must confirm the boundary, **not** add new code or claim new adapters. | TINY | Either (a) one paragraph + link in the suite-narrative page pointing at the existing `--with-mailglass` flag + Mailglass-side `migration-from-swoosh.md`, **or** (b) a slim `guides/recipes/mailglass-email-rails.md` summarizing the v1.25 shipped surface. Default: **cross-link, no new recipe**. Lean doc-only to honor "do not re-research existing features." |
| **F-NX-01 — Suite-narrative landing page** | The five recipes + Threadline adapter need a single entry point so adopters don't have to discover them one-by-one. | SMALL | New file `guides/introduction/suite-integration.md` (or `guides/recipes/szTheory-suite.md`). Sections: What the szTheory suite is, Where Sigra fits, Per-library one-paragraph posture + recipe link, Ecosystem diagram, "When you need just Sigra alone" exit ramp, **Non-goals** (Sigra is not a meta-framework; libraries stay independent). |
| **F-NX-02 — Ecosystem diagram (ASCII or PlantUML)** | Visual anchor that the narrative refers to. | TINY | ASCII diagram embedded in the narrative page. Shows: Sigra (auth identity hub) at center, Mailglass (email rails) + Threadline (audit sink) + Accrue (billing state) + Lockspire (OAuth AS) + Relyra (SAML SP) + Rulestead (flags) at periphery, with the integration direction labeled on each edge (e.g. "Sigra → Threadline: audit events", "Mailglass → Sigra: mailer impl", "Lockspire ← Sigra: AccountResolver"). |
| **F-EX-01 — Reference example proving Sigra + Threadline composition** | Without an executable proof, the adapter is doc theater. | MEDIUM | **Reuse `test/example/`** (the existing nested Phoenix example app — already proven for EMAIL-RAILS bounce/complaint recipes per Phase 114). Add Threadline as an opt-in dep, install Threadline migrations, wire the adapter, write a single integration test that asserts a Sigra login event materializes as a `Threadline.AuditAction` row. **Do not create a new `examples/suite-starter/`** — that would split maintenance and recreate the example-app drift problems EMAIL-RAILS spent Phase 114 closing. |
| **F-PR-01 — Verification proof bundle** | Standard v1.x phase close gate. | SMALL | Adapter unit tests (with Threadline loaded + with Threadline unloaded), recipe contract checks (each recipe has prereq/install/integration/verification/non-goals sections — pattern after `verify.doc_contract` in Threadline's own mix.exs), generator/install parity unchanged (no installer changes in this milestone — assert that), `mix docs --warnings-as-errors` exit 0 (the gate that nearly blocked v1.28 PROOF-01). |

### Differentiators (High-Value Optional — Defer if Schedule Pressure)

Features that elevate v1.29 from "table stakes shipped" to "this is the SaaS-builder suite anchor."

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **F-D-01 — `mix sigra.gen.adapter threadline` task** | One-command wiring instead of doc-and-paste. Mirrors `mix lockspire.install --sigra-host` from companion-oauth recipe. | MEDIUM | Generates: supervisor child spec, runtime config block, optional Oban queue entry, and a smoke test. Defer if Phase budget pressed — recipe handles the same with copy-paste, just less elegantly. |
| **F-D-02 — Behaviour-shaped audit-adapter contract (`Sigra.Audit.Adapter`)** | Threadline is the first adapter; future audit sinks (Datadog Audit, Carbonite, custom) become drop-in. | MEDIUM | Define `@callback forward(audit_row, context) :: :ok \| {:error, term}`. Configure adapters as a list: `audit_adapters: [Sigra.Audit.Adapters.Threadline, MyApp.AuditAdapters.Datadog]`. Honors Sigra's "behaviours + callbacks, no hidden macros" decision. **Strongly recommended as table stakes** — if only one adapter ships in v1.29, the behaviour cost is near-zero and locks in the contract before it ossifies. **Promote to table stakes** unless explicitly cut. |
| **F-D-03 — Correlation-ID propagation Sigra → Threadline** | Threadline derives correlation IDs today by reading Sigra state. With the reverse adapter, Sigra-internal audit rows should carry the same correlation ID so Threadline timeline queries unify. | SMALL | Adapter reads `Logger.metadata()[:request_id]` or accepts a `correlation_id` field on the audit row metadata. Inserts as Threadline's `correlation_id` column. Closes the loop. |
| **F-D-04 — Suite-starter blog/README narrative artifact** | Beyond docs: a public-facing post titled "Build a SaaS in a weekend with the szTheory Elixir suite." Differentiator for adoption, not for the library itself. | SMALL | Out of repo scope; could be a `RELEASE_NOTES.md` or a CHANGELOG paragraph that hexdocs surfaces. **Defer to publicity lane; not in milestone proof bundle.** |
| **F-D-05 — Recipe-contract test fixtures** | Threadline's own `verify.doc_contract` alias proves each guide has the required sections. Apply same pattern to Sigra's new recipes so future drift is caught at CI. | SMALL | Add `test/sigra/recipes/recipe_contract_test.exs` that walks `guides/recipes/*.md` and asserts the section heading set per recipe type (integration recipes vs deployment-style recipes have different shapes). |
| **F-D-06 — Composable scope inspector for recipes** | All five recipes read from `current_scope`. A small inspector helper (`Sigra.Scope.summary/1` returning a `%{user_id, org_id, role, auth_method, impersonating?}` map) gives every recipe a single one-liner. | TINY | Already mostly exists implicitly. Promoting it to a documented helper makes recipe code snippets ~3 lines shorter each. |

### Anti-Features (Explicitly NOT in v1.29)

Things that look like SUITE-INTEGRATION scope but cost dramatically more than they return.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **AF-01 — Sigra-managed Stripe integration via Accrue** | Adopters ask "can Sigra just hand me billing?" | Direct billing ownership crosses the permanent "Diminishing Returns Wall" in MILESTONE-ARC. Accrue is the canonical pairing; Sigra ships the identity feed and reads the result. | Doc-only recipe (F-RC-02). |
| **AF-02 — Sigra-side SAML metadata / IdP handling** | "Sigra should handle SAML, not just OIDC" | SAML SP responsibilities (metadata exchange, signing keys, IdP-initiated SLO) is Relyra's scope. Sigra owns the org-scoped session it issues after a Relyra assertion. | Doc-only recipe (F-RC-04) with explicit non-goal. |
| **AF-03 — Sigra-owned feature-flag store** | "Sigra should gate auth methods by flag" | Rulestead owns flag storage/eval/admin. Sigra reads flag values via Rulestead's context builder. | Doc-only recipe (F-RC-05) with explicit non-goal. |
| **AF-04 — A `sigra_threadline_adapter` separate Hex package** | "Keep Sigra core deps minimal" | Threadline is already an optional dep candidate (`optional: true` in `mix.exs`, `no_warn_undefined` guard). A separate package adds release coordination overhead without solving the dep-graph problem. Follows ADR 001 pattern (Lockspire glue deferred until a real trigger fires; same logic applies here — single in-tree adapter is fine until a second adapter forces extraction). | Single-tree `Sigra.Audit.Adapters.Threadline` with `optional: true` in mix.exs. |
| **AF-05 — New top-level `examples/suite-starter/` directory** | "A reference SaaS combining all six libraries" | (1) Duplicates `test/example/` maintenance; (2) splits CI signal; (3) creates a synthetic adopter context that diverges from the generator output. Phase 114 already paid the price of nested-example-app drift; do not re-open that wound. | Extend `test/example/` with opt-in deps + per-integration test files. |
| **AF-06 — Cross-library version-compatibility matrix in Sigra docs** | "Tell adopters which Mailglass / Threadline version pairs with which Sigra version" | Drift trap. Each library owns its own compat matrix. Sigra-side claim would lie within weeks. | Each recipe states the minimum companion-lib version tested against; companion docs own their full compat story. |
| **AF-07 — Sigra-emitted webhooks for the suite** | "Sigra should fire Accrue-shaped or Threadline-shaped webhooks" | v1.22 webhooks ship the canonical Sigra event contract; Accrue/Threadline subscribe to that, not the other way around. Inventing per-companion webhook shapes leaks companion identities into the Sigra event contract. | Recipe shows how to filter existing webhook subscriptions by event type and consume in companion. |
| **AF-08 — Generic "plugin registry" for arbitrary companion libs** | "Make Sigra pluggable for any library" | Sigra already exposes behaviours (Mailer, RateLimiter, Authz, Audit Adapter once F-D-02 lands). A "registry" abstraction would re-implement that loosely-typed. | Behaviour + optional-dep guard + recipe is the pattern. |
| **AF-09 — Re-architecting `Sigra.Audit` to push events instead of pulling via telemetry** | "Direct push is faster than telemetry handler" | Telemetry is canonical; single-emission-on-commit guarantees are proven through 11 milestones (D-01 + AUD-01..AUD-21). Re-architecting risks audit atomicity invariants for adapter convenience. | Adapter rides existing telemetry event. If push semantics are ever needed (F-D-02 behaviour), wrap them as a thin `Adapter.forward/2` callback invoked from a single telemetry handler attached at boot. |
| **AF-10 — Owning any companion library's roadmap** | Explicit non-goal in MILESTONE-ARC SUITE-INTEGRATION entry. | Companion libs are independent; v1.29 must not create dependencies that block their independence. | Recipes assume current shipped versions; each companion library owns its own changelog and version cadence. |

## Feature Dependencies

```
F-TL-01 Threadline adapter
    ├──requires──> F-TL-02 async dispatch
    ├──requires──> F-TL-03 retry semantics
    ├──requires──> F-TL-04 optional-dep guard
    ├──requires──> F-TL-05 telemetry parity
    ├──requires──> existing Sigra.Audit telemetry event [:sigra, :audit, :log] (v1.0)
    └──enables──> F-RC-01 Threadline recipe

F-D-02 Audit.Adapter behaviour (recommended-promote-to-table-stakes)
    └──refactors──> F-TL-01 to implement the behaviour
        └──unlocks──> future adapters without re-cutting the surface

F-RC-01..F-RC-06 recipes
    ├──require──> F-NX-01 suite-narrative landing page (cross-link target)
    └──require──> Sigra v1.21 RBAC scope + v1.22 webhooks + v1.27 ENT-SSO (already shipped)

F-NX-01 suite narrative
    └──requires──> F-NX-02 ecosystem diagram

F-EX-01 reference example
    ├──requires──> F-TL-01 Threadline adapter
    └──uses──> existing test/example/ Phoenix app (do not fork)

F-PR-01 verification proof bundle
    └──requires──> all of F-TL-* + F-RC-* + F-NX-* + F-EX-*
```

### Dependency Notes

- **F-TL-01 sits on F-D-02 if you ship the behaviour.** If F-D-02 stays deferred, F-TL-01 is a one-off module that codifies the same shape de facto. Either is fine; the behaviour version costs ~30 minutes more and prevents a refactor when a second adapter lands.
- **All recipes require the suite-narrative page (F-NX-01) to exist before they merge** so the cross-link target is real. Sequence the milestone so F-NX-01 lands in Phase 131 (or whatever the first phase is) before recipe phases.
- **F-EX-01 reference example must reuse `test/example/`** not create a new directory. This is a hard constraint born of the v1.25 Phase 114 nested-example-app pain.
- **Lockspire recipe (F-RC-03) is touch-up only.** If audit reveals it's still accurate, the diff is a single back-link to the suite-narrative page. If it's substantively wrong, escalate — that's a separate scope question, not a v1.29 expansion.

## MVP Definition

### Launch With (v1.29 must-haves)

The bounded contract that justifies the milestone tag.

- [ ] **F-TL-01** Threadline reverse adapter — the only code-deep wedge
- [ ] **F-TL-02** async dispatch — Sigra audit hot path must not regress
- [ ] **F-TL-03** retry semantics — adapter failures don't poison Sigra
- [ ] **F-TL-04** optional-dep guard — boot-time truth follows HARD-02 pattern
- [ ] **F-TL-05** telemetry parity — observability is part of the contract
- [ ] **F-RC-01..F-RC-05** five integration recipes (Threadline, Accrue, Lockspire-touchup, Relyra, Rulestead)
- [ ] **F-RC-06** Mailglass cross-link (one paragraph; not a new recipe)
- [ ] **F-NX-01** suite-narrative page
- [ ] **F-NX-02** ecosystem diagram
- [ ] **F-EX-01** reference example proof in `test/example/`
- [ ] **F-PR-01** verification proof bundle

### Add If Schedule Allows (still v1.29)

Things that should ship together but are recoverable in v1.30 if cut.

- [ ] **F-D-02** `Sigra.Audit.Adapter` behaviour — **strongly recommended as table stakes** (low cost, future-proofs the contract)
- [ ] **F-D-03** correlation-ID propagation Sigra → Threadline — closes the loop with Threadline's existing one-way wire
- [ ] **F-D-05** recipe-contract test fixtures — catches future doc drift

### Defer to v1.30+ or Beyond

- **F-D-01** `mix sigra.gen.adapter threadline` task — adopter ergonomics; recipe handles for now
- **F-D-04** suite-starter blog/README narrative artifact — publicity lane
- **F-D-06** `Sigra.Scope.summary/1` helper — adopter ergonomics

## Complexity Summary

| Sizing | Features |
|--------|----------|
| TINY (~1-3 hours) | F-RC-03, F-RC-06, F-NX-02, F-D-06 |
| SMALL (~half-day to day) | F-TL-03, F-TL-04, F-TL-05, F-RC-01, F-RC-02, F-RC-04, F-RC-05, F-NX-01, F-PR-01, F-D-03, F-D-04, F-D-05 |
| MEDIUM (~2-3 days) | F-TL-01, F-TL-02, F-EX-01, F-D-01, F-D-02 |

Estimated minimal-MVP phase count: **3-4 phases** (one phase for Threadline adapter + reference example, one phase for the five recipes + cross-link + Mailglass touch, one phase for suite-narrative + diagram, one phase for proof bundle and milestone audit). With F-D-02 promoted to table stakes: **3 phases** still works because the behaviour is a sub-task of phase 1.

## Dependencies on Existing Sigra Contracts (Named Explicitly)

| Dependency | Where It Lives | Used By |
|------------|---------------|---------|
| `[:sigra, :audit, :log]` telemetry event with `%{action, actor_id, outcome}` metadata | `lib/sigra/audit.ex:37, :304-310` | F-TL-01 adapter subscribes here |
| `Sigra.OptionalDeps` boot-time validation pattern | HARD-02 (Phase 95, v1.21) | F-TL-04 extends with `:threadline` entry |
| `mix sigra.doctor` dep matrix | HARD-02 (Phase 95, v1.21) | F-TL-04 adds Threadline-adapter row |
| `current_scope` struct shape (`:user`, `:active_organization_id`, `:membership`, `:auth_method`, `:impersonating_from`, `:token_id`, `:id`, `:role`) | `lib/sigra/scope.ex` (B2B-02 v1.21 added `:role`) | F-TL-01 derives `ActorRef`; all F-RC-* recipes read from this |
| `Sigra.Workers.*` optional-dep compile-time guards (`no_warn_undefined` in `mix.exs:65-86`) | Sigra mix.exs | F-TL-01 follows same pattern for Threadline-conditional code |
| `Sigra.Audit` reserved-prefix contract (`auth.`, `session.`, `mfa.`, `oauth.`, `api.`, `account.`, `sigra.`) | `lib/sigra/audit.ex:39` | F-TL-01 must forward events whose action uses reserved prefixes — these are exactly the events host adopters want centralized in Threadline |
| `Sigra.Mailer` behaviour (`@callback deliver/3`) | `lib/sigra/mailer.ex` | F-RC-06 references; no change to behaviour |
| `Sigra.Delivery` (`:auto` / `:async` / `:sync`) | `lib/sigra/delivery.ex` | F-TL-02 async dispatch uses `oban_running?/0` detection pattern |
| Webhook event catalog + subscription registry (v1.22 Phases 97–99) | `lib/sigra/webhooks/*` | F-RC-02 Accrue recipe shows event-type filter |
| Org-scoped enterprise routing + JIT (v1.27 ENT-SSO Phases 122–126) | `lib/sigra/enterprise_*.ex` | F-RC-04 Relyra recipe references; Relyra integrates into the JIT path |
| Generated host template seams (`priv/templates/sigra.install/`) | Generator | F-EX-01 reference example uses the generator output, **does not bypass it** |
| Threadline `record_action/2` API + `ActorRef.new/2` validation | `/Users/jon/projects/threadline/lib/threadline.ex:40` and `lib/threadline/semantics/actor_ref.ex` | F-TL-01 calls these directly |
| `Threadline.Integrations.Sigra.actor_ref_from_scope/1` existing logic | `/Users/jon/projects/threadline/lib/threadline/integrations/sigra.ex:72-86` | F-TL-01 should **mirror** the actor-type derivation (impersonating→admin, api_token/jwt→service_account, user→user) for symmetry. **Do not invent a second mapping.** |

## Reference Differentiator Note: Recipe Section Contract

Each integration recipe must include these sections (in this order) so adopters can scan-and-skip identically across all six recipes. This is the precedent from `companion-oauth-provider.md` (v1.7 INTG-01) lightly extended:

1. **Title + one-line description** ("Recipe: Sigra + Threadline audit adapter")
2. **What this is / What this is not** (1-2 sentences; cross-link to `companion-oauth-provider.md` for the pattern)
3. **Prerequisites** (Sigra version pin, companion version pin, what must work first)
4. **Architecture sketch** (ASCII or 3-line description showing Sigra → companion direction)
5. **Install steps** (mix.exs deps, `config/runtime.exs` block, supervisor child spec if needed)
6. **Integration code snippet** (copy-pasteable, ~20-40 lines)
7. **Verification snippet** (the one assertion or `iex>` line that proves it works — e.g. `:telemetry.attach(...)` + login event + Threadline row count)
8. **When NOT to use this pattern** (the anti-feature exit ramp — `companion-oauth-provider.md` precedent at lines 40-44)
9. **See also** (cross-links to suite-narrative page + sister recipes)
10. **Non-goals** (explicit list: what Sigra does not own in this integration)

The "first-class" vs "recipe" distinction in v1.29:

- **First-class:** Threadline (F-TL-01 = code surface in Sigra + recipe). Bidirectional code wire.
- **Recipe-only:** Accrue / Lockspire / Relyra / Rulestead / Mailglass-cross-link. Adopters do all the wiring; Sigra provides the seams that already exist.

## Sources

- In-repo verified (HIGH confidence):
  - `/Users/jon/projects/sigra/.planning/PROJECT.md` (project context, v1.28 close state, v1.29 active milestone)
  - `/Users/jon/projects/sigra/.planning/MILESTONE-ARC.md` (SUITE-INTEGRATION candidate scope, diminishing-returns wall)
  - `/Users/jon/projects/sigra/.planning/STATE.md` (deferred TODO list confirming five integration recipes pending)
  - `/Users/jon/projects/sigra/.planning/MILESTONES.md` (Mailglass v1.25 EMAIL-RAILS adapter already shipped via `Sigra.Mailers.Adapters.Mailglass` + `--with-mailglass` installer flag)
  - `/Users/jon/projects/sigra/guides/recipes/companion-oauth-provider.md` (v1.7 INTG-01 recipe precedent — section pattern reused)
  - `/Users/jon/projects/sigra/guides/recipes/deployment.md` (v1.10 recipe precedent — section pattern variant)
  - `/Users/jon/projects/sigra/lib/sigra/audit.ex` (telemetry event contract, optional-dep pattern context)
  - `/Users/jon/projects/sigra/lib/sigra/mailer.ex` (Mailer behaviour shape for reference)
  - `/Users/jon/projects/sigra/lib/sigra/delivery.ex` (async/sync/auto pattern that F-TL-02 mirrors)
  - `/Users/jon/projects/sigra/mix.exs` (optional-dep + `no_warn_undefined` pattern for F-TL-01 / F-TL-04)
- Companion-library verified (HIGH confidence):
  - `/Users/jon/projects/threadline/lib/threadline/integrations/sigra.ex` (existing one-way Threadline→Sigra wire; symmetry source for F-TL-01)
  - `/Users/jon/projects/threadline/lib/threadline.ex:40` (`record_action/2` public API the adapter calls)
  - `/Users/jon/projects/threadline/guides/integrations/sigra.md` (Threadline-side companion doc; reference for split-ownership wording)
  - `/Users/jon/projects/threadline/mix.exs` (`verify.doc_contract` alias — pattern referenced by F-D-05)
  - `/Users/jon/projects/lockspire/mix.exs` description (Lockspire still ships embedded OAuth/OIDC AS posture; recipe touch-up rather than rewrite)
  - `/Users/jon/projects/accrue/accrue/mix.exs` (Accrue v1.2.0 billing-state-modeled-clearly posture; doc-only integration confirmed)
  - `/Users/jon/projects/relyra/mix.exs` (Relyra v1.2.0 strict SAML 2.0 SP; complements OIDC-first ENT-SSO)
  - `/Users/jon/projects/rulestead/README.md` + `/Users/jon/projects/rulestead/rulestead/mix.exs` (Rulestead 0.1.x line typed flags; recipe is staged-rollout of Sigra auth methods)
- User memory (informational; verified against repo state):
  - `project_oss_suite_vision.md` — szTheory suite vision; integration directions confirmed against actual companion-library code rather than memory claims
