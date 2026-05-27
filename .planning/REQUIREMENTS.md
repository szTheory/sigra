# Sigra v1.29 SUITE-INTEGRATION — Requirements

**Milestone:** v1.29 SUITE-INTEGRATION
**Opened:** 2026-05-27
**Goal:** Make Sigra compose cleanly with the rest of the szTheory OSS suite — first-class Threadline audit forwarder, recipe coverage for the other companion libraries (Accrue, Lockspire, Mailglass cross-link, Relyra, Rulestead), and a coherent suite-narrative entry point — without owning any sister library's roadmap.

**Bounded contract:** Library code only where Sigra owns enforceable contracts (Threadline forwarder + behaviour); recipes everywhere else; existing scattered `Code.ensure_loaded?` precedent over new infrastructure refactors.

**Phase numbering:** Continues from v1.28 (last phase: 130). v1.29 starts at **Phase 131**.

**Research basis:** [`.planning/research/SUMMARY.md`](research/SUMMARY.md) (synthesizes STACK, FEATURES, ARCHITECTURE, PITFALLS).

---

## Active Requirements

### Threadline audit forwarder — library code

- [x] **TL-01** — Sigra ships `Sigra.Audit.Forwarders.Threadline` that subscribes to `[:sigra, :audit, :log]` telemetry and forwards committed audit rows to Threadline. The Sigra audit table remains source-of-truth; Threadline is a post-commit projection, never a destination swap.
- [x] **TL-02** — Forwarder supports two-tier dispatch (`:auto` / `:async` / `:sync`) matching the `Sigra.Delivery` precedent: `:auto` selects the `Sigra.Workers.AuditForward` Oban worker when Oban is present, falls back to inline call otherwise; `:async` raises if Oban is absent at boot; `:sync` always calls inline.
- [x] **TL-03** — `Sigra.Workers.AuditForward` Oban worker (wrapped in `if Code.ensure_loaded?(Oban.Worker) do`) handles bounded retries with exponential backoff; forwarding failures fire `[:sigra, :audit, :forward, :error]` telemetry and never roll back the originating auth operation.
- [x] **TL-04** — Forwarder is optional-dep safe — the entire `Sigra.Audit.Forwarders.Threadline` module is wrapped in `if Code.ensure_loaded?(Threadline) do`, a `Sigra.Audit.Forwarders.Noop` fallback ships in tree, and `Sigra.Application.start/2` emits a one-shot `Logger.warning` when the forwarder is configured but the Threadline dep is missing.
- [x] **TL-05** — Forwarder emits separate `[:sigra, :audit, :forward, :ok]` and `[:sigra, :audit, :forward, :error]` telemetry events so operators can observe forwarding parity against the primary audit row without grep-walking logs.

### Forwarder behaviour contract

- [x] **FB-01** — Sigra defines `Sigra.Audit.Forwarder` behaviour with a single `@callback attach(keyword) :: :ok | {:error, term}` so hosts can implement custom forwarders (Datadog, Honeycomb, OpenTelemetry, in-house) and mock the contract via `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)`. Behaviour ships in Phase 131 alongside Threadline impl — locks the contract before a 2nd forwarder lands.

### Companion-library recipes

- [ ] **RC-01** — `guides/recipes/companion-libs/threadline.md` ships as the canonical Threadline integration recipe with `validated_against:` + `last_validated:` frontmatter, `mix.exs` snippet, `forwarders:` config block, failure-modes section, non-goals section, "Sigra works fully standalone" banner.
- [ ] **RC-02** — `guides/recipes/companion-libs/mailglass.md` ships as a 1-page recipe wiring Mailglass behind the existing `Sigra.Mailer` behaviour, pinned to Mailglass `~> 1.2`. Does **not** ship a library-resident adapter; uses the existing host-owned wiring pattern (matches Devise/Rodauth/Allauth posture).
- [ ] **RC-03** — `guides/recipes/companion-libs/accrue.md` ships referencing the `Accrue.Auth` behaviour and cross-links `lib/sigra/hooks.ex` for seat-limit gating + lifecycle integration.
- [ ] **RC-04** — `guides/recipes/companion-libs/lockspire.md` ships as a concrete recipe (mix.exs deps, AccountResolver stub, walkthrough) and cross-links the existing `guides/recipes/companion-oauth-provider.md` architectural framing. Respects ADR 001 (no `sigra_lockspire` glue package).
- [ ] **RC-05** — `guides/recipes/companion-libs/relyra.md` ships with SAML 2.0 SP wiring guidance and cites the v1.27 ENT-SSO OIDC-vs-SAML decision matrix.
- [ ] **RC-06** — `guides/recipes/companion-libs/rulestead.md` ships demonstrating `Rulestead.enabled?` from a Sigra-protected controller and `RulesteadPolicy` derived from `current_scope`.

### Suite narrative

- [ ] **NX-01** — `guides/introduction/suite-integration.md` ships as the canonical narrative entry point with ASCII ecosystem diagram, fan-out matrix (auth events × Sigra DB / telemetry / webhooks / Threadline forwarder / Mailglass), "Sigra works fully standalone" banner, and explicit Diminishing Returns Wall reference. README adds a "Suite integration" pointer.

### Reference example

- [ ] **EX-01** — `test/example/` extends with a working Threadline forwarder demo: `test/example/mix.exs` adds Threadline as a dev/test dep; `test/example/lib/example/accounts.ex` adds the `forwarders:` block under the existing `audit:` keyword; a new `test/example/test/example_web/threadline_forwarder_test.exs` asserts a Sigra audit event materializes as a Threadline row; `test/example/AGENTS.md` documents the demo wiring. No new top-level `examples/` directory.

### Verification + narrative honesty

- [ ] **PROOF-01** — All forwarder unit + integration tests pass; dep-off CI lane (Threadline absent) proves `mix compile && mix test` green; `mix test test/sigra/audit/` clean; `mix test` inside `test/example/` clean; `mix docs --warnings-as-errors` exit 0 (the gate that nearly blocked v1.28 PROOF-01); `mix credo --strict` clean; `131-VERIFICATION.md` through `135-VERIFICATION.md` filed; `.planning/milestones/v1.29-ROADMAP.md`, `v1.29-REQUIREMENTS.md`, `v1.29-MILESTONE-AUDIT.md` archived at close.
- [ ] **DOC-01** — `MILESTONES.md` v1.25 EMAIL-RAILS entry appends a one-line corrigendum noting that the library-resident `Sigra.Mailers.Adapters.Mailglass` module and `--with-mailglass` flag from Phase 111/114 did **not** land on the release branch and are not part of the supported surface. `PROJECT.md` v1.25 narrative gets the same correction. `CHANGELOG.md` [Unreleased] notes the v1.29 clarification of Mailglass integration posture (host-owned wiring via `Sigra.Mailer` behaviour).

---

## Future Requirements (Deferred Out of v1.29)

- **`Sigra.OptionalDeps` SOT consolidation** — refactor scattered `Code.ensure_loaded?` guards across 29+ call sites into a single source-of-truth module. Triggered when a 3rd new optional-dep adapter lands OR when `mix sigra.doctor` is built. Not a v1.29 blocker; existing scattered-guard precedent is sound and ships across Phoenix/Plug.
- **`mix sigra.doctor` task** — adopter-facing diagnostic for missing optional deps + boot-time issues. Referenced in v1.21 HARD-02 narrative but not actually shipped. Triggered when adopter feedback or a v1.30+ milestone requires it; tracked as a separate quick task post-v1.29.
- **Mailglass library-resident adapter recovery** — separate post-v1.29 quick task to decide whether to recover `lib/sigra/mailers/adapters/mailglass.ex` + `--with-mailglass` flag from the orphaned wip branches (`backup/pre-cleanup-20260525-073728`, `chore/phase-88-uat-evidence`, `wip/2026-05-23-example-isolation`, `wip/example-admin-drift-20260525`). Current recommendation: drop the orphaned work; recipe-only stays as the supported posture.
- **Threadline correlation-ID propagation** — Sigra → Threadline trace-correlation closes the loop with Threadline's existing one-way wire. Schedule-permitting differentiator; consider for v1.30 if Threadline adoption surfaces the need.
- **Recipe-contract test fixtures** — walks `guides/recipes/companion-libs/*.md` and asserts the required section headings ("Failure modes," "Non-goals," banner, version pins). Differentiator if Phase 134 has the budget; otherwise defer.

---

## Out of Scope (Explicit Exclusions)

- **`--with-threadline` (or any `--with-*`) install flag** — zero precedent for `--with-*` flags in `lib/mix/tasks/sigra.install.ex`; would cascade to 5+ flags across the companion-lib suite. Forwarders are pure runtime config; Threadline is opt-in via `mix.exs` dep + `forwarders:` config block in the host's `sigra_config/0`.
- **Replacing the Sigra audit DB write with Threadline forwarding** — Sigra's audit table remains source-of-truth. The forwarder fires only from `{:ok, _}` commit branches of `Sigra.Audit`, so rolled-back transactions never forward. Threadline downtime never blocks login.
- **A separate `examples/suite-starter/` top-level directory** — `test/example/` is already CI-wired (3 jobs in `ci.yml` including Playwright smoke) and was the resolution to Phase 114's nested-example-app drift. Adding a parallel `examples/` re-opens that wound.
- **A separate `sigra_threadline` Hex glue package** — ADR 001 logic: companion-glue packages stay deferred until both APIs stable + a real adopter trigger fires. Threadline integration ships in-tree under `Sigra.Audit.Forwarders.Threadline`.
- **Sigra-managed billing, Stripe integration, SAML metadata storage, or feature-flag persistence** — Diminishing Returns Wall (`MILESTONE-ARC.md`). Each is owned by the relevant companion lib (Accrue / Stripe SDK / Relyra / Rulestead).
- **Marketing voice in suite docs** — banned phrases: "seamlessly," "just works," "production-ready out of the box," "the recommended way." Every suite recipe + narrative page carries the "Sigra works fully standalone" banner; every recipe includes a "Failure modes" section.
- **Owning any companion library's roadmap** — recipes pin to a `validated_against:` version and a `last_validated:` date; Sigra never claims responsibility for sister-lib API changes.
- **Re-landing the orphaned Mailglass adapter as part of v1.29** — see Future Requirements; a separate quick task post-v1.29 decides recovery vs deletion of those wip branches.
- **Building `Sigra.OptionalDeps` SOT module in v1.29** — see Future Requirements; scope-bounded to keep SUITE-INTEGRATION focused on companion-lib integration, not optional-dep infrastructure refactoring.

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| TL-01 | Phase 131 | Active |
| TL-02 | Phase 131 | Active |
| TL-03 | Phase 131 | Active |
| TL-04 | Phase 131 | Active |
| TL-05 | Phase 131 | Active |
| FB-01 | Phase 131 | Active |
| RC-01 | Phase 132 | Active |
| RC-02 | Phase 132 | Active |
| RC-03 | Phase 134 | Active |
| RC-04 | Phase 134 | Active |
| RC-05 | Phase 134 | Active |
| RC-06 | Phase 134 | Active |
| NX-01 | Phase 133 | Active |
| EX-01 | Phase 135 | Active |
| PROOF-01 | Phase 136 | Active |
| DOC-01 | Phase 136 | Active |

*Phase column populated by `gsd-roadmapper` on 2026-05-27. All 16 active REQ-IDs mapped to exactly one phase; no orphans.*
