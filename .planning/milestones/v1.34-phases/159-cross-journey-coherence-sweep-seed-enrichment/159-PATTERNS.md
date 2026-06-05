# Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment — Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 8 (6 modifications, 1 new)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/example/lib/example/demo/seeds.ex` | seed-orchestrator | batch / CRUD | self (existing `@audit_actions`, `@persona_audit_events`, `seed_invitation/1`, `seed_passkey/1`) | exact |
| `test/example/lib/example/demo/personas.ex` | data-config | batch | self (existing persona maps + `feature_map/0`) | exact |
| `test/example/test/example/demo/seeds_test.exs` | test | batch | self (existing `snapshot_counts/0`, idempotency + liveness describes) | exact |
| `lib/sigra/admin/live/organization_live.ex` | LiveView | request-response | `lib/sigra/admin/live/users_index_live.ex` (roster pills + `maybe_append`) | role-match |
| `lib/sigra/admin/organizations/detail.ex` | data-shape | CRUD | self (`shape_invitation_row/2` at `:115-127`) | exact |
| `lib/sigra/admin/components.ex` | component | request-response | self (`notice/1` at `:302-308`) | exact |
| `test/example/priv/static/assets/css/app.css` | style | request-response | self (existing `@media (hover: hover) and (pointer: fine)` at `:871`) | exact |
| `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts` | e2e-test | request-response | `admin-checkpoints.spec.ts` (single-journey ad-hoc fixtures, scope_ribbon + DOM assertions) | exact |

---

## Pattern Assignments

### `test/example/lib/example/demo/seeds.ex` (seed-orchestrator, batch)

**Analog:** self — existing patterns within this file are the authoritative model for all additions.

**Persona audit event list pattern** (lines 435–532):

```elixir
@persona_audit_events [
  %{
    email: "alice@demo.sigra.dev",
    actor: "alice@demo.sigra.dev",
    action: "auth.login.success",
    outcome: "success",
    offset: 18,          # Days subtracted from @seed_reference_ts — never utc_now()
    org: :acme           # nil for users in no org; must match the user's actual org membership
  },
  # ... more maps
]
```

New entries for FIXT-04 append here using reserved-prefix actions (`auth.*`, `api.*`). The `offset` must be a NEW value not already used (current range: 18–29). New entries:

```elixir
# Append to @persona_audit_events — pick offsets 30–34 or beyond 29
%{email: "pat@demo.sigra.dev",  actor: "pat@demo.sigra.dev",  action: "auth.password.change",      outcome: "success", offset: 30, org: nil},
%{email: "pat@demo.sigra.dev",  actor: "pat@demo.sigra.dev",  action: "auth.magic_link.sent",       outcome: "success", offset: 31, org: nil},
%{email: "grace@demo.sigra.dev",actor: "grace@demo.sigra.dev",action: "api.token.create",           outcome: "success", offset: 32, org: :acme},
%{email: "carol@demo.sigra.dev",actor: "carol@demo.sigra.dev",action: "auth.oauth.link",            outcome: "success", offset: 33, org: :acme}
# Note: carol's google link uses a distinct offset from her existing github link (offset 23)
```

**Admin audit action list pattern** (lines 414–433):

```elixir
@audit_actions [
  {"auth.login.success", "success", 0},   # {action_string, outcome_string, offset_days}
  # ...
]
```

`@audit_actions` rows are tied to admin only (via `effective_user_id: admin.id` in `insert_audit_batch/3`). Only add new rows here if the intent is to show more admin-tied events. For persona-specific events, use `@persona_audit_events`.

**Idempotency guard pattern** (lines 543–551):

```elixir
demo_tied_count =
  Repo.aggregate(
    from(a in AuditEvent, where: a.effective_user_id in ^demo_user_ids),
    :count
  )

if demo_tied_count < length(@audit_actions) + length(@persona_audit_events) do
  insert_audit_batch(admin, users, organizations)
end
```

This guard is auto-updated when new entries are appended to either list — no manual threshold number to change.

**Invitation idempotency pattern** (lines 240–268):

```elixir
defp seed_invitation(acme) do
  expires_ts = ~U[2026-06-30 00:00:00Z]
  invite_email = "invited@demo.sigra.dev"

  existing =
    Repo.one(
      from(i in OrganizationInvitation,
        where:
          i.organization_id == ^acme.id and
            i.email == ^invite_email and
            is_nil(i.accepted_at) and
            is_nil(i.revoked_at)
      )
    )

  unless existing do
    %OrganizationInvitation{}
    |> OrganizationInvitation.changeset(%{
      email: invite_email,
      role: :member,
      expires_at: expires_ts,
      organization_id: acme.id
    })
    |> Repo.insert!()
  end
end
```

FIXT-01 adds a second invitation clause inside the same function body. The key is using a DIFFERENT email and a past `expires_at`. Copy the check-then-insert block verbatim, changing `invite_email` and `expires_ts`:

```elixir
# Second invitation block — expired
expired_email = "expired-invite@demo.sigra.dev"
expired_ts = ~U[2026-01-01 00:00:00Z]   # real past; any past constant works

existing_expired =
  Repo.one(
    from(i in OrganizationInvitation,
      where:
        i.organization_id == ^acme.id and
          i.email == ^expired_email and
          is_nil(i.accepted_at) and
          is_nil(i.revoked_at)
    )
  )

unless existing_expired do
  %OrganizationInvitation{}
  |> OrganizationInvitation.changeset(%{
    email: expired_email,
    role: :member,
    expires_at: expired_ts,
    organization_id: acme.id
  })
  |> Repo.insert!()
end
```

**Passkey seed pattern** (lines 294–312):

```elixir
defp seed_passkey(users) do
  admin = users["admin@demo.sigra.dev"]

  credential_id = :crypto.hash(:sha256, "sigra-demo-admin-passkey-credential-id-v1")
  public_key    = :crypto.hash(:sha256, "sigra-demo-admin-passkey-public-key-v1")

  %UserPasskey{}
  |> UserPasskey.create_changeset(%{
    user_id: admin.id,
    credential_id: credential_id,
    public_key: public_key,
    nickname: "Demo Security Key"
  })
  |> Repo.insert!(on_conflict: :nothing, conflict_target: [:credential_id])
end
```

FIXT-03 extends this to also seed the new passkey-only persona (`pat@demo.sigra.dev`). Extract a private `upsert_passkey/2` helper and call it for both users:

```elixir
defp seed_passkey(users) do
  admin = users["admin@demo.sigra.dev"]
  pat   = users["pat@demo.sigra.dev"]

  upsert_passkey(admin, "sigra-demo-admin-passkey-credential-id-v1")
  upsert_passkey(pat,   "sigra-demo-pat-passkey-credential-id-v1")
end

defp upsert_passkey(user, seed_string) do
  credential_id = :crypto.hash(:sha256, seed_string)
  public_key    = :crypto.hash(:sha256, seed_string <> "-pubkey")

  %UserPasskey{}
  |> UserPasskey.create_changeset(%{
    user_id: user.id,
    credential_id: credential_id,
    public_key: public_key,
    nickname: "Demo Security Key"
  })
  |> Repo.insert!(on_conflict: :nothing, conflict_target: [:credential_id])
end
```

**Batch insert with `allow_reserved: true`** (lines 559–604):

```elixir
%AuditEvent{}
|> AuditEvent.changeset(
  %{action: action, outcome: outcome, ...},
  allow_reserved: true          # REQUIRED for auth.*, session.*, mfa.*, api.*, etc.
)
|> Repo.insert!()
```

Every new persona audit event row runs through this same branch. The `allow_reserved: true` is already present — do not remove it when adding new map entries.

**`maybe_schedule_deletion` pattern** (lines 155–182):

```elixir
defp maybe_schedule_deletion(user, %{scheduled_deletion: true}) do
  deleted_ts    = ~U[2026-05-16 08:00:00Z]
  scheduled_ts  = ~U[2026-05-30 08:00:00Z]

  if user.scheduled_deletion_at do
    user
  else
    user
    |> User.deletion_changeset(%{
      deleted_at: deleted_ts,
      scheduled_deletion_at: scheduled_ts
    })
    |> Repo.update!()
  end
end
```

The new `grace@demo.sigra.dev` persona (FIXT-02, Acme member with deletion scheduled) will have `scheduled_deletion: true`, which routes to this existing clause unchanged. No new clause is needed.

**Membership seed pattern** (lines 212–230):

```elixir
defp seed_memberships(users, acme, beta) do
  # ...
  grace = users["grace@demo.sigra.dev"]    # NEW: add lookup for new persona
  upsert_membership(grace.id, acme.id, :member)  # NEW: Acme member row
end
```

---

### `test/example/lib/example/demo/personas.ex` (data-config, batch)

**Analog:** self — existing persona map shape is the complete template.

**Persona map shape** (lines 39–138 — any single persona block):

```elixir
%{
  email: "grace@demo.sigra.dev",
  display_name: "Grace",
  password: "GraceDemoPass1!Acme",
  confirmed: true,
  totp: false,
  passkey: false,
  locked: false,
  scheduled_deletion: true,    # D-03: deletion-scheduled Acme member
  identity_github: false,
  org_owner: nil,
  org_admin: nil,
  org_member: :acme            # FIXT-02: must be an Acme member for roster pill
}
```

For the passkey-only persona (FIXT-03):

```elixir
%{
  email: "pat@demo.sigra.dev",
  display_name: "Pat",
  password: "PatDemoPass1!Passkey",
  confirmed: true,
  totp: false,                 # D-02: must be false — passkey-only, no MFA
  passkey: true,               # D-02: triggers passkey seed in seed_passkey/1
  locked: false,
  scheduled_deletion: false,
  identity_github: false,
  org_owner: nil,
  org_admin: nil,
  org_member: nil
}
```

**`feature_map/0` pattern** (lines 147–157):

```elixir
def feature_map do
  %{
    "admin"  => "Admin — TOTP MFA, passkey display row, multi-org owner, rich audit trail",
    "alice"  => "Standard confirmed user — happy path login, Acme Corp member",
    # ...
    # ADD matching entries for every new persona — key is email local part
    "pat"    => "Passkey-only user — no MFA, passkey display row, demonstrates Passkeys pill",
    "grace"  => "Deletion-scheduled Acme member — demonstrates in-roster Deletion scheduled pill"
  }
end
```

Every persona in `all/0` MUST have a matching key in `feature_map/0`. The key is `email |> String.split("@") |> hd()`.

---

### `test/example/test/example/demo/seeds_test.exs` (test, batch)

**Analog:** self — existing test structure.

**`snapshot_counts/0` expansion pattern** (lines 38–85):

```elixir
defp snapshot_counts do
  demo_user_ids = Repo.all(from u in User, where: like(u.email, ^"%#{@demo_domain}"), select: u.id)

  %{
    demo_users: length(demo_user_ids),
    # ...
    invitations:
      Repo.aggregate(
        from(i in OrganizationInvitation, where: i.email == ^"invited@demo.sigra.dev"),
        :count
      ),
    # ADD for FIXT-01 idempotency coverage:
    expired_invitations:
      Repo.aggregate(
        from(i in OrganizationInvitation, where: i.email == ^"expired-invite@demo.sigra.dev"),
        :count
      ),
    passkeys:
      Repo.aggregate(
        from(p in UserPasskey, where: p.user_id in ^demo_user_ids),
        :count
      ),
    # passkeys count will be 2 after FIXT-03 (admin + pat)
  }
end
```

**Idempotency test pattern** (lines 88–102):

```elixir
test "running run/0 twice yields identical counts and does not error" do
  assert :ok = Seeds.run()
  first = snapshot_counts()

  assert :ok = Seeds.run()
  second = snapshot_counts()

  assert first == second,
         "second run/0 changed counts: first=#{inspect(first)} second=#{inspect(second)}"

  assert first.demo_users == length(Personas.all())   # auto-derives — no hardcoded count
  assert first.organizations == 2
end
```

`first.demo_users == length(Personas.all())` is already dynamic — adding personas to `Personas.all()` auto-updates this assertion. No change needed to the assertion itself.

**New state assertions pattern** (lines 126–180 — any existing persona-specific test):

```elixir
# Copy the frank test block shape for new personas:
test "grace is an Acme member scheduled for deletion" do
  acme  = Repo.get_by!(Organization, slug: "acme-corp")
  grace = demo_user!("grace@demo.sigra.dev")

  refute is_nil(grace.deleted_at)
  refute is_nil(grace.scheduled_deletion_at)

  assert membership_role(grace.id, acme.id) == :member,
         "grace should be an Acme Corp member so roster pill can render"
end

test "pat has no MFA credential but has a passkey row" do
  pat = demo_user!("pat@demo.sigra.dev")

  mfa_count =
    Repo.aggregate(from(c in UserMFACredential, where: c.user_id == ^pat.id), :count)

  assert mfa_count == 0

  passkey_count =
    Repo.aggregate(from(p in UserPasskey, where: p.user_id == ^pat.id), :count)

  assert passkey_count >= 1
end

test "exactly one expired invitation to expired-invite@demo.sigra.dev" do
  expired =
    Repo.all(
      from i in OrganizationInvitation,
        where:
          i.email == ^"expired-invite@demo.sigra.dev" and
            is_nil(i.accepted_at) and is_nil(i.revoked_at)
    )

  assert length(expired) == 1
  expired_row = hd(expired)
  assert DateTime.compare(expired_row.expires_at, DateTime.utc_now()) == :lt,
         "expired invitation expires_at should be in the past"
end
```

**Audit liveness assertions to re-pin** (lines 232–270):

The `>=15` check at line 241 and `alice_tied >= 3` at line 270 use dynamic counts and will pass as-is after new rows are added to `@persona_audit_events`. The assertions themselves do not need numerical changes — they are already `>=` bounds. Re-pin only if the existing assertions were previously `==` (they are not).

---

### `lib/sigra/admin/live/organization_live.ex` (LiveView, request-response)

**Analog:** `lib/sigra/admin/live/users_index_live.ex` lines 341–359 for the roster pill pattern; self lines 132–143 for the existing roster template.

**Existing roster pills pattern** (lines 132–143 — the current member cluster):

```heex
<div class="sg-cluster">
  <span class="sg-status-pill" data-tone={role_tone(member.role)}>{role_label(member.role)}</span>
  <span :if={member.locked?} class="sg-status-pill" data-tone="risk">Locked</span>
  <span :if={member.confirmed?} class="sg-status-pill" data-tone="ok">Confirmed</span>
  <span :if={not member.confirmed?} class="sg-status-pill" data-tone="warn">Unconfirmed</span>
</div>
```

FIXT-02 adds a new pill span after `locked?` and before `confirmed?`:

```heex
<span :if={member.deletion_scheduled?} class="sg-status-pill" data-tone="warn">Deletion scheduled</span>
```

This mirrors the `users_index_live.ex:355` pattern:

```elixir
# users_index_live.ex:355 — the exact same pill label/tone
|> maybe_append(row.user.deleted_at, {"Deletion scheduled", "warn"})
```

**`format_date/1` expansion pattern** (lines 190–191 — current local definition):

```elixir
# Current (single-clause):
defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
defp format_date(_), do: "—"
```

Replace with the multi-clause pattern from `components.ex:407-413`, adapted to the date-only format already used here (no HH:MM):

```elixir
# Expanded (matches components.ex logic, uses date-only format consistent with this file):
defp format_date(%DateTime{} = dt),      do: Calendar.strftime(dt, "%Y-%m-%d")
defp format_date(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%Y-%m-%d")
defp format_date(nil),                    do: "—"
defp format_date(_),                      do: "—"
```

Note: `components.ex` raises `ArgumentError` on unknown types, but the local helper uses a silent fallback `"—"` — match the existing local contract (silent fallback) rather than introducing a raise here unless explicitly directed.

---

### `lib/sigra/admin/organizations/detail.ex` (data-shape, CRUD)

**Analog:** self — `shape_invitation_row/2` (lines 115–127) shows the exact pattern for adding a derived boolean flag to a row shape.

**`shape_invitation_row/2` as the model** (lines 115–127):

```elixir
defp shape_invitation_row(invitation, now) do
  expires_at = Map.get(invitation, :expires_at)

  expired? =
    not is_nil(expires_at) and DateTime.compare(expires_at, now) == :lt

  %{
    email:     Map.get(invitation, :email),
    role:      Map.get(invitation, :role),
    expires_at: expires_at,
    expired?:  expired?           # derived boolean flag from user struct field
  }
end
```

Apply the same derivation pattern to `shape_member_row/1` (lines 103–113). Add `deletion_scheduled?` as a derived boolean from `user.deleted_at`:

```elixir
defp shape_member_row(%{user: user, role: role}) do
  display_name = Map.get(user, :display_name) || Map.get(user, :email)

  %{
    user:                 user,
    role:                 role,
    confirmed?:           not is_nil(Map.get(user, :confirmed_at)),
    locked?:              not is_nil(Map.get(user, :locked_at)),
    deletion_scheduled?:  not is_nil(Map.get(user, :deleted_at)),   # NEW
    display_name:         display_name
  }
end
```

Also update the `@type member_row` typespec (lines 22–28) to add the new field:

```elixir
@type member_row :: %{
        user:                struct(),
        role:                atom() | String.t() | nil,
        confirmed?:          boolean(),
        locked?:             boolean(),
        deletion_scheduled?: boolean(),       # NEW
        display_name:        String.t() | nil
      }
```

---

### `lib/sigra/admin/components.ex` (component, request-response)

**Analog:** self — `notice/1` at lines 302–308.

**Current `notice/1` implementation** (lines 302–308):

```elixir
def notice(assigns) do
  ~H"""
  <div class={["sg-notice", @class]} data-tone={@tone} {@rest}>
    <p class="sg-text-sm">{render_slot(@inner_block)}</p>
  </div>
  """
end
```

The `org-notice-nested-p` fix changes the inner `<p>` wrapper to `<div>`. This eliminates the nested-`<p>` hazard for all current and future call sites without any visual change (CSS targets `sg-text-sm`, not the tag):

```elixir
def notice(assigns) do
  ~H"""
  <div class={["sg-notice", @class]} data-tone={@tone} {@rest}>
    <div class="sg-text-sm">{render_slot(@inner_block)}</div>
  </div>
  """
end
```

Verify no call site passes block-level children (currently none do per RESEARCH.md verification of all 3 call sites). After this change, the HTML structure is valid regardless of what slot content is passed.

---

### `test/example/priv/static/assets/css/app.css` (style, D-06 fork)

**Analog:** self — existing `@media (hover: hover) and (pointer: fine)` guard at lines 871–877 inside the `.sg-filter-chip` block.

**Current structure** (lines 858–892 — relevant excerpt):

```css
.sg-filter-chip {
  display: inline-flex;
  /* ...other properties... */
  transition: var(--sg-transition-tone), var(--sg-transition-press);   /* line 869 */
}
@media (hover: hover) and (pointer: fine) {
  .sg-filter-chip:hover {                                               /* line 872 */
    background: var(--sg-color-brand-soft);
    box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--sg-color-brand) 24%, transparent);
    transform: translateY(-1px);
  }
}
```

D-06 fix: move the `transition` property from the unconditional `.sg-filter-chip` block into the existing `@media (hover: hover) and (pointer: fine)` block, alongside the existing `:hover` rule:

```css
.sg-filter-chip {
  display: inline-flex;
  /* ...other properties... */
  /* REMOVE transition from here */
}
@media (hover: hover) and (pointer: fine) {
  .sg-filter-chip {                                     /* ADD this nested rule */
    transition: var(--sg-transition-tone), var(--sg-transition-press);
  }
  .sg-filter-chip:hover {
    background: var(--sg-color-brand-soft);
    box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--sg-color-brand) 24%, transparent);
    transform: translateY(-1px);
  }
}
```

This is a 3-line net change (remove 1 line from `.sg-filter-chip`, add 3 lines inside the media block). All other `.sg-filter-chip` rules (`:has(input:checked)`, dark mode) remain unchanged.

---

### `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts` (e2e-test, NEW)

**Analog:** `admin-checkpoints.spec.ts` — copy the file-level imports, helpers (`registerUser`, `waitForLiveViewReady`, `clearBrowserSession`, `createOrganization`), and overall journey structure. The sibling spec differs in two ways: (1) it asserts DOM behavior only — no `toHaveScreenshot()` calls; (2) it adds keyboard-motion and pill-state assertions.

**File-level imports pattern** (admin-checkpoints.spec.ts lines 1–7):

```typescript
import { test, expect, type Page } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';
// Note: omit captureAdminCheckpoint, statSync, AxeBuilder — not needed in behavior-only spec
```

**Local helper functions to copy verbatim** (admin-checkpoints.spec.ts lines 43–87):

```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
}

async function registerUser(page: Page, email: string, password: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.locator('form:has(input[name="user[password]"])').first().evaluate((form) => {
    (form as HTMLFormElement).requestSubmit();
  });
  await expect(page).not.toHaveURL(/\/users\/register/);
}

async function clearBrowserSession(page: Page) {
  await page.context().clearCookies();
}

async function createOrganization(page: Page, name: string, slug: string) {
  await page.goto('/organizations');
  await waitForLiveViewReady(page);
  await page.fill('input[name="organization[name]"]', name);
  await expect(page.locator('#slug-preview')).toHaveText(slug);
  await page.click('button:has-text("Create organization")');
  await expect(page).toHaveURL(new RegExp(`/organizations/${slug}/members$`));
  await waitForLiveViewReady(page);
}
```

**DOM assertion pattern for scope_ribbon** (admin-checkpoints.spec.ts lines 203–204, 317):

```typescript
// scope_ribbon/1 emits a <span class="sg-muted sg-text-sm"> with scope copy
await expect(page.locator('header').first()).toContainText('Global');
// Or for org-scoped screens:
await expect(page.getByText('Global audit explorer')).toBeVisible();
```

**DOM assertion pattern for page_back** (admin-checkpoints.spec.ts line 282):

```typescript
// page_back/1 emits an <a class="sg-btn sg-btn--ghost sg-btn--sm">
await expect(page.getByRole('link', { name: 'Back to user' })).toBeVisible();
```

**DOM assertion pattern for notice** (admin-checkpoints.spec.ts lines 182, 193):

```typescript
await expect(page.locator('.sg-notice').first()).toBeVisible();
```

**Pill DOM assertion pattern** — new for phase 159, models the text-based approach:

```typescript
// Assert "Expired" invitation pill on org overview
await expect(
  page.locator('.sg-status-pill[data-tone="risk"]').filter({ hasText: 'Expired' })
).toBeVisible();

// Assert "Deletion scheduled" roster pill
await expect(
  page.locator('.sg-status-pill[data-tone="warn"]').filter({ hasText: 'Deletion scheduled' })
).toBeVisible();

// Assert "Passkeys" pill on users index (against seeded demo DB persona)
await page.goto('/admin/users?q=pat%40demo.sigra.dev');
await waitForLiveViewReady(page);
await expect(
  page.locator('.sg-status-pill[data-tone="ok"]').filter({ hasText: 'Passkeys' })
).toBeVisible();
```

**Keyboard motion assertion pattern** — new for phase 159 (GATE-03):

```typescript
// Assert filter chip has no transition on keyboard navigation
// After tab-focusing a chip, check computed style — no transform should fire
const chip = page.locator('label.sg-filter-chip').first();
await chip.focus();
// If transition is scoped to pointer:fine, computed style reports no transition
const transition = await chip.evaluate((el) => getComputedStyle(el).transition);
// On a non-pointer-fine test environment, transition should be empty string or 'none'
// This is an environmental assertion — document the dependency clearly in a comment
```

**Playwright project assignment pattern** — the sibling spec runs in the default `chromium` project (not the `admin-checkpoints-*` partitioned projects). The `playwright.config.ts` `testIgnore` for the `chromium` project uses `ADMIN_CHECKPOINTS_SPEC = /admin-checkpoints\.spec\.ts/` — the new sibling file (`admin-coherence-sweep.spec.ts`) is NOT matched by this regex and runs automatically in the `chromium` lane without config changes. No `playwright.config.ts` modification is needed.

---

## Shared Patterns

### `on_conflict: :nothing` idempotency
**Source:** `seeds.ex` throughout (e.g., lines 235, 290, 311, 353, 402)
**Apply to:** All new `Repo.insert!` calls in seeds.ex

```elixir
|> Repo.insert!(on_conflict: :nothing, conflict_target: [:unique_column])
```

For `OrganizationInvitation`, there is no simple unique index on `[:email, :organization_id]` — use the check-then-insert pattern keyed on the `(organization_id, email, is_nil(accepted_at), is_nil(revoked_at))` query instead (already shown in the invitation pattern above).

### `@seed_reference_ts` anchor for all timestamps
**Source:** `seeds.ex:39`, used at lines 563, 586
**Apply to:** All new `occurred_at` values in audit event appends

```elixir
@seed_reference_ts ~U[2026-05-15 12:00:00Z]

# Always compute occurred_at as:
occurred_at = DateTime.add(@seed_reference_ts, -offset_days * 86_400, :second)
# NEVER: DateTime.utc_now()
```

### `allow_reserved: true` on audit changeset
**Source:** `seeds.ex:577, 601`
**Apply to:** Every `AuditEvent.changeset/3` call in the seed batch

```elixir
|> AuditEvent.changeset(%{action: action, ...}, allow_reserved: true)
```

### `Map.get(user, :field)` for struct field access in lib-owned data shapes
**Source:** `detail.ex:104, 109, 110, 111` — `shape_member_row/1`
**Apply to:** `deletion_scheduled?` derivation in `shape_member_row/1`

```elixir
deletion_scheduled?: not is_nil(Map.get(user, :deleted_at))
```

`Map.get/2` (not direct field access) is used because `user` is a host-app struct; the field may not exist in older installs — `Map.get` falls back to `nil` safely.

---

## No Analog Found

None. All files have close analogs in the codebase. The new Playwright spec (`admin-coherence-sweep.spec.ts`) is the only truly new file, and `admin-checkpoints.spec.ts` is an exact structural analog.

---

## Critical Ordering Notes for Planner

1. **`detail.ex` must be modified BEFORE `organization_live.ex` template change** — the template references `member.deletion_scheduled?` which only exists after `shape_member_row/1` is updated. If done in reverse order, the LiveView compile-time check will flag the unknown key.

2. **Personas MUST be added to BOTH `all/0` AND `feature_map/0` in the same commit** — `Seeds.print_credentials/0` calls `feature_map()[local]` for every persona; a missing key returns nil and prints broken credentials.

3. **`seed_passkey/1` extension in `seeds.ex` must match the new persona email** — if `pat@demo.sigra.dev` is added to `all/0` with `passkey: true` but `seed_passkey/1` still only references admin, the passkey row is never inserted and the "Passkeys" pill never renders.

4. **`seeds_test.exs` snapshot counts must include `expired_invitations`** — the current `invitations:` key is scoped only to `invited@demo.sigra.dev`. A new `expired_invitations: 1` key in `snapshot_counts/0` makes the idempotency test catch duplicate expired invite seeding on re-run.

5. **`playwright.config.ts` requires NO changes** — the sibling spec file name (`admin-coherence-sweep.spec.ts`) does not match the `ADMIN_CHECKPOINTS_SPEC` regex and runs in the default `chromium` project automatically.

---

## Metadata

**Analog search scope:** `lib/sigra/admin/`, `test/example/lib/example/demo/`, `test/example/test/example/demo/`, `test/example/priv/playwright/`, `test/example/priv/static/assets/css/`
**Files scanned:** 10 primary files + playwright config
**Pattern extraction date:** 2026-06-04
