---
id: wire-check-account-active-reactivation
created: 2026-06-22
source: 260622-gy0 (Vaultr account-home hub)
severity: warning
area: test/example/lib/example_web/{router.ex,user_auth.ex}
---

# Deletion-scheduled personas (Frank/Grace) don't auto-redirect to reactivation

**Problem:** `ExampleWeb.UserAuth.check_account_active/2` exists and is documented
(redirects users with a non-nil `deleted_at` to `/users/reactivation`) but is
**not wired into any pipeline**. So demo personas Frank and Grace (scheduled for
deletion) log in and land on `/app` like anyone else instead of being intercepted
into the on-brand reactivation flow that demonstrates Sigra's soft-delete +
reactivate capability.

**Why it was deferred (not just dropped in during gy0):** naively adding
`check_account_active` to the `:require_authenticated` pipeline creates a
**redirect loop** — `/users/reactivation` itself lives in that pipeline, so a
deletion-scheduled user hitting it would be redirected to it again forever. The
same latent trap applies to `require_password_unchanged` (also defined-but-unwired,
redirects to `/users/settings#password` which is in-pipeline). Wiring safely needs
path exemptions (mirror the documented "settings page is exempt" intent): the plug
must let `~p"/users/reactivation"` and `~p"/users/log_out"` through.

**Interim coverage (shipped in gy0):** `/app` (`AppLive`) shows a prominent
"Account scheduled for deletion → Review & reactivate" card when
`user.deleted_at` is set (`data-testid="app-deletion-notice"`), linking to
`/users/reactivation`. So Frank/Grace are coherent, just not auto-redirected.

**Fix:** Add an exempt-path guard to `check_account_active/2` (and, while there,
`require_password_unchanged/2`) so they can't loop, then wire `check_account_active`
into `:require_authenticated` after `require_authenticated_user`. Add a test:
deletion-scheduled user → GET `/app` → 302 `/users/reactivation`; and a
deletion-scheduled user → GET `/users/reactivation` → 200 (no loop).

**Out of scope reminder:** Dave (locked) intentionally keeps the generic
enumeration-safe "Invalid email or password" — do NOT add lockout-specific copy
there; that's Sigra security behavior, not demo flavor.
