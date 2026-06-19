# Project Retrospective

*Living document updated at milestone boundaries. v1.30 section added at milestone close (2026-05-29). Note: v1.18–v1.27 retrospective entries were skipped during execution; v1.28 resumed the cadence.*

## In-flight posture capture: v1.32 — RELEASE-ADOPTION

**Captured:** 2026-05-31 during Phase 147 planning/execution handoff  
**Status:** active milestone, not yet closed

### Decision

v1.32 is the transition from building broad auth-library surface area to proving, releasing, and supporting it. Once Phases 147-149 and the live release UAT items are complete, the right default is to cut the real Hex `1.0.0` release rather than invent another broad polish or feature milestone.

### Posture for future milestones

- Sigra should be treated as release-grade and broadly feature-complete for the expected Phoenix auth-library surface after v1.32 closes.
- Future work defaults to maintenance, release support, adopter feedback, docs/upgrade clarity, and selective strategic bets.
- New feature milestones need a concrete reason: adopter demand, security/trust risk, ecosystem strategy, or an explicitly chosen product expansion.
- Open-ended polish should stay quiet unless it removes adoption friction, closes release risk, or fixes a verified trust gap.
- Future agents should not keep re-asking "are we done?" by default. They should start from this posture, inspect current evidence, and recommend maintenance or strategic work only when the evidence supports it.

### Boundaries to preserve

- Do not reopen new auth primitives, hosted control-plane behavior, SCIM/directory sync, generic compliance platform work, broad generated-host UI redesign, or generic authorization policy by default.
- Do not treat docs/narrative polish as roadmap-worthy unless it is tied to adopter success, release evidence, upgrade/migration clarity, or trust.
- Keep the v1.32 release/adoption roadmap bounded: Phase 147 upgrade/migration lanes, Phase 148 evaluator funnel, Phase 149 launch evidence/announcement pack, then release/hotfix posture.

## Milestone: v1.39 — DS-COHERENCE

**Shipped:** 2026-06-19
**Phases:** 9 (184–192) | **Plans:** 39 | **Tasks:** 63

### What was built

A systematically audited, award-grade admin/operator design system, graded *fractally* (tokens L0 → components L1 → meta-component groups L2 → page compositions L3 → operator flows L4), and shipped to real adopters by closing the admin-CSS distribution gap. The canonical admin `sg-*` CSS now ships from the installer to generated hosts as `sigra_admin.css` (merge-blocking byte-parity + styled generated-host smoke); an example-only `/admin/_design` gallery + `admin-design-{chromium,mobile,dark}` snapshot+axe lane audits every component/group in isolation; a quality-tier ledger + merge-blocking monotonic guard make re-runs forward-only; a committed one-term-per-concept glossary is enforced by an ExUnit drift guard; and Phase 192 served as a terminal ratification gate proving "current = ratified."

### What worked

- **The idempotency ratchet (ledger + monotonic guard) was the right backbone.** Framing the whole milestone as a re-runnable, forward-only audit meant each phase raised the ledger and CI mechanically prevented regressions — the terminal Phase 192 gate then became a re-run rather than a fresh audit.
- **Closing the distribution gap first (Phase 184) paid compounding dividends.** Once `sigra_admin.css` shipped and the example consumed the same file, every later phase's evidence (axe, snapshots, generated-host smoke) ran against the actually-shipped stylesheet, not an example-only copy.
- **Fractal decomposition kept scope honest.** Grading L0→L4 with a shared D1–D11 scorecard plus level add-ons gave each phase a crisp, testable success bar and avoided open-ended "polish."
- **A terminal ratification phase removed the need for a separate milestone audit.** Phase 192 re-ran every scorecard, recaptured all baselines, reset both allowlists to empty, and ran the monotonic guard vs origin/main — so `/gsd-audit-milestone` was redundant at close.

### What was inefficient

- **Tracking artifacts drifted from reality.** At close, 19 items were open in the audit but none were real blockers — a debug session was stale-resolved (fixes had landed in PR #54 but the file was never moved to `resolved/`), and 10 quick-tasks predating the milestone were fully superseded. Closing/moving artifacts as work lands would make the close cleaner.
- **ROADMAP.md carried stale Phase Details.** The verbose per-phase blocks for the prior (v1.38) milestone were never pruned at that lightweight close, so this close had to remove 178–192 details together.
- **A few flaky/data-dependent tests surfaced late** (mg5-6 content-equivalence needs 25+ audit events; demo-showcase remember-checkbox color) and were deferred to tracked todos rather than fixed inline.

### Patterns established

- **Ship design-system CSS like auth CSS:** distributed installer asset + merge-blocking example≡template byte-parity + styled generated-host smoke. Reusable for any future host-facing stylesheet.
- **Quality-tier ledger + monotonic guard** as a durable, re-runnable governance instrument for subjective-but-gradeable surfaces (design, copy, a11y).
- **Example-only audit harness** (`/admin/_design` gallery) contract-guarded against installer templating — isolates component/group states without a storybook dependency.
- **Glossary-as-test:** a one-term-per-concept glossary enforced by an ExUnit drift guard ships with the library so adopters inherit the same copy discipline.

### Key lessons

- A milestone whose final phase is a *terminal idempotency gate* can legitimately skip a separate milestone audit — but only because the gate's invariants (recapture, empty allowlists, parity, monotonic guard) actually subsume the audit's checks. Verify that subsumption before skipping.
- Move/close tracking artifacts (debug sessions, quick-tasks, todos) at the moment work lands, not at milestone close — otherwise the close audit reads scary when it's actually clean.
- Internal GSD milestone versions (v1.36–v1.39) are *not* Hex releases (hex is `v1.1.0`); don't git-tag them, and keep the planning-version vs semver distinction explicit to avoid muddying the release line.

---

## Milestone: v1.35 — BRAND-SYSTEM-PRESSURE-TEST

**Shipped:** 2026-06-05
**Phases:** 7 (161, 162, 163, 164, 165, 166, 167) | **Plans:** 8

### What was built

- A repo-derived 14-section brand pressure-test audit that kept Sigra's inherited OSS/devtools strengths separate from missing implementation-ready collateral.
- `brandbook/brand-book.md` with brand DNA, positioning, design principles, voice rules, copy blocks, component guidance, accessibility posture, and asset policy.
- `brandbook/tokens.json` and `brandbook/tokens.css` for practical source-controlled brand tokens without mutating runtime or generated UI CSS.
- A text/SVG-first logo and specimen system: primary lockup, icon mark, monochrome mark, favicon, social card, visual specimens, and usage guidance.
- `brandbook/index.html`, a static, directly openable brandbook with local assets only.
- A repaired logo-ratification flow: Phase 167 presented five directions, recorded the human choice, finalized Option A Core Rails, and reran JSON/SVG/HTML/browser/axe/file-size/git hygiene gates.

### What worked

- Keeping the source material to repo truth plus the supplied prompt prevented generic brand advice and anchored the outcome in Sigra's actual architecture.
- The source-control-friendly artifact policy kept the milestone useful without introducing binary sprawl or broad README/HexDocs/generated-template churn.
- Phase 167 was the right correction: it acknowledged the premature completion claim, added a human logo decision point, and repaired the state instead of discarding the useful earlier work.

### What was inefficient

- The first closeout treated logo assets as final before the human direction review happened, forcing a process-repair phase.
- Browser/axe verification initially used the wrong Playwright context shape for the installed axe package and had to be rerun with `browser.newContext()`.
- v1.35 became a brand collateral exception to the maintenance-first default; future brand adoption should stay focused on concrete distribution or adoption needs.

### Patterns established

- Brand collateral lives under `brandbook/` unless a future focused milestone explicitly promotes it into README, HexDocs, generated templates, or runtime UI.
- Text/SVG/HTML/JSON/CSS are the committed source artifacts; PNG/PDF/raster exports are generated only for a concrete platform target.
- Logo direction review should be a real gate before final asset ratification whenever multiple visual directions are plausible.

### Key lessons

- Brand work can be roadmap-worthy when it makes adoption and docs surfaces buildable, but it should remain bounded and source-controlled.
- A milestone closeout must distinguish "artifact exists" from "artifact has passed the intended decision gate."
- Static local HTML plus axe/browser checks is enough for this kind of lightweight brandbook proof when no runtime behavior changes.

### Cost observations

- Model mix: n/a.
- Sessions: one brandbook execution session plus one closeout session.
- Notable: the expensive step was not code implementation; it was recovering decision integrity around the logo direction while keeping the final artifact set coherent.

## Milestone: v1.34 — ADMIN-UI-COHERENCE

**Shipped:** 2026-06-05
**Phases:** 7 (154, 155, 156, 157, 158, 159, 160) | **Plans:** 29

### What was built

- A committed admin design contract: canonical component jobs, 3 page archetypes, ARIA and motion rules, and when-not-to-use guidance.
- `Sigra.Admin.Components`, migrated across the 6 existing admin screens so repeated jobs use shared components instead of private duplicate fragments.
- Needs-led Global and Org Overview landings with a prominent risk alarm, verb-first task cards, demoted posture/capability sections, and skeleton loading states.
- Reconciled audit surfaces: mobile card fallback, shared audit row, consistent quick filters, back navigation, scope ribbon, notices, and empty states.
- Deterministic demo seed enrichment for expired invitations, deletion-scheduled users, passkey-only users, and richer audit-event variety.
- Ratification through 3-project Playwright checkpoints, axe gates, snapshot canary guard, ExUnit component goldens, and admin-generated parity.

### What worked

- The Phase 155 keystone constraint was valuable: no Playwright re-records during component extraction kept behavior-preserving work honest before visual changes began.
- The "same job -> same component" contract gave later phases a concrete standard instead of another subjective polish loop.
- Adding new checkpoint slugs for under-covered surfaces (`global-overview`, `org-overview`, `user-audit`) improved proof quality without widening the whole behavior matrix.
- The final Phase 160 ratification caught and closed real integration details: dark contrast, needs-review link/filter wiring, canary drift, and admin-generated parity.

### What was inefficient

- Some generated milestone summary extraction was too raw for closeout, producing placeholder "One-liner" rows that needed manual cleanup.
- Several small issues surfaced late through review/audit rather than phase-local checks, especially count/filter reconciliation and date-format robustness.
- The milestone deliberately reopened a polish exception after the post-1.0 maintenance posture, so future work should keep this exception bounded and evidence-led.

### Patterns established

- Future admin UI changes should route through `Sigra.Admin.Components` and the design contract before adding bespoke markup.
- Screenshot baseline changes need deliberate slugs, wait guards, allowlist/reset discipline, and canary protection.
- Demo seed data is part of evaluator UX; empty or impossible states weaken the generated admin surface even when core auth behavior is correct.

### Key lessons

- Component extraction should prove byte/structural equivalence before adoption, then baseline re-records should happen only after the shared calls are wired.
- Needs-led IA is not just visual polish when the admin surface is an adoption/evaluator touchpoint; it belongs in roadmap only when tied to concrete adoption proof.
- Milestone-close automation is useful for archival, but the shipped narrative still needs human curation.

### Cost observations

- Model mix: n/a.
- Sessions: multiple phase execution sessions plus one closeout session.
- Notable: most closeout work was documentation/archive hygiene; the expensive verification happened in Phase 160 through Playwright compare mode, canary guard, and parity proof.

## Milestone: v1.33 — POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS

**Shipped:** 2026-06-02
**Phases:** 4 (150, 151, 152, 153) | **Plans:** 4

### What was built

- Maintainer triage cadence, bug-prioritization posture, and generated-host template-update communication rules.
- Erlang/OTP and Hex dependency sync within the existing compatibility proof surface.
- A formal strategic-bet evaluation gate that keeps SCIM, `sigra_lockspire`, and Threadline correlation deferred until concrete adopter demand appears.
- A shared SQL Sandbox harness for library live-DB tests, owner-per-test rollback cleanup, and isolated query-index scratch storage.

### What worked

- The stale milestone audit correctly forced a real closure phase instead of letting the connection-exhaustion blocker disappear into narrative.
- Phase 153 kept the fix bounded to test infrastructure: no runtime code changes, no example-app sandbox redesign, and no CI matrix expansion.
- The focused Phase 153 proof was fast and decisive: 107 tests, 0 failures.

### What was inefficient

- Phase 153 initially had a summary but no canonical `153-VERIFICATION.md`, so milestone close had to backfill the verification artifact from fresh evidence.
- Local focused tests still emit unrelated `Chimeway.Repo` missing database configuration startup noise; it does not block the focused proof, but it weakens full-suite signal quality.

### Patterns established

- Live library Postgres suites use `Sigra.Test.PostgresCase, async: false` with one sandbox owner per test.
- Storage-destructive proofs use isolated scratch repos rather than mutating shared repo configuration.
- Strategic bets remain gated by explicit adopter demand rather than speculative feature expansion.

### Key lessons

- A `gaps_found` audit can be the right answer even when most requirements are satisfied; it should drive closure work until the broken flow is truly represented by passing evidence.
- Verification files are close-critical artifacts. A passing summary is not a substitute for the canonical phase verification report.

### Cost observations

- Model mix: n/a.
- Sessions: single close session with one focused proof run.
- Notable: the milestone-close work was mostly archival and artifact reconciliation; the only fresh test execution was the Phase 153 focused suite.

## Milestone: v1.30 — TRUST-HARDENING (Operator Confidence & Debt Closure)

**Shipped:** 2026-05-29
**Phases:** 4 (137, 138, 139, 140) | **Plans:** 10 (`137-01`..`137-03`, `138-01`..`138-02`, `139-01`..`139-02`, `140-01`..`140-03`)
**Git range:** `de3f3f8`..HEAD — ~89 commits, 90 files changed, +10,991 / −63 (dominated by `.planning/` docs)
**Timeline:** ~2 days — 2026-05-28 → 2026-05-29

### What was built

- **OD-01/OD-02** — `Sigra.OptionalDeps`: one canonical module with 9 `*_available?/0` predicates (oban/bcrypt/eqrcode/threadline/assent/swoosh/joken/hammer/req) + config-driven `encryption_active?/1`. ~29 scattered `Code.ensure_loaded?` guards consolidated across 17 delegation sites with **zero runtime behavior change** — proven by a 12-test drift-catching unit suite (each predicate asserted `== Code.ensure_loaded?(Mod)`, so the test stays valid in a dep-off env) and the existing `library_tests_dep_off` CI lane. Documented fences (compile-time defmodule wrappers, dynamic host-schema atoms, internal-worker leg, Oban boot warning) were deliberately left literal.
- **DR-01/DR-02** — `mix sigra.doctor`: a pure injectable `Sigra.Doctor` core (nine-feature matrix, four states, four D-09 boot-wiring hard-fail checks, no IO) + a thin Mix-task shell (ANSI output, `--quiet`, `exit({:shutdown,1})` CI gate, never `System.halt`). 30 tests via an injection seam + CaptureIO, no subprocess.
- **RCT-01/RCV-01/RCV-02** — a merge-blocking pure-ExUnit fixture asserting all 6 companion-lib recipes carry five required markers (+ a standalone D-05 non-empty-glob guard), plus sister-repo verification of the Lockspire `resolve_account/2` return shape and Rulestead `@behaviour` contract (`def616d`/`0a18360`), with the folded phase-134 residual todo closed.
- **DEPR-01/DEPR-02/PROOF-01/DOC-01** — Hex-SemVer removal targets + migration notes on both live `@deprecated` functions; an eight-gate proof bundle filed at `140-VERIFICATION.md`; docs aligned (deployment operator-diagnostics + three MAINTAINING maintainer notes).

### What worked

- **SOT-before-consumer sequencing** — building `Sigra.OptionalDeps` (137) before `mix sigra.doctor` (138) meant the doctor consumed a frozen predicate surface; the integration checker later confirmed the doctor re-implements no dep checks (all 9 predicates + `encryption_active?/1` delegated).
- **Drift-catching equality assertions** — writing the SOT unit tests as `predicate() == Code.ensure_loaded?(Mod)` rather than hardcoded booleans made one test file valid in both dep-on and dep-off environments, and turned the "no behavior change" invariant into something mechanically checkable.
- **Injection seam for the diagnostic** — `Sigra.Doctor`'s `predicates:`/`host_sigra:`/`oban_running:`/`module_loaded?:` overrides let all 30 doctor tests run without toggling the ambient dep tree or spawning subprocesses (<0.1s feedback), and made the four D-09 hard-fail branches fully unit-testable.
- **Honest low-code framing** — declaring up front that v1.30 was a consolidation milestone (net new lib surface = `OptionalDeps` + `Doctor` + the task) kept it bounded and on the right side of the Diminishing Returns Wall.

### What was inefficient

- **Verification-artifact bookkeeping lagged execution** — at milestone-audit time Phase 137 had no `137-VERIFICATION.md` (only UAT/VALIDATION/SECURITY), Phase 138 had no `138-VALIDATION.md`, and Phase 139's `139-VALIDATION.md` was a never-signed pre-execution draft. All three were substantively done — the gap was purely filing the canonical artifact. Closing them at milestone close cost a full retroactive pass (file one VERIFICATION, reconstruct one VALIDATION, sign off another, tick two checkboxes). A per-phase "VALIDATION signed off post-execution?" gate would have caught this before close.
- **`gsd-sdk query audit-open` false positives, third milestone running** — it flagged 3 genuinely-complete quick tasks as open (each has a SUMMARY.md; `status:` frontmatter just isn't where the SDK looks). MAINTAINING.md already documents the SDK as unreliable for this repo and prescribes grep-driven checks — the audit-open call could be dropped from the close flow entirely here.
- **The SDK's `milestone.complete` accomplishments were unusable** — it globbed *all* phase SUMMARYs (so the v1.30 MILESTONES.md entry came out full of v1.29 Threadline/suite content + literal "One-liner:" artifacts + a wrong `10 phases / 23 plans` count) and had to be rewritten by hand. The counts in its JSON (`phases: 10`) are cumulative-disk, not milestone-scoped.
- **A deferred fold-in silently didn't happen** — the phase-138 doctor Info findings (IN-01/02/03) were tagged for a Phase-140 fold-in that never occurred; they were still in `pending/` at close and had to be carried forward. "Resolve in phase N+k" notes need a verification step at phase N+k.

### Patterns established

- **Retroactive artifact backfill at milestone close is legitimate when alternate evidence is current and strong** — a missing `VERIFICATION.md` was closed by synthesizing from existing UAT (7/7) + VALIDATION (nyquist-compliant) + SECURITY (9/9) + the integration checker, with an explicit `backfilled: true` frontmatter flag, rather than re-running execution.
- **Document, don't churn, a versioning-coherence wart** — WR-01 (deprecation removal target rendering *before* `@doc since:`, an artifact of a Hex-SemVer axis vs an internal milestone axis) was resolved to "accept + document": a "Dual version axes" note in MAINTAINING.md plus a kept-open todo for a future library-wide `since:` re-keying, instead of a large mechanical edit at close.

### Key lessons

- A phase can be functionally and code-verified (integration checker WIRED, tests green) yet still trip the close gate purely on artifact hygiene. Treat `*-VERIFICATION.md` / signed `*-VALIDATION.md` as execution deliverables, not close-time chores.
- When a milestone audit says `gaps_found` but `requirements: N/N` with zero unsatisfied, read the gap categories before reacting — process/hygiene gaps close in minutes; requirement gaps need phases.

### Cost observations

- Model mix: predominantly Opus (single-session close). Sessions: 1 (this close) atop the per-phase execution sessions.
- Notable: the entire close was no-code — every gap closed with docs/artifacts. The expensive part was reading evidence across UAT/VALIDATION/SECURITY/integration to file one honest VERIFICATION, not generating anything.

## Milestone: v1.29 — SUITE-INTEGRATION (Companion-Library Integration)

**Shipped:** 2026-05-29
**Phases:** 6 (131, 132, 133, 134, 135, 136) | **Plans:** 13 (`131-01`..`131-06`, `132-01`, `133-01`, `134-01`, `135-01`, `136-01`..`136-03`)
**Git range:** `5026262`..HEAD — ~133 commits, 110 files changed, +19,460 / −67 (~17k of which is recipe/narrative docs)
**Timeline:** 2 days — 2026-05-27 → 2026-05-28

### What was built

- **TL-01..TL-05 / FB-01** — `Sigra.Audit.Forwarder` single-callback behaviour + `Sigra.Audit.Forwarders.Threadline` telemetry-tap impl + `Noop` fallback + optional `Sigra.Workers.AuditForward` Oban worker. `:auto`/`:async`/`:sync` dispatch on the `Sigra.Delivery` precedent; `[:sigra,:audit,:forward,:ok|:error]` telemetry; whole impl wrapped in `Code.ensure_loaded?(Threadline)` with a one-shot boot warning; the Sigra audit DB row stays source-of-truth (post-commit projection, never a destination swap, never rolls back the originating txn). The only new library code in the milestone.
- **RC-01..RC-06 / NX-01** — six companion-library recipes under `guides/recipes/companion-libs/` (Threadline, Mailglass, Accrue, Lockspire, Relyra, Rulestead) on a uniform template + `guides/introduction/suite-integration.md` narrative (ASCII diagram, fan-out matrix, Diminishing Returns Wall), all under a new ExDoc "Companion Libraries" group with no orphan pages.
- **EX-01** — `test/example/` extended with a runnable Sigra→Threadline audit projection demo: dev/test dep + ordered migrations + dual `forwarders:` config + an integration test asserting a `session.create` audit event materializes as a Threadline `audit_actions` row joined on `correlation_id`, green on existing CI lanes (no new top-level `examples/`).
- **PROOF-01 / DOC-01** — six-gate proof bundle green on release-branch HEAD (full suite 2252, audit suite 60, dep-off lane 2246 with Threadline absent, example app 236, `mix docs --warnings-as-errors` exit 0); `131-VERIFICATION.md`..`136-VERIFICATION.md` filed; v1.25 EMAIL-RAILS Mailglass overclaim corrected across MILESTONES.md/PROJECT.md/CHANGELOG.md.

### What worked

- **Bounded "one piece of new library code" framing** — deciding up front that only the Threadline forwarder was library code (everything else recipe/narrative/`test/example/`) kept the milestone honest to the Diminishing Returns Wall and made phase scoping trivial.
- **Behaviour-first (Phase 131 before any 2nd forwarder)** — locking `Sigra.Audit.Forwarder` + the `forwarders:` config shape before recipes/demo pinned against it meant the canary recipe, the demo, and the example config all referenced a frozen contract.
- **Real E2E demo as the integration proof** — the `test/example/` DB round-trip test (Phase 135) caught the RC-01 config-drift class of bug that prose review would have missed; the milestone audit's "verbatim paste fires `:forward:error`" finding came directly from having a runnable reference.

### What was inefficient

- **Recipe config drift slipped past phase verification** — RC-01 (threadline.md shipped `endpoint:`/`api_key:`, omitted the required `repo:` key) and CR-01 (accrue/audit-logging referenced a non-existent `log/1`/`log/3`) were both caught only at milestone audit, requiring two post-verification quick tasks (`260528-nwa`, `260528-sbn`). Recipe-contract test fixtures (deferred) would have caught the config-block divergence between validator, recipe, and example mechanically.
- **Three audit passes to close** — gaps_found → tech_debt → passed. The doc-debt (mailglass corrigendum present-tense pointer, `~> 1.29` vs `~> 0.2` self-pins) was avoidable drift that a version-pin lint would have flagged before the first audit.
- **Quick-task status frontmatter again unstamped** — same bookkeeping miss as v1.28: `gsd-sdk query audit-open` flagged two genuinely-complete quick tasks as open at close because they lacked a `status: complete` field.

### Patterns established

- **`guides/recipes/companion-libs/<name>.md` subdir convention** + ExDoc "Companion Libraries" group as the home for all future companion-lib recipes, on a uniform template (`validated_against:`/`last_validated:` frontmatter, `mix.exs` snippet, "Failure modes", "Non-goals", standalone banner).
- **`Sigra.Audit.Forwarders.*` naming** ("Forwarders" not "Adapters") to signal projection-not-destination-swap semantics — applies to any future post-commit audit sink.
- **Extend `test/example/` over new top-level `examples/`** — reaffirmed; existing CI lanes cover it and it avoids re-opening the Phase 114 nested-example-app drift.

### Key lessons

- A runnable reference example is worth more than recipe prose for catching integration drift — the config block an adopter pastes must be byte-for-byte identical across validator, recipe, and example, and only an executable test enforces that.
- Version-pin and present-tense-pointer drift in docs is a recurring, cheap-to-prevent audit gap; a lint over recipe self-pins and corrigendum pointers would remove a whole audit pass.

### Cost observations

- Lowest-code milestone in recent memory: 1 new library module, ~17k of the diff is documentation. Three audit passes added overhead but each was a focused doc-only quick task, not re-execution.
- Quick tasks `260528-nwa` / `260528-sbn` were the right tool for post-verification doc-debt closure — atomic, doc-only, no library wiring touched, `mix docs --warnings-as-errors` re-verified exit 0.

---

## Milestone: v1.28 — DATA-LIFECYCLE (Compliance Export & Data Lifecycle)

**Shipped:** 2026-05-27
**Phases:** 4 (127, 128, 129, 130) | **Plans:** 6 (`127-01`, `127-02`, `128-01`, `129-01`, `129-02`, `130-01`)
**Git range:** `v1.27..v1.28` — 77 commits, 78 files changed, +10,340 / −145
**Timeline:** single-day milestone — 2026-05-27 02:00 → 08:42 EDT (~7 hours of execution time)

### What was built

- **EXP-01 / EXP-02** — `Sigra.DataExport.export_auth_data/3` ships `schema_version: 1` with curated safe serializers, lifecycle status derived from `Sigra.Account.Deletion.status/1`, explicit structured omission notes, backup-code summary-only exposure, and explicit exclusion of enterprise connections.
- **LIFE-01 / LIFE-02 / LIFE-03** — `Sigra.Account.Deletion.schedule/3` enqueues `Sigra.Workers.AccountDeletion` when Oban + generated-host context exist; degrades safely when context is absent; cancel/execute gated through `Deletion.scheduled?/1`; soft-delete finalization clears scheduled-deletion + pending/original email fields while preserving the row and `deleted_at`.
- **HOST-01** — Generated host templates, example app, and install golden fixture all delegate to library export/lifecycle APIs (no per-host re-implementation).
- **DOC-01** — Account lifecycle, audit export, and testing docs pin Sigra-owned vs host-owned data boundaries, omission behavior, and deletion strategy consequences; guide tests assert the contract.
- **PROOF-01** — 56+66 lifecycle/install-lane targeted tests, 2211 full-suite tests, and `mix docs --warnings-as-errors` exit 0 (unblocked by docs-fix commit `110a560`).

### What worked

- **Assumptions-mode discuss → planning → execute** chain on day-of: all four phases planned and executed in a single working session with clean handoffs through `*-CONTEXT.md` resume artifacts.
- **RED-first plan-01 for Phase 127** — test-only proof committed before implementation gave Plan 02 a precise contract to satisfy; export payload shape stabilized fast.
- **Single library ownership boundary** — keeping export payload in `Sigra.DataExport.export_auth_data/3` and deletion lifecycle in `Sigra.Account.Deletion` meant Phase 129 generated-host work was a thin wrapper, not a re-implementation.
- **Audit unblocker via quick-task `260527-bsd`** — when PROOF-01 hit the `mix docs --warnings-as-errors` blocker on OAuth callback xrefs, a focused quick task (commits `110a560` + `111e024`) closed the docs gate and reconciled all five v1.28 traceability artifacts in one atomic doc-only pass.

### What was inefficient

- **Docs gate caught late** — `mix docs --warnings-as-errors` is a release-readiness gate that should run earlier in Phase 130 (or in a Phase 129 verification step) so docs-xref drift surfaces before the final proof commit, not after.
- **Quick-task SUMMARY missing `status: complete` field** — bookkeeping caused `gsd-sdk query audit-open` to flag a clean task as open at milestone close. Future quick-tasks should set `status: complete` in frontmatter alongside `completed: <timestamp>`.
- **No v1.18–v1.27 retrospective entries** — 10 milestones shipped without retrospective sections, leaving cross-milestone trend tables stale. Worth a one-time backfill pass before next retrospective grows further.

### Patterns established

- **Versioned payload + structured omissions** — Library-owned exports carry `schema_version` plus an explicit `omissions` block keyed by `(section, schema)` rather than silently dropping missing optional data.
- **Safe missing-context degradation for schedulers** — Background-job scheduling functions check for required context (Oban + generated-host modules) and no-op rather than failing when the host hasn't wired them; explicit return values communicate the degradation.
- **Active-scheduled gating for state transitions** — Cancel/execute paths assert `scheduled?/1` and return `{:error, :not_scheduled}` rather than mutating finalized rows; stale workers also use the same predicate to no-op gracefully.
- **Row-preserving soft-delete finalization** — Soft-delete clears scheduled-deletion + pending/original email fields while preserving the row and `deleted_at`, keeping audit + recovery possible.

### Key lessons

1. **Run release docs gate early.** `mix docs --warnings-as-errors` is a fast check; bake it into the phase that owns docs (Phase 129) so xref drift gets caught before the verification phase.
2. **RED-first for contract-defining plans.** Phase 127 Plan 01 as test-only proof made Plan 02 implementation almost mechanical and prevented payload-shape drift.
3. **One library ownership boundary per concern.** Resisting the urge to duplicate export logic into generated-host templates kept Phase 129 small and made HOST-01 verification trivial.
4. **Acknowledge bookkeeping gaps explicitly.** The `status: complete` frontmatter quirk in the quick-task SUMMARY surfaced through `audit-open` — fix the canonical form rather than acknowledging it as deferred debt.

### Cost observations

- Model mix: n/a (not instrumented)
- Sessions: single working day (2026-05-27, ~7 hours wall-clock)
- Notable: 77 commits with +10,340 / −145 in a single day is a high-throughput milestone; the bounded scope (auth export + deletion lifecycle only — no SCIM, BI export, hosted control plane) and the strong substrate from v1.0–v1.27 (account lifecycle, audit, Oban workers, generated-host pattern) were the leverage.

---

## Milestone: v1.17 — Forced password change audit atomicity

**Shipped:** 2026-04-24  
**Phases:** 1 (80) | **Plans (on-disk):** 2 (`80-01`, `80-02`) | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-17-01** — **`clear_password_change_requirement/3`** wraps **`PasswordChange.clear_force_change/2`** semantics in **`Repo.transaction/1`** with **`Multi` + `log_multi_safe`** when audit is enabled.
- **AUD-17-02** — **`audit_forced_password_change/2`** **`@deprecated`** for the path now covered by the **`Multi`**.
- **AUD-17-03** — **`account_audit_atomicity_test.exs`** forced-clear happy path + audit **`CHECK`** rollback.
- **AUD-17-04** — **44** / **09** / **09-03-SUMMARY** / **`CHANGELOG` [Unreleased]**; **EX-44-05** closed.

### What worked

- **Verification gate** — **`80-VERIFICATION.md`** mapped 1:1 to code, tests, and planning surfaces.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still fails (`version required for phases archive`); manual **`milestones/v1.17-*`** + **`/gsd-complete-milestone`** finish (same as **v1.12**–**v1.16**).

### Patterns established

- **Account forced-clear** follows the same transactional audit pattern as **`change_password`** in **`account_audit_atomicity_test.exs`**.

### Key lessons

1. Close **EX-44-05** in the same milestone as **043** **T1** to avoid dangling inventory appendix rows.
2. Deprecation on the old helper keeps semver-safe migration for any host callers.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Tight scope (one public API + tests + planning); highest leverage was **`account.ex`** + atomic tests.

---

## Milestone: v1.16 — API verify failure audit atomicity

**Shipped:** 2026-04-24  
**Phases:** 1 (79) | **Plans (on-disk):** 0 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-16-01 / AUD-16-02** — **`verify/2`** invalid / revoked / expired paths emit **`api.token_verify.failure`** inside **`Repo.transaction/1`** with **`Ecto.Multi`** + **`log_multi_safe`** when `:audit_schema` is set.
- **AUD-16-03** — **44** inventory + **09-VERIFICATION** C-1 **044–046** → **T1**; **09-03-SUMMARY** + **`CHANGELOG` [Unreleased]** trace **v1.16** / **79** / **AUD-16**.
- **AUD-16-04** — **D-27** preserved: no success-path **`api.token_verify`** audit rows.
- **`api_token_audit_atomic_test.exs`** — Postgres-backed failure + fault-injection coverage alongside **`api_token_test.exs`**.

### What worked

- **Verification-first single phase** — **`79-VERIFICATION.md`** checklist mapped cleanly to code + docs.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** not used; manual **`milestones/v1.16-*`** writes (same as **v1.12**–**v1.15**).
- **No on-disk `79-SUMMARY.md`** — closure relied on **VERIFICATION** + requirements traceability (same shape as **v1.15**).

### Patterns established

- **Failure-only API token verify audits** co-fated with the **`{:error, reason}`** return path without widening **D-27** success noise.

### Key lessons

1. Retire **EX-44-01** appendix honesty when code moves **`044–046`** to **T1** — keep appendix row for archaeology.
2. Keep **`log_safe_error`** telemetry explicit when audit insert fails but the caller still gets the domain error.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Single commit since **`v1.15`** tag; highest leverage was **`api_token.ex`** + one atomic test module + planning matrix rows.

---

## Milestone: v1.15 — Account + API C-1 planning truth

**Shipped:** 2026-04-24  
**Phases:** 1 (78) | **Plans (on-disk):** 0 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-14-01 / AUD-14-02** — **44-AUD-04-INVENTORY** rows **035–042** and **047** aligned to **`lib/sigra/account.ex`** / **`lib/sigra/api_token.ex`**; hybrid **044–046** and **043** deferrals preserved (**EX-44-01**, **EX-44-05**).
- **AUD-14-03** — **09-VERIFICATION** C-1 table honesty for the same row IDs.
- **AUD-14-04 / AUD-14-05** — **09-03-SUMMARY** bounded-batch note; **CHANGELOG [Unreleased]** trace; **`account_audit_atomicity_test.exs`** **`change_password`** success + CHECK-guard rollback.

### What worked

- **Verification-first single phase** — **`78-VERIFICATION.md`** gave a tight checklist against inventory + matrix + tests.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still failed (`version required for phases archive`); manual **`milestones/v1.15-*`** writes repeated the established pattern.
- **No on-disk `78-SUMMARY.md`** — closure relied on **VERIFICATION** + requirements traceability (same shape as other micro-ships).

### Patterns established

- **Planning truth before the next SEED-002 batch** — when code already matched **Multi**, the milestone was mostly honest **C-1** labeling + test evidence.

### Key lessons

1. Keep **EX-44-01** / **EX-44-05** explicit whenever **Account**/**API** rows mix **`log_safe`** and **`log_multi_safe`**.
2. **`change_password`** audit atomicity belongs in **`account_audit_atomicity_test.exs`** alongside **`set_password`** for symmetric confidence.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Small diff since **`v1.14`** tag; highest leverage was matrix + inventory alignment + one focused test file.

---

## Milestone: v1.14 — Bounded audit trust closure

**Shipped:** 2026-04-24  
**Phases:** 1 (77) | **Plans (on-disk):** 1 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-13-01 / AUD-13-02** — **`audit_backup_codes_regenerate/3`** and **`audit_trust_browser/2`** routed through **`commit_ad_hoc_mfa_audit/5`** (**`Repo.transaction/1`** + **`Ecto.Multi`** + **`log_multi_safe`**).
- **AUD-13-03** — **`mfa_audit_atomicity_test.exs`** success, audit-disabled no-op, and CHECK-guard rollback coverage on Postgres.
- **AUD-13-04** — **09-VERIFICATION** / **09-03-SUMMARY** / **44-AUD-04-INVENTORY** / **CHANGELOG [Unreleased]** aligned to **T1** for **033**/**034** with **phase 77** pointer.

### What worked

- **Single-phase bounded batch** — closed a discrete **C-1** pair without scope bleed into **Account**/**API** or **SEED-001**.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still failed (`version required for phases archive`); manual **`milestones/v1.14-*`** writes repeated the established pattern.
- **No `v1.14-MILESTONE-AUDIT.md`** — optional; honesty gate was **77-VERIFICATION.md** + requirements traceability.

### Patterns established

- **Shared `commit_ad_hoc_mfa_audit/5`** — one helper for ad-hoc MFA audit inserts preserves telemetry parity with legacy **`log_safe/3`** swallowing.

### Key lessons

1. Add an on-disk **`*-SUMMARY.md`** for single-phase ships so milestone close and **MILESTONES** extraction stay uniform (**77-01-SUMMARY** added at archive).
2. Keep **AUD-04-022** explicitly out of hybrid **Multi** batches when there is no durable business row to co-fate (**EX-44-02**).

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Tight **SEED-002** slice; highest leverage was Postgres rollback tests + inventory row honesty.

---

## Milestone: v1.12 — Trust, evidence, and adoption polish

**Shipped:** 2026-04-24  
**Phases:** 3 (73–75) | **Plans (on-disk):** 7 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-11 (Phase 73)** — Bounded **`mfa.ex`** **`Ecto.Multi`** + **`log_multi_safe`**; **`mfa_audit_atomicity_test.exs`** rollback coverage; inventory / **09-VERIFICATION** row reconciliation.
- **AUD-12 / UAT-01 / UAT-02 (Phase 74)** — **`09-03-SUMMARY.md`** carries post–**73** truth; **`.planning/v1.12-UAT-EVIDENCE.md`**; **`docs/uat-ci-coverage.md`** aligned with evidence story.
- **TRN-01..TRN-03 (Phase 75)** — **`upgrading-to-v1.12.md`** + ExDoc extras; trust bundle on getting-started / **MAINTAINING** / **CHANGELOG**; **`v1.11-TRIAGE.md`** § v1.12 reconciliation + **`75-VERIFICATION.md`**.

### What worked

- **Same tranche shape as v1.9–v1.11** — one code batch + evidence/planning closure + doc polish without scope explosion.
- **`audit-open` all clear** — no deferred artifact debt at close.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still failed; manual **`milestones/v1.12-*`** writes repeated the established pattern.
- **No `v1.12-MILESTONE-AUDIT.md`** — honesty gate was phase **`*-VERIFICATION.md`** + requirements; consider a short audit file next ship if comparing to **v1.10**.

### Patterns established

- **Planning-label evidence file** — **`v1.12-UAT-EVIDENCE.md`** as the single auditable index before a loud launch.

### Key lessons

1. Reconcile **`.planning/REQUIREMENTS.md`** traceability at close so **Pending** rows never lag **`*-VERIFICATION.md` passed** (fixed at archive for **v1.12**).
2. Keep **`roadmap.analyze`** limitations in mind; **ROADMAP + filesystem** remained source of truth.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Small phase count; highest leverage was evidence packaging + one more bounded **SEED-002** batch.

---

## Milestone: v1.10 — Adopter confidence for solo production

**Shipped:** 2026-04-23  
**Phases:** 3 (68–70) | **Plans (on-disk):** 5 | **Sessions:** n/a (not instrumented)

### What was built

- **ACF-01 / ACF-04 (Phase 68)** — **`guides/recipes/deployment.md`** production checklist hub + mail inline vs Oban TL;DR; cross-links from README, intro guides, **MAINTAINING**, and install flag anchors.
- **ACF-02 / ACF-03 (Phase 69)** — **`intermediate-production-path.md`**, canonical **`generator-options.md`**, ExDoc **Reference** group, **`Mix.Tasks.Sigra.Install`** `@moduledoc` bullet, intro mesh.
- **ACF-05 / ACF-06 (Phase 70)** — **`upgrading-to-v1.10.md`** + ExDoc extras; explicit **ADR 001** / **SEED-002** deferrals in planning surfaces.

### What worked

- **Verification-first closure** — **`068-VERIFICATION.md`** **passed** gave a clean signal for **ACF-01** / **ACF-04** even when live requirement rows briefly lagged.
- **Same-day phases** — three small doc phases shipped without scope creep into new auth primitives.

### What was inefficient

- **`gsd-sdk query milestone.complete`** unavailable; manual archival repeated the **v1.3**–**v1.9** pattern.
- **`roadmap.analyze`** empty JSON for this roadmap shape; relied on filesystem + **VERIFICATION** artifacts.

### Patterns established

- **Planning-label upgrade stubs** — **`upgrading-to-v1.x.md`** files disambiguate GSD / planning milestones from Hex SemVer for adopters.

### Key lessons

1. Reconcile **`.planning/REQUIREMENTS.md`** traceability at ship so **Pending** rows never contradict **`*-VERIFICATION.md` passed**.
2. Keep **adopter-confidence** milestones doc-only but still milestone-audited when the prior ship window used the same honesty gate.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: **28** commits since **`v1.9`** tag on the measured range; **47** files in **`git diff --stat v1.9..HEAD`** summary.

---

## Milestone: v1.9 — Audit atomicity (bounded SEED-002)

**Shipped:** 2026-04-23  
**Phases:** 2 (66–67) | **Plans (on-disk):** 3 | **Sessions:** n/a (not instrumented)

### What was built

- **AUD-09 (Phase 66)** — **`confirm_enrollment/5`** **AUD-04-020..021** on **`Ecto.Multi`** with **`log_multi_safe`**; **`mfa_audit_atomicity_test.exs`** for success + rollback/failure signals.
- **AUD-10 (Phase 67)** — **`09-03-SUMMARY.md`** post–phase-66 narrative; **D-06** inventory cross-check; explicit **no `09-VERIFICATION.md` edit** where rows already matched intent.

### What worked

- **Mirror v1.7 pattern** — one bounded code batch plus honest planning closure closed the milestone without boiling the ocean.
- **Merge-gated audit tests** — kept **T1** semantics provable in CI for the touched subsystem.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again; manual archival repeated the v1.3–v1.8 pattern.
- **`roadmap.analyze`** returned empty JSON for this roadmap shape; closure relied on **REQUIREMENTS.md** + on-disk **`*-SUMMARY.md`** checks.

### Patterns established

- **Failure-path `Multi`** for enrollment audit parity with success-path co-fated writes where **C-1** demands it.

### Key lessons

1. Keep **bounded SEED-002** milestones to **one production batch + one planning closure** per ship window when possible.
2. File a short **milestone audit** at close when prior milestones used the same honesty gate.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Very small phase count; highest leverage was MFA audit atomicity + **C-1** narrative alignment.

---

## Milestone: v1.8 — Adopter polish (diminishing returns)

**Shipped:** 2026-04-23  
**Phases:** 3 (63–65) | **Plans (on-disk):** 0 | **Sessions:** n/a (not instrumented)

### What was built

- **ADOPT-04 (Phase 63)** — **`upgrading-to-v1.8.md`** with honest **planning vs SemVer** framing, **`mix.exs`** extras ordering, and pointers back to **v1.7** maintainer context.
- **ADOPT-05 (Phase 64)** — Cross-links so **getting-started → first-hour → troubleshooting → upgrades** reads as one mesh.
- **INTG-02 (Phase 65)** — **`companion-oauth-provider.md`** prerequisites, explicit **B2C-only / no third-party API clients** anti-pattern, and **See also** navigation to **v1.8** upgrades.

### What worked

- **Doc-only milestone with full traceability** — three requirements mapped to three phases without inventing fake execution packs.
- **Small diff, high leverage** — most churn was prose + navigation, not security-sensitive code paths.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again; manual archival repeated the v1.3–v1.7 pattern.
- **No `063-*` / `064-*` / `065-*` phase directories** — harder to grep execution history; prefer lightweight doc phase dirs if Nyquist strictness matters later.

### Patterns established

- **Upgrade guide per planning focus** — when “v1.x” is planning language, ship a dedicated upgrade page that does not pretend SemVer is the same thing.

### Key lessons

1. Ship **adopter polish** milestones with the same **REQUIREMENTS.md** traceability discipline as code-heavy milestones.
2. When **`roadmap.analyze`** returns empty JSON for this roadmap shape, rely on **`.planning/REQUIREMENTS.md`** + filesystem checks before close.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Single-day closure; git range since **`v1.7`** was intentionally tiny.

---

## Milestone: v1.7 — Adoption readiness & audit durability

**Shipped:** 2026-04-23  
**Phases:** 3 (60–62) | **Plans (with on-disk summaries):** 3 (**061**–**062**) | **Sessions:** n/a (not instrumented)

### What was built

- **ADOPT / INTG (Phase 60)** — First-hour, upgrade, troubleshooting guides plus **`companion-oauth-provider`** recipe with explicit non-coupling (no IdP in Sigra core).
- **AUD-01 (Phase 61)** — `verify_backup/4` failure path on **`Ecto.Multi`** with **`mfa_audit_atomicity_test.exs`**; **AUD-04-067** + C-1 / inventory alignment.
- **AUD-02 (Phase 62)** — **`09-03-SUMMARY.md`** carries honest post-batch narrative; **D-06** confirmed **`09-VERIFICATION.md`** unchanged.

### What worked

- **Tiny code + heavy truth** — one subsystem batch plus doc alignment closed a real audit durability gap without boiling the ocean.
- **D-06 discipline** — avoided churning verification files when the matrix already matched the summary.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again; manual archival repeated v1.3–v1.6 toil.
- **No `060-*` phase directory** — Phase **60** is harder to grep as execution history; prefer creating doc phases on disk up front.

### Patterns established

- **Document status blocks** on planning-facing audit summaries for time-bounded narrative patches.
- **Companion recipe** as architecture doc, not a new core dependency surface.

### Key lessons

1. Ship **adoption** milestones with the same traceability table discipline as code milestones — even when most work is prose.
2. When **`roadmap.analyze`** returns empty for this roadmap shape, rely on **`REQUIREMENTS.md`** + filesystem checks before close.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Very small product diff; highest leverage was MFA audit atomicity + C-1 honesty.

---

## Milestone: v1.6 — Nyquist closure + OAuth audit depth

**Shipped:** 2026-04-23  
**Phases:** 3 (57–59) | **Plans:** 6 | **Sessions:** n/a (not instrumented)

### What was built

- **NYQ-01 / NYQ-02** — Canonical `.planning/nyquist-phases-41-44-matrix.md` plus `MAINTAINING.md` index; explicit disposition + reopen triggers for historical **41–44** rows; optional **`Phase57NyquistMatrixContractTest`** guard.
- **OA-01** — **`Sigra.OAuthCeremonyAuditTest`** (registration + `authorize_url` audit assertions on Postgres) and **`phase_58_oauth_oa01_ci_contract_test`** to keep `library_tests` honest about OAuth exclude drift.
- **OA-02** — **`docs/uat-ci-coverage.md`** hub for machine vs human OAuth proof; GA-03 / waiver / evidence **INDEX** / **`docs/ga-evidence.md`** / **PROJECT** alignment (Phase 59).

### What worked

- **Narrow verification milestone** closed planning truth gaps without shipping new end-user auth surface area.
- **Dedicated ceremony test module** separated merge-blocking OAuth audit proof from rollback-only atomicity tests.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again (`version required for phases archive`); manual archival duplicated v1.3–v1.5 toil.
- Milestone audit file landed **after** the **`v1.6`** tag (retroactive **`v1.6-MILESTONE-AUDIT.md`**); prefer **`/gsd-audit-milestone`** pre-close next time so the tag and audit commit align.

### Patterns established

- **Two-tier maintainer docs:** short index in `MAINTAINING.md`, canonical matrix under `.planning/`.
- **Grep-first OA-02 maintenance:** subsection titles carry literal module / job names for quick CI↔docs consistency checks.

### Key lessons

1. When **v1.3** explicitly deferred OAuth ceremony audit assertions, schedule a **small follow-on milestone** rather than letting the waiver live forever without machine proof.
2. **Nyquist honesty** is mostly **disposition visibility** — matrices + triggers beat silent `nyquist_compliant: false` rows.

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: High leverage per line changed; mostly tests + maintainer-facing docs.

---

## Milestone: v1.5 — Public release narrative & community readiness

**Shipped:** 2026-04-22  
**Phases:** 4 (53–56) | **Plans:** 5 | **Sessions:** n/a (not instrumented)

### What was built

- **PUB-01** — `mix.exs` Hex description and `package[:links]` aligned with shipped **v1.0–v1.4** and honest optional-dep framing.
- **PUB-02** — `CHANGELOG.md` milestone glossary, roadmap traceability blocks (**v1.2–v1.4**), and compare URLs tied to `@source_url`.
- **DOC-01** / **DOC-02** — README **Production readiness & GA evidence**, **`SECURITY.md`**, **`docs/ga-evidence.md`**, ExDoc extras, and `mix docs --warnings-as-errors` hygiene.
- **MAINT-01** — **First public launch** checklist in **`MAINTAINING.md`** with owners, tag-scoped `.planning` pointers, and optional comms rows aligned with **v1.4** waivers.

### What worked

- **Narrative-only milestone** stayed bounded: no auth surface expansion while still shipping maintainer-critical artifacts.
- **Reuse of v1.4 evidence** as the canonical GA story avoided re-running the full human matrix in-docs.

### What was inefficient

- **`gsd-sdk query milestone.complete`** failed again (`version required for phases archive`); manual archival duplicated v1.3/v1.4 toil.
- **`roadmap.analyze`** still returned an incomplete phase list for this roadmap shape (only phase **56** in one probe).

### Patterns established

- **Tag-scoped GitHub URLs** for `.planning` evidence in README / maintainer docs where ExDoc cannot resolve local paths.
- **Ship vs announce** separation in maintainer checklist — execution of posts stays optional; the artifact is the ordered runbook.

### Key lessons

1. Close **public narrative** milestones with the same traceability table discipline as product milestones — small REQ sets still benefit from explicit phase mapping.
2. When automation regresses, **document the manual close path** in `MILESTONES.md` so the next ship does not wonder whether archival “counts.”

### Cost observations

- Model mix: n/a  
- Sessions: n/a  
- Notable: Very small code footprint; highest value was cross-doc consistency and link hygiene.

---

## Milestone: v1.4 — GA readiness & audit trail completeness

**Shipped:** 2026-04-22  
**Phases:** 12 (41–52) | **Plans:** 38 | **Sessions:** n/a (not instrumented)

### What was built

- **GA-01** backup-code rotation end-to-end in library, generator surfaces, and regression tests.
- **GA matrix** with explicit **Executed / Waived / Blocked** rows, dated evidence, and documented machine substitutes where human rows were waived.
- **AUD-04..AUD-08** inventory and prioritized **`log_safe/3` → `Ecto.Multi`** conversion batches with audit-aware tests; **43/44/45** merge-gated `*-VERIFICATION.md` artifacts and refreshed Phase 9 **C-1** matrices.
- **Nyquist + install golden** policy in `MAINTAINING.md`, **`mix ci.install_golden`**, **`install_golden_contract`**, and CI path coupling so installer receipts stay merge-blocking where intended.
- **Milestone honesty** guardrails: ROADMAP clarifies implementation vs verification phases; contract tests lock narrative drift.

### What worked

- **Gap-closure phases** (46–52) after an early **`gaps_found`** audit prevented “green plans / red matrix” drift at close.
- **Merge gates as documents** (`mix ci.audit_45`, install-golden contract tests) made deferred human rows legible without pretending they were executed.

### What was inefficient

- **`gsd-sdk query milestone.complete`** still failed in-repo; archival remained a manual, error-prone checklist (same theme as v1.3 retro).
- **`roadmap.analyze`** returned an empty phase list for Sigra’s roadmap shape — readiness checks had to be manual.

### Patterns established

- **Implementation vs verification** phase pairs (44 vs 48, 45 vs 49) called out explicitly in ROADMAP prose.
- **GA waiver ↔ CI attestation** cross-links enforced by structural tests, not only narrative docs.

### Key lessons

1. When a milestone audit goes **`gaps_found`**, either re-audit or schedule explicit **gap-closure phases** with the same REQ IDs — do not “hope” drift resolves.
2. **Installer golden** belongs in the same policy frame as library tests when GA rows cite it as substitute evidence.

### Cost observations

- Model mix: n/a
- Sessions: n/a
- Notable: Heavy verification + CI policy work; relatively small net-new product surface.

---

## Milestone: v1.3 — Cleanup & Hardening

**Shipped:** 2026-04-19  
**Phases:** 5 | **Plans:** 11 | **Sessions:** n/a (not instrumented)

### What was built

- Nyquist-style inventory and explicit waivers for historical planning validation debt, plus a cheap structural verifier script.
- SHA-pinned first-party GitHub Actions upgrades with Dependabot triage notes and contributor-facing pin policy.
- Shift-left GA UAT evidence: CI job map, Playwright GA slice, consolidated human-UAT tables under `.planning/`.
- `Sigra.Audit.Assertions`, atomic audited `api.token_create`, and example-app audit smoke for core login + MFA enrollment paths.
- Maintainer-facing `MAINTAINING.md` release guidance, optional isolated Hex publish workflow, and bash planning hygiene superseding broken JSON audit tooling paths.

### What worked

- Treating **999.x** seeds as milestone-scoped work prevented infinite “we’ll fix planning later” drift.
- Automation-first evidence for **SEED-001** reduced reliance on subjective screenshots for merge gates.
- Keeping v1.3 explicitly **non-product** avoided scope creep while still shipping library + CI improvements.

### What was inefficient

- `gsd-sdk query` / `milestone.complete` automation assumed by upstream workflow docs was unavailable here — archival steps were performed manually.
- `STATE.md` velocity metrics for v1.3 were not kept current mid-flight; recovery relied on per-phase `*-VERIFICATION.md`.

### Patterns established

- **Machine-readable UAT maps** (`docs/uat-ci-coverage.md`) as the canonical bridge from SEED rows to CI jobs.
- **Plain-function audit test helpers** with explicit `repo` argument — friendly to Sandbox and ordering-sensitive assertions.

### Key lessons

1. Close planning-debt loops with **inventory + waiver + verifier** rather than silent exceptions.
2. When hybrid audit writes exist, pick **one high-risk API path** for a reference `Ecto.Multi` implementation before boiling the ocean.
3. Deprecate broken maintainer tooling by **superseding docs + bash** instead of leaving stale JSON flags in READMEs.

### Cost observations

- Model mix: n/a
- Sessions: n/a
- Notable: Milestone was mostly planning + CI + tests; highest human cost was evidence consolidation and policy wording.

---

## Cross-Milestone Trends

### Process evolution

| Milestone | Sessions | Phases | Key change |
|-----------|----------|--------|--------------|
| v1.39 | n/a | 9 | Fractal design-system audit (L0–L4) governed by a re-runnable quality-tier ledger + merge-blocking monotonic guard; admin `sg-*` CSS shipped to hosts as `sigra_admin.css`; terminal ratification gate (Phase 192) replaced a separate milestone audit |
| v1.16 | n/a | 1 | **`APIToken.verify/2`** failure **`api.token_verify.failure`** → **`Multi` + `log_multi_safe`** + **`api_token_audit_atomic_test.exs`** (**044–046** **T1**) |
| v1.14 | n/a | 1 | MFA ad-hoc **`log_safe`** closure (**033**/**034**) → **`Multi` + `log_multi_safe`** + **`mfa_audit_atomicity_test.exs`** |
| v1.6 | n/a | 3 | Nyquist 41–44 posture matrix + OA-01 OAuth ceremony audit tests + OA-02 docs alignment |
| v1.5 | n/a | 4 | Public narrative + Hex/changelog/README/MAINTAINING alignment with v1.4 GA evidence |
| v1.4 | n/a | 12 | GA matrix honesty + audit Multi batches + merge-gated verification + install-golden CI coupling |
| v1.3 | n/a | 5 | Shift-left UAT + explicit planning archive at close |

### Cumulative quality

| Milestone | Tests | Coverage | Zero-dep additions |
|-----------|-------|----------|---------------------|
| v1.6 | `Sigra.OAuthCeremonyAuditTest` + planning/CI contract tests | n/a | None |
| v1.5 | Docs compile gates (`mix compile` / `mix docs --warnings-as-errors`) | n/a | None |
| v1.4 | Planning contract tests + `verify-phase36` path fix | n/a | None in this milestone close commit |
| v1.3 | Library + example suites extended via new audit tests / smoke | n/a | Optional workflow snippets only |

### Top lessons (verified across milestones)

1. **Automation-first verification** pays off again (v1.0 Playwright → v1.2 harness → v1.3 GA shift-left).
2. **Explicit waivers beat implicit debt** for planning artifacts (Nyquist inventory pattern).
