# Project Research Summary — v1.29 SUITE-INTEGRATION

**Project:** Sigra
**Milestone:** v1.29 SUITE-INTEGRATION
**Domain:** Companion-library integration recipes + first-class Threadline audit adapter for a Phoenix 1.8+ authentication library
**Researched:** 2026-05-27
**Confidence:** HIGH (all four research files independently verified against repo HEAD on `v1.28-data-lifecycle`, against hex.pm on 2026-05-27, and against in-tree companion-lib source where present)

## Headline Recommendation

**v1.29 ships exactly one piece of new library code — a `Sigra.Audit.Forwarders.Threadline` telemetry-tap adapter — plus six recipe docs under `guides/recipes/companion-libs/`, a `guides/introduction/suite-integration.md` narrative, and a single Threadline-demo extension of the existing `test/example/` app.** Everything else is documentation that pins to existing Sigra contracts (telemetry, `current_scope`, optional-dep guards, hooks registry, webhooks). Threadline is the only direction that justifies code because (a) the adapter must respect Sigra's "telemetry fires only on committed audit rows" invariant, (b) drift across host implementations is a real risk, and (c) it is the one companion lib for which Sigra-side code lives in lockstep with `Sigra.Audit`'s rollback semantics. Build order is Phase **131 → 136**, with Phase 131 establishing the boundary doctrine + optional-dep handling **before** any adapter code lands.

This stays inside `MILESTONE-ARC`'s Diminishing Returns Wall and the milestone's own non-goal: Sigra does not own any companion lib's roadmap, does not ship `--with-threadline`-style flags, does not host a control plane, and does not absorb companion-shaped schema.

## Cross-Cutting Truths (Converged Across Researchers)

These three findings appeared independently in 3+ of the 4 research files. Treat as HIGH-confidence shared conclusions:

1. **Threadline integration is a post-commit, fire-and-forget telemetry-tap on `[:sigra, :audit, :log]` — NOT a destination swap inside `Sigra.Audit`.** STACK Option A, ARCHITECTURE §1, and PITFALLS Pitfall 2 all arrived at this independently. The naming proposal varies (STACK: `Sigra.Audit.Adapters.Threadline`; ARCHITECTURE: `Sigra.Audit.Forwarders.Threadline`) — **adopt ARCHITECTURE's `Forwarders` naming** because it correctly signals "Sigra DB row remains source-of-truth; Threadline is a projection," which matches the actual semantics. The DB row is authoritative; Threadline is the operator's suspenders. Telemetry already fires only on `{:ok, changes}` commit (`lib/sigra/audit.ex:286-302`), so rollback-safety is free.

2. **Reference example extends `test/example/`, do NOT create a new top-level `examples/` directory.** ARCHITECTURE §7, FEATURES F-EX-01 / AF-05, and PITFALLS Pitfall 6 all converged. `test/example/` is already CI-wired (3 jobs in `ci.yml` including Playwright smoke), already auth-focused, and Phase 114 already paid the cost of closing nested-example-app drift. A new `examples/` subdir would re-open that wound and consume CI minutes without ergonomic gain.

3. **Recipe location convention is `guides/recipes/companion-libs/<name>.md` (new subdir).** ARCHITECTURE §5 recommends this for separation of feature recipes from integration recipes. FEATURES referenced flat `guides/recipes/`, but with 5–6 companion-lib recipes about to land, the subdir convention scales better. **Adopt the subdir.** ExDoc wiring needs `extras:` updates and a new `"Companion Libraries"` group in `groups_for_extras`.

4. **Companion-lib Hex availability is solid for v1.29.** STACK verified directly on hex.pm 2026-05-27: Threadline `0.5.0`, Mailglass `1.2.0`, Accrue `1.2.0`, Lockspire `1.2.0`, Relyra `1.2.0` are all published. Rulestead's README ships `{:rulestead, "~> 0.1"}` (installable) though the GA narrative is at 1.0.0. PITFALLS Pitfall 8 raised a vapor-recipe concern based on the milestone-narrative claim that "most companion libs are not on Hex" — that concern is **superseded by STACK's verified Hex publish status**. Treat STACK's table as authoritative; no `preview/` gating needed for v1.29 recipes.

## Surfaced Inconsistencies That Affect Scope

These three findings contradict the milestone narrative in `PROJECT.md` / `MILESTONES.md` / `STATE.md` and MUST be reconciled before requirements authoring.

### 1. Mailglass adapter is NOT on the v1.28 release branch

**Finding (STACK §2, ARCHITECTURE exec summary, PITFALLS context):** `lib/sigra/mailers/adapters/mailglass.ex` does not exist on `v1.28-data-lifecycle` HEAD. The file was authored in Phase 111/114 work (commits `b75189e`, `470af1f`) but only lives on `backup/pre-cleanup-20260525-073728`, `chore/phase-88-uat-evidence`, `wip/2026-05-23-example-isolation`, and `wip/example-admin-drift-20260525`. `mix.exs` HEAD has no `:mailglass` optional dep. CHANGELOG stops at `[0.3.0]`. The narrative claim that "v1.25 EMAIL-RAILS shipped the adapter + `--with-mailglass` flag" does not match the released branch.

**Implication for v1.29 scope:** The "Mailglass cross-link" in MILESTONE-ARC SUITE-INTEGRATION scope is NOT a "confirm and link" — it's **"decide what to do about the orphaned Phase 111/114 work."**

**Recommended call:** **Treat Mailglass as recipe-only in v1.29.** Do NOT re-land the orphaned adapter as part of this milestone's scope; that's a separate v1.28.1 / v1.30 question. Ship `guides/recipes/companion-libs/mailglass.md` as a 1-page cross-link showing how the host wires `Mailglass.deliver/1` behind the existing `Sigra.Mailer` behaviour. If the orphaned adapter needs to re-land, it gets its own scoped quick task post-v1.29.

### 2. `Sigra.OptionalDeps` SOT module does NOT exist

**Finding (ARCHITECTURE exec summary item 2, PITFALLS Pitfall 1):** The v1.21 HARD-02 narrative documents `Sigra.OptionalDeps` + `mix sigra.doctor` as shipped. `grep -r "Sigra.OptionalDeps" lib/` returns zero hits. The actual pattern is scattered `Code.ensure_loaded?` guards across 29+ call sites in `lib/sigra/{delivery,application,jwt,oauth,mfa,crypto,plug,account}.ex`, plus the `no_warn_undefined` whitelist in `mix.exs:65-87`, plus one-shot boot warnings in `lib/sigra/application.ex`. FEATURES referenced `Sigra.OptionalDeps` as if it exists — that was based on the milestone narrative, not the repo state.

**Implication for v1.29 scope:** Phase 131 has a fork. Either: (a) build the `Sigra.OptionalDeps` SOT module first, then add Threadline to it; or (b) follow the existing scattered-guard precedent for the Threadline forwarder and treat the SOT as a separate cleanup later.

**Recommended call:** **Take option (b) for v1.29.** Following the existing scattered-guard precedent (mirroring `Sigra.RateLimiters.Hammer` + `Sigra.RateLimiters.Noop` + the `lib/sigra/workers/*.ex` `if Code.ensure_loaded?(Oban.Worker) do` pattern) is the lowest-risk path. The Threadline forwarder wraps its `defmodule` in `if Code.ensure_loaded?(Threadline) do … end`, uses a `Sigra.Audit.Forwarders.Noop` fallback, adds entries to `mix.exs` `no_warn_undefined`, and emits boot-time warnings in `lib/sigra/application.ex`. Building the `Sigra.OptionalDeps` SOT module is a separate refactor that should not block v1.29 — file it as a follow-on quick task or v1.30 candidate.

### 3. `mix sigra.doctor` task does NOT exist

**Finding (ARCHITECTURE exec summary item 3):** `lib/mix/tasks/` contains only `install`, `upgrade`, `gen.oauth`, and `fixture.rebless_golden`. No `doctor` task. The v1.21 HARD-02 narrative references it as shipped; the repo state contradicts that.

**Implication for v1.29 scope:** FEATURES F-TL-04 and PITFALLS Pitfall 1 / UX-pitfall row both lean on `mix sigra.doctor` as a verification surface. That surface does not exist to lean on.

**Recommended call:** **Defer `mix sigra.doctor` to a separate post-v1.29 quick task.** Do NOT expand v1.29 scope to build it. For v1.29 verification, lean on boot-time `Logger.warning` in `lib/sigra/application.ex` (existing precedent: `maybe_warn_audit_cleanup_fallback/0`, `verify_vault!/0`) and on the forwarder's own telemetry events (`[:sigra, :audit, :forward_error]`). Recipe verification snippets use `:telemetry.attach/4` + assertion of forwarded payload, not `mix sigra.doctor`. When `doctor` is eventually built (separate quick task), it gains a forwarder row.

## Stack Additions (Final List for v1.29 mix.exs)

```elixir
defp deps do
  [
    # ... existing v1.28 deps unchanged ...
    {:threadline, "~> 0.5", optional: true},  # NEW — the only v1.29 stack delta
  ]
end

# Add to elixirc_options no_warn_undefined:
#   Threadline,
#   Threadline.ActorRef,
#   Threadline.AuditChange,
#   Threadline.AuditTransaction
```

**That is the entire stack delta.** No new HTTP client, no new `nimble_options` schemas in `lib/sigra/`, no new transitive runtime deps. Threadline talks to its own Repo. The other five companion libs (Mailglass cross-link, Accrue, Lockspire, Relyra, Rulestead) are recipe-only and do NOT appear in Sigra's `mix.exs` — the host adds them when needed.

## Feature Triage

### Must Ship in v1.29 (Table Stakes)

| ID | Feature | Why |
|----|---------|-----|
| F-TL-01 | `Sigra.Audit.Forwarders.Threadline` telemetry-tap module | The only code-deep wedge of the milestone |
| F-TL-02 | Two-tier async dispatch (`:auto` / `:async` / `:sync`) | Sigra audit hot path must not regress on Threadline p99 |
| F-TL-03 | Bounded retry + DLQ via Oban worker (when present), fail-open on telemetry handler errors | Adapter failures never poison Sigra; OWASP A09 satisfied |
| F-TL-04 | Optional-dep guard via `if Code.ensure_loaded?(Threadline) do` + `Sigra.Audit.Forwarders.Noop` fallback + boot warning | Follows existing rate-limiter precedent; revised since no `OptionalDeps` SOT exists |
| F-TL-05 | Telemetry parity — separate `[:sigra, :audit, :forward, :ok\|:error]` events | Observability is part of the contract |
| F-AB-01 | `Sigra.Audit.Forwarder` behaviour (single `@callback attach(keyword) :: :ok`) | Locks in the contract before a second forwarder lands; ~30 min cost, future-proofs |
| F-RC-01..06 | Six recipes under `guides/recipes/companion-libs/`: threadline, accrue, lockspire (concrete; cross-link to existing `companion-oauth-provider.md`), mailglass (cross-link only), relyra, rulestead | The doc deliverable the milestone is named after |
| F-NX-01 | `guides/introduction/suite-integration.md` — single canonical narrative entry point with fan-out matrix, "Sigra works fully standalone" banner, ASCII ecosystem diagram | Without this, the recipes are six islands |
| F-EX-01 | Threadline-forwarder demo in `test/example/` (NOT a new `examples/` dir) | Executable proof; reuses existing CI |
| F-PR-01 | Verification proof bundle: forwarder unit + integration tests, dep-on/dep-off CI lanes, recipe contract checks, `mix docs --warnings-as-errors` exit 0 | Standard v1.x close gate |

### Differentiators (Schedule-Permitting)

- **F-D-03 — Correlation-ID propagation Sigra → Threadline.** Closes the loop with Threadline's existing one-way wire.
- **F-D-05 — Recipe-contract test fixtures.** Walks `guides/recipes/companion-libs/*.md` and asserts the required section headings.

### Defer to v1.30+ or Separate Quick Task

- `Sigra.OptionalDeps` canonical SOT module — consolidation refactor; do NOT block v1.29.
- `mix sigra.doctor` task — does not exist today; build separately post-v1.29.
- `mix sigra.gen.adapter threadline` generator task — recipes handle for now.
- Re-landing the Mailglass adapter from Phase 111/114 work — separate scoped task.

### Anti-Features (Explicitly NOT in v1.29)

- Replacing the Sigra audit DB write with a Threadline forward (Pitfall 2).
- `--with-threadline` install flag or any companion-specific install flags (Pitfall 4 — no `--with-*` precedent in repo).
- New top-level `examples/suite-starter/` directory (converged anti-feature).
- Sigra-managed billing/Stripe/SAML metadata/feature-flag storage (Diminishing Returns Wall).
- A separate `sigra_threadline` Hex glue package (ADR 001 precedent).
- Marketing voice in suite docs ("seamlessly," "recommended stack," "just works") — banned by Pitfall 5; lint check on recipe markdown.

## Watch Out For (Top 5 Pitfalls Distilled)

1. **Audit-destination divergence.** Adapter MUST be a post-commit telemetry tap, not a destination swap. Contract test: rolled-back transactions do NOT forward; Threadline downtime does not break login.
2. **Compile-time coupling to Threadline.** Wrap the entire forwarder `defmodule` in `if Code.ensure_loaded?(Threadline) do`. Add `Threadline` modules to `mix.exs` `no_warn_undefined`. Add a dep-off CI lane proving `mix compile && mix test` passes with Threadline absent.
3. **Recipe rot.** Pin each recipe to a `validated_against:` + `last_validated:` date in frontmatter. One canary CI lane (Threadline) exercises the recipe end-to-end. Other recipes are doc-only but versioned.
4. **Cross-library event duplication.** Sigra audit row + telemetry + webhook + Threadline forward + Mailglass event store can all represent the same logical event. Forward the Sigra audit row's UUID + `occurred_at` as the canonical idempotency key; document the fan-out matrix in `suite-integration.md`.
5. **Suite over-promising.** Banned phrases in suite docs: "seamlessly," "just works," "production-ready out of the box," "the recommended way." Every adapter moduledoc + recipe + narrative page MUST carry the "Sigra works fully standalone" banner. Every recipe MUST include a "Failure modes" section.

## Build Order Recommendation (Phases 131 → 136)

Drawn from ARCHITECTURE §8 + PITFALLS phase-mapping; they converged on this ordering.

### Phase 131 — Forwarder behaviour + Threadline forwarder scaffolding + boundary doctrine

**Why first:** It's the only new library code. Every later phase depends on the config shape and the boundary doctrine being settled.

**Artifacts:**
- `lib/sigra/audit/forwarder.ex` — behaviour (single `@callback attach(keyword) :: :ok | {:error, term}`)
- `lib/sigra/audit/forwarders/threadline.ex` — wrapped in `if Code.ensure_loaded?(Threadline) do`
- `lib/sigra/audit/forwarders/noop.ex` — fallback
- `lib/sigra/workers/audit_forward.ex` — optional Oban worker (wrapped in `if Code.ensure_loaded?(Oban.Worker)`)
- `lib/sigra/config.ex` — extend `:audit` NimbleOptions schema with `:forwarders` list
- `lib/sigra/application.ex` — `maybe_warn_missing_forwarder_deps/1` + `attach_forwarders/1`
- `mix.exs` — add `{:threadline, "~> 0.5", optional: true}` + `no_warn_undefined` entries
- Tests: forwarder unit tests + dep-off CI lane
- Boundary doctrine paragraph (draft) for the suite-narrative page

### Phase 132 — Threadline forwarder contract + recipe + Mailglass cross-link recipe

**Why second:** Recipes depend on Phase 131's config shape; Threadline recipe is the canary.

**Artifacts:**
- Contract tests: rolled-back transactions do NOT forward; Threadline-down does not break auth; canonical UUID + `occurred_at` propagation
- `guides/recipes/companion-libs/threadline.md` (full integration recipe)
- `guides/recipes/companion-libs/mailglass.md` (~1 page cross-link; do NOT re-land Phase 111/114 adapter)
- `mix.exs` `extras:` + `groups_for_extras` updates (new `"Companion Libraries"` group)

### Phase 133 — Suite narrative + ecosystem diagram

**Why third:** Narrative references Phase 131/132 artifacts.

**Artifacts:**
- `guides/introduction/suite-integration.md` (single canonical entry point)
- ASCII ecosystem diagram (not Mermaid — ExDoc compatibility)
- Fan-out matrix table (auth events × Sigra DB / telemetry / webhooks / Threadline forwarder / Mailglass)
- "Sigra works fully standalone" banner
- Banned-phrase lint applied to all suite docs
- README addition pointing at `suite-integration.md`

### Phase 134 — Recipe-only companion libs (parallelizable with 133)

**Artifacts:**
- `guides/recipes/companion-libs/accrue.md` — references `Accrue.Auth` behaviour; cross-links to `lib/sigra/hooks.ex` for seat-limit gating
- `guides/recipes/companion-libs/lockspire.md` — concrete recipe; cross-links to existing `guides/recipes/companion-oauth-provider.md`
- `guides/recipes/companion-libs/relyra.md` — SAML 2.0 SP wiring; cites v1.27 ENT-SSO OIDC-vs-SAML decision matrix
- `guides/recipes/companion-libs/rulestead.md` — `Rulestead.enabled?` from Sigra-protected controller; `RulesteadPolicy` from `current_scope`
- Every recipe carries: validated-against version pin, last_validated date, failure-modes section, non-goals section

### Phase 135 — Reference example (extend `test/example/`)

**Artifacts:**
- `test/example/mix.exs` — add `{:threadline, "~> 0.5", only: [:dev, :test]}`
- `test/example/lib/example/accounts.ex` — add `forwarders:` block under `audit:` keyword
- `test/example/test/example_web/threadline_forwarder_test.exs` — assert that a Sigra login event materializes as a Threadline audit row
- `test/example/AGENTS.md` — document the Threadline demo wiring
- Existing CI lanes for `test/example/` cover this — no new CI surface

### Phase 136 — Verification proof bundle + milestone audit

**Artifacts:**
- All forwarder unit + integration tests passing
- `mix test test/sigra/audit/` clean
- `mix test` in `test/example/` clean
- Dep-off CI lane (Threadline absent) green
- `mix docs --warnings-as-errors` exit 0 (the gate that nearly blocked v1.28 PROOF-01)
- `mix credo --strict` clean
- Optional: recipe contract test (F-D-05) if shipped
- `131-VERIFICATION.md` through `135-VERIFICATION.md` filed
- `.planning/milestones/v1.29-ROADMAP.md`, `v1.29-REQUIREMENTS.md`, `v1.29-MILESTONE-AUDIT.md`

### Dependency chain

```
131 (library code + behaviour + boundary doctrine)
  ↓
132 (Threadline recipe needs config shape + contract tests)
  ↓
  ├─→ 133 (narrative refs recipe + ecosystem diagram)
  ├─→ 134 (recipe-only siblings, parallelizable with 133)
  ↓
  135 (example app demos forwarder, refs recipe)
  ↓
136 (verification gates all of above)
```

## Research Flags (For Roadmap Authoring)

| Phase | Research needed? | Why |
|-------|------------------|-----|
| 131 | NO | Pattern-match on existing rate-limiter / worker triad; everything in `lib/sigra/audit.ex` already mapped |
| 132 | LIGHT | Need to confirm Threadline `record_action/2` parameter shape against current Hex `0.5.0` source |
| 133 | NO | Pure narrative; pull from already-completed research |
| 134 | LIGHT | Each recipe needs a 30-min validation pass against the latest companion-lib Hex version to pin `validated_against:` |
| 135 | NO | Standard extend-`test/example/` pattern; no new CI scaffolding |
| 136 | NO | Standard milestone-close audit |

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (companion-lib Hex versions, optional-dep shape) | HIGH | Verified directly against hex.pm on 2026-05-27 |
| Features (table-stakes vs differentiator split) | HIGH | Anchored in MILESTONE-ARC non-goals + ADR 001 precedent + repo-verified existing surfaces |
| Architecture (forwarder pattern + recipe location + example placement) | HIGH | Converged across 3 of 4 research files |
| Pitfalls (top 5) | HIGH | Each pitfall is grounded in a specific Sigra precedent |
| Mailglass-on-release-branch claim | HIGH (against) | `git ls-tree HEAD` on `v1.28-data-lifecycle` returns no `lib/sigra/mailers/adapters/mailglass.ex`; CHANGELOG stops at `[0.3.0]` |
| `Sigra.OptionalDeps` existence | HIGH (against) | `grep -r "Sigra.OptionalDeps" lib/` returns zero hits |
| `mix sigra.doctor` existence | HIGH (against) | `lib/mix/tasks/` contains no `doctor.ex` |

**Overall confidence:** HIGH

### Gaps to address during planning

- **Pin exact Threadline `record_action/2` signature** before Phase 132 cuts code.
- **Decide Mailglass disposition explicitly** in the v1.29 REQUIREMENTS doc. Recommend: "recipe-only in v1.29; orphaned Phase 111/114 work goes to a separate post-v1.29 quick task." Do not paper over this.
- **Decide `Sigra.OptionalDeps` SOT timing.** Recommend: separate refactor quick task, not in v1.29.

## Open Questions to Escalate (3–5 Max)

1. **Mailglass disposition.** Re-land the orphaned Phase 111/114 adapter in v1.29, or accept "recipe-only" and file a separate quick task for the re-land? **Recommend: recipe-only.**
2. **`Sigra.Audit.Forwarder` behaviour or no behaviour?** Threadline is the only forwarder. Behaviour costs ~30 minutes; locks the contract; future-proofs. **Recommend: ship the behaviour now.**
3. **Suite-narrative location.** `guides/introduction/suite-integration.md` (next to `getting-started.md`) or `guides/recipes/companion-libs/README.md` (next to the recipes)? **Recommend: `guides/introduction/suite-integration.md`** — narrative entry point, not a recipe.
4. **`Sigra.OptionalDeps` SOT — defer or include?** **Recommend: defer to a separate quick task post-v1.29.**
5. **`mix sigra.doctor` — defer or include?** **Recommend: defer.** Forwarder uses boot warnings + its own telemetry events instead.

## Sources

### Primary research files (all HIGH confidence, all written 2026-05-27)

- `.planning/research/STACK.md` — Hex verification + library boundary rationale + Threadline-as-forwarder reasoning
- `.planning/research/FEATURES.md` — F-TL-01..F-PR-01 + Differentiator/Anti-feature triage + recipe section contract
- `.planning/research/ARCHITECTURE.md` — Forwarder-not-adapter naming; `companion-libs/` subdir convention; `test/example/` reference example; phase 131→136 ordering
- `.planning/research/PITFALLS.md` — 8 critical pitfalls; tech-debt patterns; integration gotchas; "looks done but isn't" checklist

### Repo evidence (HIGH confidence, 2026-05-27)

- `lib/sigra/audit.ex` (528 lines) — telemetry contract, D-23 forbidden-keys policy, `emit_telemetry_from_changes/2` rollback-safety invariant
- `lib/sigra/rate_limiter.ex`, `lib/sigra/rate_limiters/{hammer,noop}.ex` — behaviour + impl + Noop fallback triad
- `lib/sigra/workers/{account_deletion,audit_cleanup}.ex` — `if Code.ensure_loaded?(Oban.Worker) do` optional-worker precedent
- `lib/sigra/application.ex:68-88` — boot-warning pattern
- `lib/sigra/hooks.ex` — runtime hook registry designed for Accrue (Phase 13 D-05)
- `lib/sigra/install/feature.ex` + `lib/mix/tasks/sigra.install.ex:41-46` — install-feature behaviour and absence of `--with-*` flag precedent
- `mix.exs:65-87` + `mix.exs:163-218` — `no_warn_undefined` + ExDoc `extras:`/`groups_for_extras` wiring
- `.github/workflows/ci.yml` — `test/example/` CI wiring (3 jobs)
- `guides/recipes/companion-oauth-provider.md` — v1.7 INTG-01 recipe section pattern precedent
- `.planning/decisions/001-defer-sigra-lockspire-glue-package.md` — ADR 001 deferral rationale

### Companion-library evidence (HIGH confidence, 2026-05-27)

- hex.pm/packages/threadline `0.5.0`, 2026-05-08
- hex.pm/packages/mailglass `1.2.0`, 2026-05-26
- hex.pm/packages/accrue `1.2.0`, 2026-05-27
- hex.pm/packages/lockspire `1.2.0`, 2026-05-27
- hex.pm/packages/relyra `1.2.0`, 2026-05-25
- github.com/szTheory/rulestead — `0.1.x` Hex line installable per README

### Milestone context (HIGH confidence)

- `.planning/PROJECT.md` — v1.29 active milestone scope + non-goals
- `.planning/MILESTONE-ARC.md` — SUITE-INTEGRATION candidate scope; Diminishing Returns Wall
- `.planning/MILESTONES.md` — v1.25 EMAIL-RAILS narrative (with the inconsistency flagged above)

---
*Research synthesized: 2026-05-27 — Ready for v1.29 requirements authoring.*
