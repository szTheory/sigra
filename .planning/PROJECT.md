# Sigra

## What This Is

Sigra is a comprehensive authentication library for Elixir/Phoenix that fills the critical gap left by Pow's incompatibility with Phoenix 1.8+. It uses a hybrid lib+generator architecture: security-critical code lives in the library (updated via `mix deps.update`), while customizable application code (schemas, routes, LiveViews) is generated into the developer's project. Sigra targets Phoenix/Ecto as the blessed path, with Plug compatibility where it doesn't compromise DX.

## Core Value

Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence, without wiring together 4+ libraries or maintaining security-sensitive code themselves.

## North Star (milestones)

Milestone scoping for GSD (`/gsd-new-milestone`, `/gsd-plan-phase`) should prefer work that advances these outcomes; defer open-ended polish unless it is tied to adoption, operator trust, or concrete risk.

- **Production-viable by default** — Optional integrations and limitations stay honest in package metadata and docs; merge-blocking CI and documented evidence (README production readiness, `MAINTAINING.md`, GA / audit artifacts) are the trust surface, not marketing claims.
- **Clear integration path** — `mix sigra.install`, generator output, introductory guides, upgrade stubs, and companion seams (with explicit non-goals where Sigra stops) so teams can adopt without reverse-engineering the library.
- **Great DX on happy path and rough edges** — First-run success, predictable errors, migrations, audit expectations, and maintainer operations are first-class, not afterthoughts.

**GSD use:** When a phase or milestone proposal does not clearly move one of the bullets above, treat it as lower priority unless it closes a documented adoption gap or security/audit risk.

**GSD preference:** When the user delegates architecture or product tradeoffs, default to researched decisive recommendations and only escalate choices that materially alter the security model, the public/semver contract, or the generated-host contract. Implementation-level forks should usually be resolved by the agent without reopening broad decision loops. Repo default: discuss-phase should run assumption-first, do codebase, prompt, and relevant primary-source prior-art research before questioning, synthesize one cohesive recommendation set, and ask only when no clear winner remains after narrowing. Treat this as the default for future discuss/research/planning work unless the user explicitly asks to stay in brainstorming mode.

## Post-1.0 Operating Posture

After `v1.32 RELEASE-ADOPTION` closes and Sigra's real Hex `1.32.0` release is cut, treat the library as broadly feature-complete for the expected Phoenix authentication-library surface. The default future posture is maintenance, release support, adopter feedback, and selective strategic building — not another open-ended feature treadmill.

Future milestones should begin from this assumption:

- **Release-grade until evidence says otherwise** — do not re-litigate "are we done?" at every milestone. Ask what concrete risk, adopter pain, or strategic opportunity justifies new work.
- **Maintenance first** — prioritize regressions, security/trust findings, upgrade issues, docs corrections, CI/release failures, and adopter-reported friction.
- **Strategic bets only by thesis** — new capability work should have a clear product thesis, ecosystem signal, or contract gap. Good examples: a real adopter integration need, a security model improvement, or a narrowly scoped ecosystem wedge.
- **Polish is not default roadmap** — super-polish, broad UI redesign, compliance theater, hosted-control-plane imitation, SCIM/directory sync, generic authorization policy, and new auth primitives stay deferred unless explicitly promoted by evidence.
- **Quieter future planning** — agents should make decisive recommendations from repo evidence and ask fewer broad questions. Escalate only decisions that materially alter the security model, public/semver contract, generated-host contract, or post-1.0 strategic direction.

## Current Milestone: v1.34 ADMIN-UI-COHERENCE

**Goal:** Take the admin UI from "each screen polished individually" to one coherent, needs-led journey — principle of least surprise everywhere, "same job → same component."

**Why this is promoted now (vs. the Post-1.0 "polish is not default roadmap" posture):** The admin UI is Sigra's evaluator-facing showcase surface (v1.31 DEMO-SHOWCASE) and a generated-host adoption touchpoint. Coherent, intuitive operator UX directly serves the **Clear integration path** and **Great DX** North Star bullets. This is an explicit, user-promoted exception (2026-06-03), bounded to coherence of the existing surface — not a broad feature expansion.

**Scope (locked):** Polish the 6 existing admin screens + enrich seed data so every screen fully expresses itself. Consolidate duplicated components (3 "stat" variants, 2 filter idioms, boxed-vs-open headers) into a shared lib-owned `Sigra.Admin.Components` module. Harden the needs-led landing (verbs-first task cards, one risk alarm, demoted posture metrics). Heaviest effort on under-iterated areas with no screenshot baseline today: the two Overview landings, org overview, per-user audit, and audit mobile.

**Out of scope:** No net-new admin surfaces (API-token/service-account management UIs). No top-level nav restructure (keep the Overview→List→Detail IA). No token-layer/motion-primitive work (the `sg-*` layer is mature and Emil-Kowalski-compliant; this milestone audits *usage*).

**Verification:** Automated only (Jon's standing zero-human-UAT preference) — playwright `admin-checkpoints-{chromium,mobile,dark}` + axe (WCAG A/AA) + `admin-generated` installer-parity. Coverage gaps closed by ADDING checkpoints (`global-overview`, `org-overview`, `user-audit`), not by widening the behavior matrix.

**Kickoff brief:** `~/.claude/plans/recap-sigra-v1-0-0-ga-cached-puppy.md` (approved 2026-06-03). Phases continue from 154.

## Latest Shipped Milestone: v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS

**Shipped:** 2026-06-02 (Phases 150–153) · 10/10 requirements satisfied · milestone audit passed

Sigra has shifted into a post-1.0 stewardship posture: maintainer triage and template-update communication are documented, the toolchain and Hex dependencies are synced, strategic bets are gated by concrete adopter demand, and the live Postgres test harness is stabilized through a shared SQL Sandbox owner-per-test pattern.

Archives:
- [`.planning/milestones/v1.33-ROADMAP.md`](milestones/v1.33-ROADMAP.md)
- [`.planning/milestones/v1.33-REQUIREMENTS.md`](milestones/v1.33-REQUIREMENTS.md)
- [`.planning/milestones/v1.33-MILESTONE-AUDIT.md`](milestones/v1.33-MILESTONE-AUDIT.md)
- [`.planning/milestones/v1.33-phases/`](milestones/v1.33-phases/)

### Just shipped: v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS

- formalized maintainer issue triage, bug prioritization, and generated-host template-update communication in maintainer/release surfaces
- updated the Erlang/OTP toolchain target and Hex dependency lockfile while preserving the existing compatibility proof surface
- created the v1.33 strategic-bet evaluation gate so SCIM, `sigra_lockspire`, and Threadline correlation stay deferred unless concrete adopter demand overrides maintenance-first defaults
- stabilized the library live-DB test harness with `Sigra.Test.PostgresCase`, SQL Sandbox manual mode, owner-per-test rollback cleanup, and isolated query-index scratch storage
- closed the stale audit blocker from the earlier connection-exhaustion finding; focused Phase 153 proof passes with 107 tests and 0 failures

## Previous Shipped Milestone: v1.30 TRUST-HARDENING

**Shipped:** 2026-05-29 (Phases 137–140)

Sigra carries legible operator trust: a single canonical answer to optional-dependency availability, a one-command operator diagnostic, and companion-recipe contracts that cannot silently drift.

Archives:
- [`.planning/milestones/v1.30-ROADMAP.md`](milestones/v1.30-ROADMAP.md)
- [`.planning/milestones/v1.30-REQUIREMENTS.md`](milestones/v1.30-REQUIREMENTS.md)
- [`.planning/milestones/v1.30-MILESTONE-AUDIT.md`](milestones/v1.30-MILESTONE-AUDIT.md)

### Just shipped: v1.30 TRUST-HARDENING

- shipped `Sigra.OptionalDeps` SOT (OD-01/OD-02): 9 `*_available?/0` predicates + config-driven `encryption_active?/1`; ~29 scattered `Code.ensure_loaded?` guards consolidated across 17 delegation sites with zero runtime behavior change
- shipped `mix sigra.doctor` (DR-01/DR-02): nine-feature optional-dep matrix with actionable hints, four boot-wiring hard-fail checks, and a non-zero CI gate
- shipped the merge-blocking companion-lib recipe-contract fixture (RCT-01), plus Lockspire/Rulestead sister-repo contract verification (RCV-01/RCV-02)
- shipped deprecation hygiene (DEPR-01/DEPR-02): Hex-SemVer removal targets and migration notes for both live `@deprecated` functions
- landed the PROOF-01 eight-gate proof bundle and DOC-01 docs alignment

## Previous Shipped Milestone: v1.29 SUITE-INTEGRATION

**Shipped:** 2026-05-29 (Phases 131–136)

Sigra now composes cleanly with the rest of the szTheory OSS suite: a first-class, optional-dep-safe Threadline audit forwarder (the milestone's only new library code), recipe coverage for the five other companion libraries, and a coherent suite-narrative entry point — without owning any sister library's roadmap and without re-landing the orphaned Phase 111/114 Mailglass adapter.

Archives:
- [`.planning/milestones/v1.29-ROADMAP.md`](milestones/v1.29-ROADMAP.md)
- [`.planning/milestones/v1.29-REQUIREMENTS.md`](milestones/v1.29-REQUIREMENTS.md)
- [`.planning/milestones/v1.29-MILESTONE-AUDIT.md`](milestones/v1.29-MILESTONE-AUDIT.md)

### Just shipped: v1.29 SUITE-INTEGRATION

- shipped `Sigra.Audit.Forwarder` behaviour + `Sigra.Audit.Forwarders.Threadline` telemetry-tap impl + `Noop` fallback + optional `Sigra.Workers.AuditForward` Oban worker — `:auto`/`:async`/`:sync` dispatch, `[:sigra,:audit,:forward,:ok|:error]` telemetry, Sigra audit row stays source-of-truth, optional-dep safe (no Threadline runtime dep when unused)
- published six companion-library recipes under `guides/recipes/companion-libs/` (Threadline, Mailglass, Accrue, Lockspire, Relyra, Rulestead) on a uniform template with the "Sigra works fully standalone" banner, under a new ExDoc "Companion Libraries" group
- published `guides/introduction/suite-integration.md` suite narrative (ASCII ecosystem diagram, fan-out matrix, Diminishing Returns Wall framing) + README pointer
- extended `test/example/` with a runnable end-to-end Threadline forwarder demo proven by a real DB round-trip test on existing CI lanes (no new top-level `examples/`)
- landed the PROOF-01 proof bundle (full suite + dep-off lane + example app + `mix docs --warnings-as-errors` exit 0) and the v1.25 EMAIL-RAILS Mailglass-narrative corrigendum (DOC-01)

## Previous Shipped Milestone: v1.28 DATA-LIFECYCLE

**Shipped:** 2026-05-27

Sigra now ships a bounded, truthful auth/account data lifecycle: a versioned Sigra-owned export payload with explicit omission truth, schedule/cancel/execute deletion semantics that match operator-facing docs, generated-host parity for templates and docs, and a release-readiness proof package — all without expanding into generic compliance, SCIM, BI exports, or hosted-control-plane behavior.

Archives:
- [`.planning/milestones/v1.28-ROADMAP.md`](milestones/v1.28-ROADMAP.md)
- [`.planning/milestones/v1.28-REQUIREMENTS.md`](milestones/v1.28-REQUIREMENTS.md)
- [`.planning/milestones/v1.28-MILESTONE-AUDIT.md`](milestones/v1.28-MILESTONE-AUDIT.md)

## Earlier Shipped Milestone: v1.27 ENT-SSO

**Shipped:** 2026-05-26

Sigra now ships a bounded enterprise login contract for organization-based B2B adopters: truthful enterprise connection setup and activation, canonical org-aware routing and bounded discovery, safe JIT membership reconciliation, SSO-only enforcement with explicit break-glass recovery, and a generated-host/operator proof package that stays honest about non-goals.

Archives:
- [`.planning/milestones/v1.27-ROADMAP.md`](milestones/v1.27-ROADMAP.md)
- [`.planning/milestones/v1.27-REQUIREMENTS.md`](milestones/v1.27-REQUIREMENTS.md)
- [`.planning/milestones/v1.27-MILESTONE-AUDIT.md`](milestones/v1.27-MILESTONE-AUDIT.md)

## Current State

`v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS` is shipped and archived. Sigra's current posture is maintenance-first: preserve the released authentication surface, respond to adopter friction, keep release and dependency lanes healthy, and promote new feature work only when a concrete adopter/security/product signal justifies it.

Next focus: define the next milestone with `$gsd-new-milestone`; phase numbering should continue after Phase 153.

## Next Milestone Goals

- Treat regressions, security/trust findings, release failures, dependency drift, and adopter-reported friction as the default highest-value work.
- Keep strategic bets gated by the v1.33 decision: enterprise features such as SCIM, `sigra_lockspire`, and Threadline correlation need explicit demand before implementation.
- Resolve the non-blocking `Chimeway.Repo` missing database configuration startup noise before using local full-suite `mix test` output as a clean release signal.
- Avoid broad feature expansion, generated-host UI redesign, hosted-control-plane behavior, or generic authorization/compliance work unless the next milestone explicitly promotes it.

### Just shipped: v1.28 DATA-LIFECYCLE

- added versioned Sigra-owned auth/account export with `schema_version: 1`, lifecycle status, and configured-schema safe serializers
- added explicit structured omission notes for optional export schemas (truthful instead of silent)
- added account deletion enqueue that builds `Sigra.Workers.AccountDeletion` jobs when generated-host context exists and degrades safely when absent
- added active-scheduled gating on cancel/execute paths and stale worker no-op behavior via `Sigra.Account.Deletion.scheduled?/1`
- added row-preserving soft-delete finalization that clears scheduled-deletion and pending/original email fields without claiming hard deletion
- aligned generated host templates, example app, install golden fixture, and public docs with the bounded library contract
- locked targeted release-readiness proof through 56+66 lifecycle/install-lane tests, 2211 full-suite tests, and `mix docs --warnings-as-errors` exit 0

### Previously shipped: v1.27 ENT-SSO

- added truthful organization-bound enterprise connection setup and activation refusal
- added canonical org-aware enterprise routing with bounded exact-match discovery
- added safe JIT enterprise reconciliation and first-session org/audit truth
- added SSO-only enforcement with explicit break-glass recovery
- closed generated-host/operator proof, installer parity, and bounded enterprise docs
- backfilled authoritative verification artifacts for Phases 123, 124, and 125

Archives: [`.planning/milestones/v1.27-ROADMAP.md`](milestones/v1.27-ROADMAP.md), [`v1.27-REQUIREMENTS.md`](milestones/v1.27-REQUIREMENTS.md), [`v1.27-MILESTONE-AUDIT.md`](milestones/v1.27-MILESTONE-AUDIT.md).

### Previously shipped: v1.26 PK-LIFECYCLE

- strengthened last-passkey deletion truth
- backfilled `PK-02` through `115-VERIFICATION.md` and `115-VALIDATION.md`
- kept passkey-primary and enrollment flows recovery-first
- clarified cross-device and RP-ID migration posture
- closed `PK-05` with generated-host/browser proof and repaired-form verification
- closed `PK-03` through the repaired Phase 116 backfill artifacts and current-head browser proof
- completed the remaining Nyquist cleanup and milestone re-audit reconciliation through Phase 121
- locked the repaired-form rule: Phases 119 and 120 are completed backfill/reconciliation phases, while proof authority remains on Phases 115 and 116
- did not claim Sigra-owned sync, restore, migration, escrow, or cross-platform portability

### Previously shipped: v1.25 EMAIL-RAILS

- generated-host override seam for auth emails (override rails and failure handler seams)
- provider-agnostic async-delivery telemetry verified as a zero-code closure
- canonical bounce/complaint normalizer, host-owned handler seam, and runnable provider recipes

**Corrigendum (v1.29 DOC-01, 2026-05-28):** The original v1.25 narrative claimed an optional Mailglass adapter plus `--with-mailglass` installer path and a Mailglass preview catalog for auth emails. These did not land on the release branch. The library-resident `Sigra.Mailers.Adapters.Mailglass` module and the `--with-mailglass` flag from Phase 111/114 were never merged to `main` and are not part of the supported surface. The supported Mailglass posture is recipe-only host-owned wiring via the `Sigra.Mailer` behaviour — no library-resident adapter, no `--with-mailglass` flag. See `guides/recipes/companion-libs/mailglass.md`.

### Previously shipped: v1.24 Session Control Plane

- preserve-current revoke semantics via a library-owned `revoke_other_sessions` seam
- truthful current-session labeling across user and admin surfaces
- recent security activity over persisted audit rows
- repaired-form verification artifacts for Phases 108-109 and a passing live milestone audit

### Previously closed milestones

**v1.22 — Webhooks / outbound event pipeline** — **Phases 97–102** (shipped **2026-05-06**). Phase **97** established the public event catalog, durable subscription registry, stable payload envelope, and signing contract. Phase **98** made delivery reliable with persisted attempts, bounded retries, and dead-letter state. Phase **99** turned that capability into a usable adopter feature through generated admin LiveViews, routing, and host guidance. Gap-closure Phase **100** restored the production enqueue handoff from persisted delivery rows into the async worker path, Phase **101** made retrying/dead-lettered operator views truthful, and Phase **102** proved the generated-host flow end to end while reconciling `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and verification artifacts. Archives: [`.planning/milestones/v1.22-ROADMAP.md`](milestones/v1.22-ROADMAP.md), [`v1.22-REQUIREMENTS.md`](milestones/v1.22-REQUIREMENTS.md), [`v1.22-MILESTONE-AUDIT.md`](milestones/v1.22-MILESTONE-AUDIT.md).

**v1.21 — B2B-ready & production-honest** — **Phases 91–96** (shipped **2026-05-06**). Three legs converged: **B2B trust** — Phase **91** org-level MFA enforcement (**B2B-01**) with `Sigra.Plug.RequireOrgMfa` + atomic `organization.mfa_policy_change` audit row, Phase **92** RBAC seams (**B2B-02**) shipping `Sigra.Authz` behaviour + nullable `role` on memberships + scope-struct `:role` propagation + role-based-access-control recipe (zero opinionated roles), Phase **93** M2M / service-account tokens (**B2B-03**) with `client_credentials` grant on existing JWT path + `current_scope.actor_type: :service_account` discriminator + 5 SA-mutation rollback proofs (re-verified 22/22 after gap-closure plans 06–10 + critical fixes in commit `bf5a8a8`). **Production hardening** — Phase **94** Postgres-only declaration (**HARD-01**) refusing non-Postgres at `mix sigra.install` pre-flight + removed MySQL/SQLite placeholder branches + aligned `mix.exs` description / README / getting-started (env Oban-test caveat closed 2026-05-06), Phase **95** optional-dep boot validation (**HARD-02**) via `Sigra.OptionalDeps` SOT + raise-on-missing for Oban/Bcrypt/EQRCode + `mix sigra.doctor` per-feature dep matrix + 3 dep-off CI lanes (only v1.21 phase with `nyquist_compliant: true`). **OAuth + API polish** — Phase **96** OAuth refresh dispatch (**HARD-03**) for GitHub/Apple/Facebook/Generic via Assent + atomic `oauth.token_refreshed` audit + rate-limit headers (**API-01**) emitting `X-RateLimit-Limit/Remaining/Reset` + `Retry-After` from Hammer state in single-pass plug (122 passing tests across 4 evidence sections). Audit: tech_debt → reconciled (substantive 7/7; bookkeeping reconciled 2026-05-06). Open at close (non-blocking): 2 install-smoke todos from 2026-04-30, `DEF-92-02-01` pre-existing audit Multi step-name collision (predates Phase 92), Nyquist VALIDATION.md gaps for 91/92/93/94/96. Archives: [`.planning/milestones/v1.21-ROADMAP.md`](milestones/v1.21-ROADMAP.md), [`v1.21-REQUIREMENTS.md`](milestones/v1.21-REQUIREMENTS.md), [`v1.21-MILESTONE-AUDIT.md`](milestones/v1.21-MILESTONE-AUDIT.md).

**v1.20 — GA Launch (SEED closure + public release)** — **Phases 85–90** (shipped **2026-04-28**). Closed **SEED-002** OAuth audit atomicity remainder (Phase **45 T2** clusters **052–056**, **058**, **063** to atomic **`Multi` + `log_multi_safe`**; Phase 9 **C-1 PASS-WITH-CAVEATS → PASS**). Closed **SEED-001** GA UAT — all 8 rows machine-substituted via Playwright + Premailex (**GAUAT-01..09**) with evidence under **`.planning/uat-evidence/v1.20/`**. Public launch via **`mix hex.publish`** v1.20.0 + README "use this in production" promotion + CHANGELOG alignment (**LAUNCH-01..07**). **Phase 90** publicity / monitoring waived. Archives: [`.planning/milestones/v1.20-ROADMAP.md`](milestones/v1.20-ROADMAP.md), [`v1.20-REQUIREMENTS.md`](milestones/v1.20-REQUIREMENTS.md), [`v1.20-MILESTONE-AUDIT.md`](milestones/v1.20-MILESTONE-AUDIT.md).

**v1.19 — JWT refresh persistence + audit co-fate & MFA enrollment failure (SEED-002)** — **Phases 82–83** (shipped **2026-04-24**). Closed the **v1.18** footnote deferral: **JWT `user_tokens` rotation** (`Sigra.JWT.RefreshToken` / **`Sigra.JWT.refresh/3`**) shares a **single transactional boundary** with **`api.jwt_refresh`** / **`api.jwt_refresh_reuse`** audit rows when `:audit_schema` is set. Second tranche: **`AUD-04-022`** / **`EX-44-02`** — invalid pre-DB TOTP on **`Sigra.MFA.confirm_enrollment/5`** promoted to the same **`Multi` + `log_multi_safe`** discipline where semantics allow. Plus **Phase 84** routing-honesty reconciliation (**2026-04-25**).

**Previously closed:** **v1.18 — JWT refresh / reuse audit atomicity (SEED-002 / AUD-04-048..049 / AUD-18)** (**Phase 81**, **AUD-18-01**..**AUD-18-04**, **2026-04-24**). **`Sigra.APIToken.audit_jwt_refresh/2`** / **`audit_jwt_refresh_reuse/2`** use **`Repo.transaction/1`** + audit-only **`Multi` + `log_multi_safe`** when `:audit_schema` is set; **`api_token_audit_atomic_test.exs`**; **44** / **45** / **09** / **`CHANGELOG` [Unreleased]**; **JWT persistence co-fate** explicitly deferred to **v1.19**. Verification: **`.planning/phases/81-jwt-refresh-audit-atomicity/81-VERIFICATION.md`**.

**Previously closed:** **v1.17 — Forced password change audit atomicity (SEED-002 / AUD-04-043)** (**Phase 80**, **AUD-17-01**..**AUD-17-04**, **2026-04-24**). **`Sigra.Account.clear_password_change_requirement/3`** **`Multi` + `log_multi_safe`**; **`audit_forced_password_change/2`** **`@deprecated`**; **`account_audit_atomicity_test.exs`**; **44** / **09** / **09-03-SUMMARY** / **`CHANGELOG` [Unreleased]**; **EX-44-05** closed. Archives: [`.planning/milestones/v1.17-ROADMAP.md`](milestones/v1.17-ROADMAP.md), [`.planning/milestones/v1.17-REQUIREMENTS.md`](milestones/v1.17-REQUIREMENTS.md). Verification: **`.planning/phases/80-forced-password-change-audit/80-VERIFICATION.md`**.

**Previously closed:** **v1.16 — API verify failure audit atomicity (SEED-002 slice)** (**Phase 79**, **AUD-16-01**..**AUD-16-04**, **2026-04-24**). **`Sigra.APIToken.verify/2`** failure **`api.token_verify.failure`** via **`Repo.transaction/1`** + **`Multi` + `log_multi_safe`**; **`api_token_audit_atomic_test.exs`**; **44** / **09** / **09-03-SUMMARY** / **`CHANGELOG` [Unreleased]**; **D-27** preserved. Archives: [`.planning/milestones/v1.16-ROADMAP.md`](milestones/v1.16-ROADMAP.md), [`.planning/milestones/v1.16-REQUIREMENTS.md`](milestones/v1.16-REQUIREMENTS.md). Verification: **`.planning/phases/79-api-token-verify-failure-audit/79-VERIFICATION.md`**.

**Previously closed:** **v1.15 — Account + API C-1 planning truth (SEED-002 slice)** (**Phase 78**, **AUD-14**..**AUD-14-05**, **2026-04-24**). **44** + **09** C-1 planning truth for **035–042**, **047**; **`09-03-SUMMARY`** + **`CHANGELOG` [Unreleased]**; **`account_audit_atomicity_test.exs`** **`change_password`**. Archives: [`.planning/milestones/v1.15-ROADMAP.md`](milestones/v1.15-ROADMAP.md), [`.planning/milestones/v1.15-REQUIREMENTS.md`](milestones/v1.15-REQUIREMENTS.md). Verification: **`.planning/phases/78-account-api-c1-planning-truth/78-VERIFICATION.md`**.

**Previously closed:** **v1.14 — Bounded audit trust closure (SEED-002 slice)** (**Phase 77**, **AUD-13**..**AUD-13-04**, **2026-04-24**). **`audit_backup_codes_regenerate/3`** and **`audit_trust_browser/2`** use **`commit_ad_hoc_mfa_audit/5`**; **`mfa_audit_atomicity_test.exs`**; planning truth on **09** / **44** / **CHANGELOG**. Archives: [`.planning/milestones/v1.14-ROADMAP.md`](milestones/v1.14-ROADMAP.md), [`.planning/milestones/v1.14-REQUIREMENTS.md`](milestones/v1.14-REQUIREMENTS.md). Verification: **`.planning/phases/77-mfa-adhoc-audit-multi/77-VERIFICATION.md`**.

**Previously closed:** **v1.13 — Post–v1.12 operational cadence** (planning **2026-04-24**, **Phase 76**, **CAD-01**..**CAD-03**). Archives: [`.planning/milestones/v1.13-ROADMAP.md`](milestones/v1.13-ROADMAP.md), [`.planning/milestones/v1.13-REQUIREMENTS.md`](milestones/v1.13-REQUIREMENTS.md). Attestation: **`.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md`**.

**Last shipped code milestone:** **v1.18 — JWT refresh / reuse audit atomicity** (**Phase 81**, **2026-04-24**; **`AUD-18`**). Verification: **`.planning/phases/81-jwt-refresh-audit-atomicity/81-VERIFICATION.md`**. _(Prior: **v1.17** — **Phase 80** / **`AUD-17`**.)_

**Previously closed:** **v1.11 Adoption stabilization** — shipped **2026-04-23** (**phases 71–72**; **`STAB-01`**..**`STAB-04`**). Archives: [`.planning/milestones/v1.11-ROADMAP.md`](milestones/v1.11-ROADMAP.md), [`v1.11-REQUIREMENTS.md`](milestones/v1.11-REQUIREMENTS.md); triage [`.planning/v1.11-TRIAGE.md`](v1.11-TRIAGE.md).

**Previously closed:** **v1.10 Adopter confidence for solo production** — shipped **2026-04-23** (**phases 68–70**; **`ACF-01`**..**`ACF-06`**). Archives: [`.planning/milestones/v1.10-ROADMAP.md`](milestones/v1.10-ROADMAP.md), [`v1.10-REQUIREMENTS.md`](milestones/v1.10-REQUIREMENTS.md), [`v1.10-MILESTONE-AUDIT.md`](milestones/v1.10-MILESTONE-AUDIT.md); summary in [`.planning/MILESTONES.md`](MILESTONES.md).

**Reader bundle (v1.10 planning label):** [`.planning/v1.10-ADOPTER-SCOPE.md`](v1.10-ADOPTER-SCOPE.md).

**Previously closed:** **v1.9 Audit atomicity (bounded SEED-002)** — shipped **2026-04-23** (**phases 66–67**; **`AUD-09`** + **`AUD-10`**). Archives: [`.planning/milestones/v1.9-ROADMAP.md`](milestones/v1.9-ROADMAP.md), [`v1.9-REQUIREMENTS.md`](milestones/v1.9-REQUIREMENTS.md), [`v1.9-MILESTONE-AUDIT.md`](milestones/v1.9-MILESTONE-AUDIT.md).

**Reference (continuing work):** **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`** for further **SEED-002** batches when scheduled.

## Current State

**v1.23 (shipped 2026-05-08):** Phases **103–107** closed the webhook operator-trust follow-ons to v1.22. Phase **103** shipped overlap-safe secret rotation with a dual-slot lifecycle and overlap-window signatures (**WH-04**). Phase **104** implemented replay recovery as new delivery lineage, and Phase **106** authoritatively verified that recovery path through `104-VERIFICATION.md` (**WH-05**). Phase **105** implemented webhook egress policy enforcement, and Phase **107** closed the remaining operator-truth and evidence gap for `WH-06` through `105-VERIFICATION.md`, `105-VALIDATION.md`, and the blocked-policy proof bundle under `.planning/uat-evidence/v1.23/webhook-policy-operator-truth/`.

**v1.22 (shipped 2026-05-06):** Phases **97–102** delivered the outbound event pipeline: signed event contract, durable subscription registry, bounded retries, dead-letter state, generated admin UX, production enqueue repair, operator-truth queries, and generated-host proof.

**v1.21 (shipped 2026-05-06):** Phases **91–96** — B2B trust + production hardening + API polish. Org-level MFA enforcement (**B2B-01**, Phase 91), RBAC seams (**B2B-02**, Phase 92), M2M service-account tokens (**B2B-03**, Phase 93, re-verified 22/22), Postgres-only declaration (**HARD-01**, Phase 94), optional-dep boot validation + `mix sigra.doctor` (**HARD-02**, Phase 95), OAuth refresh + rate-limit headers (**HARD-03 + API-01**, Phase 96). Audit: tech_debt → reconciled. Phase numbering continues from **Phase 96**. Archives: [`.planning/milestones/v1.21-ROADMAP.md`](milestones/v1.21-ROADMAP.md), [`v1.21-REQUIREMENTS.md`](milestones/v1.21-REQUIREMENTS.md), [`v1.21-MILESTONE-AUDIT.md`](milestones/v1.21-MILESTONE-AUDIT.md).

**v1.20 (shipped 2026-04-28):** Phases **85–90** — **AUD-21** (OAuth audit atomicity closure: Phase 45 T2 clusters 052–056 / 058 / 063 → atomic `Multi`; Phase 9 **C-1 PASS-WITH-CAVEATS → PASS**), **GAUAT-01..09** (machine substitutes for all 8 SEED-001 rows via Playwright + Premailex; evidence at `.planning/uat-evidence/v1.20/`), **LAUNCH-01..07** (Hex v1.20.0 push + README promotion + CHANGELOG alignment). Phase 90 publicity / monitoring waived. Verification: `.planning/phases/89-pre-launch-hex-publish/`, milestone audit `.planning/milestones/v1.20-MILESTONE-AUDIT.md`.

**v1.19 (shipped 2026-04-24):** Phases **82–83** — **AUD-19** (JWT **`user_tokens`** persistence + **`api.jwt_refresh*`** co-fate) + **AUD-20** (**`AUD-04-022`** invalid-code → **`commit_ad_hoc_mfa_audit/5`**). **`83-VERIFICATION.md`** / **`82-VERIFICATION.md`** merge gates. **Phase 84** routing-honesty reconciliation closed **2026-04-25** (`84-VERIFICATION.md`).

**v1.18 (shipped 2026-04-24):** Phase **81** — **AUD-18-01**..**AUD-18-04** — **`audit_jwt_refresh/2`** / **`audit_jwt_refresh_reuse/2`** transactional **`log_multi_safe`** (audit-only txn); **`api_token_audit_atomic_test.exs`**; **44** / **45** / **09** / **`CHANGELOG` [Unreleased]**; **persistence co-fate** → **v1.19**. Verification: **`.planning/phases/81-jwt-refresh-audit-atomicity/81-VERIFICATION.md`**.

**v1.17 (archived 2026-04-24):** Phase **80** — **AUD-17-01**..**AUD-17-04** — **`clear_password_change_requirement/3`** + **`account_audit_atomicity_test.exs`**; **44** / **09** / **09-03-SUMMARY** / **`CHANGELOG` [Unreleased]**; **EX-44-05** closed. Archives **`milestones/v1.17-ROADMAP.md`**, **`milestones/v1.17-REQUIREMENTS.md`**; verification **`.planning/phases/80-forced-password-change-audit/80-VERIFICATION.md`**.

**v1.16 (archived 2026-04-24):** Phase **79** — **AUD-16-01**..**AUD-16-04** — **`Sigra.APIToken.verify/2`** **`api.token_verify.failure`** transactional **`log_multi_safe`** (**AUD-04-044..046**); **`api_token_audit_atomic_test.exs`**; archives **`milestones/v1.16-ROADMAP.md`**, **`milestones/v1.16-REQUIREMENTS.md`**; verification **`.planning/phases/79-api-token-verify-failure-audit/79-VERIFICATION.md`**.

**v1.15 (archived 2026-04-24):** Phase **78** — **AUD-14**..**AUD-14-05** — **SEED-002** planning truth for **Account** + **`APIToken.revoke`** C-1 rows (**AUD-04-035..042**, **047**) aligned to **`lib/`**; **`account_audit_atomicity_test.exs`** **`change_password`**. Archives: **`milestones/v1.15-ROADMAP.md`**, **`milestones/v1.15-REQUIREMENTS.md`**; verification **`.planning/phases/78-account-api-c1-planning-truth/78-VERIFICATION.md`**.

**v1.14 (archived 2026-04-24):** Phase **77** — **AUD-13**..**AUD-13-04** MFA ad-hoc audit **`Multi`** closure. Archives: **`milestones/v1.14-ROADMAP.md`**, **`milestones/v1.14-REQUIREMENTS.md`**; verification **`.planning/phases/77-mfa-adhoc-audit-multi/77-VERIFICATION.md`**.

**v1.13 (planning shipped 2026-04-24):** Phase **76** — **CAD-01**..**CAD-03** cadence lock-in. Archives: **`milestones/v1.13-ROADMAP.md`**, **`milestones/v1.13-REQUIREMENTS.md`**; verification **`.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md`**.

**v1.12 (shipped 2026-04-24):** Phases **73–75** complete — bounded **SEED-002** batch + **09-03** truth (**73**), launch evidence + **`docs/uat-ci-coverage.md`** alignment (**74**), and upgrade continuity + triage reconciliation (**75**). Planning archives: **`milestones/v1.12-ROADMAP.md`**, **`milestones/v1.12-REQUIREMENTS.md`**; verification **`.planning/phases/75-upgrade-continuity-triage-polish/75-VERIFICATION.md`**.

**v1.11 (shipped 2026-04-23):** Phases **71–72** — **`STAB-01`**..**`STAB-04`** adoption stabilization (triage log, **`MAINTAINING.md`** pause guidance, **`upgrading-to-v1.11.md`** + ExDoc, intro cross-links). Archives: [`.planning/milestones/v1.11-ROADMAP.md`](milestones/v1.11-ROADMAP.md), [`v1.11-REQUIREMENTS.md`](milestones/v1.11-REQUIREMENTS.md).

**v1.10 (shipped 2026-04-23):** Phases **68–70** — **`ACF-01`**..**`ACF-06`** adopter-confidence documentation (deployment + mail hub, intermediate path + **`generator-options`** index, **`upgrading-to-v1.10.md`** + **ADR 001** / **SEED-002** non-goal attestation). Archives: [`.planning/milestones/v1.10-ROADMAP.md`](milestones/v1.10-ROADMAP.md), [`v1.10-REQUIREMENTS.md`](milestones/v1.10-REQUIREMENTS.md).

**v1.9 (shipped 2026-04-23):** Phases **66–67** — **`confirm_enrollment/5`** **AUD-04-020..021** **`Multi`** + **`mfa_audit_atomicity_test.exs`** (**AUD-09**); **`09-03-SUMMARY.md`** + **D-06** attestation (**AUD-10**). Archives: [`.planning/milestones/v1.9-ROADMAP.md`](milestones/v1.9-ROADMAP.md), [`v1.9-REQUIREMENTS.md`](milestones/v1.9-REQUIREMENTS.md), [`v1.9-MILESTONE-AUDIT.md`](milestones/v1.9-MILESTONE-AUDIT.md).

**v1.8 (shipped 2026-04-23):** Phases **63–65** — **ADOPT-04** / **ADOPT-05** / **INTG-02** doc polish (archives: [`.planning/milestones/v1.8-ROADMAP.md`](milestones/v1.8-ROADMAP.md), [`v1.8-REQUIREMENTS.md`](milestones/v1.8-REQUIREMENTS.md)).

**v1.7 (shipped 2026-04-23):** **Phases 60–62** — archives: [`.planning/milestones/v1.7-ROADMAP.md`](milestones/v1.7-ROADMAP.md), [`v1.7-REQUIREMENTS.md`](milestones/v1.7-REQUIREMENTS.md), [`v1.7-MILESTONE-AUDIT.md`](milestones/v1.7-MILESTONE-AUDIT.md). **Phase 61:** **`AUD-01`** — `verify_backup/4` wrong-code failures are **`Ecto.Multi`** + **`log_multi_safe`** with **`mfa_audit_atomicity_test.exs`**; **AUD-04-067** + C-1 matrix refreshed. **Phase 62:** **`AUD-02`** — **`09-03-SUMMARY.md`** carries **v1.7** document status + Phase **61** bounded-batch narrative keyed to **`AUD-04-067`**; **D-06** left **`09-VERIFICATION.md`** unchanged. **Phase 60:** adoption + companion recipe guides under **`guides/introduction/`** and **`guides/recipes/companion-oauth-provider.md`** (no discrete **`060-*`** phase directory — see milestone audit).

**v1.6 (shipped):** **Phases 57–59** — **NYQ-01** / **NYQ-02** Nyquist posture matrix for **41–44**, **OA-01** merge-blocking OAuth ceremony audit coverage (**`Sigra.OAuthCeremonyAuditTest`**, **`phase_58_oauth_oa01_ci_contract_test`**), and **OA-02** documentation alignment across **`docs/uat-ci-coverage.md`**, **GA-03** planning surfaces, and maintainer routers. Archives: `.planning/milestones/v1.6-ROADMAP.md`, `v1.6-REQUIREMENTS.md`, `v1.6-MILESTONE-AUDIT.md` (audit filed retroactively on 2026-04-23).

**v1.5 (narrative + maintainer readiness):** Shipped **2026-04-22** — **`mix.exs`** Hex metadata (**PUB-01**), **`CHANGELOG.md`** milestone anchors (**PUB-02**), README / ExDoc GA entry paths (**DOC-01**, **DOC-02**), and maintainer **First public launch** checklist in **`MAINTAINING.md`** (**MAINT-01**). Archives: `.planning/milestones/v1.5-ROADMAP.md`, `v1.5-REQUIREMENTS.md`.

**Shipped:** **v1.4 GA readiness & audit trail completeness** (2026-04-22) — Phases **41–52**: backup-code rotation (**GA-01**), GA matrix with executed/waived rows and evidence (**GA-02..GA-05**), audit inventory + prioritized **`log_safe/3` → `Ecto.Multi`** batches through **OAuth/ops** (**AUD-04..AUD-08**) with formal **43/44/45 `*-VERIFICATION.md`** gates, **Nyquist + install-golden CI** policy (**50–51**), and **ROADMAP / milestone honesty** guardrails (**52**). Archives: `.planning/milestones/v1.4-ROADMAP.md`, `v1.4-REQUIREMENTS.md`, `v1.4-MILESTONE-AUDIT.md`.

**Previously shipped:** v1.3 Cleanup & Hardening (2026-04-19); v1.2 Admin Dashboard (2026-04-17); v1.1 Foundations (2026-04-16); v1.0 Phoenix Auth Library (2026-04-11).

Sigra is a Phoenix 1.8+ authentication platform spanning the v1.0 auth stack, v1.1 organizations and passkeys, v1.2 admin (default-on installer admin surface, impersonation, audit exploration, automation-first verification, generator parity), v1.3 hardening (validation/CI/UAT/audit-testability/maintainer tooling), and **v1.4 GA + audit-trail closure** (defensible GA substitutes where waived, broader atomic audit writes with merge-gated verification, CI truth for installer golden).

**Verification:** v1.4 requirements **10/10** satisfied in archive (Complete or Waived with documented substitutes); v1.3 milestone audit **passed** at close (2026-04-19); v1.2 audit **passed** (2026-04-17) with **23/23** in archive; v1.1 remains **79/79** in its archive.

## Next milestone goals

**Current ranking source:** [`.planning/MILESTONE-ARC.md`](MILESTONE-ARC.md)

**Immediate next action:** v1.32 RELEASE-ADOPTION is active — plan Phase 148 with `/gsd-plan-phase 148`.

**Recent between-milestones closeouts:** **`REL-01 Release Truth Reset`** (v1.20-era release/version truth reset)

**Last shipped milestone:**
- `v1.31 DEMO-SHOWCASE` (shipped 2026-05-31, Phases 141–144.2) — Seed-rich Evaluator Demo Showcase. The named milestone arc was exhausted through v1.29; v1.30 deepened shipped substrate per the arc's own ranking rules (diagnostics/trust > greenfield), shipping the previously trigger-gated `Sigra.OptionalDeps` SOT + `mix sigra.doctor`. v1.32 is now active as the real Hex `1.32.0` release and adoption push.

**Ranked follow-on (next candidates after v1.30):**
- **"Demo Showcase"** — seed-rich, persona-driven, one-command spin-up extending `test/example/` (not a new repo). Ranked highest-value near-term build by the mid-v1.30 boundary assessment; closes the one genuine adoption gap (no evaluator-facing demo). See `.planning/threads/adoption-evidence-and-demo-showcase.md`.
- **1.0 Hex cut + adoption push** — the honest bottleneck is absence of real adopters, not features.
- `SCIM / Directory Sync` — newly ripe (ENT-SSO proved the login+JIT wedge the arc required); large; compliant with the Wall. Strongest greenfield candidate.
- Threadline correlation-ID propagation (CORR-01) — blocked on a stable Threadline injection seam.
- `sigra_lockspire` glue package (ADR 001) — blocked until both libraries stabilize + a real companion-app trigger fires.
- The "Diminishing Returns Wall" still excludes opinionated authz, billing, and frontend component libraries.

**Deferred after `v1.29` shipment:**
- `sigra_lockspire` glue package per **ADR 001** once a real companion-app trigger fires.
- full SCIM / directory sync and generic directory lifecycle automation until an enterprise SSO milestone proves the narrower login + JIT wedge first
- Any theme that primarily expands generic admin CRUD, hosted-control-plane behavior, or authz policy rather than the auth control plane itself.
- Any newly identified validation or assurance work should use newly numbered phases; do not reuse **999.x**.

**Backlog / hygiene:** **`999.1`** / **999.x** remain archaeology only; see **`.planning/ROADMAP.md`** and **`999.1-*`** tombstone files. **`STATE.md`** is session handoff only. **Planning precedence:** **`ROADMAP.md`** + phase **`*-VERIFICATION.md`** / **`*-VALIDATION.md`** over conflicting **`STATE.md`** notes.

<details>
<summary>Archived v1.2 milestone framing (Admin Dashboard)</summary>

**Goal:** Ship a default-on admin surface that feels excellent to use: mobile-responsive LiveView user management, secure impersonation, and rich audit exploration on top of the v1.1 organizations and passkeys foundation.

**Target features (shipped in v1.2):**
- Admin user-management UI in LiveView, default on with `--no-admin` opt-out, mobile-friendly, light/dark, and basic branding hooks
- Admin impersonation with strict guardrails, visible session state, dual-actor audit trail, and blocked sensitive mutations while impersonating
- Expanded audit views across user, organization, and global admin workflows with scope-respecting CSV export
- Automation-first verification: Playwright, screenshots/video where useful, HTML reports, browser and curl-style smoke, CI jobs including generated-host parity and shift-left gates (Phases 31-35)

</details>

<details>
<summary>Archived v1.1 milestone framing</summary>

**Goal:** Ship the architectural foundation that unlocks v1.2's admin dashboard — logical multi-tenancy (organizations + memberships, single DB, no PG schema-per-tenant) and passkey/WebAuthn authentication. No admin UI in this milestone; only the user-facing surface each feature needs to be usable end-to-end.

**Target features:**
- Organizations (logical multi-tenancy, default-on with `--no-organizations` opt-out): `Organization` / `OrganizationMembership` / `OrganizationInvitation` schemas, `Sigra.Organizations` context, `Sigra.Plug.RequireMembership`, Scope struct extension (`:active_organization`, `:membership`), sessions `active_organization_id` column, automatic `organization_id` in audit metadata, HMAC-protected invite flow with email acceptance, `OrganizationSwitcherLive` / `OrganizationSettingsLive` / `OrganizationMembersLive` / `InvitationAcceptLive`, generator conditional template pattern (first in codebase, load-bearing for v1.2 `--no-admin`)
- Passkeys (WebAuthn via `wax_`, default-on with `--no-passkeys` opt-out): `UserPasskey` schema with `cloak_ecto`-encrypted public keys, `Sigra.Passkeys` / `Sigra.Passkeys.Registration` / `Sigra.Passkeys.Authentication` contexts, `Sigra.Plug.PasskeyChallenge`, passkey-as-2FA AND passkey-as-primary modes, `PasskeyEnrollmentLive` / `PasskeyAuthenticationLive`, `MfaSettingsLive` updates to list passkeys alongside TOTP, runtime RP ID / origin config, JS hooks for credential ceremonies

**Deferred to v1.2 "Admin Dashboard"** (full direction captured in `.planning/v1.2-DIRECTION.md`): admin user-management LiveView UI (Django-admin-loved, mobile-first, light+dark mode, basic branding, default-on opt-out), admin impersonation (time-limited, audited, sudo-gated, locked-down sensitive ops, org-scoped for org admins), expanded audit views (per-user, per-org, global, impersonation feed, CSV export).

</details>

## Requirements

### Validated — Phase 151
- ✓ **ECO-01, ECO-02, ECO-03** — Validated in Phase 151: ecosystem-sync-hex-dependency-management

### Validated — v1.31 DEMO-SHOWCASE (shipped 2026-05-31)

_See [`.planning/milestones/v1.31-REQUIREMENTS.md`](milestones/v1.31-REQUIREMENTS.md), [`.planning/milestones/v1.31-ROADMAP.md`](milestones/v1.31-ROADMAP.md), and [`.planning/milestones/v1.31-MILESTONE-AUDIT.md`](milestones/v1.31-MILESTONE-AUDIT.md) for the archived bounded contract (14/14 satisfied)._

- ✓ **SEED-01..SEED-06** — deterministic six-persona demo seed layer with idempotency, test-env guard, audit variety, and security posture — **Phase 141**
- ✓ **DEMO-01, DEMO-02** — dev credentials page, stdout summary, and realistic app framing — **Phase 142**
- ✓ **PW-01..PW-03** — isolated demo-showcase Playwright partition, screenshots, and seeds-smoke coverage — **Phase 143**
- ✓ **DOC-01..DOC-03** — evaluator README lane, guide, ExDoc wiring, screenshots, and proof bundle — **Phase 144**

### Validated — v1.30 TRUST-HARDENING (shipped 2026-05-29)

_See [`.planning/milestones/v1.30-REQUIREMENTS.md`](milestones/v1.30-REQUIREMENTS.md), [`.planning/milestones/v1.30-ROADMAP.md`](milestones/v1.30-ROADMAP.md), and [`.planning/milestones/v1.30-MILESTONE-AUDIT.md`](milestones/v1.30-MILESTONE-AUDIT.md) for the archived bounded contract (11/11 satisfied)._

- ✓ **OD-01, OD-02** — `Sigra.OptionalDeps` single-source-of-truth (9 `*_available?/0` predicates + `encryption_active?/1`); ~29 scattered `Code.ensure_loaded?` guards consolidated across 17 delegation sites with zero runtime behavior change — **Phase 137**
- ✓ **DR-01, DR-02** — `mix sigra.doctor`: per-feature optional-dep matrix with remediation hints + four boot-wiring hard-fail checks + non-zero CI exit gate — **Phase 138**
- ✓ **RCT-01** — merge-blocking ExUnit fixture asserting all 6 companion-lib recipes carry the five required contract markers — **Phase 139**
- ✓ **RCV-01, RCV-02** — Lockspire `resolve_account/2` return shape + Rulestead `@behaviour` contract verified against sister repos (`def616d`/`0a18360`) and recipes corrected — **Phase 139**
- ✓ **DEPR-01, DEPR-02** — Hex-SemVer removal targets + migration notes for `audit_forced_password_change/2` (→ 0.5.0) and `cookie_opts/0` (→ 0.4.0) — **Phase 140**
- ✓ **PROOF-01, DOC-01** — eight-gate proof bundle (full suite + dep-off lane + `mix docs --warnings-as-errors` + `test/example/` doctor run + per-phase verification) + docs alignment — **Phase 140**

### Validated — v1.29 SUITE-INTEGRATION (shipped 2026-05-29)

_See [`.planning/milestones/v1.29-REQUIREMENTS.md`](milestones/v1.29-REQUIREMENTS.md), [`.planning/milestones/v1.29-ROADMAP.md`](milestones/v1.29-ROADMAP.md), and [`.planning/milestones/v1.29-MILESTONE-AUDIT.md`](milestones/v1.29-MILESTONE-AUDIT.md) for the archived bounded contract (16/16 satisfied)._

- ✓ **TL-01..TL-05, FB-01** — `Sigra.Audit.Forwarder` behaviour + `Sigra.Audit.Forwarders.Threadline`/`Noop` + optional `Sigra.Workers.AuditForward` worker; `:auto`/`:async`/`:sync` dispatch; `[:sigra,:audit,:forward,:ok|:error]` telemetry; optional-dep safe; Sigra audit row stays source-of-truth — **Phase 131**
- ✓ **RC-01, RC-02** — Threadline canary recipe + Mailglass host-owned-wiring recipe under `guides/recipes/companion-libs/` — **Phase 132**
- ✓ **NX-01** — `guides/introduction/suite-integration.md` suite narrative + ecosystem diagram + fan-out matrix + README pointer — **Phase 133**
- ✓ **RC-03..RC-06** — Accrue, Lockspire, Relyra, Rulestead recipe-only companion-lib docs — **Phase 134**
- ✓ **EX-01** — runnable end-to-end Threadline forwarder demo in `test/example/` proven on existing CI lanes — **Phase 135**
- ✓ **PROOF-01, DOC-01** — six-gate proof bundle (full suite + dep-off lane + example app + `mix docs --warnings-as-errors` exit 0) + v1.25 EMAIL-RAILS Mailglass-narrative corrigendum — **Phase 136**

### Validated — v1.28 DATA-LIFECYCLE (shipped 2026-05-27)

_See [`.planning/milestones/v1.28-REQUIREMENTS.md`](milestones/v1.28-REQUIREMENTS.md), [`.planning/milestones/v1.28-ROADMAP.md`](milestones/v1.28-ROADMAP.md), and [`.planning/milestones/v1.28-MILESTONE-AUDIT.md`](milestones/v1.28-MILESTONE-AUDIT.md) for the archived bounded contract._

- ✓ **EXP-01** — Versioned Sigra-owned auth/account export with lifecycle fields, sessions, identities, audit rows, MFA, passkeys, backup-code summary, and org memberships — **Phase 127**
- ✓ **EXP-02** — Explicit structured omission notes for missing optional export schemas (truthful, not silent) — **Phase 127**
- ✓ **LIFE-01** — Deletion scheduling enqueues `Sigra.Workers.AccountDeletion` when Oban + generated-host context are available, with safe missing-context degradation — **Phase 128**
- ✓ **LIFE-02** — Cancel/execute paths gated to actively scheduled deletions; finalized users return `{:error, :not_scheduled}` — **Phase 128**
- ✓ **LIFE-03** — Soft-delete finalization clears scheduled deletion state and pending/original email fields without claiming hard deletion — **Phase 128**
- ✓ **HOST-01** — Generated host templates, example app, and install golden fixture preserve library export/lifecycle semantics — **Phase 129**
- ✓ **DOC-01** — Account lifecycle, audit export, and testing docs explain Sigra-owned vs host-owned data boundaries, omission behavior, and deletion strategy consequences — **Phase 129**
- ✓ **PROOF-01** — Targeted lifecycle/export tests + 2211 full-suite tests + `mix docs --warnings-as-errors` exit 0 (release docs gate unblocked by commit `110a560`) — **Phase 130**

### Archived — v1.27 ENT-SSO (shipped 2026-05-26)

_See [`.planning/milestones/v1.27-REQUIREMENTS.md`](milestones/v1.27-REQUIREMENTS.md), [`.planning/milestones/v1.27-ROADMAP.md`](milestones/v1.27-ROADMAP.md), and [`.planning/milestones/v1.27-MILESTONE-AUDIT.md`](milestones/v1.27-MILESTONE-AUDIT.md) for the archived enterprise SSO contract._

- **SSO-01 / SSO-02** — Organization-bound enterprise OIDC connection setup, validation, and truthful activation refusal — Phase 122
- **SSO-03** — Org-aware enterprise routing with bounded exact-match email-domain discovery, signed authorize context, callback revalidation — Phase 123
- **SSO-04 / JIT-01 / JIT-02** — Safe JIT enterprise reconciliation, exact invite reuse, first-session org/audit truth — Phase 124
- **ENF-01** — SSO-only enforcement with explicit break-glass recovery — Phase 125
- **PROOF-01 / OPS-01 / DOC-01** — Generated-host/operator proof, installer parity, bounded enterprise docs — Phase 126

### Archived — v1.26 PK-LIFECYCLE (shipped 2026-05-25)

_See [`.planning/milestones/v1.26-REQUIREMENTS.md`](milestones/v1.26-REQUIREMENTS.md), [`.planning/milestones/v1.26-ROADMAP.md`](milestones/v1.26-ROADMAP.md), and [`.planning/milestones/v1.26-MILESTONE-AUDIT.md`](milestones/v1.26-MILESTONE-AUDIT.md) for the archived bounded contract._

- **PK-02** — Last-passkey safety and truthful deletion consequences, backfilled through the authoritative Phase 115 verification and validation artifacts.
- **PK-03** — Recovery-first passkey-primary posture, backfilled through the authoritative Phase 116 verification and validation artifacts.
- **PK-04** — Cross-device, bootstrap, and RP-ID/origin migration truth, closed with current-head verification and validation.
- **PK-05** — Thin-host lifecycle contract plus generated-host/browser proof, closed with current-head verification and validation.

### Validated — v1.22 Webhooks / outbound event pipeline (shipped 2026-05-06)

_See [`.planning/milestones/v1.22-REQUIREMENTS.md`](milestones/v1.22-REQUIREMENTS.md) for the archived requirement contract and outcomes._

- ✓ **WH-01** — Host app can register outbound webhook subscriptions for Sigra-owned auth and identity events, and Sigra emits signed payloads with stable event IDs, timestamps, and a documented verification contract.
- ✓ **WH-02** — Each subscription can filter event types, failed deliveries retry automatically with bounded policy, and exhausted deliveries land in a dead-letter state with durable attempt history.
- ✓ **WH-03** — Generated admin LiveView lets adopters create, enable/disable, rotate, and inspect webhook subscriptions and delivery history without hand-editing Sigra internals.

### Validated — v1.20 GA Launch (shipped 2026-04-28)

- ✓ **LAUNCH-01, LAUNCH-02, LAUNCH-07** — Pre-launch Hex publish and README promotion — **Phase 89**
- ✓ **AUD-21** — OAuth audit atomicity closure (Phase 45 T2 cluster: 052–056, 058, 063 → atomic) — **Phase 85** (2026-04-25)
- ✓ **GAUAT-01** — Phase 04 lockout + suspicious-login email visual regression: 8 baselines, evidence under `.planning/uat-evidence/v1.20/email-phase-04/`, 0-human-MUA — **Phase 86** (2026-04-26)
- ✓ **GAUAT-02** — Phase 08 lifecycle email visual regression: 28 baselines, evidence under `.planning/uat-evidence/v1.20/email-phase-08/`, same residual policy as GAUAT-01 — **Phase 86** (2026-04-26)
- ✓ **GAUAT-03..09** — OAuth real-credential cycles + MFA backup-code rotation E2E + clean-machine getting-started — **Phases 87–88** (2026-04-26..28)
- ✓ **LAUNCH-03..06** — CHANGELOG alignment + maintainer monitoring lane (Phase 90 publicity / HN / community soft-launch waived per user direction)

### Validated — v1.19 JWT persistence + audit co-fate & MFA invalid-code audit (shipped in-repo 2026-04-24)

- ✓ **AUD-19-01** — **`Sigra.JWT` / `RefreshToken.rotate`** success path co-fates **`user_tokens`** + **`api.jwt_refresh`** when `:audit_schema` is set — **Phase 82**
- ✓ **AUD-19-02** — Reuse-detected path co-fates family revocation + **`api.jwt_refresh_reuse`** — **Phase 82**
- ✓ **AUD-19-03** — **`jwt_refresh_audit_cofate_test.exs`** (+ related) proves co-fate, audit-off, fault injection — **Phase 82**
- ✓ **AUD-19-04** — **09-VERIFICATION** / **44** / **45** / **09-03-SUMMARY** / **`CHANGELOG` [Unreleased]** + **`82-VERIFICATION.md`** — **Phase 82**
- ✓ **AUD-20-01** — **`Sigra.MFA.confirm_enrollment/5`** invalid-TOTP path → **`commit_ad_hoc_mfa_audit/5`** — **Phase 83**
- ✓ **AUD-20-02** — **`mfa_audit_atomicity_test.exs`** invalid-code matrix — **Phase 83**
- ✓ **AUD-20-03** — **44** inventory **022** + **EX-44-02**, **09** C-1 **022**, **09-03-SUMMARY**, **`CHANGELOG` [Unreleased]**, **`83-VERIFICATION.md`** — **Phase 83**

### Validated — v1.18 JWT refresh / reuse audit atomicity (shipped in-repo 2026-04-24)

- ✓ **AUD-18-01** — **`Sigra.APIToken.audit_jwt_refresh/2`** — **`Repo.transaction/1`** + audit-only **`Multi` + `log_multi_safe`** when `:audit_schema` set — **Phase 81**
- ✓ **AUD-18-02** — **`Sigra.APIToken.audit_jwt_refresh_reuse/2`** — same pattern — **Phase 81**
- ✓ **AUD-18-03** — **`api_token_audit_atomic_test.exs`** — happy path + audit insert **`CHECK`** rollback / audit-off — **Phase 81**
- ✓ **AUD-18-04** — **44** + **45** inventories, **09-VERIFICATION** C-1 **048–049**, **09-03-SUMMARY**, **`CHANGELOG` [Unreleased]** — **Phase 81**

### Validated — v1.17 Forced password change audit atomicity (shipped in-repo 2026-04-24)

- ✓ **AUD-17-01** — **`Sigra.Account.clear_password_change_requirement/3`** — **`Repo.transaction/1`** + **`Ecto.Multi`** + **`log_multi_safe`** when `:audit_schema` is set — **Phase 80**
- ✓ **AUD-17-02** — **`audit_forced_password_change/2`** **`@deprecated`** for that completion path — **Phase 80**
- ✓ **AUD-17-03** — **`account_audit_atomicity_test.exs`** forced-clear + **`CHECK`** rollback — **Phase 80**
- ✓ **AUD-17-04** — **44** / **09** / **09-03-SUMMARY** / **`CHANGELOG` [Unreleased]** — **Phase 80**

### Validated — v1.16 API verify failure audit atomicity (shipped in-repo 2026-04-24)

- ✓ **AUD-16-01** — **`verify/2`** invalid-token **`api.token_verify.failure`** — **`Repo.transaction/1`** + **`Multi` + `log_multi_safe`** — **Phase 79**
- ✓ **AUD-16-02** — **`verify/2`** revoked + expired failure branches — same pattern — **Phase 79**
- ✓ **AUD-16-03** — **44** + **09** + **09-03-SUMMARY** + **`CHANGELOG` [Unreleased]** — **044–046** **T1** — **Phase 79**
- ✓ **AUD-16-04** — **D-27** — no success-path **`api.token_verify`** audit — **Phase 79**

### Validated — v1.15 Account + API C-1 planning truth (shipped 2026-04-24)

- ✓ **AUD-14-01** — **44-AUD-04-INVENTORY** — **AUD-04-035..042** **`Multi` + `log_multi_safe`** + **Phase 78**; **043** was **`log_safe`** (**EX-44-05** open) at **v1.15** close — superseded by **v1.17** / **phase 80** (**AUD-17**) — **Phase 78**
- ✓ **AUD-14-02** — Same file — **AUD-04-047** **`Multi` + `log_multi_safe`**; **044–046** were **`log_safe`** (**EX-44-01**) at **v1.15** close — superseded by **v1.16** / **phase 79** (**AUD-16**) — **Phase 78**
- ✓ **AUD-14-03** — **`09-VERIFICATION.md`** C-1 rows **035–042**, **047** → **T1**; **043** / **044–046** / **048–049** honest **T2** / deferral — **Phase 78**
- ✓ **AUD-14-04** — **`09-03-SUMMARY.md`** phase **78** bounded-batch note + document status — **Phase 78**
- ✓ **AUD-14-05** — **`CHANGELOG.md` [Unreleased]** + **`account_audit_atomicity_test.exs`** **`change_password`** CHECK rollback — **Phase 78**

### Validated — v1.14 Bounded audit trust closure (shipped 2026-04-24)

- ✓ **AUD-13-01** — **`audit_backup_codes_regenerate/3`** **`Multi` + `log_multi_safe`** — **Phase 77**
- ✓ **AUD-13-02** — **`audit_trust_browser/2`** same pattern — **Phase 77**
- ✓ **AUD-13-03** — **`mfa_audit_atomicity_test.exs`** coverage — **Phase 77**
- ✓ **AUD-13-04** — C-1 matrix + inventory + summary + **CHANGELOG** — **Phase 77**

### Validated — v1.13 Post–v1.12 operational cadence (planning shipped 2026-04-24)

- ✓ **CAD-01** — **`.planning/PROJECT.md`** + archive **[`milestones/v1.13-REQUIREMENTS.md`](milestones/v1.13-REQUIREMENTS.md)** — default ops lane and event lanes — **Phase 76**
- ✓ **CAD-02** — **`.planning/STATE.md`** (at close) reflected **v1.13** / Phase **76** — **Phase 76**
- ✓ **CAD-03** — **`.planning/ROADMAP.md`** + **[`milestones/v1.13-REQUIREMENTS.md`](milestones/v1.13-REQUIREMENTS.md)** traceability — **Phase 76**

### Validated — v1.12 Trust, evidence, and adoption polish (shipped 2026-04-24)

- ✓ **AUD-11** — Bounded **SEED-002** **`Multi`** + **`log_multi_safe`** batch + audit-aware tests — **Phase 73**
- ✓ **AUD-12** — **09-03-SUMMARY** (+ **09-VERIFICATION** rationale) — **Phase 74**
- ✓ **UAT-01** — **`.planning/v1.12-UAT-EVIDENCE.md`** (eight SEED-001 rows) — **Phase 74**
- ✓ **UAT-02** — **`docs/uat-ci-coverage.md`** aligned with **v1.12** evidence — **Phase 74**
- ✓ **TRN-01** — **`upgrading-to-v1.12.md`** + **`mix.exs`** ExDoc extras — **Phase 75**
- ✓ **TRN-02** — Intro + **MAINTAINING** or **CHANGELOG** pointers — **Phase 75**
- ✓ **TRN-03** — Triage/issue-derived polish or explicit “no triage deltas” — **Phase 75**

### Validated — v1.11 Adoption stabilization (shipped 2026-04-23)

- ✓ **STAB-01** — **`.planning/v1.11-TRIAGE.md`** records triage + week-one path notes — **Phase 71**
- ✓ **STAB-03** — **`MAINTAINING.md`** *Milestone cadence and pause* section — **Phase 71**
- ✓ **STAB-02** — **`guides/introduction/upgrading-to-v1.11.md`** + **`mix.exs`** ExDoc extras — **Phase 72**
- ✓ **STAB-04** — **getting-started** + **upgrading-to-v1.10** cross-links — **Phase 72**

### Validated — v1.0

**Core authentication:**
- ✓ `mix sigra.install` generator (migrations, schemas, context, routes, optional LiveView pages) — v1.0
- ✓ Phoenix context pattern (`MyApp.Auth`) — v1.0
- ✓ Headless mode (all logic works without UI) — v1.0
- ✓ Behaviour + callback architecture for extensibility (no hidden macros) — v1.0
- ✓ Smart defaults with easy overrides via NimbleOptions — v1.0
- ✓ Email/password registration with Argon2id hashing — v1.0
- ✓ Magic link / passwordless email authentication — v1.0
- ✓ Login / logout with server-side database-backed sessions — v1.0
- ✓ Password hash migration (bcrypt → Argon2id transparent upgrade on login) — v1.0
- ✓ Email confirmation (link + 6-digit code verification) — v1.0
- ✓ Password reset via HMAC-protected single-use time-limited email tokens — v1.0
- ✓ Remember-me persistent sessions — v1.0
- ✓ Sudo/re-authentication mode for sensitive operations — v1.0

**OAuth / Social login:**
- ✓ OAuth integration via Assent (Google, GitHub, Apple, Facebook, Generic) — v1.0
- ✓ Account linking (existing user adds OAuth provider, email-match handling) — v1.0
- ✓ Multiple OAuth providers per user — v1.0
- ✓ PKCE and OIDC support via Assent — v1.0

**MFA:**
- ✓ TOTP enrollment, verification, and recovery (full lifecycle) — v1.0
- ✓ Backup codes (SHA-256 hashed, single-use, regeneration) — v1.0
- ✓ "Trust this browser" cookie to skip MFA on trusted devices — v1.0
- ✓ MFA enforcement policies via plug — v1.0

**Session management:**
- ✓ Active session tracking (IP, user agent, last active, device) — v1.0
- ✓ Session revocation (individual and log-out-everywhere) — v1.0
- ✓ Session invalidation on password change — v1.0
- ✓ Idle and absolute timeout (configurable) — v1.0
- ✓ Secure cookie defaults (SameSite=Lax, HttpOnly, Secure) — v1.0
- ✓ Account lockout after N failed attempts — v1.0
- ✓ Email enumeration prevention — v1.0

**API authentication:**
- ✓ Bearer token authentication with human-readable prefix (`myapp_sk_*`) — v1.0
- ✓ Personal access tokens (user-scoped, scopes + expiration) — v1.0
- ✓ JWT support for stateless API use cases (opt-in, family-based refresh rotation) — v1.0
- ✓ Dual-mode auth plug (session for browser, bearer for API, identical `current_scope`) — v1.0

**Security:**
- ✓ IP-based and account-based rate limiting via Hammer 7.x — v1.0
- ✓ HMAC-protected tokens for all email flows — v1.0
- ✓ Suspicious login detection with email notification — v1.0

**Transactional email:**
- ✓ Confirmation, password reset, lockout, suspicious-login, MFA, account lifecycle emails — v1.0
- ✓ Swoosh integration with pluggable mailer — v1.0
- ✓ HTML + text multipart with inline CSS — v1.0
- ✓ Async delivery via Oban with inline fallback — v1.0

**Account lifecycle:**
- ✓ Email change with re-verification — v1.0
- ✓ Password change with current password verification — v1.0
- ✓ Account deletion (soft, hard, anonymize) with grace period — v1.0
- ✓ Profile hooks engine with Ecto.Multi abort support — v1.0

**Developer experience:**
- ✓ Testing helpers (`log_in_user/2`, `register_user/1`, `setup_totp/1`, `create_api_key/2`, browser trust helpers) — v1.0
- ✓ Telemetry events for all auth operations (24+ events across phases) — v1.0
- ✓ Audit logging (security events with user, IP, user agent, action, metadata) — v1.0 (with C-1 caveat)
- ✓ `getting-started.md` guide + 15 additional guides + `llms.txt` — v1.0

### Validated — v1.5 Public release narrative & community readiness

- ✓ **PUB-01** — `mix.exs` package description and links aligned with shipped **v1.0–v1.4** capabilities; optional deps called out honestly — **Phase 53** (2026-04-22)
- ✓ **PUB-02** — `CHANGELOG.md` milestone anchors, roadmap traceability (**v1.2–v1.4**), compare links — **Phase 54** (2026-04-22)
- ✓ **DOC-01** — README GA / production-readiness paragraph with pointers to **v1.4** evidence — **Phase 55** (2026-04-22)
- ✓ **DOC-02** — ExDoc landing path to maintainer GA / audit narrative — **Phase 55** (2026-04-22)
- ✓ **MAINT-01** — `MAINTAINING.md` **First public launch** checklist with owners and evidence links — **Phase 56** (2026-04-22)

### Validated — v1.8 Adopter polish (shipped 2026-04-23)

- ✓ **ADOPT-04** — **`guides/introduction/upgrading-to-v1.8.md`**, **`mix.exs`** ExDoc extras ordering, **planning v1.8** vs **Hex SemVer** framing, pointers to **v1.7** upgrade context — **Phase 63**
- ✓ **ADOPT-05** — Cross-links across **`getting-started`**, **`first-hour`**, **`troubleshooting-install`**, **`CHANGELOG`**, and both upgrade guides — **Phase 64**
- ✓ **INTG-02** — **`companion-oauth-provider.md`** prerequisites, **B2C-only / no third-party clients** anti-pattern clarity, **See also** → **`upgrading-to-v1.8.html`** — **Phase 65**

### Validated — v1.9 Audit atomicity (bounded SEED-002) (shipped 2026-04-23)

- ✓ **AUD-09** — **`Sigra.MFA.confirm_enrollment/5`** **AUD-04-020..021** **`Multi`** + **`log_multi_safe`** with **`mfa_audit_atomicity_test.exs`**; **022** remains **T2** / **`EX-44-02`** — **Phase 66**
- ✓ **AUD-10** — **`09-03-SUMMARY.md`** post–**phase-66** trace + bounded-batch narrative; **D-06** reconciliation **AUD-04-020..022** vs **44** inventory with explicit **no `09-VERIFICATION.md` edit`** attestation — **Phase 67**

### Validated — v1.10 Adopter confidence for solo production (shipped 2026-04-23)

- ✓ **ACF-01** — Production **HTTPS / proxy / session cookie** checklist hub in **`guides/recipes/deployment.md`** with maintainer + intro discovery links — **Phase 68**
- ✓ **ACF-04** — **Oban-backed vs inline** Swoosh delivery TL;DR + install flags + example pointers — **Phase 68**
- ✓ **ACF-02** — **`guides/introduction/intermediate-production-path.md`** intermediate dogfood spine + **`.planning/v1.10-ADOPTER-SCOPE.md`** link — **Phase 69**
- ✓ **ACF-03** — **`guides/reference/generator-options.md`** optional-feature index + intro cross-links — **Phase 69**
- ✓ **ACF-05** — **`guides/introduction/upgrading-to-v1.10.md`** + **`mix.exs`** ExDoc extras — **Phase 70**
- ✓ **ACF-06** — Archived **v1.10** requirements + **`PROJECT.md`** explicit deferrals for **`sigra_lockspire`** and full **SEED-002** with **ADR 001** + seed pointers — **Phase 70**

### Validated — v1.7 Adoption readiness & audit durability (shipped 2026-04-23)

- ✓ **ADOPT-01** / **ADOPT-02** / **ADOPT-03** — First-hour guide, **v1.7** upgrade stub, install troubleshooting wired into ExDoc — **Phase 60**
- ✓ **INTG-01** — Companion embedded OAuth/OIDC provider recipe (non-coupled seam) — **Phase 60**
- ✓ **AUD-01** — Bounded **`verify_backup/4`** failure-path **`Multi`** + audit-aware tests + honest **AUD-04** / **C-1** rows — **Phase 61** (2026-04-23)
- ✓ **AUD-02** — **`09-03-SUMMARY.md`** aligned to post–**phase-61** **C-1** truth with explicit planning trace; **D-06** required no **`09-VERIFICATION.md`** edit — **Phase 62** (2026-04-23)

### Validated — v1.6 Nyquist closure + OAuth audit depth

- ✓ **NYQ-01** / **NYQ-02** — Maintainer-facing **41–44** posture matrix under **`.planning/`** with **`MAINTAINING.md`** entry point + precedence rule; optional **D-11** contract test — **Phase 57** (2026-04-23)
- ✓ **OA-01** — Postgres-backed **`Sigra.OAuthCeremonyAuditTest`** (registration + **`authorize_url`** audit rows) and **`phase_58_oauth_oa01_ci_contract_test`** CI honesty for **`library_tests`** — **Phase 58** (2026-04-22)
- ✓ **OA-02** — **`docs/uat-ci-coverage.md`** machine vs human hub plus **GA-03** matrix / waiver / evidence **INDEX** / **`docs/ga-evidence.md`** alignment — **Phase 59** (2026-04-23)

### Validated — v1.4 GA readiness & audit trail completeness

- ✓ **GA-01** — Backup-code rotation: `Sigra.MFA.regenerate_backup_codes/4`, example `Accounts` + `MFASettingsLive`, install templates, regression in `test/example/.../backup_code_rotation_test.exs` — **Phase 41** (2026-04-20)
- ✓ **GA-02** — Email visual QA row **Waived** with machine baseline + evidence pointers — **Phase 46** (2026-04-21)
- ✓ **GA-03** — Live Google OAuth row **Waived** with `Sigra.OAuthTest` substitute — **Phase 46** (2026-04-21)
- ✓ **GA-04** — Clean-machine getting-started row **Waived** with CI contract substitute — **Phase 46** (2026-04-21)
- ✓ **GA-05** — Consolidated matrix `.planning/v1.4-GA-UAT.md` + cross-links — **Phase 46** (2026-04-21)
- ✓ **AUD-04** / **AUD-05** — Inventory + Auth `Ecto.Multi` batch + `43-VERIFICATION.md` — **Phase 47** (2026-04-21)
- ✓ **AUD-06** / **AUD-07** — MFA + Account/API batch + `44-VERIFICATION.md` — **Phase 48** (2026-04-21)
- ✓ **AUD-08** — OAuth/ops batch + `45-VERIFICATION.md` + `mix ci.audit_45`; Phase 9 **C-1** matrices refreshed — **Phase 49** (2026-04-21)
- ✓ **Process closure** — Nyquist policy + **`mix ci.install_golden`** + **`install_golden_contract`** (**50**), CI path coupling + GA↔installer attestation tests (**51**), ROADMAP honesty + contract tests (**52**) — **2026-04-21–22**

### Validated — v1.3 Cleanup & Hardening

**Planning, CI, UAT, audit, tooling:**
- ✓ Nyquist retro inventory + waivers for historical validation debt (**999.1**) — v1.3
- ✓ SHA-pinned first-party Actions upgrades with Dependabot triage notes (**999.2**) — v1.3
- ✓ GA UAT gate evidence + shift-left automation map for **SEED-001** posture — v1.3
- ✓ `Sigra.Audit.Assertions` + atomic audited `api.token_create` + example login/MFA audit smoke — v1.3
- ✓ Maintainer release checklist + planning hygiene supersession (`MAINTAINING.md`, optional Hex publish job pattern) — v1.3

### Validated — v1.2 Admin Dashboard

**Admin user management UI:**
- ✓ LiveView admin dashboard enabled by default with `--no-admin` opt-out — v1.2
- ✓ Mobile-responsive user list and user detail flows for core operator jobs — v1.2
- ✓ Light/dark mode plus basic branding controls suitable for internal tooling — v1.2
- ✓ Org-aware admin scopes so platform admins and org admins see the right surface by construction — v1.2

**Impersonation + audit:**
- ✓ Secure admin impersonation with visible banner state, time bounds, dual-actor audit trail, and forbidden sensitive actions — v1.2
- ✓ Rich audit views for per-user, per-organization, and global exploration, including impersonation-aware filtering — v1.2 (Phase 30; polish Phase 33)
- ✓ Admin-side user detail views for sessions, security state, identities, organizations, memberships, and danger-zone actions — v1.2

**Verification + review ergonomics:**
- ✓ Browser and system automation for critical admin flows using Playwright and CI — v1.2 (Phases 31, 34-35)
- ✓ Review artifacts (Playwright HTML, screenshots/traces/video where configured, curated PNG baselines) — v1.2
- ✓ Route, controller, and curl-style smoke coverage outside the browser happy path — v1.2

### Other deferred items

_SEED-001 and SEED-002 were promoted and **closed in v1.4** (see `.planning/milestones/v1.4-REQUIREMENTS.md`). Use this list for ideas **not** selected for the next milestone._

- (none captured — add here when `/gsd-new-milestone` promotes new seeds)

### Out of Scope

- SAML support — enterprise SSO protocol, high maintenance burden, low SaaS builder need. Leave architecture extensible for future plugin.
- Acting as OAuth/OIDC identity provider — enterprise/B2B concern, dramatically expands scope. Architecture should not prevent future addition.
- Rebuilding organizations or passkeys as standalone milestones — v1.1 shipped the foundation; v1.2 builds on top of it.
- Authorization (RBAC, permissions, policies) — separate concern. Sigra provides identity context; authorization builds on top.
- SCIM directory sync — enterprise feature, out of scope for v1.
- Full theming engine or runtime UI builder — only basic branding hooks are in scope for the admin surface.

## Context

**Ecosystem gap:** Elixir's auth ecosystem is fragmented. phx.gen.auth is a minimal generator (no OAuth, MFA, API tokens, rate limiting). Pow is dead on Phoenix 1.8+. Ueberauth/NimbleTOTP/Guardian each handle one slice — no integrated solution exists. State of Elixir surveys (2023-2025) rank missing libraries as the #1-2 challenge.

**Prior art studied extensively:**
- **Devise** (Ruby) — cautionary tale of hidden magic, but defined the "batteries-included" category
- **Rodauth** (Ruby) — architectural gold standard (encapsulated auth object, per-feature tables, HMAC tokens, uniform DSL), but integration ergonomics suffer from Rack middleware approach
- **Better Auth** (JS) — modern benchmark for plugin architecture and composable features
- **Django Allauth** — feature completeness standard (100+ providers, MFA, headless API, identity provider)
- **Laravel** — progressive complexity with clear layers (Breeze → Jetstream → Fortify → Sanctum → Passport)
- **phx.gen.auth** — respects José's "own your code" philosophy, but security patches don't propagate

**Hybrid architecture chosen because:** Pure generators have a fatal flaw (no security patch propagation). Pure libraries fight the Elixir philosophy of visible code. The hybrid — security in the dep, UX in generated code — threads the needle.

**Database design:** Hybrid user/identity pattern — `users` table as stable identity anchor, `user_identities` table for credentials (password, OAuth providers). Separate tables per concern (tokens, passkeys, MFA credentials, API keys, audit log). This is the pattern Better Auth, Django Allauth, and PowAssent all converge on.

**Key dependencies (minimal, high-quality):**
- Assent — OAuth/OIDC (framework-agnostic, PKCE, 20+ providers in one package)
- Comeonin + Argon2 — password hashing
- NimbleTOTP — TOTP primitives (or copy-paste if simple enough)
- Wax — WebAuthn/FIDO2 ceremonies
- Swoosh — transactional email (pluggable mailer interface)
- Prefer copy-paste over deps where the code is small and stable

**Code philosophy:**
- Idiomatic Elixir/Plug/Phoenix
- DDD with clean layered architecture (domain → application services → infrastructure)
- Command/query separation at application layer
- Behaviours + callbacks for extensibility (no hidden macros)
- Dependency injection via module attributes/config for testability
- Principle of least surprise — API should be a joy to use
- Flat, self-contained AAA-style specs with scenario-based fixtures

**Target users:**
- Solo SaaS builders wanting auth done in an afternoon (Persona A)
- Mid-market engineering teams needing MFA/SSO for enterprise customers (Persona B)
- API builders needing bearer tokens and JWT (Persona C)
- Developers migrating from Pow or hand-rolled auth (Persona D)

## Constraints

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path. Plug compatibility where DX is not compromised.
- **Database:** PostgreSQL only (citext, JSONB).
- **Security:** OWASP standards throughout. Argon2id default. All tokens HMAC-protected. Enumeration prevention by default.
- **Dependencies:** Minimal transitive deps. Copy-paste over deps when code is small and stable.
- **LiveView:** Supported but optional. Core works with standard controllers. Login/logout via HTTP POST (not LiveView events).
- **Testing:** Comprehensive spec coverage — happy path, main error cases, boundary conditions. AAA style, flat, self-contained.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Hybrid lib+generator architecture | Security patches propagate via dep updates; devs own customizable code. Respects José's philosophy while solving the patch propagation problem. | ✓ Validated v1.0 — no regret |
| Phoenix context pattern for generated code | `MyApp.Auth` context follows DDD boundaries, is idiomatic Phoenix, and keeps the public API clean. | ✓ Validated v1.0 — no regret |
| Assent over Ueberauth for OAuth | Framework-agnostic, PKCE/OIDC built-in, single package vs N strategy deps, actively maintained. | ✓ Validated v1.0 — shipped 5 strategy wrappers (Google/GitHub/Apple/Facebook/Generic); Assent's PKCE + OIDC + single-package design paid off |
| Hybrid user/identity table pattern | `users` + `user_identities` — clean multi-provider support, natural Ecto idiom, matches Better Auth/Django Allauth/PowAssent. | ✓ Validated v1.0 — pattern held through registration/login/linking/unlink |
| Argon2id default with bcrypt migration path | OWASP gold standard; memory-hard; transparent upgrade on login keeps migration invisible to users. | ✓ Validated v1.0 — `verify_with_upgrade/3` pattern works cleanly |
| Database-backed session tokens (no JWT for browser) | Revocation requires server-side state; JWT-only for browser is an anti-pattern for session auth. | ✓ Validated v1.0 — JWT remains opt-in for stateless API paths only |
| D-01 universal atomic `Ecto.Multi` for audit writes | Audit rows must be as durable as the business op that produced them; no dropped rows on partial failure. | ✓ Advanced through **v1.16** — **`APIToken.verify/2`** failure audits (**AUD-04-044..046**) use transactional **`log_multi_safe`**; **Account** + **`APIToken.revoke`** (**v1.15**) + prior batches; remaining deferrals explicit in **44** / **09** matrices |
| D-10 installer default PK type = `binary_id` (uuid) | UUIDs are idiomatic for modern Phoenix; avoids enumeration of integer IDs; matches phx.gen.auth 1.8 convention. | ✓ Validated v1.0 (flipped in phase 10.1.1) — no integer-PK regressions downstream |
| IN-03 SHA-pin all GitHub Actions | Supply-chain security: tag-based references allow the tag to be moved post-publish; SHA pins lock the exact code. | ✓ Validated v1.0 (phase 10.1 + 10.1.1) — Dependabot `github-actions` ecosystem handles upgrade churn |
| D-15 no `continue-on-error` on any required CI check | Flakes must be fixed at root cause; masking them defeats the gate's purpose. | ✓ Validated v1.0 — all 5 CI jobs are strict-pass; no `continue-on-error` anywhere in `.github/workflows/ci.yml` |
| Playwright over Cypress/WebdriverIO for browser smoke | Only runner with first-class frameLocator support for Swoosh dev-mailbox iframe; lowest-friction TypeScript setup. | ✓ Validated v1.0 (phase 10.1.1) — golden-path spec runs in ~90s on CI, zero flakes to date |
| Organizations as first-class multi-tenancy | Logical tenants without schema-per-tenant; scope + membership + invitations. | ✓ Shipped v1.1 — org switcher, plugs, audit columns; superseded the old “defer to v2” note |
| SAML / OAuth IdP out of scope | Enterprise concern with high maintenance burden. Architecture should not prevent future plugin/extension. | — Pending (still out of scope) |
| Optional `sigra_lockspire` glue package | Keeps Sigra core deps minimal; companion OAuth servers integrate via **host-generated** seams (`AccountResolver`); glue only after both APIs stable. | — Deferred — see `.planning/decisions/001-defer-sigra-lockspire-glue-package.md` |
| WebAuthn / passkeys deferred from v1.0 MFA | TOTP covers the broader developer use case; WebAuthn adds meaningful complexity; `wax_` dep was evaluated but not integrated. | ✓ Shipped v1.1 — passkeys + orgs foundations |
| v1.2 admin is default-on installer feature with library-owned enforcement | Keeps security semantics in the dep while host owns policy module + shell chrome; matches hybrid architecture. | ✓ Validated v1.2 — plugs, `Sigra.Admin.*`, generator parity phases 32-33 |
| Shift-left gates for installer + verification docs | Prevents INT-01..04 recurrence: emission audit, drift dead-text nav guard, milestone VERIFICATION.md gate, installer-scoped milestone audit CI, artifact bundle contract. | ✓ Validated v1.2 — Phase 35 |
| v1.3 audit assertions + partial Multi conversion | Give hosts test-grade audit helpers and prove one high-risk API path can commit business + audit rows atomically without inventing audit macros. | ✓ Validated v1.3 — Assertions module + `api.token_create` Multi; OAuth smoke out of scope |
| Library owns versioned export payload via `Sigra.DataExport.export_auth_data/3` | Keep the auth/account export contract bounded and testable inside the library so generated hosts can call a thin wrapper instead of reimplementing payload shape, lifecycle status, or omission semantics. | ✓ Validated v1.28 — schema_version 1 + structured omission notes + curated safe serializers ship in Phase 127; generated host parity in Phase 129 |
| Backup codes summary-only and enterprise connections excluded from user export | Honor security model: never round-trip raw backup codes or enterprise-org secrets through a user-initiated data export; expose counts and presence only. | ✓ Validated v1.28 (Phase 127) — backup codes export as summary; enterprise connections explicitly excluded |
| Account deletion enqueue ownership stays in `Sigra.Account.Deletion.schedule/3` | Schedule/cancel/execute semantics belong in the library; the generated host wires the worker but does not re-implement gating. Safe degradation when Oban or generated-host context is missing prevents silent loss. | ✓ Validated v1.28 (Phase 128) — `Sigra.Workers.AccountDeletion` enqueue + `scheduled?/1` gating + stale-job no-ops |
| Soft-delete finalization is row-preserving | Soft-delete must clear scheduled-deletion + pending/original email fields without claiming hard deletion or destroying the row, so audit and recovery stay possible. | ✓ Validated v1.28 (Phase 128) — `deleted_at` preserved; row not destroyed |
| Adoption is the bottleneck, not features (assessment 2026-05-29) | Repo-grounded done-band is 90–95% for scope; adoption-evidence automation (E2E/install-smoke/golden-path/dep-off CI) is already strong. The honest constraint on "done" is absence of real adopters. | → Next build wedge = `DEMO-SHOWCASE` (seed-rich evaluator demo, extend `test/example/`); then 1.0 Hex cut + adoption push over further feature wedges. See MILESTONE-ARC.md Candidates + `.planning/threads/adoption-evidence-and-demo-showcase.md`. Working branch name `v1.28-data-lifecycle` is stale vs active v1.30. |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---

<details>
<summary>Archived milestone “Last updated” footers (v1.0–v1.17 execution log)</summary>

- **2026-05-27** — **`/gsd-complete-milestone` v1.28**: archived **`v1.28-REQUIREMENTS.md`**, **`v1.28-ROADMAP.md`**, **`v1.28-MILESTONE-AUDIT.md`**; archived phase directories **127–130** under `milestones/v1.28-phases/`; live **`REQUIREMENTS.md`** removed; tag **`v1.28`**.
- **2026-04-24** — **`/gsd-complete-milestone` v1.17**: **`MILESTONES.md`** + **`RETROSPECTIVE.md`**; live **`REQUIREMENTS.md`** removed; tag **`v1.17`**; **`ROADMAP`** link → **`milestones/v1.17-REQUIREMENTS.md`**.
- **2026-04-24** — **`/gsd-complete-milestone` v1.16**: archived **`v1.16-REQUIREMENTS.md`**, **`v1.16-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed; tag **`v1.16`**.
- **2026-04-24** — **`/gsd-complete-milestone` v1.15**: archived **`v1.15-REQUIREMENTS.md`**, **`v1.15-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed; tag **`v1.15`**.
- **2026-04-24** — **`/gsd-complete-milestone` v1.14**: archived **`v1.14-REQUIREMENTS.md`**, **`v1.14-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed; tag **`v1.14`**.
- **2026-04-24** — **`/gsd-complete-milestone` v1.13** (planning-only): archived **`v1.13-REQUIREMENTS.md`**, **`v1.13-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed; no Hex tag (no library version bump).
- **2026-04-24** — **`/gsd-complete-milestone` v1.12**: archived **`v1.12-REQUIREMENTS.md`**, **`v1.12-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed; tag **`v1.12`**.
- **2026-04-23** — **v1.11** phases **71–72** complete; archived **`v1.11-REQUIREMENTS.md`** + **`v1.11-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.10** phases **68–70** complete; `/gsd-complete-milestone` archived planning + tag **`v1.10`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.9** phases **66–67** complete; `/gsd-complete-milestone` archived planning + tag **`v1.9`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.8** phases **63–65** complete; `/gsd-complete-milestone` archived planning + tag **`v1.8`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.7** phases **60–62** complete; `/gsd-complete-milestone` archived planning + tag **`v1.7`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.6** phases **57–59** complete; `/gsd-complete-milestone` archived planning + tag **`v1.6`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-22** — **v1.5** phases **53–56** complete; `/gsd-complete-milestone` archived planning + tag **`v1.5`**.
- **2026-04-22** — v1.4 phases **41–52** complete on ROADMAP; milestone wrap via `/gsd-complete-milestone`.
- **2026-04-21** — Phases **50** (Nyquist + `install_golden_contract`), **49** (`45-VERIFICATION.md`, **AUD-08**), **48** / **47** (44/43 verification), **46** (GA matrix gap closure).
- **2026-04-20** — Phase **41** (**GA-01**); `/gsd-new-milestone` opened v1.4.
- **2026-04-19** — v1.3 shipped; live `REQUIREMENTS.md` removed for next milestone.
- **2026-04-17** — v1.2 shipped.
- **2026-04-11** — v1.0 shipped + v1.1 milestone start notes.
- **2026-04-09** — Phase 8 account lifecycle completion notes.

</details>

*Last updated: 2026-05-28 — Phase 136 (Verification Proof Bundle + Narrative-Honesty Corrigendum) shipped (PROOF-01, DOC-01). PROOF-01 proof bundle run on release-branch HEAD — five hard test/docs gates green (full `mix test` 2252/0, `test/sigra/audit/` 60/0, dep-off lane 2246/0, `test/example/` 236/0, `mix docs --warnings-as-errors` exit 0); `mix credo --strict` recorded as a non-CI-enforced local advisory (506 pre-existing library style/design issues disclosed, non-blocking — the 2 enforced custom Sigra checks pass). Per-phase `131–136-VERIFICATION.md` all filed with canonical dash-prefix names (132 history-preserving rename, 133 backfilled). DOC-01 v1.25 EMAIL-RAILS Mailglass corrigendum landed across MILESTONES.md/PROJECT.md/CHANGELOG.md (the library-resident adapter + `--with-mailglass` flag did not land; recipe-only host-owned `Sigra.Mailer` posture). PROOF-01 + DOC-01 reconciled in-place. **v1.29 SUITE-INTEGRATION shipped and archived on 2026-05-29 via `/gsd-complete-milestone` — milestone audit passed (16/16 requirements, 6/6 phases, 5/5 integration, 2/2 flows); ROADMAP/REQUIREMENTS/audit archived to `milestones/v1.29-*`, live `REQUIREMENTS.md` removed for the next milestone, tagged `v1.29`.***

*Last updated: 2026-05-28 — `/gsd-new-milestone` opened **v1.30 TRUST-HARDENING** (Operator Confidence & Debt Closure). The named milestone arc was exhausted through v1.29; v1.30 deepens shipped substrate per the arc's ranking rules. Scope: `mix sigra.doctor`, `Sigra.OptionalDeps` SOT, recipe-contract test fixtures, deprecation-removal timelines, sister-repo recipe-contract verification, proof/docs at close. Phases continue from **137**. Note: 88 stale phase directories (pre-v1.29 + un-archived v1.29 `131–136`) remain in `.planning/phases/` — destructive `phases.clear` was deliberately skipped (no number collision at 137+); recommend a `/gsd-cleanup` archive pass.*

*Last updated: 2026-05-29 — Phase 140 (Deprecation Hygiene + Verification & Docs Close) shipped (DEPR-01, DEPR-02, PROOF-01, DOC-01) — the final phase of **v1.30 TRUST-HARDENING**. The 2 live `@deprecated` functions now carry concrete Hex-SemVer removal targets (`Sigra.MFA.Trust.cookie_opts/0` → 0.4.0, `Sigra.Account.audit_forced_password_change/2` → 0.5.0) with migration notes, rendered into published docs (Gate 8 proof). DOC-01 closed: `mix sigra.doctor` operator section in `guides/recipes/deployment.md` + 3 maintainer sections in `MAINTAINING.md` (OptionalDeps SOT, recipe-contract fixture, deprecation timeline); ROADMAP Phase 137 reconciled to 3/3 Complete (D-12). PROOF-01 eight-gate bundle filed at `140-VERIFICATION.md` (status: passed): 6/8 hard gates green; 2 non-green results are pre-existing/environmental and recorded verbatim — Gates 1/3 install-test failures are the local Xcode-license/argon2-NIF compile block (CI unaffected), Gate 7 doctor exit-1 is the `test/example/` passkeys-on-plaintext-stub wiring gap. Code review: 1 Warning (WR-01 deprecation since-vs-removal version-axis inversion) + 2 Info deferred to tracked todos. **All v1.30 phases (137–140) complete — milestone ready to close via `/gsd-complete-milestone`.** Carry-forward to milestone close: WR-01 version-axis reconciliation; deferred phase-138 doctor Info findings (IN-01/02/03, untagged from 140 — not folded in); REQUIREMENTS.md traceability gaps (SCIM-01/CORR-01/GLUE-01); 88 stale phase dirs pending `/gsd-cleanup`.*

*Last updated: 2026-05-29 after v1.30 TRUST-HARDENING milestone — **shipped and archived via `/gsd-complete-milestone`**. Milestone audit re-run (post-137-closeout) found **11/11 requirements satisfied, 4/4 integration seams WIRED, 3/3 flows intact** — `gaps_found` reflected process/hygiene only, and all four were closed retroactively at this close: filed `137-VERIFICATION.md` from existing UAT/VALIDATION/SECURITY evidence; reconstructed `138-VALIDATION.md` (State B) and signed off `139-VALIDATION.md` (State A) → all 4 phases now Nyquist-compliant; ticked OD-01/OD-02 in REQUIREMENTS.md. WR-01 dual-version-axis deprecation wart resolved to "accept + document" (dual-axis note added to MAINTAINING.md; library-wide `@doc since:` re-keying kept as an open tracked todo). ROADMAP/REQUIREMENTS/audit archived to `milestones/v1.30-*`, ROADMAP collapsed in place, live `REQUIREMENTS.md` removed for the next milestone, tagged `v1.30` (not pushed). 3 deferred tech-debt todos acknowledged in STATE.md (phase-135 cross-milestone, WR-01 version-axis, phase-138 doctor IN-01/02/03). Phases continue from **141**; re-rank `MILESTONE-ARC.md` before `/gsd-new-milestone`. Still pending: 88 stale phase dirs await a `/gsd-cleanup` archive pass.*

*Last updated: 2026-05-29 — `/gsd-new-milestone` opened **v1.31 DEMO-SHOWCASE** (Seed-rich Evaluator Demo Showcase). `MILESTONE-ARC.md` re-ranked first: DATA-LIFECYCLE/SUITE-INTEGRATION/TRUST-HARDENING marked shipped, DEMO-SHOWCASE promoted to SELECTED-next, greenfield SCIM explicitly deprioritized below it and the subsequent 1.0 Hex cut + adoption push. Goal: turn `test/example/` into double-duty adopter proof + click-around evaluator showcase (seed-rich personas, deterministic `seeds.exs`, one-command spin-up, README "try it locally" lane, Playwright over seeded data). The unbuilt remainder of v1.29's deferred "reference starter app"; extends `test/example/` (no new repo). Research-first chosen. Phases continue from **141**.*

*Last updated: 2026-05-31 after v1.31 DEMO-SHOWCASE milestone — shipped and archived via `$gsd-complete-milestone`. ROADMAP/REQUIREMENTS/audit archived to `milestones/v1.31-*`; live `REQUIREMENTS.md` removed for the next milestone; phases continue from **145**.*
*Last updated: 2026-06-01 — Phase 150 (Issue Triage & Bugfix Cadence) shipped. Requirements MAINT-01..MAINT-03 validated.*
*Last updated: 2026-06-01 — Phase 151 (Ecosystem Sync & Hex Dependency Management) complete.*
*Last updated: 2026-06-02 after v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS milestone — shipped and archived via `$gsd-complete-milestone`. ROADMAP/REQUIREMENTS/audit archived to `milestones/v1.33-*`, phase artifacts moved to `milestones/v1.33-phases/`, live `REQUIREMENTS.md` removed for the next milestone, and the close audit passed with 10/10 requirements satisfied. Phases continue after **153**.*
*Last updated: 2026-06-03 — `/gsd-new-milestone` opened **v1.34 ADMIN-UI-COHERENCE** (admin UI coherence & needs-led journey pass). Explicit user-promoted exception to the Post-1.0 "polish is not default roadmap" posture, justified by the admin UI being the evaluator-facing showcase + generated-host adoption surface (Clear integration path / Great DX North Star). Scope locked: polish the 6 existing admin screens + enrich seed data, consolidate duplicated components into a shared `Sigra.Admin.Components` module, harden the needs-led landing, heaviest effort on under-iterated areas (two Overview landings, org overview, per-user audit, audit mobile). No net-new surfaces, no nav restructure, no token-layer work. Verification automated-only (playwright admin-checkpoints {chromium,mobile,dark} + axe + admin-generated parity; coverage closed by ADDING checkpoints). Research-first chosen. Kickoff brief: `~/.claude/plans/recap-sigra-v1-0-0-ga-cached-puppy.md`. Phases continue from **154**.*

*Last updated: 2026-06-03 — Phase 154 (Design Contract + sg-notice) complete — COMP-03, COMP-04 validated. Committed `guides/reference/admin-design-contract.md` (the governance contract: 10 canonical component jobs with winning CSS/ARIA/motion-incl-explicit-"not-animated"/when-NOT-to-use, plus 3 page archetypes — Overview/List/Detail — as explicit component compositions) and registered it in the mix.exs ExDoc extras. Added the `.sg-notice` style (base + 4 tone variants) inside `@layer sg-components` in `test/example/.../app.css` — a behavior-preserving selector-rename of `.sg-list-row[data-tone]` (same tokens/color-mix/ring-opacity asymmetry, no new `!important`). No LiveView or Playwright-baseline changes (verifier 4/4, status passed). Code review: 1 Warning fixed in-phase (WR-01 — the doc's `app.css` line citations were shifted by this changeset's own CSS insertion; corrected to 1421–1443 / 1463–1473); WR-02 (sg-notice/sg-list-row tone-rule duplication has no drift guard) deferred to a tracked pending todo for the 154→156 migration window. Phases continue from **155** (KEYSTONE: build `Sigra.Admin.Components`).*

*Last updated: 2026-06-04 — Phase 155 (Shared Component Foundation, KEYSTONE) complete — COMP-01, COMP-02 validated (verifier 9/9, status passed). Built `lib/sigra/admin/components.ex` — the lib-owned `Sigra.Admin.Components` module with all 10 canonical admin function components in contract order (`stat_link`, `stat`, `task_card`, `summary_chip`, `applied_chip`, `empty_state`, `page_back`, `scope_ribbon`, `notice`, `skeleton`), each declaring explicit `attr`/`slot` contracts, `attr :class, :any, default: nil` merged as `class={["sg-…", @class]}`, and `attr :rest, :global`. The `notice` component ships its target `sg-notice`/`data-tone` form with no default live-region role (D-07/D-08). Module is intentionally UNWIRED this phase — no LiveView consumes it (that is Phase 156); original `defp`/inline markup stays in place. COMP-02 proof: `test/sigra/admin/components_test.exs` — 10 DB-free `render_component/2` tests (7 strict byte-equal goldens from original markup, 1 target golden for `notice`, 2 structural asserts for `stat`/`skeleton`), all green, each carrying a drift message citing the design contract and forbidding Playwright baseline re-records (D-13). Also wired the CI gate so `example_playwright_smoke` `needs: [release_ref_guard, library_tests]` (D-14) and corrected the design contract's notice ARIA entry to the no-role form (D-09). Full suite green (2333 tests, 0 failures). Code review: 1 Warning fixed in-phase (WR-01/WR-02 — `notice/1` was the only component missing the `attr :class` merge mandated by D-02, a latent duplicate-`class` hazard for Phase 156; commit 5ad22cda added the attr + merge and updated `@notice_golden`); 3 Info deferred (IN-03 orphaned `<dt>/<dd>` in `summary_chip` is verbatim behavior-preservation — a Phase 156 `<dl>`-wrapper note, not a defect). Phases continue from **156** (adopt shared components on baselined screens).*
