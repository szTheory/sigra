# Phase 33: Admin Shell Navigation and Audit Preview Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 33-admin-shell-navigation-and-audit-preview-polish
**Areas discussed:** INT-05 seam, INT-05 field surface, INT-04 regression guard

Research method: three parallel subagent investigations (Phoenix/Elixir
ecosystem conventions, admin-tool precedent from Stripe/Clerk/Okta/GitHub/
Django, generator-library test pyramid from phx.gen.auth/Ash/Igniter/Rails),
results synthesized into coherent recommendation set before decision.

---

## INT-05 seam — where Presenter.present/2 is called

| Option | Description | Selected |
|--------|-------------|----------|
| Detail.recent_audit_preview/3 presents | Function returns [map()] with Presenter-shaped rows. Mirrors Sigra.Admin.Audit.Explorer load+present ownership. Planner greps callers before flipping contract; if external caller found, fall back to new helper. | ✓ |
| UserShowLive.mount presents | Detail keeps [struct()] return. LiveView loads raw events + calls Presenter.present/2 itself. Matches Phoenix-community "contexts return raw structs" precedent but diverges from Explorer pattern inside Sigra. | |
| Add Detail.recent_audit_preview_presented/3 | Keep existing fn; add a new one returning [map()]. Non-breaking, but two lookalike fns become a wrong-one-chosen footgun. | |

**User's choice:** Detail.recent_audit_preview/3 presents (Recommended)
**Notes:** Research found 75% confidence. Upholds "audit rows are always
Presenter-shaped before leaving the Sigra admin layer" — an invariant
violated in the current preview. Falls back to the helper option (C) only if
the planner's caller grep finds an external caller outside `Detail.load!/3`
and its tests.

---

## INT-05 field surface — which Presenter fields render in the compact preview

| Option | Description | Selected |
|--------|-------------|----------|
| badge + action_label + actor_summary + time | Matches Stripe/Clerk/Okta/GitHub/Django "recent activity" convention. Preserves Phase 28 D-24 preview intent + Phase 29 D-02/D-11 impersonation visibility. Subset of Presenter output — never adds fields the explorer lacks. | ✓ |
| Full explorer parity | 1:1 with /admin/audit table (badge + action_label + raw action + Actor/Effective labels + outcome). Cramped on mobile, weakens "preview" info scent — operators may not click through to full explorer. | |
| Ultra-minimal | Drops actor_summary (badge + action_label + time only). Lightest density but loses impersonation actor context that Phase 29 D-02/D-11 said must stay visible. | |

**User's choice:** badge + action_label + actor_summary + time (Recommended)
**Notes:** Research found high confidence. Every admin tool that ships the
"detail preview + full explorer" pair reduces the preview's field set
relative to the explorer, and keeps a visible signal when actor ≠ subject
(impersonation). Existing Presenter copy strings stay verbatim; no new copy
introduced.

---

## INT-04 guard — regression protection for the admin-shell Users nav

| Option | Description | Selected |
|--------|-------------|----------|
| Fixture pair in installer_drift_test.exs | ~25 LOC. Asserts users_link/1 helper defined both sides, desktop sidebar uses <a href={users_link(...)}>, mobile bottom-nav has btm-nav-label Users, and dead <li><span>Users</span></li> is forbidden. Matches Phase 32 "fix + guard" precedent. | ✓ |
| Render-EEx-template component test | Build harness to compile the generator template (requires web_module binding, ~p sigil resolution, verified-routes stub). Higher fidelity but duplicates Phase 35's generator_emission_audit_test.exs infrastructure. | |
| Both fixture pair and render test | Defense-in-depth. Render test overlaps heavily with Phase 35 scope — roughly 3 hrs now and again later. | |
| Defer entirely to Phase 35's generalized dead-text detector | 0 LOC now. Phase 35 is not yet scaffolded and axe-core baselines alone cannot detect dead-<span> nav (WCAG SC 1.3.1 structural assertion needed). Risk: another Phase-33-class drift slips in before Phase 35 lands. | |

**User's choice:** Fixture pair in installer_drift_test.exs (Recommended)
**Notes:** Research found 90% confidence. Phase 32 set the "fix + guard"
precedent; skipping it here would contradict the milestone's own discipline.
axe-core cannot detect dead-`<span>` nav on its own — structural assertion
needed. Render-harness work belongs to Phase 35's
`generator_emission_audit_test.exs`; shipping it in Phase 33 would duplicate
Phase 35's scope and increase blast radius of a surgical phase.

---

## Post-discussion gray-area check

| Option | Description | Selected |
|--------|-------------|----------|
| Ready for context | Phase 33 is surgical; the three locked decisions are the load-bearing ones. Planner + UI-checker will handle port fidelity, LiveView copy tweaks, and any minor shell-test assertion updates without additional user input. | ✓ |
| Port strategy for admin_shell.ex | Discuss verbatim copy-paste vs. targeted diff (example has 'Operations' before 'Overview'; template has 'Overview' before 'Operations'). | |
| Host-app upgrade path for the return-type flip | Discuss whether Detail.recent_audit_preview/3's contract change needs a CHANGELOG entry, deprecation note, or upgrade guide hook. | |
| Something else | User to describe. | |

**User's choice:** Ready for context (Recommended)
**Notes:** The two follow-up threads (port ordering + CHANGELOG) were
pre-resolved in CONTEXT.md D-11 (example ordering wins) and in the deferred
list (CHANGELOG entry conditional on the planner's grep finding an external
caller).

---

## Claude's Discretion

- Exact phrasing of the updated `@spec`/`@doc` on `Detail.recent_audit_preview/3`.
- Whether to extract a `format_preview_row/1` helper or inline the subset
  render in `UserShowLive`.
- Exact `:id` string for the new `installer_drift_test.exs` fixture entry.
- Whether `ExampleWeb.AdminShellTest` gains an extra `href={users_link(...)}`
  assertion — trivial, planner decides.

## Deferred Ideas

- Generalized dead-text-as-nav detector (WCAG SC 1.3.1 class). → Phase 35.
- EEx template render harness. → Phase 35.
- axe-core + visual regression baselines. → Phase 35.
- `admin-generated.spec.ts` coverage for `/admin/users`. → Phase 34.
- `admin-acceptance-smoke.sh` audit-export + impersonation-controller cases.
  → Phase 34.
- Retroactive `28-VERIFICATION.md`. → Phase 34.
- Unifying `audit_link/1` string path with the `~p` sigil — minor hygiene,
  separate phase.
- Refactoring `users_active?/1` from the always-true stub to a path-aware
  predicate — separate phase, not a shipped defect.
