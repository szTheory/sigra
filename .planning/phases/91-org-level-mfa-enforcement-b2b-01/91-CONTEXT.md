# Phase 91: Org-level MFA enforcement (B2B-01) — Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>

## Phase Boundary

B2B customers can require MFA for every member of an organization with a single admin toggle, with non-MFA-enrolled members blocked at the request boundary until enrollment. The policy change is recorded as a single atomic audit row co-fated with the schema write under `Repo.transaction/1` + `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`. After this phase, an org admin's "all members must MFA" policy is enforced consistently across HTTP and LiveView surfaces inside `:org_scoped` without host code changes.

**Explicitly out of scope:**
- RBAC seam work (role field on `OrganizationMembership`, `Sigra.Authz` behaviour) — Phase 92.
- Service-account / M2M token actor exemption mechanics — Phase 93 (this phase ships YAGNI; Phase 93 modifies `Sigra.Plug.RequireOrgMfa` to short-circuit on `scope.actor_type == :service_account` when it adds that field).
- Grace-period enforcement (e.g., 7-day grace before policy bites). ROADMAP locks "blocked at the request boundary until enrollment" = hard cutover.
- Email notifications to unenrolled members on policy change.
- Per-route opt-in pipelines (`:org_scoped_mfa`). Generator-emitted enforcement is one pipeline (`:org_scoped`) for "no host code edit needed to opt in" per ROADMAP success criterion #3.
- GitHub-style member ejection on enforcement (success criterion #2 specifies redirect-to-enroll, not removal from org).

</domain>

<decisions>

## Implementation Decisions

### Pipeline Integration

- **D-91-01 — Plug placement: inside `:org_scoped`, after `RequireMembership`.** `Sigra.Plug.RequireOrgMfa` runs in the existing generator-emitted `:org_scoped` pipeline, ordered after `LoadOrganizationFromSlug` and `RequireMembership`. Only routes namespaced under `/organizations/:org/*` are enforced. Account-level routes (`/users/settings`, `/users/settings/mfa`, logout, `/organizations/switch`, `/organizations`, `/organizations/new`, `/invitations/:token/accept` in `:invitations_public`) remain reachable by construction — this provides the natural hard-wall + carve-out structure without an explicit allowlist. Matches ROADMAP success criterion #3 ("no host code edit needed to opt in").

- **D-91-02 — Halt mode: delegate to `error_handler.auth_error/2`.** Mirrors `Sigra.Plug.RequireMembership`. Plug calls `error_handler.auth_error(:mfa_required, opts)` (or `:org_mfa_required` — planner discretion on atom name) and halts. Host's `AuthErrorHandler` template owns the redirect / JSON response shape. Adds one new error reason atom to the generated `AuthErrorHandler` template. Rejected: hardcoded `Phoenix.Controller.redirect` (matches `RequireMFAEnrolled` but diverges from v1.1+ org plug family).

- **D-91-03 — LiveView coverage: HTTP plug + on_mount pair.** Add `Sigra.LiveView.RequireOrgMfa` on_mount alongside the plug, attached to `live_session :organization_scoped`. Mirrors the existing `Sigra.Plug.RequireMembership` ↔ `Sigra.LiveView.OrganizationScope` pairing. on_mount returns `{:halt, redirect(socket, to: enrollment_path)}` on enforcement-required-but-user-not-enrolled. Catches mid-session policy flips on next `live_redirect` inside the live_session. Rejected: HTTP-plug-only (leaves a gap on already-mounted LVs); PubSub-broadcast-disconnect (overkill for v1.21).

- **D-91-04 — Sibling plug, not a generalization.** `Sigra.Plug.RequireOrgMfa` is a new module. The existing `Sigra.Plug.RequireMFAEnrolled` (host-`mfa_check_fn`-driven, used for "any user must MFA on this route" e.g. admin) stays unchanged. Different responsibilities, different opt surfaces, different scopes (`scope.user` vs `scope.active_organization`). Document the distinction in moduledocs + a recipe. Rejected: composing one on top of the other (couples them); generalizing into `Sigra.Plug.RequireMfa` with `mode:` opt (deprecation cycle, API churn).

- **D-91-05 — Column shape: boolean.** `enforce_mfa_for_members :boolean, null: false, default: false`. Minimal-schema DX (PROJECT.md). Future actor-type carve-outs (Phase 93 service accounts) are handled at the plug layer via `scope.actor_type` discriminator, not at the column. Rejected: 3-state enum atom now (pre-decides Phase 93 design); boolean + nullable jsonb policy column (premature flexibility).

- **D-91-06 — Plug option surface: minimal.** Required `:error_handler` (validated via NimbleOptions). Optional `:enrollment_path` (default `/users/settings`) passed to `error_handler.auth_error/2`. No `:grace_period` (out of scope). No `:exempt_paths` (`:org_scoped` placement provides natural carve-outs; would couple plug to Phoenix routing surface). NimbleOptions schema mirrors `Sigra.Plug.RequireMembership`'s pattern.

### Allowlist Exemption

- **D-91-07 — Service-account exemption: YAGNI.** Phase 91 plug enforces for any authenticated session reaching `:org_scoped`. Phase 93 will modify `Sigra.Plug.RequireOrgMfa` to short-circuit on `scope.actor_type == :service_account` when it adds that field. Document the interaction here; do not add speculative API surface in Phase 91. Rejected: defensive `Map.get(scope, :actor_type)` hook now (YAGNI smell, no scope.actor_type field exists yet); blocking Phase 91 on adding `:actor_type` to scope (scope creep into Phase 92/93 territory).

- **D-91-08 — Post-enrollment return flow: server-side `return_to` in session, fallback to org dashboard.** Plug stores blocked org-route path in session under `:org_mfa_return_to`; enrollment-success controller restores it. Path validation: must start with `/`, reject `//` (open-redirect prevention per OAuth RFC 6749 §10.15 / Phoenix `phx.gen.auth` precedent). Fallback if missing/invalid: `/organizations/:org` (current org dashboard). Rejected: always-org-dashboard (loses deep-link UX); always-/users/settings (worst UX, every blocked trip ends with manual re-navigation).

### Admin Self-Lockout

- **D-91-09 — Hard pre-flight refuse if admin not MFA-enrolled.** `Sigra.Organizations.set_mfa_policy(scope, org, true)` returns `{:error, :admin_must_enroll_first}` when `Sigra.MFA.enabled?(config, scope.user)` is false. LiveView surfaces inline copy: "Enable MFA on your account first — you'll be locked out otherwise" and disables the toggle in UI until admin's own MFA is on. Matches GitHub / GitLab / Auth0 / Okta industry pattern. Rejected: warn-and-confirm modal (atypical for B2B IdP UX, doesn't prevent foot-gun); allow + recover (jarring "I clicked save and got kicked off" UX).

- **D-91-10 — Inline impact preview before enabling.** OrganizationSettingsLive shows a count: "N of M members are not MFA-enrolled. They'll be redirected to enroll on their next request to this org." Adds one COUNT query in the LV mount/update. Improves admin's decision quality. Rejected: simple toggle no preview (hides blast radius); impact preview + opt-in email (scope creep — new email template + Oban worker + integration tests for v1.21).

- **D-91-11 — Light confirmation friction, both directions.** New "Security" section in OrganizationSettingsLive between General and Danger Zone. Toggle is a checkbox; saving (enable OR disable) shows an inline confirm form (`phx-click="confirm_mfa_policy"` revealing impact preview + Save / Cancel). NO sudo password. NO typed-confirm. Audit row is the compliance signal. Rejected: medium-friction sudo-on-enable / confirm-on-disable (asymmetric, foot-gun is recoverable in one click); heavy sudo + typed-confirm (Danger-Zone treatment overkill for a recoverable setting).

### Audit Shape + Idempotency

- **D-91-12 — Action name: `organization.mfa_policy_change` (canonicalized).** ROADMAP success criterion #1 wording (`organization.mfa_policy_changed`, past tense) is one-line edited to `organization.mfa_policy_change` to match codebase precedent (`organization.{create,update,rename,delete,slug_change,member_role_change,member_add,member_remove}` — all present-tense). Planner edits ROADMAP.md success criterion #1 as part of phase commit. Operator-facing audit query stays consistent across all org actions.

- **D-91-13 — Metadata payload: `%{old_value, new_value}`.** Concrete: `%{old_value: false, new_value: true}` (or reversed). `actor_id` already populated by `Sigra.Organizations.append_audit/5` helper from `scope.user.id` — not duplicated in metadata. Matches codebase precedent (`organization.rename` → `%{old_name, new_name}`, `organization.slug_change` → `%{old_slug, new_slug, alias_expires_at}`, `organization.member_role_change` → `%{old_role, new_role, user_id}`). Rejected: `affected_member_count` snapshot (extra COUNT query in txn, stale by next request); `org_name`/`org_slug` snapshot (most queries already join on organization_id).

- **D-91-14 — Idempotency: skip Multi entirely on no-op.** `Sigra.Organizations.set_mfa_policy/3` checks `changeset.changes` — if empty, short-circuits and returns `{:ok, org}` without running the Multi or writing an audit row. Idiomatic Ecto (matches `Repo.update` no-op behavior). SOC 2 / ISO 27001 require recording state changes, not button clicks. Rejected: always-write `%{no_op: true}` audit row (pollutes table, atypical for codebase); `{:error, :no_change}` return (breaks Ecto idiom).

### Atomicity (Locked Precedent — Not a Discussion Outcome)

- **D-91-15 — Atomic audit pattern (locked from Phases 73, 77, 79, 80, 81, 82, 85).** `Sigra.Organizations.set_mfa_policy/3` follows the established pattern:
  ```elixir
  Multi.new()
  |> Multi.update(:organization, mfa_policy_changeset(org, value))
  |> append_audit(config, "organization.mfa_policy_change", scope,
       metadata: %{old_value: old, new_value: new})
  |> config.repo.transaction()
  |> normalize_multi_result()
  ```
  `append_audit/5` already delegates to `Sigra.Audit.log_multi_safe/3`. Co-fated rollback: under fault injection (CHECK-guard on audit_events insert), no orphan org write. Public contract on co-fated path: `{:ok, org}` only if both rows commit; failure → `{:error, :mfa_policy_aborted}` (per D-AUD-08 stable error atom). Mirrors Phase 82 D-82-02 / Phase 85 D-85-02.

### Claude's Discretion

- Exact NimbleOptions schema field names for plug options.
- AuthErrorHandler reason atom: `:mfa_required` vs `:org_mfa_required` (mild preference for `:org_mfa_required` for specificity, but `:mfa_required` is shorter).
- Exact LiveView form ergonomics for the "Security" section (progressive disclosure shape, copy wording).
- Exact wording of inline impact-preview copy and admin-must-enroll-first error message.
- Whether `Repo.transact/2` (Ecto 3.13) replaces `Repo.transaction/1` for the new path only.
- Stable error atom name: `:mfa_policy_aborted` vs `:enforce_mfa_aborted` vs `:org_mfa_policy_aborted`.
- Exact session key for `return_to` (`:org_mfa_return_to` vs `:user_return_to` reused).
- Test file naming conventions:
  - Plug unit: `test/sigra/plug/require_org_mfa_test.exs`
  - LiveView mount unit: `test/sigra/live_view/require_org_mfa_test.exs`
  - Atomicity: `test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` (mirroring `test/sigra/jwt_refresh_audit_cofate_test.exs` shape per Phase 82 / 85 precedent)
  - Generator-host integration: `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` (per ROADMAP success criterion #4)

### Folded Todos

_None — `gsd-sdk query todo.match-phase 91` returned 0 matches._

</decisions>

<canonical_refs>

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **B2B-01** (the requirement this phase satisfies)
- `.planning/ROADMAP.md` — Phase 91 goal + 5 success criteria (`### Phase 91: Org-level MFA enforcement (B2B-01)`). **Note D-91-12: success criterion #1 wording requires a one-line edit from `organization.mfa_policy_changed` → `organization.mfa_policy_change` during phase commit.**
- `.planning/PROJECT.md` — v1.21 framing (B2B trust leg) + minimal-schema DX value + Phoenix 1.8+ / PostgreSQL primary constraints
- `.planning/STATE.md` — v1.21 leg-1 framing (Phase 91 = first B2B trust phase)

### Atomic-audit precedent (locked behaviour contract)

- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — `D-AUD-01` (orchestrator owns txn), `D-AUD-06` (audit-only `:ok` semantics), `D-AUD-08` (co-fated paths roll back with stable error atom)
- `.planning/phases/85-oauth-audit-atomicity-closure-aud-21/85-CONTEXT.md` — `D-85-02` orchestrator pattern + `D-85-04` D-AUD-06 sharpening
- `.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-CONTEXT.md` — `D-82-01` orchestrator pattern, `D-82-02` public contract on co-fated paths, `D-82-04` test shape
- `.planning/phases/81-jwt-refresh-audit-atomicity/81-CONTEXT.md` — `D-81-04` planning-truth surgical-update pattern
- `.planning/phases/09-audit-logging/09-CONTEXT.md` — `D-01` universal-atomic-Multi original intent

### Code (integration points — read these)

- `lib/sigra/organizations.ex` — `update_organization/4` (line 435), `rename_organization/4` (line 517), `update_slug/4` (line 568), `soft_delete_organization/4` (line 472), private `append_audit/5` helper. **The `set_mfa_policy/3` function follows these orchestrator shapes.**
- `lib/sigra/audit.ex` — `log_safe/3`, `log_multi_safe/3`, `__log_internal__/3`
- `lib/sigra/plug/require_membership.ex` (148 lines) — **structural twin** for `Sigra.Plug.RequireOrgMfa`: error_handler delegation, NimbleOptions-style opt validation, scope-only reads, halt shape
- `lib/sigra/plug/require_mfa_enrolled.ex` (54 lines) — sibling plug; do NOT modify (D-91-04). Reference for moduledoc disambiguation copy.
- `lib/sigra/plug/load_active_organization.ex` — populates `scope.active_organization` and `scope.membership` (the data the new plug reads)
- `lib/sigra/live_view/organization_scope.ex` — **structural twin** for `Sigra.LiveView.RequireOrgMfa` on_mount: scope hydration, halt-via-redirect pattern
- `lib/sigra/mfa.ex:932` — `Sigra.MFA.enabled?(config, user)` is the canonical "is this user MFA-enrolled" API used by the plug, on_mount, and pre-flight admin check

### Generator templates (where new code lands)

- `priv/templates/sigra.install/organizations/migration.exs` — extend with `enforce_mfa_for_members` column (additive `alter table` migration recommended for new install — verify with planner)
- `priv/templates/sigra.upgrade/alter_add_personal.exs` — **structural twin** for the v1.21 upgrade migration adding `enforce_mfa_for_members` to existing organizations tables (idempotent `add_if_not_exists` pattern)
- `priv/templates/sigra.install/organizations/organization.ex` — extend Organization schema with `enforce_mfa_for_members` field (NOT exposed via `cast/3` in changeset/2; library writes it via `set_mfa_policy_changeset/2`)
- `priv/templates/sigra.install/organizations/router_injection.ex` — extend `:org_scoped` pipeline with `Sigra.Plug.RequireOrgMfa`; verify the new plug runs after `RequireMembership`
- `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` — add "Security" section with toggle, impact preview, confirm form
- `priv/templates/sigra.install/core/error_handler.ex` — add `:mfa_required` (or `:org_mfa_required`) clause to `auth_error/2`
- `priv/templates/sigra.install/core/auth_hooks.ex` — add `Sigra.LiveView.RequireOrgMfa` to live_session `:organization_scoped` on_mount list

### Verification + planning truth touch points

- `.planning/ROADMAP.md` — surgical edit to Phase 91 success criterion #1 (action name canonicalization per D-91-12)
- `CHANGELOG.md` `[Unreleased]` — add B2B-01 trace bullet at phase commit
- `.planning/phases/91-org-level-mfa-enforcement-b2b-01/91-VERIFICATION.md` — to be authored at phase close per ROADMAP success criterion #5

</canonical_refs>

<code_context>

## Existing Code Insights

### Reusable Assets

- **`Sigra.Audit.log_multi_safe/3`** — atomic-audit Multi step composer. No changes needed.
- **`Sigra.Organizations.append_audit/5` (private helper, line 1313 area)** — already used by every org mutation. `set_mfa_policy/3` reuses this helper; no new audit infrastructure.
- **`Sigra.Plug.RequireMembership` (148 lines)** — structural twin: NimbleOptions-style opt validation, error_handler delegation, scope-only reads, halt shape. Copy-paste-modify for `Sigra.Plug.RequireOrgMfa` (~80-120 lines projected).
- **`Sigra.LiveView.OrganizationScope`** — structural twin for `Sigra.LiveView.RequireOrgMfa` on_mount. Same scope-hydration entry point in `live_session :organization_scoped`.
- **`Sigra.MFA.enabled?(config, user)`** — single-call check the plug, on_mount, and pre-flight admin enrollment guard all use.
- **Existing `priv/templates/sigra.upgrade/alter_add_personal.exs`** — exact template shape for the v1.21 upgrade migration adding `enforce_mfa_for_members` (idempotent `add_if_not_exists`).

### Established Patterns

- **Atomic Multi + audit** — every org mutation in `lib/sigra/organizations.ex` uses `Multi.new() |> Multi.update(...) |> append_audit(config, "organization.X", scope, metadata: ...) |> config.repo.transaction() |> normalize_multi_result()`. `set_mfa_policy/3` is one more instance.
- **Idempotent no-op short-circuit** — Ecto `Repo.update` returns `{:ok, struct}` when changeset has no changes. Library code typically still wraps in Multi; `set_mfa_policy/3` short-circuits BEFORE Multi to avoid the no-op audit row (D-91-14).
- **Plug ↔ on_mount pairing** — `RequireMembership` plug pairs with `OrganizationScope` on_mount. Same pairing for `RequireOrgMfa` plug + `RequireOrgMfa` on_mount. Live_redirect within the live_session re-runs on_mount, not the pipeline.
- **Generator-managed router pipelines** — `:org_scoped` pipeline lives in `priv/templates/sigra.install/organizations/router_injection.ex`; hosts inherit changes on `mix sigra.install` re-run / upgrade. ROADMAP success criterion #3 explicitly relies on this.
- **Sudo-ladder for org-settings actions** — General (rename, no sudo), Slug (sudo + typed-confirm), Danger (sudo + typed-confirm + red). New "Security" toggle slots between General and Danger Zone with light confirm only (D-91-11).

### Integration Points

- New schema field `enforce_mfa_for_members` on `Organizations` schema (non-castable; library-writes-only via `set_mfa_policy_changeset/2`).
- New library function `Sigra.Organizations.set_mfa_policy(scope, org, value)` returning `{:ok, org} | {:error, :admin_must_enroll_first | :mfa_policy_aborted | %Ecto.Changeset{}}`.
- New plug `Sigra.Plug.RequireOrgMfa` and on_mount `Sigra.LiveView.RequireOrgMfa`.
- New error reason `:mfa_required` (or `:org_mfa_required`) in generated `AuthErrorHandler.auth_error/2`.
- Generated `OrganizationSettingsLive` "Security" section + impact-preview COUNT query.
- Upgrade migration template `priv/templates/sigra.upgrade/alter_add_enforce_mfa_for_members.exs` (idempotent additive).

</code_context>

<specifics>

## Specific Ideas

- **Industry-precedent locks (from Area 2 research):** GitHub / GitLab / Auth0 / Okta / Slack all enforce a hard wall with carve-outs only for "fix-it-yourself" paths. Service accounts / M2M tokens are universally exempt as a separate actor class. Server-side `return_to` with relative-path validation is the OAuth-ecosystem-standard return-flow pattern. Sigra matches this composition exactly via the routing structure.
- **GitHub's "eject from org" pattern is explicitly NOT adopted** — ROADMAP success criterion #2 specifies redirect-to-enroll, not member removal.
- **Auth0/Okta admin lockout protection is explicitly adopted** — pre-flight refuse if admin themselves not MFA-enrolled (D-91-09).
- **Phoenix `phx.gen.auth` `:user_return_to` session pattern is the model for D-91-08** — relative-path-only validation, server-side store, fallback to safe default.
- **Decimal phase numbering not used** — Phase 91 is a primary phase under v1.21.

</specifics>

<deferred>

## Deferred Ideas

- **Grace period for existing members** (e.g., 7-day window between policy change and enforcement) — GitLab pattern, NOT adopted because ROADMAP success criterion #2 specifies "blocked at the request boundary until enrollment" (hard cutover). If demanded later, would add a per-member `enforced_after` snapshot column to memberships and rework the plug check. Park as a v1.22+ candidate if adopters request it.
- **Email notification to unenrolled members on policy change** — Auth0 pattern. Out of scope to keep Phase 91 narrow. Add as a candidate Phase if Phase 91 ships and adopters ask.
- **PubSub-broadcast disconnect for already-mounted LV sockets** — would close the mid-session enforcement gap to milliseconds. Phase 16 force-logout pattern (org member removal) is the structural model. Not adopted because the on_mount hook (D-91-03) catches the next live_redirect and the gap in practice is seconds-to-minutes. Re-evaluate if real adopters report the gap as a security finding.
- **Service-account exemption hook in the plug** — Phase 93 will add it. Documented here so Phase 93 planner doesn't have to rediscover the contract.
- **Per-route `:org_scoped_mfa` pipeline for hosts who want fine-grained opt-in** — explicitly defeated by ROADMAP success criterion #3. Park as a v2 host-extension recipe if requested.
- **GitHub-style member ejection on enforcement** — explicitly out of scope (ROADMAP success criterion #2 wording).
- **Generalizing `Sigra.Plug.RequireMFAEnrolled` + `Sigra.Plug.RequireOrgMfa` into a single `Sigra.Plug.RequireMfa` with `mode:` opt** — would clean up the plug family long-term but adds a v1.21 deprecation cycle. Sibling-plug stance (D-91-04) is the v1.21 default; revisit in a future "plug API consolidation" phase if other plugs accumulate similar overlap.

### Reviewed Todos (not folded)

_No todos matched the phase scope (`gsd-sdk query todo.match-phase 91` returned 0)._

</deferred>

---

*Phase: 91-org-level-mfa-enforcement-b2b-01*
*Context gathered: 2026-04-29*
