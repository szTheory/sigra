# Domain Pitfalls

**Domain:** Adding a v1.2 admin dashboard, impersonation, expanded audit exploration, and automation-first UI verification to an existing Phoenix auth platform with organizations, passkeys, server-side sessions, and audit trails
**Researched:** 2026-04-16
**Confidence:** HIGH for security/control pitfalls, MEDIUM for mobile/admin UX pitfalls

## Critical Pitfalls

### Pitfall 1: UI-only admin checks create privilege bypasses
**What goes wrong:** The LiveView hides admin routes and buttons, but contexts, controllers, LiveActions, CSV exports, or JSON endpoints still trust caller input. A non-admin or wrong-scope admin can hit the path directly.
**Why it happens:** Teams bolt on an admin UI after shipping user auth and forget that a new surface needs a new authorization boundary on every request, not just a new menu item.
**Consequences:** User enumeration, org-crossing reads, destructive actions by the wrong operator, and a false sense that "the admin area is protected."
**Prevention:**
- Introduce a distinct admin authorization layer for every entry point: router pipelines, mount hooks, controller actions, LiveView events, exports, and background jobs.
- Treat platform-admin and org-admin as separate scopes with different query helpers; do not branch on raw params inside views.
- Build an authorization matrix for admin features and run it in integration tests, including org-admin vs platform-admin vs impersonating-admin cases.
**Detection:** Requests that never call a shared `ensure_admin/ensure_org_admin` primitive; actions reachable by URL copy/paste; tests that only assert "button not visible."
**Phases that should neutralize it:** admin auth foundation, admin routes/controllers/LiveView mount, authorization-matrix verification.

### Pitfall 2: Impersonation reuses the admin's normal session instead of a distinct impersonation session
**What goes wrong:** The system mutates the current session in place, or only flips a flag in assigns, instead of issuing a separate impersonation-scoped session with its own timeout and identifiers.
**Why it happens:** Reusing the existing server-side session feels simpler than modeling impersonation as a first-class session state.
**Consequences:** Session fixation-like confusion, weak timeout enforcement, broken "end impersonation" semantics, bad audit attribution, and accidental persistence across tabs/devices.
**Prevention:**
- Create a new server-side session row for impersonation with `actor_admin_id`, `effective_user_id`, start/end timestamps, and stricter idle/absolute timeouts.
- Rotate browser session identifiers on impersonation start and end.
- Make impersonation non-nestable and impossible to upgrade into broader privileges.
- Expose impersonation state from session-backed scope only, never from LiveView assigns alone.
**Detection:** No new session row on impersonation start; ending impersonation just clears an assign; same session token before and after impersonation.
**Phases that should neutralize it:** impersonation session model, session rotation/timeout work, audit wiring.

### Pitfall 3: Dual-actor audit trail is incomplete or inconsistent
**What goes wrong:** Some actions log only the effective user, others only the real admin, and async jobs or exports lose impersonation context entirely.
**Why it happens:** Existing audit code was written for single-actor flows; teams patch a few hot paths and miss background work, redirects, or bulk operations.
**Consequences:** Compliance failure, unusable investigations, inability to answer "who actually did this," and dangerous ambiguity during support incidents.
**Prevention:**
- Standardize audit fields for `actor_admin_id`, `effective_user_id`, `organization_id`, `impersonation_session_id`, request metadata, and action outcome.
- Route every admin and impersonated mutation through one audit helper that derives actor/effective fields from scope.
- For async work, serialize the actor/effective context explicitly into job args and rebuild minimal scope there.
- Add tests that compare the same action in normal, admin, and impersonated contexts.
**Detection:** Audit rows with only one actor field during impersonation; bulk actions writing one parent event but no per-target detail; exports/jobs missing actor metadata.
**Phases that should neutralize it:** audit schema extension, admin action service layer, worker instrumentation, audit-explorer verification.

### Pitfall 4: "Forbidden during impersonation" is enforced in the UI, not in the domain layer
**What goes wrong:** Password reset, MFA changes, API key management, passkey enrollment/revocation, or account deletion buttons disappear in the UI, but the underlying action remains callable.
**Why it happens:** Teams think the banner and hidden controls are the control. They forget direct POSTs, LiveView events, stale browser tabs, and future surfaces.
**Consequences:** An admin can silently perform sensitive identity-changing actions while impersonating, defeating the whole guardrail model.
**Prevention:**
- Put impersonation-sensitive action checks in contexts/services, not only components.
- Maintain an explicit denylist of operations unavailable while impersonating.
- Test each forbidden operation through HTTP/controller and LiveView event paths.
**Detection:** Feature works when called from curl or an old open tab; no service-level `forbid_if_impersonating` checks; forbidden-state tests cover only rendered HTML.
**Phases that should neutralize it:** impersonation policy layer, dangerous-action hardening, controller/LiveView parity tests.

### Pitfall 5: Admin queries bypass organization scoping or leak cross-org data in "support" views
**What goes wrong:** A platform admin query path gets reused by org admins, or filters/search/autocomplete/session lists aggregate outside the active org.
**Why it happens:** The admin surface mixes global and org-scoped jobs in one UI, and teams optimize for convenience over explicit scoping contracts.
**Consequences:** Cross-tenant leakage, wrong counts, wrong exports, and escalation from org-admin to pseudo-platform-admin behavior.
**Prevention:**
- Separate platform-admin and org-admin query APIs; do not gate a shared unscoped query with a late `if`.
- Require explicit scope objects for all admin reads and writes, including exports and search suggestions.
- Test list, detail, counts, filters, CSV export, and "recent activity" with multiple org fixtures.
**Detection:** Shared `list_users(params)` used by both admin roles; CSV/export code reaching for raw `Repo`; tests cover rows but not counts or exports.
**Phases that should neutralize it:** admin query architecture, org-aware user management, export/audit search verification.

### Pitfall 6: Bulk admin actions partially succeed without precise user feedback or audit detail
**What goes wrong:** Lock/unlock, revoke sessions, require password reset, or delete operations succeed for some users and fail for others, but the UI shows one generic flash and the audit log cannot reconstruct target-level outcomes.
**Why it happens:** Bulk flows are added late for convenience and reuse single-record code without transactional design.
**Consequences:** Operators do not know what actually changed, retries create duplicate work, and audit review cannot explain inconsistencies.
**Prevention:**
- Design bulk actions as explicit batch jobs or transactionally chunked operations with per-target results.
- Return structured success/failure counts and item-level reasons.
- Audit both the batch command and each target outcome.
- Add tests for mixed-result batches and idempotent retries.
**Detection:** One flash message for N targets; no per-record audit rows; rerunning a failed batch changes successful rows again.
**Phases that should neutralize it:** admin actions service layer, batch UX, audit detail verification.

## Moderate Pitfalls

### Pitfall 7: Admin search and audit filters look rich but are operationally useless
**What goes wrong:** The dashboard ships many filters, but they are slow, non-composable, missing actor/effective-user dimensions, or impossible to share/export for investigations.
**Why it happens:** Teams design the UI before deciding what incident responders and support staff actually need to answer.
**Prevention:**
- Prioritize investigation workflows: actor, effective user, org, event type, time range, outcome, impersonation-only, and target resource.
- Use stable URL/query-param state so filtered views can be shared and replayed.
- Index fields used by exploration; do not bury key dimensions in JSON only.
- Test realistic investigations, not just "filter renders."
**Detection:** Filters reset on navigation; no way to distinguish actor vs target user; audit explorer times out on common queries.
**Phases that should neutralize it:** audit explorer design, audit indexing/schema work, investigation workflow verification.

### Pitfall 8: Existing non-atomic audit writes become more dangerous under admin and impersonation flows
**What goes wrong:** A privileged action succeeds but its audit row fails, or an audit row is written before the mutation fails.
**Why it happens:** The system already carries `log_safe/3` caveats from v1.1, and v1.2 introduces higher-value actions where missing audit evidence hurts more.
**Consequences:** Unreliable forensics on the most sensitive admin actions, especially impersonation start/stop, forced logout, role changes, and danger-zone operations.
**Prevention:**
- Convert high-risk admin and impersonation flows to atomic `Ecto.Multi` writes even if full-system conversion remains deferred.
- Treat impersonation start/end and sensitive admin mutations as "must be atomic" phase requirements.
- Add failure-injection tests around audit persistence.
**Detection:** Sensitive actions still route through best-effort logging; there is no test where audit insert failure aborts the mutation.
**Phases that should neutralize it:** audit hardening, impersonation launch path, danger-zone actions.

### Pitfall 9: Mobile admin UX is "responsive" but not operable
**What goes wrong:** The dashboard technically fits on a phone, but key jobs require horizontal scrolling, banner state obscures actions, tables collapse into unreadable cards, confirm dialogs cover critical context, or filter controls become impossible to use one-handed.
**Why it happens:** Teams validate at desktop first and treat mobile as CSS cleanup rather than task design.
**Prevention:**
- Define the top mobile jobs first: search a user, inspect security state, revoke sessions, end impersonation, review recent audit events.
- Keep impersonation state and primary actions visible without burying content under persistent banners.
- Use task-specific mobile layouts, not generic squashed tables.
- Add device-emulated browser tests with screenshots for small viewports and dark mode.
**Detection:** Mobile tests only assert "page loads"; screenshots show clipped controls or hidden action bars; support tasks require more than 2-3 viewport jumps.
**Phases that should neutralize it:** admin UI design contract, mobile workflow implementation, Playwright screenshot review.

### Pitfall 10: Light/dark mode and branding hooks create unreadable or misleading admin states
**What goes wrong:** Warning banners, lockout badges, impersonation state, or destructive buttons lose contrast or semantic distinction once branding colors and dark mode are applied.
**Why it happens:** Teams add theming late and do not verify security-significant states across variants.
**Prevention:**
- Reserve non-overridable tokens for critical states like impersonation, destructive actions, and security warnings.
- Test light mode, dark mode, and a branded palette in screenshots.
- Keep critical state semantics in text and iconography, not color alone.
**Detection:** The impersonation banner blends into normal chrome; destructive states fail contrast; screenshot review covers only default theme.
**Phases that should neutralize it:** branding/theming hooks, visual verification artifacts, accessibility checks.

### Pitfall 11: Stale LiveView state makes admin decisions against old data
**What goes wrong:** An operator views a user record, another admin changes it, and the first operator acts on stale sessions, org role, lockout, or impersonation eligibility.
**Why it happens:** LiveView makes it easy to keep server state in assigns without explicit concurrency strategy.
**Consequences:** Wrong-user assumptions, conflicting actions, confusing errors, and subtle policy bypasses when checks are only made at mount time.
**Prevention:**
- Re-check sensitive state at action time in contexts, not just on page load.
- Use optimistic locking or explicit stale-data handling for editable resources.
- Surface "record changed" feedback and refresh affordances on critical tabs.
**Detection:** Context calls trust assign-cached state; no tests for concurrent admin changes; LiveView actions succeed after role/session state changed elsewhere.
**Phases that should neutralize it:** detail-view architecture, context hardening, concurrency verification.

### Pitfall 12: Audit export and admin export leak more than the on-screen UI
**What goes wrong:** CSV exports include hidden columns, raw metadata, IP/session identifiers, deleted-user data, or records outside the visible filter scope.
**Why it happens:** Export paths are often separate codepaths built for convenience and reviewed less than the main UI.
**Prevention:**
- Make exports consume the same scoped query object as the screen.
- Define an explicit export schema; do not dump arbitrary metadata blobs.
- Redact or omit secrets, tokens, session IDs, and security-sensitive internals.
- Test export contents and scope boundaries, not only file generation.
**Detection:** Export code selects `*`; tests only check "CSV downloads"; exported row counts differ from screen counts.
**Phases that should neutralize it:** export implementation, data redaction review, export parity tests.

## Minor Pitfalls

### Pitfall 13: "Send magic link / reset on behalf of user" creates support-side confusion or accidental account takeover optics
**What goes wrong:** Admin-triggered assistance flows are indistinguishable from user-initiated flows, or they surprise users without clear copy and audit trace.
**Prevention:** Label admin-initiated messages clearly, audit them as admin actions, and require sudo for high-risk support actions.

### Pitfall 14: Admin dashboard becomes a second product with weak extension boundaries
**What goes wrong:** Teams add ad hoc callbacks, custom columns, and brand overrides directly into core flows until the default-on admin surface is hard to maintain.
**Prevention:** Keep extension points narrow and documented: extra columns, additional detail sections, branding config. Do not let host apps rewrite security-critical behavior.

### Pitfall 15: Human-only review artifacts drift from the real release path
**What goes wrong:** Screenshots and videos are captured manually from a local happy path, while CI smoke coverage exercises different seeds, routes, or privileges.
**Prevention:** Generate review artifacts from the same scripted Playwright/system test flows used in CI.

## Verification Blind Spots

### Blind Spot 1: Over-reliance on manual UAT for authorization and impersonation rules
**What goes wrong:** Reviewers click around the UI and conclude the feature is safe because the visible flows work.
**Prevention:** Encode an authorization matrix covering admin role, org scope, impersonation state, and forbidden actions. Run it in automated request/system tests.

### Blind Spot 2: Only testing the browser happy path
**What goes wrong:** LiveView flows pass, but direct HTTP requests, curl smoke, stale CSRF tokens, and old open tabs bypass assumptions.
**Prevention:** Add route/controller smoke, direct POST tests, and stale-session/stale-tab coverage for admin and impersonation actions.

### Blind Spot 3: No artifact review for mobile, dark mode, and impersonation-banner states
**What goes wrong:** Teams collect desktop screenshots only and miss clipped banners, hidden buttons, and unreadable critical states.
**Prevention:** Require screenshots for at least one narrow mobile viewport, one desktop viewport, dark mode, and impersonation-active layouts.

### Blind Spot 4: Treating Playwright traces/videos as enough without semantic assertions
**What goes wrong:** A video exists, but nobody asserted the right audit row, timeout behavior, or role restriction.
**Prevention:** Pair visual artifacts with deterministic assertions on DB/audit/session state. Artifacts are evidence, not the test oracle.

### Blind Spot 5: Not testing failure paths with real data volume
**What goes wrong:** Search, filters, audit pagination, and bulk actions pass on tiny fixtures but break or time out on realistic admin datasets.
**Prevention:** Add seeded medium-size fixtures for admin/audit tests and benchmark the common exploration queries.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Admin auth foundation | UI-only admin gating | Shared authorization primitives plus automation matrix |
| Admin user list/detail | Cross-org query leakage | Separate org-admin/platform-admin query APIs and multi-org integration tests |
| Impersonation session model | Reusing normal session | New session record, token rotation, stricter timeouts |
| Impersonation UX | Hidden or ignorable impersonation state | Non-dismissable layout banner with tested mobile behavior |
| Dangerous admin actions | UI-only restrictions during impersonation | Context-level denylist and direct-request tests |
| Audit schema and explorer | Missing dual-actor data, weak indexes | Real columns for actor/effective/org/session and investigation-driven indexes |
| Export flows | Export scope differs from on-screen scope | Shared query builder plus content-parity tests |
| Mobile/admin UX | Responsive but not operable | Task-driven phone layouts and screenshot review gates |
| Visual verification artifacts | Manual screenshots diverge from CI | Generate artifacts from automated Playwright flows |
| Verification harness | Browser-only confidence | Add HTTP/curl smoke, authorization matrix, failure-path fixtures |
| Sensitive audit writes | Existing `log_safe/3` gaps stay untouched | Make high-risk v1.2 flows atomic before release |

## Sources

- OWASP Authorization Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html
- OWASP Authorization Testing Automation Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Testing_Automation_Cheat_Sheet.html
- OWASP Logging Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
- OWASP Session Management Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
- NIST SP 800-63B (current public draft site): https://pages.nist.gov/800-63-4/sp800-63b.html
- Playwright docs: traces, screenshots, visual comparisons, emulation, accessibility: https://playwright.dev/docs/trace-viewer , https://playwright.dev/docs/test-snapshots , https://playwright.dev/docs/emulation , https://playwright.dev/docs/accessibility-testing
- GitHub Enterprise audit log docs (useful prior art for actor/action/filter/export expectations): https://docs.github.com/enterprise-cloud@latest/admin/monitoring-activity-in-your-enterprise/exploring-your-enterprise-audit-log
- Material Design data tables guidance: https://m3.material.io/components/data-tables/overview
- Internal project context: `/Users/jon/projects/sigra/.planning/PROJECT.md`, `/Users/jon/projects/sigra/.planning/v1.2-DIRECTION.md`
