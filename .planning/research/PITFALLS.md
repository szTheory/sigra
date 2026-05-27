# Pitfalls Research — v1.29 SUITE-INTEGRATION

**Domain:** Companion-library integration for an established Phoenix auth library (Sigra + szTheory OSS suite: Accrue, Lockspire, Mailglass, Relyra, Rulestead, Threadline)
**Researched:** 2026-05-27
**Confidence:** HIGH — anchored in Sigra's own precedent (v1.21 HARD-02 optional-dep gating, v1.25 EMAIL-RAILS Mailglass adoption, ADR 001 Lockspire deferral) and the published `Sigra.Audit` module (`lib/sigra/audit.ex`, 528 lines) whose contract every adapter must respect.

---

## Critical Pitfalls

### Pitfall 1: Compile-time coupling to an optional companion library

**What goes wrong:**
A new adapter (e.g. `Sigra.Audit.Adapters.Threadline`) references `Threadline.Event` or `Threadline.Repo` at compile time. When an adopter installs Sigra without Threadline, the application fails to compile — or worse, succeeds but raises `UndefinedFunctionError` at runtime when the adapter is invoked. Sigra's release breaks for everyone not opted into Threadline.

**Why it happens:**
- Idiomatic Elixir code references modules by name; the compiler emits BEAM references to those names. When the dep is missing, those references either generate warnings (`no_warn_undefined` not set) or runtime `:undef`.
- The Mailglass `OptionalDeps.Sigra` precedent (`test/example/deps/mailglass/lib/mailglass/optional_deps/sigra.ex`) shows the correct pattern: **wrap the entire `defmodule` in `if Code.ensure_loaded?(...)` and set `@compile {:no_warn_undefined, [Module]}`** — but a casual adapter author will skip both.
- Sigra has **no canonical `Sigra.OptionalDeps` SOT module today.** The v1.21 HARD-02 milestone shipped `mix sigra.doctor` + boot-time `Code.ensure_loaded?` guards scattered across `lib/sigra/{delivery,application,jwt,oauth,mfa,crypto,plug,account}.ex` (29 grep hits). There is no single registry to add a new optional dep to — each adapter author re-invents the guard, and inconsistency creeps in.

**How to avoid:**
1. **Introduce a canonical `Sigra.OptionalDeps` namespace** before adding the Threadline adapter — mirror Mailglass's pattern (one module per optional dep, conditionally compiled, declaring `available?/0`).
2. The Threadline adapter module file must open with `if Code.ensure_loaded?(Threadline) do … end` wrapping the entire `defmodule`. The module **must not exist at all** when Threadline is absent.
3. Set `@compile {:no_warn_undefined, [Threadline, Threadline.Event, …]}` inside the conditional `defmodule` so that on warm rebuilds the compiler does not emit phantom warnings against missing modules.
4. Callers (config resolution, telemetry handlers, doctor checks) **must guard via `Code.ensure_loaded?(Sigra.Audit.Adapters.Threadline)`** — not the upstream `Threadline` module — because conditional compilation means the *adapter* module is the existence signal.
5. Extend `mix sigra.doctor` (already shipped in HARD-02) with a per-adapter feature row: when `config :sigra, audit: [adapter: Sigra.Audit.Adapters.Threadline]` is set, doctor checks that `Threadline` is loaded, the Threadline endpoint config is present, and the adapter module is compiled. Failure prints a remediation line, not a stack trace.
6. Add a CI lane that compiles and tests Sigra **with Threadline absent from `mix.lock`** — the HARD-02 precedent of "3 dep-off CI lanes" is the model. Without this lane, optional-dep regressions ship undetected.

**Warning signs:**
- A PR adds `{:threadline, "~> X.Y"}` to `mix.exs` without `optional: true`.
- A PR references `Threadline.…` outside a `Code.ensure_loaded?` guard or outside an `if`-wrapped `defmodule`.
- `mix compile --force` emits `warning: Threadline.X.Y/Z is undefined` when Threadline is not in the lock.
- `mix sigra.doctor` does not list the Threadline adapter as a known feature row.
- A new adapter author copy-pastes scattered `Code.ensure_loaded?(SomeDep)` calls instead of adding a `Sigra.OptionalDeps.Threadline` gateway module.

**Phase to address:**
Phase 131 (foundational adapter scaffolding). Land `Sigra.OptionalDeps.Threadline` (and the namespace SOT if it does not exist) **before** Phase 132 builds the actual adapter logic. Adopt a "dep-off CI lane" gate as a merge-blocking check.

---

### Pitfall 2: Audit-destination divergence between Sigra DB rows and Threadline

**What goes wrong:**
The host configures `Sigra.Audit.Adapters.Threadline` and expects audit rows to land in Threadline. The adapter either:
- (a) **Replaces** the DB write — audit rows stop landing in Postgres, but `Sigra.Audit.Assertions` (test helpers) and `Sigra.Admin.Audit` (admin LiveView) still query the local `audit_events` table → admin views show empty audit history while Threadline holds the truth; tests pass against an empty table; operators lose forensic data when Threadline is down.
- (b) **Dual-writes** without a defined precedence — the DB write commits, Threadline POST 500s, retry storms generate duplicates, and audit timestamps in the two systems disagree because Threadline assigns its own.
- (c) **Replaces silently** when Threadline is unreachable — the adapter swallows the error in a `Task.start/1` and the auth flow continues, but the audit row never lands anywhere → the OWASP "log auth events" invariant is silently broken.

**Why it happens:**
- `Sigra.Audit.log_multi_safe/3` is co-fated to the **caller's `Repo.transaction/1`** — the audit row commits or rolls back with the auth-state change (`lib/sigra/audit.ex:254-261`). Threadline is an HTTP/event sink, not a Postgres transaction participant; co-fate is not achievable for a remote sink.
- Sigra has shipped 20+ phases of audit-atomicity work (v1.9 → v1.21 AUD-04..AUD-21) precisely to make audit writes co-fated with state changes. A non-co-fated remote adapter undoes that invariant for any event it claims to own.
- The current `Sigra.Audit` module has **no behaviour/adapter abstraction.** It writes directly to `:audit_schema` via `Ecto.Multi` and emits `[:sigra, :audit, :log]` telemetry on commit. There is no defined "swap destination" seam, so adapter authors will invent one ad-hoc.

**How to avoid:**
1. **Default to telemetry-tap, not write-replacement.** The Threadline adapter should be a `:telemetry.attach/4` handler on `[:sigra, :audit, :log]` that forwards committed rows to Threadline. DB rows remain the source of truth; Threadline is a *projection*. This preserves co-fate (only committed rows fire telemetry — see `lib/sigra/audit.ex:286-302`), preserves admin LiveView coverage, and makes Threadline downtime non-blocking.
2. **Document the destination contract explicitly** in the adapter moduledoc and the recipe: *"DB rows remain authoritative. Threadline is a forwarded projection. If you want Threadline to be the SOT, you are outside the supported contract — and you also need to replace `Sigra.Admin.Audit` views, `Sigra.Audit.Assertions`, and the audit retention/cleanup worker (`Sigra.Workers.AuditCleanup`)."*
3. **Failure mode must be fail-open, not fail-closed.** Threadline 500/timeout must not break the user-facing auth flow. The telemetry handler runs out-of-band; failures emit a separate `[:sigra, :audit, :forward_error]` telemetry event for the host to alert on.
4. **Retries belong in the adapter's queue (Oban worker), not in the telemetry handler.** Inline retries inside the telemetry handler block the BEAM scheduler and risk retry storms when Threadline is partially degraded. The adapter's worker should use exponential backoff and a dead-letter terminal state (same shape as `Sigra.Workers.WebhookDelivery` from v1.22).
5. **De-duplicate on the Threadline side using a stable event ID.** The audit row's UUID primary key is the natural idempotency key; the adapter must include it in the Threadline payload. Without this, retries create duplicate Threadline events.
6. **Add a milestone-level non-goal:** "Sigra does not support write-replacement audit adapters. Adapters tap committed audit rows; the DB remains the SOT." Capture in MILESTONE-ARC's Diminishing Returns Wall.

**Warning signs:**
- Adapter implementation contains `def insert(changeset)` or `def write(row)` callbacks — implies destination swap, not forwarding.
- Adapter calls happen *inside* `Ecto.Multi` steps or `Repo.transaction/1` — synchronous coupling to a remote service inside a DB transaction is a deadlock/timeout magnet.
- Admin LiveView shows fewer rows than Threadline, or vice versa, in a soak test.
- Threadline downtime in staging produces 5xx responses on login, MFA, or password change.
- No `[:sigra, :audit, :forward_error]` telemetry event is documented.

**Phase to address:**
Phase 132 (Threadline adapter design + contract). The phase must produce a `Sigra.Audit.Adapters` behaviour (or explicit telemetry-handler convention) document and a contract test asserting: (a) committed rows are forwarded, (b) rolled-back rows are NOT forwarded, (c) Threadline downtime does not break auth, (d) duplicate-protection via event ID.

---

### Pitfall 3: Recipe rot when companion libraries change their API

**What goes wrong:**
A `guides/recipes/companion-threadline-audit.md` ships at v1.29 documenting `Threadline.Event.create/1`. Six months later, Threadline 2.0 renames it to `Threadline.Events.publish/1`. Adopters following the Sigra recipe get `UndefinedFunctionError`. Sigra has no signal that the recipe is stale; nobody owns Threadline-compatibility validation; the recipe drifts silently. Same problem multiplied across Accrue, Lockspire, Mailglass, Relyra, Rulestead.

**Why it happens:**
- Documentation-only integrations have no CI signal. Markdown does not compile.
- ADR 001 explicitly chose "documentation + recipes" over a glue package precisely to avoid the version-lock matrix — but the recipe path needs a different verification model than a real Hex package would.
- Sigra ships at high cadence (28 milestones in 6 weeks); companion libs ship independently. Drift is statistically guaranteed without an executable contract.
- Phoenix's own ecosystem docs (the Phoenix guides + HexDocs Mix tasks) live in the same repo as the code they document, so drift is bounded to one repo. Cross-repo recipes don't have that property.

**How to avoid:**
1. **Recipes that are not executable are unsupported.** Treat the recipe as a contract; if it can't be exercised in CI, it must not claim "verified" or "tested" status. Mark such recipes "REFERENCE — community contributions welcome, last validated YYYY-MM-DD."
2. **Pin the exact companion-lib version each recipe was validated against** in the recipe frontmatter: `validated_against_threadline: "~> 0.7.2"` plus a `last_validated: 2026-05-27` date. Make recipe-validation tracking a first-class artifact (`guides/recipes/COMPATIBILITY.md` summarizing all validated combos).
3. **Run at least one companion lib through real CI** as the "canary adapter" — Threadline is the obvious pick for v1.29 because it's the one Sigra is shipping an adapter for. The test exercises the recipe end-to-end against the pinned Threadline version in a CI job. When Threadline ships a major, the canary breaks; the recipe gets updated or the validated-against pin gets bumped. This buys executable freshness for *one* recipe, not all six.
4. **Add a quarterly recipe-freshness gate** to `MAINTAINING.md`: when `last_validated` is older than 6 months, the recipe must either be re-validated or have a banner injected: *"This recipe was last validated against Threadline 0.7.2 on 2026-05-27. Newer Threadline versions may require adjustments."*
5. **Anchor recipes to companion-lib stability tier.** Hex-published libs with semver and a CHANGELOG (Mailglass if/when published) get fuller recipes; non-Hex / pre-1.0 / private libs (Accrue, Lockspire, Relyra, Rulestead today) get **"reference posture only"** recipes with explicit "API may shift" disclaimers.
6. **Do not include companion-lib API snippets inline if you can't test them.** Prefer linking to the companion lib's own README/docs ("see Threadline §Configuration") plus the Sigra-side wiring that's actually tested. This keeps drift in the companion repo where the maintainer can see it.

**Warning signs:**
- A recipe contains code snippets with no corresponding `.exs` file in `test/recipes/` or `test/integration/`.
- The recipe has no `last_validated` date or version pin.
- A new Sigra release ships without any compatibility check against companion libs the docs mention.
- An adopter opens an issue: "the recipe doesn't compile."

**Phase to address:**
Phase 133 (recipe authoring + compatibility doctrine). Land the recipe-freshness model, `COMPATIBILITY.md`, and the canary CI lane in the same phase as the first recipe ships.

---

### Pitfall 4: Scope creep — Sigra accidentally owns companion-library concerns

**What goes wrong:**
The Threadline adapter feature pulls Sigra into owning concerns it should not:
- Sigra's `mix sigra.install` grows a `--threadline-endpoint` flag, then a `--threadline-api-key-env` flag, then a `mix sigra.threadline.test` task. Sigra now owns Threadline's configuration UX.
- Sigra ships a migration that creates `threadline_dlq` tables for the adapter's retry queue. Sigra now owns a piece of Threadline's schema.
- Operators file Sigra issues for Threadline outages because the adapter is "in Sigra." Sigra's maintainer triage backlog inherits Threadline's operational concerns.
- ADR 001 deferred a `sigra_lockspire` glue package on identical grounds — but the same drift can happen *inside Sigra core* if the boundary isn't held visibly.

**Why it happens:**
- The auth library is the integration hub for many adopter concerns (sessions, audit, email, identity), so it's tempting to absorb companion concerns into the hub.
- Generators and install tasks have a natural "while we're here" gravity — adding one more flag feels cheap; ten more flags later, Sigra owns the world.
- Maintainers often respond to "the integration broke" issues by fixing in Sigra rather than triaging to the companion lib.

**How to avoid:**
1. **Codify ownership in the milestone non-goals (already drafted in `PROJECT.md` line 37):** *"owning any companion library's roadmap, replacing recipes with code where the library boundary doesn't justify it."* Reaffirm in every adapter moduledoc with an "Ownership" section: what Sigra owns (the seam, telemetry, optional-dep guard), what the host owns (config, deploy), what the companion lib owns (its own schema, API, SLO).
2. **No companion-specific install flags beyond a single opt-in toggle.** The v1.25 `--with-mailglass` precedent is the ceiling: one boolean per companion. No `--threadline-endpoint`, no `--threadline-api-key-env`. Config lives in the host's `config/runtime.exs`, owned by the host.
3. **Adapters do not ship migrations for companion lib state.** If the adapter needs a queue, it uses Oban's `default` queue (already a Sigra optional dep) with a Sigra-owned worker module — no companion-specific tables. If the companion lib needs schema (e.g. Threadline events), the companion lib owns it.
4. **Issue-triage protocol in `MAINTAINING.md`:** issues about companion-lib behavior get triaged to the companion repo with a stock response. Sigra's responsibility ends at the seam contract: "did the telemetry fire correctly with the documented payload shape?"
5. **Quarterly boundary audit:** count lines of code, doc, and config Sigra ships for each companion. If the count grows >2x without a clear adopter pull, the boundary is leaking.
6. **The `examples/` reference app (if any) lives in a separate repo or `examples/` subdir gated by its own CI job — not coupled to Sigra's core test suite.** See Pitfall 6.

**Warning signs:**
- A PR adds `--threadline-*` install flag beyond the single opt-in toggle.
- A migration template references companion-lib table names.
- An adapter's moduledoc explains how to operate the companion lib (vs. how Sigra connects to it).
- The Sigra issue tracker accumulates "Threadline is slow," "Mailglass deliverability question," "Accrue billing not syncing" issues without triage tags.
- A recipe is rewritten as a generator template "for convenience."

**Phase to address:**
Phase 131 (boundary doctrine). The first phase of v1.29 must produce a `guides/introduction/suite-narrative.md` (already on the scope list) that defines the ownership boundary visibly. Every subsequent phase's PLAN must check this doctrine before adding surface area.

---

### Pitfall 5: Suite-narrative over-promising — "works seamlessly together"

**What goes wrong:**
The new `guides/introduction/suite-narrative.md` says things like:
- *"Sigra, Mailglass, and Threadline work seamlessly together."* → adopter expects zero-config integration, hits one config knob, opens a "false advertising" issue.
- *"The szTheory suite is the recommended way to deploy Sigra in production."* → adopter reads this as "Sigra-without-the-suite is unsupported," chooses a competitor.
- *"Threadline is the recommended audit destination."* → reads as "DB-only audit is deprecated."
- *"Just add `:threadline` to your deps and you're done."* → under-documents the configuration, signing-key setup, and the failure modes of Threadline-down scenarios.

**Why it happens:**
- Marketing voice creeps into ecosystem docs when the same person writes both.
- Suite narratives invite vendor-lock-in framing even when the libs are MIT-licensed and independent.
- It's easier to write a glossy "works together" sentence than the longer "here's the contract, here are the failure modes, here's what you give up if you don't" paragraph.

**How to avoid:**
1. **Banned marketing phrases in suite docs:** "seamlessly," "just works," "production-ready out of the box," "the recommended way." Replace with bounded claims: *"When Threadline is configured per the recipe, committed audit rows are forwarded asynchronously. If Threadline is unreachable, audit forwarding is queued with bounded retries and DLQs; the auth flow is not blocked."*
2. **Every "X works with Y" claim must link to (a) the recipe, (b) the validated version pin, (c) the failure-mode section.** No floating endorsements.
3. **Explicit non-requirement banner on each adapter:** *"Sigra works fully without Threadline. The Threadline adapter is opt-in via `config :sigra, audit: [adapter: Sigra.Audit.Adapters.Threadline]`. Default audit-to-DB remains the supported configuration."* This banner is mandatory in the moduledoc, the recipe, and the suite-narrative page.
4. **No "recommended stack" language.** "Compatible companion libraries" is the upper bound of endorsement. The Diminishing Returns Wall (`MILESTONE-ARC.md` line 213) already commits Sigra to not owning opinionated authorization, billing, or UI; extend the same restraint to suite framing.
5. **Failure-mode section is mandatory in every recipe.** Minimum: what happens when the companion is down, when it returns 4xx, when it returns malformed payload, when its API rotates.

**Warning signs:**
- A guide uses the words "seamlessly," "just works," or "recommended stack."
- A recipe lacks a "Failure modes" section.
- A README sentence reads as if Sigra is incomplete without the companion.
- An issue arrives: "I thought I had to use Mailglass — can I use plain Swoosh?"

**Phase to address:**
Phase 131 (suite-narrative authoring) + Phase 134 (recipe authoring contract). Treat this as a copy-review gate in PR review: no "seamless" merges.

---

### Pitfall 6: Reference example app drift and CI cost

**What goes wrong:**
A new `examples/sigra-suite/` app is created at v1.29 showing Sigra + Threadline + (optionally) Accrue. Six months later:
- The example app pins `sigra ~> 1.29`, has not been updated since the v1.29 ship, references deprecated generator templates, runs an old Phoenix version, and the README screenshot shows a UI element that no longer exists.
- The example app's CI lane consumes 30% of total CI minutes because it does `mix phx.new` + `mix sigra.install` + `mix deps.get` + browser smoke on every push.
- Fixture data in the example app drifts from `priv/templates/sigra.install/` golden fixtures (`test/sigra/install/golden_diff_test.exs`) → two SOTs disagree.
- The example app's tests pass against the example's local Sigra version but break against `main` because the example was never wired into Sigra's monorepo test harness.

**Why it happens:**
- Reference apps are demos at creation time and rot rapidly without an owner.
- Phoenix LiveView, generator output, and dep matrices shift on every Sigra minor; the example needs continuous reconciliation.
- CI cost feels free at ship time and burdensome later.
- The temptation to "improve the example beyond the recipe" splits effort between two SOTs.

**How to avoid:**
1. **Decide upfront: example in-repo or out-of-repo.** In-repo costs CI minutes but stays current; out-of-repo costs nothing but rots. ADR 001 chose "documentation + recipes" precisely to avoid the maintenance matrix; apply the same restraint here. Default for v1.29: **no examples/ subdir.** Use the existing `test/example/` nested app (already in the repo, already CI-validated) for whatever integration proof is needed.
2. **If a reference example ships anyway**, scope it to one companion (Threadline, since it's the one with the adapter), keep it under `examples/threadline/`, gate it behind a `mix sigra.example.threadline` task, and add a single CI lane that boots it, runs a smoke (login + audit assertion against Threadline), and exits. No browser, no fixtures, no UI verification.
3. **Treat example apps as part of the recipe `last_validated` tracking** — when the recipe is re-validated, the example is re-run. Out of validation date → CI is allowed to mark "stale" instead of failing red, but the README banner appears.
4. **Never duplicate generator golden fixtures.** Example app's `lib/example_app_web/` is generated by `mix sigra.install` and re-generated on every Sigra release; it is not a separate SOT. The example is *consumer config + companion wiring*, not a fork of the generator output.
5. **Hard cap CI minutes for example/integration lanes.** Set a budget (e.g. 5 minutes for the example lane); enforce in CI workflow. If the lane exceeds budget, optimize or remove — do not lazily expand.

**Warning signs:**
- The example app diverges from `priv/templates/sigra.install/` output.
- CI runtime for the example lane grows >2x.
- Example app's last commit is from a previous Sigra minor.
- The example README screenshots no longer match the current LiveView output.
- An adopter follows the example, hits an error, and the error doesn't reproduce against the recipe.

**Phase to address:**
Phase 135 (reference example decision + scope). The phase must explicitly choose "no examples/" or "scoped Threadline-only example" with hard CI budget. Do not defer this to phase-end polish.

---

### Pitfall 7: Cross-library event/audit duplication and conflicting records

**What goes wrong:**
A login event arrives at the Sigra audit table (`auth.login.success`). It also fires `[:sigra, :audit, :log]` telemetry. The Threadline adapter forwards it to Threadline as one event. Simultaneously, the v1.22 webhook pipeline (already shipped) emits an `auth.login.success` webhook to subscribed endpoints. If Mailglass logs an email failure related to the login (lockout email send), Mailglass writes its own event to *its* event store. The host now has:
- 1 row in the Sigra audit table
- 1 row in Threadline (forwarded copy)
- N webhook deliveries (one per subscription) — each persisted in Sigra's `webhook_deliveries` table
- 1 entry in Mailglass's event store for the email outcome

When the host reconciles, the same logical event is represented 4+ ways with potentially conflicting timestamps, conflicting metadata, and conflicting "what is the source of truth." Compliance auditors get confused; operators get paged spuriously; investigations cite the wrong record.

**Why it happens:**
- Multiple pipelines (audit, webhooks, email-event hooks) were added incrementally. Each was correct in isolation; their composition was never specified.
- Each pipeline has its own ID space, its own timestamping, its own retry semantics.
- The natural inclination on "we need observability" is "add another sink" rather than "rationalize what the sinks are."

**How to avoid:**
1. **Declare the canonical event ID and timestamp once, propagate everywhere.** The Sigra audit row's UUID and `occurred_at` are the canonical pair. Every downstream pipeline (webhooks, Threadline adapter, future suite consumers) **must** include both in the forwarded payload. Adopters can join across systems on the audit ID. This is a *contract*, not a *suggestion*; encode it in the webhook envelope (already partially present from v1.22 WH-01) and in the Threadline adapter payload.
2. **Document the "fan-out matrix" explicitly** in the suite-narrative guide:

   | Event class | Sigra DB | Telemetry | Webhooks (v1.22) | Threadline adapter | Mailglass event |
   |---|---|---|---|---|---|
   | auth.login.success | authoritative | always | if subscribed | if configured | n/a |
   | account.email_send.failure | n/a | always | if subscribed | if configured | authoritative |
   | webhook.delivery.dlq | authoritative | always | n/a (don't recurse) | if configured | n/a |

   Adopters need to see this; without it they assume duplication is a bug.
3. **Webhook subscriptions to Sigra-emitted events must not recurse.** If Threadline is itself a webhook subscriber (it could be) AND the Threadline adapter forwards audit rows, the same event lands in Threadline twice. The adapter must check the subscription registry on install / doctor and warn on the duplicate path. Recipe must call this out.
4. **Mailglass email-failure events are NOT audit events.** Mailglass's event store covers email-delivery lifecycle (sent, bounced, complained). Sigra audit covers auth-state changes. These are distinct concerns; do not collapse them. The v1.25 EMAIL-RAILS bounce/complaint hooks (`Sigra.Email` host-owned handler seam) already preserve this boundary — keep it.
5. **Provide a `Sigra.Audit.canonical_id/1` helper** so downstream consumers can extract the ID without reinventing the convention.

**Warning signs:**
- A webhook payload and a Threadline payload for the same logical event have different IDs.
- A recipe says "configure Threadline as a webhook subscriber" without warning about adapter-overlap.
- Adopter asks "which is the source of truth?" — the answer is not obvious from docs.
- An audit query in admin LiveView returns fewer rows than the Threadline query for the same time window.

**Phase to address:**
Phase 132 (adapter contract) + Phase 134 (recipe authoring). The fan-out matrix lives in the suite-narrative guide; the canonical-ID rule is contract-tested in Phase 132.

---

### Pitfall 8: Recipes for not-yet-published companion libs

**What goes wrong:**
Sigra ships v1.29 with recipes for Accrue, Lockspire, Relyra, Rulestead. Several of these are not yet on Hex.pm (the szTheory suite is internal-to-Jon's-projects at varying maturity). Adopters reading the recipe try `mix deps.get`, get *"package accrue not found"*, file an issue. The recipe has effectively shipped vaporware. Alternatively, the recipe references private GitHub URLs, leaving a maintenance contract Sigra cannot honor.

**Why it happens:**
- The suite-narrative milestone has a natural pull to enumerate the whole suite even when only Mailglass + (eventually) Threadline are publicly installable.
- Authoring a recipe is cheap; verifying that the companion lib is actually consumable is the expensive part that gets skipped.
- "Coming soon" framing is hard to maintain across releases — last year's "coming soon" becomes this year's broken link.

**How to avoid:**
1. **Recipes only ship for companion libs that are either (a) on Hex.pm with a published version, or (b) explicitly labeled `vapor: true` with a "this library is not yet generally available" banner.** No middle ground. The recipe frontmatter declares the status.
2. **Vapor-status recipes live under `guides/recipes/preview/` with their own index.** They are not linked from the suite-narrative main page; they're discoverable only from the preview index. This prevents accidental "look how complete the suite is" framing.
3. **The Hex.pm published-status check is automated** — a small CI script reads each recipe's `companion_package:` field and `mix hex.search`-s it; if absent and not labeled `vapor: true`, CI fails. This prevents "we shipped a recipe for `relyra` but it never made it to Hex" drift.
4. **For libs in vapor status, recipes are "design sketches"** — they describe what the integration *will* look like, but explicitly disclaim "this code does not run today." When the lib publishes, the recipe is promoted from `preview/` to `recipes/`, validated, and gets the standard `last_validated` treatment.
5. **License + dep posture in `mix.exs`:** never reference an unpublished lib in `mix.exs` even as `optional: true`. Mix will resolve optional deps from Hex by default; pointing at a private GitHub repo creates a clone-time dep that breaks `mix deps.get` for adopters.
6. **For Threadline specifically** — confirm Hex publish status before Phase 132 ships. If Threadline is not on Hex by v1.29 cut, either (a) defer the adapter until Threadline publishes, or (b) ship the adapter as `Sigra.Audit.Adapters.Threadline` but mark the recipe `preview/` and the `mix.exs` entry as commented-out with a comment pointing at the Threadline release plan.

**Warning signs:**
- A recipe references `{:somelib, "~> X"}` but `mix hex.search somelib` returns no result.
- A recipe links to a GitHub URL instead of HexDocs.
- A recipe lacks a `companion_package:` field in frontmatter.
- An adopter opens an issue: "Mix can't find package X."

**Phase to address:**
Phase 134 (recipe authoring). Pair every recipe with the Hex-publication check before merge.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hard-code Threadline references outside `Code.ensure_loaded?` guards | Adapter "just works" in dev where Threadline is present | Adopter mix.exs without Threadline fails to compile or boot | Never — see Pitfall 1 |
| Replace audit DB write with Threadline forward | One less Postgres write, "Threadline as SOT" simplicity | Admin LiveView empty, assertions broken, OWASP audit invariant lost, retention worker no-ops | Never — see Pitfall 2 |
| Inline retries in telemetry handler | No extra dep, simpler code | BEAM scheduler block, retry storms, lost rows on crash | Never in production. Acceptable for a one-shot bench script. |
| Ship a recipe without `last_validated` date | Faster authoring | Drift, no signal of staleness, eventual issue flood | Only if the recipe is labeled "REFERENCE — community contributions welcome" |
| Add `--threadline-*` install flags for convenience | Lower adopter friction at install | Generator surface area sprawls, every companion lib adds N flags, install task becomes the integration hub | Never. Use a single `--with-threadline` opt-in toggle at most. |
| Ship reference example without CI budget cap | Looks impressive in README | CI minutes spiral, example rots, screenshots stale | Only if example lane has hard time/cost budget and validation cadence |
| Recipe references unpublished companion lib | Suite story looks complete | "Vaporware" issue reports, broken `mix deps.get` for adopters | Only under `preview/` with explicit vapor banner |
| Adapter writes its own `dlq` table | Self-contained retry semantics | Sigra owns companion-shaped schema, schema drift between Sigra and companion releases | Only if the DLQ table is logically Sigra's (forwarded-event DLQ, not companion-state DLQ) |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|---|---|---|
| Threadline (audit forwarding) | Replace DB write; co-fate with Repo.transaction | Tap `[:sigra, :audit, :log]` telemetry on `{:ok, changes}` branch; forward via Oban worker; DB remains SOT |
| Threadline (event ID) | Generate new ID in adapter / let Threadline assign | Forward `audit_row.id` (UUID) + `occurred_at` as idempotency key + canonical timestamp |
| Mailglass (cross-link) | Re-document Mailglass as if EMAIL-RAILS didn't ship | Cross-link to existing v1.25 docs; do not re-introduce `Sigra.Mailers.Adapters.Mailglass` surface or `--with-mailglass` flag |
| Mailglass (event store) | Conflate Mailglass email-event store with Sigra audit | Mailglass owns email-lifecycle events; Sigra owns auth-state events; do not merge |
| Webhooks (v1.22) recursion | Subscribe Threadline as a webhook AND configure adapter | Doctor + recipe must detect+warn on duplicate forward path |
| Accrue (billing identity sync) | Sigra emits "user.subscription_changed" event | Out of scope; Sigra emits auth-state changes only; billing changes are Accrue-owned |
| Lockspire (third-party OAuth server) | Cross-call between Sigra and Lockspire core paths | Per ADR 001: documentation + recipe only; no library-to-library calls; revisit when Lockspire Phase 6 ships |
| Rulestead (rules engine) | Wire as authorization decisions inside Sigra plugs | Sigra provides `current_scope` identity; rules engine is host-owned (per Diminishing Returns Wall: no opinionated authz) |
| Relyra (TBD) | Adopt before companion lib has a stable public API | Recipe stays `preview/` until Hex publish; no `mix.exs` entry |
| Companion lib HTTP failure | Block auth flow on adapter failure | Fail-open: adapter emits `[:sigra, :*, :forward_error]` telemetry; auth flow proceeds |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|---|---|---|---|
| Sync HTTP call in audit telemetry handler | p99 login latency tracks Threadline p99 | Adapter enqueues to Oban worker; telemetry handler is non-blocking | Any time Threadline p99 > 200ms |
| Adapter retries without exponential backoff | Retry storm when Threadline degrades | Bounded retry with exponential backoff + DLQ (mirror v1.22 webhook delivery) | Threadline partial outage |
| Webhook + Threadline adapter both forwarding same event | 2x outbound load per event | Doctor warns; recipe documents the overlap | Adopter who naively adds both pipelines |
| Reference example app full LiveView smoke on every push | CI minute spend grows; ship cadence slows | Hard CI budget for example lane; smoke-only, not full UI | Once you accumulate >2 companion examples |
| Recipe-validation lane bloats over time | CI runtime regresses each milestone | Cap canary-lane scope to one companion (Threadline); other recipes are doc-only | Beyond 1 canary companion lane |
| Audit retention cleanup running while Threadline backlog ships | Adapter forwards already-deleted rows | Retention cleanup and forward-DLQ must agree on a max retention window; document the invariant | Long Threadline outages spanning retention boundary |
| Unbounded forward-DLQ growth | Oban table bloat; dead-letter rows pile up | Bounded DLQ retention; operator-facing UI to inspect/replay (mirror v1.22 webhooks dead-letter UI) | Long outage + no operator attention |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---|---|---|
| Forwarding raw audit metadata (containing PII) to Threadline without redaction | Compliance violation; audit row D-23 forbidden-keys policy bypass | Adapter MUST apply same `Sigra.Audit.Changeset` D-23 forbidden-keys filter to the forwarded payload. Add a contract test. |
| Storing Threadline API key in `mix.exs` or generator templates | Key leak in repo history | Key is host-owned config; recipe documents env-var pattern (e.g. `THREADLINE_API_KEY`); generator does not template a literal key |
| Unauthenticated Threadline endpoint | Forged audit events poison the forensic record | Adapter signs each forwarded event with HMAC (reuse Sigra's existing token-HMAC primitive); Threadline verifies signature |
| Adapter swallows forward errors → silent loss of failed-login audit rows | OWASP A09 (logging failure) — undetected breach | Forward failures emit `[:sigra, :audit, :forward_error]` telemetry + populate DLQ; doctor surfaces DLQ size; operator playbook documents response |
| Recipe shows companion lib API key in plaintext config | Adopter copies sample literally → production key in source | Recipe MUST use `System.fetch_env!/1` examples; never literal keys; lint check on recipe markdown |
| Adapter retries indefinitely on 4xx (signing rejection) | Permanent retry loop; queue saturation | Adapter distinguishes retryable (5xx, timeout) from permanent (4xx) failures; permanent failures go straight to DLQ |
| Companion lib pulled in as transitive dep widens attack surface | Adopter unaware of new HTTP-calling lib | `optional: true` in `mix.exs`; doctor lists active optional deps; security audit covers the adapter's payload shape |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---|---|---|
| "Just add Threadline to your deps" without doctor coverage | Adopter installs, sees no audit events flowing, has no diagnostic path | `mix sigra.doctor` lists adapter status + Threadline reachability + last successful forward |
| Adapter failures silent on operator dashboards | Outages discovered via missing audit rows weeks later | DLQ size + last-forward-error visible in admin LiveView (mirror v1.22 webhook delivery UI) |
| Recipe shows "happy path only" code | Adopter hits a 4xx, has no model for recovery | Recipe MUST include "Failure modes" + "When the companion lib is down" + "How to replay DLQ" sections |
| `--with-threadline` install flag does not exist (but `--with-mailglass` does) | Adopter expects symmetric UX across companion libs | Either provide the toggle symmetrically OR document explicitly that runtime config is the only seam |
| Suite-narrative implies all libs are required | Adopter feels forced into vendor lock-in | "Sigra works fully standalone" banner on every adapter; suite-narrative leads with the optional posture |
| `mix sigra.install` adds Threadline templates by default | Adopter pulls in companion config they don't want | Adapter scaffolding is strictly opt-in; default install path is unchanged |
| Removing a companion lib leaves stale config that breaks boot | Adopter cannot easily back out | Adapter is config-driven; missing config means adapter is inert (not a boot error); doctor flags orphaned config |

---

## "Looks Done But Isn't" Checklist

- [ ] **Threadline adapter:** Often missing dep-off CI lane — verify `mix compile && mix test` passes with Threadline removed from `mix.lock`.
- [ ] **Threadline adapter:** Often missing the contract test for "rolled-back transactions do not forward" — verify a failing transaction does NOT fire telemetry and does NOT enqueue a forward job.
- [ ] **Threadline adapter:** Often missing DLQ operator UI — verify admin LiveView surfaces forward failures + retry/replay/drop actions.
- [ ] **Threadline adapter:** Often missing the canonical event ID propagation — verify forwarded payload includes Sigra `audit_row.id` and `occurred_at` (not Threadline-assigned).
- [ ] **Threadline adapter:** Often missing D-23 forbidden-keys filter on forwarded metadata — verify PII filter applies on the forward path identically to the insert path.
- [ ] **Threadline adapter:** Often missing fail-open guarantee — verify a 500 from Threadline does not block a login.
- [ ] **Recipes (Accrue/Lockspire/Mailglass/Relyra/Rulestead/Threadline):** Often missing `last_validated` date + version pin — verify recipe frontmatter is complete.
- [ ] **Recipes:** Often missing "Failure modes" section — verify every recipe documents downtime behavior.
- [ ] **Recipes:** Often missing Hex-publication validation — verify `companion_package:` lookup returns a Hex version OR recipe is labeled `vapor: true` under `preview/`.
- [ ] **Suite-narrative guide:** Often missing the fan-out matrix — verify cross-library event/audit/email duplication is documented explicitly.
- [ ] **Suite-narrative guide:** Often missing "Sigra works fully standalone" banner — verify no "recommended stack" framing.
- [ ] **`mix sigra.doctor`:** Often missing per-adapter feature row — verify Threadline adapter status, reachability, and DLQ size are all surfaced.
- [ ] **OptionalDeps namespace:** Often missing the canonical SOT — verify `Sigra.OptionalDeps.Threadline` (or equivalent) exists and is the single registration point, not scattered `Code.ensure_loaded?` calls.
- [ ] **Reference example (if any):** Often missing CI budget cap — verify the example lane has a documented minute/timeout budget.
- [ ] **Reference example (if any):** Often missing generator-fixture deduplication — verify the example consumes `mix sigra.install` output rather than forking the templates.
- [ ] **Compatibility doc:** Often missing — verify `guides/recipes/COMPATIBILITY.md` enumerates each companion lib + validated version + date.
- [ ] **Webhook + Threadline overlap:** Often missing — verify doctor + recipe warn on adopters who configure both pipelines for the same event class.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---|---|---|
| Compile-time coupling shipped (Pitfall 1) | LOW (early), HIGH (post-release) | Pre-release: wrap adapter in `Code.ensure_loaded?`, add dep-off CI lane, ship patch. Post-release: yank version, ship patch, communicate to adopters who already upgraded. |
| Audit-destination divergence (Pitfall 2) | HIGH | Adapter must be redesigned as telemetry-tap, not destination swap. Existing adopters need a migration path: dual-write window + reconciliation script + cutover. Document timeline. |
| Recipe rot (Pitfall 3) | LOW per recipe | Re-validate against current companion lib version; update `last_validated`; if API changed, rewrite snippet or downgrade to "REFERENCE" status. |
| Scope creep (Pitfall 4) | MEDIUM | Audit code: each `--threadline-*` flag added gets deprecated and removed in next minor. Adapter-specific tables get migrated to companion-owned schema. ADR captures the rollback. |
| Suite over-promise (Pitfall 5) | LOW | Doc edit + CHANGELOG note. No code change. Add banned-phrase lint to docs CI. |
| Reference example rot (Pitfall 6) | MEDIUM | Either re-validate against current Sigra version OR archive with "last validated against X.Y" banner OR delete entirely. Prefer archive + banner over silent rot. |
| Cross-library duplication (Pitfall 7) | MEDIUM | Publish the fan-out matrix as a doc patch; add doctor warnings on overlap; backfill canonical-ID propagation across pipelines. |
| Vapor-recipe (Pitfall 8) | LOW | Move recipe from `recipes/` to `preview/`; add banner; update suite-narrative link. |

---

## Pitfall-to-Phase Mapping

Phase numbering continues from v1.28's last phase (130); v1.29 starts at Phase 131.

| Pitfall | Prevention Phase | Verification |
|---|---|---|
| **1. Compile-time coupling** | Phase 131 (foundational adapter scaffolding + `Sigra.OptionalDeps.Threadline` SOT) | New dep-off CI lane (model: v1.21 HARD-02 "3 dep-off CI lanes") passes with Threadline absent; `mix sigra.doctor` surfaces adapter availability |
| **2. Audit-destination divergence** | Phase 132 (adapter contract design + telemetry-tap implementation) | Contract test: rolled-back transactions do NOT fire forward; admin LiveView and Threadline return matching counts; Threadline downtime test exits with auth flow successful |
| **3. Recipe rot** | Phase 133 (recipe authoring doctrine + `COMPATIBILITY.md`) | Recipe frontmatter check in CI; `last_validated` date + version pin enforced; one canary lane (Threadline) executes recipe end-to-end |
| **4. Scope creep** | Phase 131 (boundary doctrine in suite-narrative) + ongoing PR review | Each phase PLAN cites the boundary doctrine; install task surface area count tracked milestone-over-milestone |
| **5. Suite over-promise** | Phase 131 (suite-narrative + banned-phrase lint) | Doc CI fails on banned phrases ("seamlessly," "recommended stack," "just works"); failure-mode section required per recipe |
| **6. Reference example drift** | Phase 135 (reference example decision) | Explicit "no examples/" decision OR scoped Threadline-only example with hard CI budget cap; generator-fixture deduplication enforced |
| **7. Cross-library duplication** | Phase 132 (adapter contract — canonical-ID propagation) + Phase 134 (recipe — fan-out matrix doc) | Contract test: forwarded payload includes audit row UUID + occurred_at unchanged; doctor warns on webhook+adapter overlap |
| **8. Vapor recipes** | Phase 134 (recipe authoring + Hex-publication CI check) | CI fails on recipes that reference unpublished Hex packages without `vapor: true` + `preview/` placement |

**Suggested phase ordering for v1.29:**

1. **Phase 131** — Boundary doctrine + `Sigra.OptionalDeps.Threadline` SOT + suite-narrative landing page draft (no adapter code yet; establishes the contract first)
2. **Phase 132** — Threadline adapter implementation + contract tests (telemetry-tap pattern; fail-open; canonical-ID propagation)
3. **Phase 133** — Recipe authoring doctrine + `COMPATIBILITY.md` + recipe-freshness gate + Hex-publication CI check
4. **Phase 134** — Companion-library recipes (Threadline canary + Mailglass cross-link + `preview/` for Accrue/Lockspire/Relyra/Rulestead)
5. **Phase 135** — Reference example decision + scope (default: no examples/; explicit gate before any examples/ subdir ships)
6. **Phase 136** — `mix sigra.doctor` extensions for adapters + admin LiveView DLQ surface + verification proof bundle

Phases 132–135 can partially overlap; Phase 131 (boundary + optional-dep SOT) must land first because every subsequent phase depends on it.

---

## Sources

- `/Users/jon/projects/sigra/.planning/MILESTONE-ARC.md` — Diminishing Returns Wall + SUITE-INTEGRATION candidate scope (HIGH confidence, primary)
- `/Users/jon/projects/sigra/.planning/PROJECT.md` — v1.29 current-milestone goal + non-goals (HIGH confidence, primary)
- `/Users/jon/projects/sigra/.planning/decisions/001-defer-sigra-lockspire-glue-package.md` — ADR 001 deferral precedent (HIGH confidence, primary)
- `/Users/jon/projects/sigra/lib/sigra/audit.ex` (528 lines) — current audit module surface: no behaviour abstraction, telemetry on `{:ok, changes}` only, D-23 forbidden-keys policy, retention cleanup (HIGH confidence, primary)
- `/Users/jon/projects/sigra/MAINTAINING.md` — release cadence, installer golden contract, Nyquist matrix policy (HIGH confidence, primary)
- `/Users/jon/projects/sigra/test/example/deps/mailglass/lib/mailglass/optional_deps.ex` — `Mailglass.OptionalDeps.*` namespace pattern (HIGH confidence; precedent for proposed `Sigra.OptionalDeps.Threadline`)
- `/Users/jon/projects/sigra/.planning/MILESTONES.md` — v1.25 EMAIL-RAILS shipped scope: `Sigra.Mailers.Adapters.Mailglass`, `--with-mailglass` flag, generated-host override seam (HIGH confidence; precedent for Threadline opt-in toggle ceiling)
- v1.21 HARD-02 narrative in `.planning/PROJECT.md` line 119 — `Sigra.OptionalDeps` SOT mention + `mix sigra.doctor` + 3 dep-off CI lanes; the planning narrative documents this as shipped, but `grep -r "Sigra.OptionalDeps" lib/` returns no hits in `lib/` — the SOT module is referenced as a doctrine but not present as a canonical namespace today (MEDIUM confidence on current state; HIGH confidence that the precedent exists)
- v1.22 webhooks (WH-04/05/06 — Phases 103–107) — model for delivery retry, signature rotation, DLQ + replay, blocked-policy operator truth; same shape applies to Threadline adapter delivery semantics (HIGH confidence)
- `/Users/jon/projects/sigra/lib/sigra/mailer.ex` — pluggable mailer behaviour (host-provided implementation) — model for adapter-behaviour pattern (HIGH confidence)
- `/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex` — install task scope ceiling (HIGH confidence; informs Pitfall 4 "no per-companion flag sprawl")

---

*Pitfalls research for: SUITE-INTEGRATION (v1.29)*
*Researched: 2026-05-27*
