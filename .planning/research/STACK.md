# Project Research — STACK for v1.29 SUITE-INTEGRATION

**Project:** Sigra
**Milestone:** v1.29 SUITE-INTEGRATION
**Researched:** 2026-05-27
**Confidence:** HIGH (companion lib facts verified against hex.pm + hexdocs.pm + szTheory GitHub on 2026-05-27)

## Headline Recommendation

**Add no new Sigra-core deps in `mix.exs`.** SUITE-INTEGRATION is a recipes-and-thin-adapters milestone, not a "Sigra grows a new dependency surface" milestone. The only adapter that justifies *library-owned code* on the Sigra side is Threadline (audit destination), and it should follow the **same optional-dep pattern already used for Oban/Swoosh/Assent/Bcrypt** — `optional: true` + `no_warn_undefined` guard + `Sigra.OptionalDeps`-style boot check. Every other companion lib (Accrue, Lockspire, Relyra, Rulestead, Mailglass cross-link) is best served by a `guides/recipes/<lib>.md` page plus, where applicable, a *generated-host* adapter module — not library-owned glue.

This keeps the rule from `CLAUDE.md` honest: "Minimal transitive deps. Copy-paste over deps when code is small and stable." Threadline is the one place where the boundary justifies a library module because the *adapter shape* needs to live in lockstep with `Sigra.Audit`'s telemetry/Multi semantics; everything else is glue the host writes once.

## v1.25 Mailglass Posture — Honest Correction

Before proposing the v1.29 stack, the milestone context's claim that **"v1.25 EMAIL-RAILS shipped an optional `Sigra.Mailers.Adapters.Mailglass` + `--with-mailglass` install path"** does not match the current `v1.28-data-lifecycle` working tree:

- `lib/sigra/mailers/adapters/mailglass.ex` is **not tracked on `v1.28-data-lifecycle`** (verified via `git ls-tree HEAD`).
- The adapter file *was authored* in commits `b75189e` and `470af1f` (Phase 111/114 work) but those commits are only reachable on `backup/pre-cleanup-20260525-073728`, `chore/phase-88-uat-evidence`, `wip/2026-05-23-example-isolation`, and `wip/example-admin-drift-20260525` — **none of which is the current release lineage**.
- `mix.exs` on HEAD contains no `:mailglass` optional dep entry, and `CHANGELOG.md` stops at `[0.3.0]` (v1.26 PK-LIFECYCLE).
- `.planning/MILESTONES.md` describes v1.25 as shipped; `.planning/STATE.md` and the milestone bookkeeping treat it as shipped — but the code is not in the released branch.

**Implication for v1.29 planning:** the "Mailglass cross-link" requirement in `MILESTONE-ARC.md` SUITE-INTEGRATION scope is **not** a "confirm and link"; it is **"decide what to do about the orphaned Phase 111/114 work"** — likely either (a) cherry-pick / re-land the adapter on the v1.29 branch as part of the suite recipes, or (b) consciously drop the adapter and ship a recipe-only Mailglass integration. The roadmap author needs to decide; this is not a stack question, but it gates whether `{:mailglass, "~> 1.2", optional: true}` belongs in `mix.exs`.

## Companion Library Facts (Hex / GitHub, 2026-05-27)

| Library | Hex | Hex version | Last update | One-line scope | Integration shape with Sigra |
|---------|-----|-------------|-------------|----------------|------------------------------|
| **Threadline** | yes — [`threadline`](https://hex.pm/packages/threadline) | `0.5.0` | 2026-05-08 | Audit platform: trigger-backed row capture with actor, intent, request context | `Threadline.Plug` reads actor via `:actor_fn :: (Plug.Conn.t() -> ActorRef.t() \| nil)`; `Threadline.record_action/2` writes via host's `:repo`; data model has `%ActorRef{}`, `%AuditChange{}`, `%AuditTransaction{}`; **no formal adapter behaviour exposed** — Sigra writes TO Threadline, Threadline does not call into Sigra |
| **Mailglass** | yes — [`mailglass`](https://hex.pm/packages/mailglass) | `1.2.0` | 2026-05-26 | Transactional email framework on top of Swoosh (rendering, events, webhooks, suppression) | Mailable pattern: `MyApp.UserMailer.welcome(user) \|> Mailglass.deliver()` — **not a Swoosh adapter**, sits above Swoosh. Sigra-side glue lives in a thin `Sigra.Mailer`-behaviour-implementing adapter (already prototyped in Phase 111) |
| **Accrue** | yes — [`accrue`](https://hex.pm/packages/accrue) | `1.2.0` | 2026-05-27 | Billing / subscription state ("Stripe-shaped surface as plain Elixir") | **Explicit `Accrue.Auth` behaviour** with 5 required + 2 optional callbacks (`current_user/1`, `require_admin_plug/0`, `user_schema/0`, `log_audit/2`, `actor_id/1`, optional `step_up_challenge/2`, `verify_step_up/3`). The host implements the adapter, configures Accrue with it. No Sigra library code needed |
| **Lockspire** | yes — [`lockspire`](https://hex.pm/packages/lockspire) | `1.2.0` | 2026-05-27 | Embedded OAuth/OIDC authorization server for Phoenix (Sigra is the *end-user* auth; Lockspire turns the same host INTO an IdP for third-party clients) | Per Lockspire docs the host seam resolves users via `conn.assigns.current_scope.user` — Lockspire docs **already cite "Sigra-shaped account resolution"** as the canonical reference. Glue is host-app config, not library-to-library deps (per [`.planning/decisions/001-defer-sigra-lockspire-glue-package.md`](../decisions/001-defer-sigra-lockspire-glue-package.md)) |
| **Relyra** | yes — [`relyra`](https://hex.pm/packages/relyra) | `1.2.0` | 2026-05-25 | Strict-by-default SAML 2.0 Service Provider for Phoenix (intentionally **no** OIDC, **no** OAuth, **no** SCIM) | Standalone SP — own `mix relyra.install`, own provider presets (Okta, Entra ID, Google Workspace), own admin. Integration shape: Relyra completes a SAML ACS round-trip and hands the host an authenticated subject; the host then mints a Sigra session. **No behaviour exposed by either side** — recipe-level wiring only |
| **Rulestead** | yes — [`rulestead`](https://hex.pm/packages/rulestead) | `0.1.x` (1.0.0 narrative GA 2026-05-21 but installable Hex remains `0.1.x`) | 2026-05-27 | Typed feature flags + remote config + experimentation | `Rulestead.enabled?("flag", conn)` — reads context from `conn`; the optional `rulestead_admin "/admin/flags", policy: MyApp.RulesteadPolicy` accepts a host-supplied authorization policy module. Sigra-side glue is a generated-host `RulesteadPolicy` that reads `conn.assigns.current_scope` — no library code needed |

**Rulestead Hex publish caveat:** the README does ship `{:rulestead, "~> 0.1"}`, so it is installable. The version mismatch (1.0.0 narrative GA vs 0.1.x Hex line) is a sibling-package release-cadence quirk worth flagging in the recipe but not blocking.

## What Goes Into Sigra `mix.exs` for v1.29

```elixir
defp deps do
  [
    # ... existing v1.28 deps unchanged ...

    # NEW in v1.29 — optional, Threadline-only:
    {:threadline, "~> 0.5", optional: true},

    # CONDITIONAL — only if v1.29 decides to re-land Phase 111/114:
    # {:mailglass, "~> 1.2", optional: true},
  ]
end

# Add to elixirc_options no_warn_undefined:
#   Threadline,
#   Threadline.Plug,
#   Threadline.ActorRef,
#   # plus Mailglass.Message, Mailglass etc. iff Mailglass re-lands
```

That is the entire stack delta for v1.29. **No new transitive runtime deps** (no Req, no Tesla, no Finch — Threadline talks to its own Repo, not over HTTP; the other companion libs don't need Sigra-side wire calls). **No new `nimble_options` schemas in `lib/sigra/`** for adapter config — Threadline's adapter takes a small fixed set of keys (`:repo`, optional `:include_metadata`, optional `:actor_resolver`) that fit the existing pattern already used by `Sigra.Audit` callers.

## Why Threadline Is a Library Module, Not a Recipe

A library module (`Sigra.Audit.Adapters.Threadline`) is justified over a copy-paste recipe **only** when:

1. The adapter is non-trivial enough that drift between hosts becomes a real risk.
2. The adapter's correctness depends on Sigra-internal invariants the host doesn't see.
3. The adapter benefits from version-pinned testing inside Sigra's CI.

Threadline meets all three:

1. **Non-trivial:** Sigra writes audit rows via `Ecto.Multi` + `log_multi_safe/3` with telemetry-on-commit-only semantics (`emit_telemetry_from_changes/2`). Threadline records via `record_action/2` with its own `%ActorRef{}` + `%AuditTransaction{}` shape. The mapping (Sigra scope → `ActorRef`, Sigra `metadata` → Threadline `:verb`/`:category`/`:reason`/`:correlation_id`/`:request_id`/`:job_id`) is doable but not five lines.
2. **Sigra-internal invariants:** the adapter must *not* fire on rollback (matches Sigra's `emit_telemetry_from_changes/2` rule — telemetry MUST NOT fire when the enclosing transaction rolls back, per `lib/sigra/audit.ex` lines 79–82). A naïve recipe would get this wrong.
3. **CI value:** Sigra already has `audit_45` CI alias for atomic audit invariants. A library-owned adapter can ride that lane with `optional: true` + a dep-on / dep-off matrix (per `Sigra.OptionalDeps` precedent shipped in v1.21 HARD-02).

The other companion libs do not meet criteria 2 or 3 — their integration is host-config, not library-internal-invariant-sensitive.

## Adapter Boundary: How `Sigra.Audit.Adapters.Threadline` Fits

`Sigra.Audit` today does **not** expose a formal adapter behaviour. Reading [`lib/sigra/audit.ex`](../../lib/sigra/audit.ex):

- Audit writes happen via direct `Ecto.Multi.insert` into a host-configured `:audit_schema` (`lib/sigra/audit.ex` line 269).
- Telemetry `[:sigra, :audit, :log]` is the cross-cutting hook callers can subscribe to (line 37).
- `log_safe/3` and `log_multi_safe/3` are no-ops when `:audit_schema` is `nil` (lines 167–169, 257–260).

There are **two coherent boundary shapes** for the Threadline adapter. The roadmap author should pick one; both are reasonable:

### Option A (recommended): Telemetry-subscriber adapter — zero `Sigra.Audit` changes

`Sigra.Audit.Adapters.Threadline` is a telemetry handler that subscribes to `[:sigra, :audit, :log]` and mirrors the audit row into Threadline via `Threadline.record_action/2`. The host attaches it in `application.ex`. Because Sigra already fires telemetry only on successful commit (via `emit_telemetry_from_changes/2`), the rollback-safety invariant is preserved for free.

- **Pro:** Zero changes to `Sigra.Audit`. Survives any v1.30+ audit refactor. Matches the precedent that Sigra audit already treats telemetry as the cross-cutting observability boundary (`@telemetry_event [:sigra, :audit, :log]`, D-24).
- **Con:** Threadline's `record_action/2` and Sigra's audit row each become their own DB row — two rows per event. Acceptable because Threadline is the canonical audit destination for adopters who pick it; Sigra's audit table is the library-owned belt, Threadline is the operator's suspenders.

### Option B: Multi-extension adapter — `Sigra.Audit` gains an optional `:audit_adapter` opt

`Sigra.Audit.log_multi_safe/3` learns one new option `:audit_adapter` (default `nil`) that, when set to a module, has that module append additional `Ecto.Multi` steps inside the same transaction. `Sigra.Audit.Adapters.Threadline` implements this by calling `Threadline.record_action/2` inside an `Ecto.Multi.run/3` step.

- **Pro:** Single atomic transaction across both audit destinations.
- **Con:** Couples `Sigra.Audit` to a new public surface that has to be semver-stable. Costlier to add and remove.

**Recommendation: Option A.** It honors the already-shipped D-02 decision ("direct `Ecto.Multi` writes, not telemetry subscribers" for the library's *primary* write path) by treating Threadline as an *additional* observability destination, not a replacement audit primary — which is the actual relationship. Adopters who want single-source audit can configure Threadline as the primary and turn off Sigra's `:audit_schema`; adopters who want dual-write get it via the telemetry adapter.

## Other Companion Lib Integrations — Recipes, Not Library Code

| Companion | Recipe file | Stack delta in Sigra | Generated-host delta |
|-----------|-------------|----------------------|----------------------|
| **Accrue** | `guides/recipes/accrue-billing.md` | none | Host implements `MyApp.Accrue.Auth` (the `Accrue.Auth` behaviour). Cite `Sigra.Scope` extraction patterns. Reference `Sigra.Hooks` registry (`lib/sigra/hooks.ex`) for seat-limit gating on `before_add_member` and subscription cleanup on `after_member_remove` — that pattern is already designed-for-Accrue per Phase 13 D-04/D-05 |
| **Lockspire** | `guides/recipes/lockspire-companion-oauth-provider.md` (and update existing `guides/recipes/companion-oauth-provider.md` if it currently exists) | none | Host wires Lockspire to read `conn.assigns.current_scope.user` — Lockspire docs already cite this. ADR 001 stays accepted; no `sigra_lockspire` glue package |
| **Mailglass** | `guides/recipes/mailglass-email-framework.md` | conditional on re-landing Phase 111/114 work (see "Honest Correction" section above) | If re-landed: host generates `--with-mailglass` mailer; if not: host wires `MyApp.UserMailer.deliver \|> Mailglass.deliver()` with Sigra's `Sigra.Mailer` behaviour pointing at a host-owned shim |
| **Relyra** | `guides/recipes/relyra-saml-sp.md` | none | Host runs `mix relyra.install`; after SAML ACS callback, host mints a Sigra session via existing `Sigra.Session.create_session/3`. Cross-reference v1.27 ENT-SSO docs to distinguish OIDC-via-Assent path (in Sigra) from SAML-via-Relyra path (out-of-Sigra) |
| **Rulestead** | `guides/recipes/rulestead-feature-flags.md` | none | Host generates `MyApp.RulesteadPolicy` that reads `conn.assigns.current_scope` for admin policy. Show `Rulestead.enabled?` from a Sigra-protected controller |

## What Stays Explicitly OUT of the Stack

Per the milestone non-goals + `CLAUDE.md` constraints + ADR 001:

- **No Hex-published `sigra_threadline` / `sigra_accrue` / `sigra_lockspire` glue packages.** ADR 001 explicitly defers `sigra_lockspire`; the same logic applies to every other companion. Glue packages would force a version-lock matrix across Sigra + companion-lib cores for no real DX gain — recipes + thin host modules cover it.
- **No `req` / `tesla` / `finch` core dep.** None of the v1.29 adapters need HTTP from inside the Sigra library. (Threadline is a Repo-backed library; the rest are host-side.) If a future recipe needs HTTP it lives in generated-host code where the host already has its preferred HTTP client.
- **No new `nimble_options` schemas in the Sigra library for companion-lib config.** Adapter options stay small enough that the existing per-call keyword list pattern is enough. `nimble_options` is already in `mix.exs` (`~> 1.1`) — no version bump needed.
- **No vendor lock-in.** No hosted-control-plane companion-lib paths get adopted as Sigra defaults. Every companion-lib integration is opt-in, optional-dep-guarded, and has a "Sigra works without it" baseline. This matches the MILESTONE-ARC GSD Defaults rule "keep Sigra core provider-agnostic and Phoenix-native."
- **No companion-lib roadmap ownership.** Per SUITE-INTEGRATION non-goals: Sigra does not pin companion-lib versions tighter than necessary, does not regress when a companion-lib ships a breaking change, and does not claim sister-lib features in Sigra docs.
- **No `Sigra.Audit` behaviour module added to formalize a generic audit-adapter contract.** That would be premature generalization — Threadline is the only known adapter, Option A (telemetry-subscriber) needs zero new behaviour, and a generic audit-adapter behaviour is what would *force* Option B's coupling that we're rejecting.

## Version Compatibility & Constraints

| Companion | Constraint | Why |
|-----------|------------|-----|
| `threadline ~> 0.5` | Pin to `~> 0.5` (not `~> 0`) | 0.x release — minor bumps may break the public API per Hex convention. Re-evaluate at `1.0`. |
| `mailglass ~> 1.2` (conditional) | Pin to `~> 1.2` if re-landed | 1.x stable; safe minor-bump compatibility. |
| `accrue ~> 1.2` | **Not in Sigra `mix.exs`** — host adds it | Host implements `Accrue.Auth` behaviour; Sigra has no Accrue compile-time touchpoint. |
| `lockspire ~> 1.2` | **Not in Sigra `mix.exs`** | Per ADR 001. |
| `relyra ~> 1.2` | **Not in Sigra `mix.exs`** | Standalone SP; no Sigra compile-time touchpoint. |
| `rulestead ~> 0.1` | **Not in Sigra `mix.exs`** | Host integration; recipe references `~> 0.1` to match published Hex line. |
| Phoenix `~> 1.8`, Ecto `~> 3.12` | Unchanged | Existing constraints already cover everything v1.29 needs. |
| Elixir `~> 1.18`, OTP 27+ | Unchanged | All companion libs target the same baseline (verified Mailglass `~> 1.18`; others ride Phoenix 1.8's OTP 27 floor). |

## Tooling Additions

None required. Existing tooling already covers v1.29:

- `ex_doc ~> 0.40` — already emits `llms.txt`, used for the suite-narrative guide.
- `credo ~> 1.7` `--strict` — already runs on CI; new adapter module rides existing lane.
- `dialyxir ~> 1.4` — already on CI; the `no_warn_undefined` list grows by the Threadline modules.
- `Sigra.OptionalDeps` — the v1.21 HARD-02 boot-validation SOT — gains a Threadline entry so `mix sigra.doctor` reports adapter readiness.
- `mix docs --warnings-as-errors` — already merge-blocking after the v1.28 PROOF-01 unblock; recipe additions in `guides/recipes/` ride the existing lane.

## Sources

- [hex.pm/packages/threadline](https://hex.pm/packages/threadline) — `0.5.0`, 2026-05-08 (HIGH confidence, verified directly)
- [hex.pm/packages/mailglass](https://hex.pm/packages/mailglass) — `1.2.0`, 2026-05-26 (HIGH confidence, verified directly)
- [hex.pm/packages/accrue](https://hex.pm/packages/accrue) — `1.2.0`, 2026-05-27 (HIGH confidence, verified directly)
- [hex.pm/packages/lockspire](https://hex.pm/packages/lockspire) — `1.2.0`, 2026-05-27 (HIGH confidence, verified directly)
- [hex.pm/packages/relyra](https://hex.pm/packages/relyra) — `1.2.0`, 2026-05-25 (HIGH confidence, verified directly)
- [github.com/szTheory/rulestead](https://github.com/szTheory/rulestead) — README confirms `{:rulestead, "~> 0.1"}` installable line; narrative GA at `v1.0.0` 2026-05-21 (HIGH confidence, README-verified; `hex.pm/packages/rulestead` URL returned 404 at lookup time but the package is installable per README)
- [hexdocs.pm/threadline/Threadline.Plug.html](https://hexdocs.pm/threadline/Threadline.Plug.html) — `:actor_fn :: (Plug.Conn.t() -> ActorRef.t() \| nil)` confirmed (HIGH confidence)
- [hexdocs.pm/threadline/Threadline.html](https://hexdocs.pm/threadline/Threadline.html) — `record_action/2`, `%ActorRef{}`, `%AuditChange{}`, `%AuditTransaction{}` confirmed (HIGH confidence)
- [hexdocs.pm/accrue/Accrue.Auth.html](https://hexdocs.pm/accrue/Accrue.Auth.html) — `Accrue.Auth` behaviour with 5 required + 2 optional callbacks confirmed (HIGH confidence)
- [hexdocs.pm/lockspire/supported-surface.html](https://hexdocs.pm/lockspire/supported-surface.html) — docs already cite "Sigra-shaped account resolution from `conn.assigns.current_scope.user`" (HIGH confidence)
- [hexdocs.pm/mailglass/readme.html](https://hexdocs.pm/mailglass/readme.html) — Mailglass is a framework above Swoosh, not a Swoosh adapter; mailable pattern confirmed (HIGH confidence)
- [github.com/szTheory](https://github.com/szTheory?tab=repositories) — all seven repos active, last updated 2026-05-25..27 (HIGH confidence)
- Local repo evidence — [`lib/sigra/audit.ex`](../../lib/sigra/audit.ex) (audit behaviour shape + D-02 + telemetry rollback rule), [`lib/sigra/hooks.ex`](../../lib/sigra/hooks.ex) (runtime hook registry designed for Accrue per Phase 13 D-05), [`mix.exs`](../../mix.exs) (optional-dep pattern), [`.planning/decisions/001-defer-sigra-lockspire-glue-package.md`](../decisions/001-defer-sigra-lockspire-glue-package.md) (Lockspire deferral), [`.planning/phases/13-organizations-schemas-context/13-CONTEXT.md`](../phases/13-organizations-schemas-context/13-CONTEXT.md) (Accrue interop as design validation), `git log --all --oneline` (Phase 111/114 Mailglass adapter authored on `b75189e` / `470af1f` but only reachable from backup/wip branches, not from `v1.28-data-lifecycle` HEAD) (HIGH confidence, repo-verified 2026-05-27)

---
*Stack research for: Sigra v1.29 SUITE-INTEGRATION (companion-library integration recipes + Threadline audit adapter)*
*Researched: 2026-05-27*
