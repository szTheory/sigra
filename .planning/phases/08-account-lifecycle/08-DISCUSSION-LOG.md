# Phase 8: Account Lifecycle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-08
**Phase:** 08-account-lifecycle
**Areas discussed:** Email change flow, Account deletion, Password change, Profile update hooks, Account settings page, Migration strategy, Email change schema, Cross-feature interactions

---

## Email Change Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Confirm-then-switch | Send verification to NEW address. Old stays active until confirmed. | ✓ |
| Switch immediately | Change email right away, revert if unconfirmed after TTL. | |
| Double confirmation | Require confirmation from BOTH old and new addresses. | |

**User's choice:** Confirm-then-switch
**Notes:** GitHub/GitLab pattern. Safer — no lockout if new email is wrong.

| Option | Description | Selected |
|--------|-------------|----------|
| Notify with cancel link | Old address gets notification with cancel option. | ✓ |
| Notify without cancel | Informational notice only. | |
| No notification | Only new address receives a message. | |

**User's choice:** Notify with cancel link

| Option | Description | Selected |
|--------|-------------|----------|
| 24 hours | Shorter than confirmation since user is authenticated. | ✓ |
| 48 hours | Same as account confirmation TTL. | |

**User's choice:** 24 hours

| Option | Description | Selected |
|--------|-------------|----------|
| One at a time | New request cancels pending. Simple mental model. | ✓ |
| Allow multiple | Multiple addresses pending; confirming any one wins. | |

**User's choice:** One at a time

| Option | Description | Selected |
|--------|-------------|----------|
| Delete token + notify new | Cancel deletes token, new address notified. | ✓ |
| Delete token silently | No notification to new address. | |

**User's choice:** Delete token + notify new

| Option | Description | Selected |
|--------|-------------|----------|
| Reserve it | Store pending_email, block registration with that email. | ✓ |
| No reservation | First to confirm wins. | |

**User's choice:** Reserve it

| Option | Description | Selected |
|--------|-------------|----------|
| Error page with retry | Same pattern as Phase 3 expired flows. | ✓ |
| Auto-redirect to settings | Redirect with flash message. | |

**User's choice:** Error page with retry

| Option | Description | Selected |
|--------|-------------|----------|
| Invalidate all except current | Same as password change pattern. | ✓ |
| Keep sessions | Only update email. | |

**User's choice:** Invalidate all except current

| Option | Description | Selected |
|--------|-------------|----------|
| Require sudo | Consistent with success criteria #4. | ✓ |
| Logged in is enough | Skip sudo since confirmation still needed. | |

**User's choice:** Require sudo

| Option | Description | Selected |
|--------|-------------|----------|
| Same flow, OAuth re-auth for sudo | Consistent with Phase 4 D-21 sudo pattern. | ✓ |
| Skip sudo for OAuth users | Just request change without re-auth. | |

**User's choice:** Same flow, OAuth re-auth

| Option | Description | Selected |
|--------|-------------|----------|
| Three emails | Confirm new + notify old + post-change confirmation. | ✓ |
| Two emails | Skip post-change confirmation. | |

**User's choice:** Three emails

| Option | Description | Selected |
|--------|-------------|----------|
| Link only | Same as password reset pattern. | ✓ |
| Link + code fallback | Like account confirmation. | |

**User's choice:** Link only

---

## Account Deletion

| Option | Description | Selected |
|--------|-------------|----------|
| Soft delete | Set deleted_at + anonymize PII. Reversible. | ✓ |
| Hard delete | Physically remove user row. Irreversible. | |
| Anonymize only | Keep row, strip PII. | |

**User's choice:** Soft delete (as default; all three available as config options)

| Option | Description | Selected |
|--------|-------------|----------|
| Require sudo | Destructive operation per success criteria #4. | ✓ |
| Just a confirmation | Are you sure? No re-auth. | |

**User's choice:** Require sudo

| Option | Description | Selected |
|--------|-------------|----------|
| Full cleanup | Sessions, tokens, OAuth, API keys, TOTP, passkeys. | ✓ |
| Sessions + tokens only | Leave OAuth/API for developer hooks. | |

**User's choice:** Full cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Configurable grace period | 14 days default. Cancel during window. | ✓ |
| Immediate | No undo period. | |

**User's choice:** Configurable grace period (14 days)

| Option | Description | Selected |
|--------|-------------|----------|
| Config option | :soft_delete, :hard_delete, :anonymize | ✓ |
| Callback behaviour | Full custom control. | |
| Both | Config + behaviour override. | |

**User's choice:** Config option

| Option | Description | Selected |
|--------|-------------|----------|
| Show reactivation option | Login shows cancel option during grace. | ✓ |
| Block login entirely | Must contact support. | |

**User's choice:** Show reactivation option

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, with cancel link | Email with cancel mechanism. | ✓ |
| Informational only | No cancel in email. | |

**User's choice:** Yes, with cancel link

| Option | Description | Selected |
|--------|-------------|----------|
| Oban scheduled job | Job at grace period expiry. | ✓ |
| Cron sweep | Daily check for expired grace periods. | |

**User's choice:** Oban scheduled job

| Option | Description | Selected |
|--------|-------------|----------|
| Email + clear optional fields | Replace email, clear password, null optionals. | ✓ |
| Full PII wipe | Null ALL fields except id/deleted_at. | |

**User's choice:** Email + clear optional fields

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-delete callback | Runs in same transaction. | ✓ |
| Telemetry only | Async, no transaction guarantee. | |
| Both | Callback + telemetry. | |

**User's choice:** Pre-delete callback (later merged into :hooks config as :on_delete)

| Option | Description | Selected |
|--------|-------------|----------|
| Behaviour hook only | Sigra.DataExport behaviour. | ✓ |
| Built-in JSON export | Auto-generate JSON. | |
| Out of scope | Leave for host app. | |

**User's choice:** Behaviour hook only

| Option | Description | Selected |
|--------|-------------|----------|
| Sudo + cooldown | 24h cooldown after cancel. | ✓ |
| Hammer rate limit | 3 per 30 days. | |

**User's choice:** Sudo + cooldown

| Option | Description | Selected |
|--------|-------------|----------|
| Telemetry + Phase 9 | Telemetry events, audit log captures. | ✓ |
| Separate deletion_log table | Independent persistence. | |

**User's choice:** Telemetry + Phase 9

| Option | Description | Selected |
|--------|-------------|----------|
| Standard flow, no special handling | OAuth re-auth for sudo, same flow. | ✓ |
| Attempt provider-side revocation | Call revocation endpoints. | |

**User's choice:** Standard flow

| Option | Description | Selected |
|--------|-------------|----------|
| Delete all immediately | All OAuth identities removed at request. | ✓ |
| Delete at finalization | Keep during grace period. | |

**User's choice:** Delete all immediately

| Option | Description | Selected |
|--------|-------------|----------|
| Clear at finalization | Preserved during grace for cancel. | ✓ |
| Clear immediately | Remove on request. | |

**User's choice:** Clear at finalization

| Option | Description | Selected |
|--------|-------------|----------|
| Three templates | Request + cancellation + finalized. | ✓ |
| Two templates | Skip cancellation. | |
| Four templates | Add 48h reminder. | |

**User's choice:** Three templates

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, after finalization | Email freed in all strategies. | ✓ |
| Block re-registration | Keep record of deleted emails. | |

**User's choice:** Yes, after finalization

| Option | Description | Selected |
|--------|-------------|----------|
| Cancel automatically | Pending change is moot. | ✓ |
| Warn and let user choose | Show prompt. | |

**User's choice:** Cancel automatically

| Option | Description | Selected |
|--------|-------------|----------|
| Partial unique index | WHERE deleted_at IS NULL. | ✓ |
| Include user_id in email | deleted_{id}@deleted.invalid. | |

**User's choice:** Partial unique index

| Option | Description | Selected |
|--------|-------------|----------|
| Three columns | deleted_at, scheduled_deletion_at, original_email. | ✓ |
| Two columns | Separate deletion_requests table. | |

**User's choice:** Three columns

| Option | Description | Selected |
|--------|-------------|----------|
| Full restore | Clear fields, restore email, fresh login. | ✓ |
| Partial restore | Clear flags only. | |

**User's choice:** Full restore

| Option | Description | Selected |
|--------|-------------|----------|
| Context functions only | Programmatic API for admins. | ✓ |
| Skip admin support | User-initiated only. | |

**User's choice:** Context functions only

| Option | Description | Selected |
|--------|-------------|----------|
| Revoke immediately | Security-first, not restored on cancel. | ✓ |
| Revoke after grace period | Active during grace. | |

**User's choice:** Revoke immediately

| Option | Description | Selected |
|--------|-------------|----------|
| Sigra cascades its own tables | Developer handles app FKs via hook. | ✓ |
| Migration adds ON DELETE CASCADE | Automatic but less visible. | |

**User's choice:** Sigra cascades its own tables

| Option | Description | Selected |
|--------|-------------|----------|
| Standard set (5 functions) | schedule, cancel, execute, scheduled?, status. | ✓ |
| Minimal set | Just delete + cancel. | |

**User's choice:** Standard set

| Option | Description | Selected |
|--------|-------------|----------|
| Standard set | Fixtures + assertions + simulate. | ✓ |
| Minimal | Just fixtures. | |

**User's choice:** Standard set

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, generate | Settings page + deletion UI + reactivation. | ✓ |
| Context functions only | Developer builds UI. | |

**User's choice:** Yes, generate

| Option | Description | Selected |
|--------|-------------|----------|
| Standard config | 5 options: strategy, grace_period_days, cooldown_hours, before_delete→on_delete, notify. | ✓ |
| Minimal config | Just strategy + grace period. | |

**User's choice:** Standard config

---

## Password Change

| Option | Description | Selected |
|--------|-------------|----------|
| Invalidate all except current | Same as password reset. Security best practice. | ✓ |
| Invalidate all including current | Force re-login everywhere. | |
| Keep all sessions | Least disruptive. | |

**User's choice:** Invalidate all except current

| Option | Description | Selected |
|--------|-------------|----------|
| No, current password is enough | Entering current password IS re-auth. | ✓ |
| Yes, require sudo | Double verification. | |

**User's choice:** No sudo (current password suffices)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, as 'set password' | OAuth users can add password. Sudo required. | ✓ |
| No, stays passwordless | No password option for OAuth users. | |

**User's choice:** Yes, as 'set password'

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, always | With device info. Security alert. | ✓ |
| Only from new device | Conditional notification. | |

**User's choice:** Yes, always

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, flag-based | must_change_password boolean + plug redirect. | ✓ |
| No, out of scope | Leave for host app. | |

**User's choice:** Yes, flag-based

| Option | Description | Selected |
|--------|-------------|----------|
| Same rules, reuse validation | Phase 2 password validation. | ✓ |
| Stricter for changes | Higher bar for changes. | |

**User's choice:** Same rules

| Option | Description | Selected |
|--------|-------------|----------|
| Standard set (4 functions) | change_password, set_password, must_change_password?, require_password_change. | ✓ |
| Minimal | Just change_password. | |

**User's choice:** Standard set

| Option | Description | Selected |
|--------|-------------|----------|
| Plug + redirect | RequirePasswordChange plug. Same as RequireSudo. | ✓ |
| LiveView hook | Modal overlay approach. | |

**User's choice:** Plug + redirect

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include context | IP, location, browser/OS. Same as suspicious login. | ✓ |
| Minimal notification | Date only. | |

**User's choice:** Yes, include context

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, generate | Change/set password form in settings. | ✓ |
| Context functions only | Developer builds UI. | |

**User's choice:** Yes, generate

| Option | Description | Selected |
|--------|-------------|----------|
| One column | must_change_password boolean. | ✓ |
| No new columns | Skip force-change. | |

**User's choice:** One column

| Option | Description | Selected |
|--------|-------------|----------|
| Standard set | Fixtures + assertions + helpers. | ✓ |
| Minimal | Just fixtures. | |

**User's choice:** Standard set

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing | Add to :password section. | ✓ |
| New section | Separate :password_change section. | |

**User's choice:** Extend existing

| Option | Description | Selected |
|--------|-------------|----------|
| Standard events | 4 telemetry event types. | ✓ |
| Minimal events | Just :change. | |

**User's choice:** Standard events

---

## Profile Update Hooks

| Option | Description | Selected |
|--------|-------------|----------|
| Callback config | {module, function} tuples in config. | ✓ |
| Behaviour module | Implement Sigra.ProfileCallbacks. | |
| Event-based (PubSub) | Async, no transaction guarantee. | |

**User's choice:** Callback config

| Option | Description | Selected |
|--------|-------------|----------|
| Core lifecycle | Register, email change, password change, delete. | ✓ |
| All auth operations | Include login, logout, MFA, etc. | |

**User's choice:** Core lifecycle

| Option | Description | Selected |
|--------|-------------|----------|
| Ecto.Multi step | Hook appends steps to Multi. Same transaction. | ✓ |
| After-commit callback | Separate transaction. | |

**User's choice:** Ecto.Multi step

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, via Multi failure | Failing step rolls back everything. | ✓ |
| No, best-effort | Log failure, proceed. | |

**User's choice:** Yes, via Multi failure

| Option | Description | Selected |
|--------|-------------|----------|
| Multi + context map | Hook receives (multi, %{user: user, params: params}). | ✓ |
| User + params only | Simpler but can't participate in Multi. | |

**User's choice:** Multi + context map

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, with commented examples | Generator creates MyApp.Auth.Hooks. | ✓ |
| No generated module | Developer creates own. | |

**User's choice:** Yes, with commented examples

| Option | Description | Selected |
|--------|-------------|----------|
| Single hook per operation | Developer composes inside function. | ✓ |
| List of hooks | Multiple tuples, executed in order. | |

**User's choice:** Single hook per operation

| Option | Description | Selected |
|--------|-------------|----------|
| Hooks section in config | on_register, on_email_change, on_password_change, on_delete. | ✓ |
| Flat config | Top-level keys. | |

**User's choice:** Hooks section in config

| Option | Description | Selected |
|--------|-------------|----------|
| Changeset errors + telemetry | {:error, :hook_failed, changeset}. | ✓ |
| Log warning + proceed | Best-effort. | |

**User's choice:** Changeset errors + telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| Mock-friendly design | Sigra.Testing.with_hook/3. Config swap. | ✓ |
| No special helpers | Developer manages testing. | |

**User's choice:** Mock-friendly design

| Option | Description | Selected |
|--------|-------------|----------|
| Merge into hooks section | Remove :before_delete, use :on_delete. | ✓ |
| Keep both | Different purposes. | |

**User's choice:** Merge into hooks

| Option | Description | Selected |
|--------|-------------|----------|
| After auth step | Hook runs after auth operation in Multi. | ✓ |
| Before auth step | Hook runs before. | |

**User's choice:** After auth step

| Option | Description | Selected |
|--------|-------------|----------|
| At confirmation | When email actually switches. | ✓ |
| At request time | When pending_email is set. | |
| Both events | Separate hooks. | |

**User's choice:** At confirmation

---

## Account Settings Page

| Option | Description | Selected |
|--------|-------------|----------|
| Single page with sections | /users/settings with Email, Password, Deletion. | ✓ |
| Tabbed interface | Tab navigation. | |
| Separate pages | Each on own URL. | |

**User's choice:** Single page with sections

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing | Add to Phase 4 infrastructure. | ✓ |
| Replace with unified page | New comprehensive page. | |

**User's choice:** Extend existing

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, red border/warning | GitHub-style danger zone. | ✓ |
| Same styling | No special treatment. | |

**User's choice:** Red border/warning

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, inline status | Pending change, scheduled deletion, force-change banners. | ✓ |
| No indicators | Clean forms only. | |

**User's choice:** Inline status

| Option | Description | Selected |
|--------|-------------|----------|
| Current + pending display | Read-only label + pending state. | ✓ |
| Form always visible | Always show form. | |

**User's choice:** Current + pending display

| Option | Description | Selected |
|--------|-------------|----------|
| Adaptive sections | Set password for OAuth, linked accounts reference. | ✓ |
| Hide password for OAuth | No password section. | |

**User's choice:** Adaptive sections

| Option | Description | Selected |
|--------|-------------|----------|
| Single URL | /users/settings with anchor links. | ✓ |
| Nested URLs | Separate routes per section. | |

**User's choice:** Single URL

| Option | Description | Selected |
|--------|-------------|----------|
| Reference only | Show providers, link to Phase 5 management page. | ✓ |
| Full inline management | Embed connect/disconnect. | |
| No section | OAuth stays on own page. | |

**User's choice:** Reference only

---

## Migration Strategy, Email Change Schema, Cross-feature Interactions

**User's choice:** Locked in Claude's recommendations without discussion.

**Migration strategy:** Single migration template adding 5 columns to users table. Update Phase 1 template.
**Email change schema:** `pending_email` (citext, nullable) with uniqueness index. Existing user_tokens "change_email" context reused.
**Cross-feature interactions:** Password change allowed during pending email change. Pending deletion blocks other changes. Force-change flag clears on any successful change.

---

## Claude's Discretion

- Migration template structure and column ordering
- Flash messages and error wording
- Oban job module naming
- Additional telemetry events beyond specified set
- Cross-feature interaction edge cases not discussed

## Deferred Ideas

None — discussion stayed within phase scope.
