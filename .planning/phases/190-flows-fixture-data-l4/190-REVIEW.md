---
phase: 190-flows-fixture-data-l4
reviewed: 2026-06-17T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - lib/sigra/admin/live/branding_live.ex
  - lib/sigra/admin/live/user_show_live.ex
  - priv/templates/sigra.install/admin/admin_hooks.js
  - test/example/assets/js/admin_hooks.js
  - test/example/priv/playwright/helpers/adminFlows.ts
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts
  - test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts
  - test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 190: Code Review Report

**Reviewed:** 2026-06-17T00:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the Phase 190 L4 flow-spec submission: two LiveView edits (branding_live, user_show_live), the admin_hooks.js ConfirmDialog hardening (mirrored verbatim into both the installer template and the example copy), a Playwright config regex change, a new shared `adminFlows.ts` helper, and three new JTBD flow spec files.

Scope of actual change is narrow. The two `.ex` edits are small (a `data-sg-confirm-cancel` attribute and a new `error_message/1` clause); the bulk is the new browser specs and helper. No critical/security defects found: the admin LiveViews are scope-gated by the `Sigra.LiveView.AdminScope` on_mount hook (verified `current_scope`/`admin_scope` are assigned upstream), persona seed assumptions (dave=locked+unconfirmed, frank=scheduled_deletion via `deleted_at`) match the rendered status pills, and the `ADMIN_BEHAVIOR_SPECS` regex change correctly captures the new `admin-flow-*` specs without leaking into checkpoint/design/modal lanes (verified by execution).

Findings are correctness/robustness concerns in the new error-handling clause, an accessibility regression in the focus-return fallback, and several test-robustness issues where assertions are weaker than their stated intent. One notable maintenance defect: the two `admin_hooks.js` files are byte-identical duplicates with no enforced sync.

## Warnings

### WR-01: `String.to_existing_atom/1` in new changeset error formatter can raise mid-error-handling

**File:** `lib/sigra/admin/live/branding_live.ex:714-723`
**Issue:** The newly added `error_message(%Ecto.Changeset{})` clause interpolates Ecto error placeholders with `String.to_existing_atom(key)`:

```elixir
Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
  opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
end)
```

`error_message/1` exists to turn an arbitrary failure `reason` into a user-facing string. If a changeset message contains an interpolation token whose name is not an already-loaded atom (e.g. a custom validation message like `"must match %{pattern}"` where `:pattern` was never used as an atom in the running system), `String.to_existing_atom/1` raises `ArgumentError` — inside the very function meant to render the error safely. Unlike the sibling clauses below it, this clause has no `rescue`, so the LiveView process crashes instead of showing the error notice.

Separately, this clause appears to be defensive-only: `Branding.save_global/3` and `Branding.delete_global/1` return `{:error, message}` (binary), `{:error, reason}` (term), or `{:error, exception}` (rescued struct) — none of the inspected paths return a bare `%Ecto.Changeset{}`. If it is genuinely unreachable it is dead code; if it is reachable it can crash. Either way it needs attention.

**Fix:** Avoid `to_existing_atom`; look the key up by string or fall back without atom conversion, and never raise:
```elixir
defp error_message(%Ecto.Changeset{} = changeset) do
  changeset
  |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts
      |> Enum.find_value(key, fn {k, v} -> if to_string(k) == key, do: to_string(v) end)
    end)
  end)
  |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
end
```
If the clause is in fact unreachable, drop it instead.

### WR-02: `document.body.focus()` fallback does not move focus (accessibility regression on focus return)

**File:** `priv/templates/sigra.install/admin/admin_hooks.js:485-489` (and identical `test/example/assets/js/admin_hooks.js:485-489`)
**Issue:** The new `destroyed()` fallback for ConfirmDialog focus return is:

```js
if (this._trigger && document.contains(this._trigger) && this._trigger.focus) {
  this._trigger.focus();
} else {
  document.body.focus();
}
```

`document.body` is not focusable by default (it has no `tabindex`), so `document.body.focus()` is effectively a no-op — focus stays on whatever the now-removed dialog element was, which the browser then resets to `<body>` as the *active element* but without a focus ring or a deterministic tab origin. The comment frames this as the recovery path "when the trigger has been removed from the DOM (e.g. after a LiveView patch that replaces the triggering element)" — exactly the case where graceful focus restoration matters most for keyboard/AT users. The guard added value (avoid focusing a detached node) but the fallback does not actually relocate focus.

Note: the keyboard specs only exercise the happy path where the trigger is NOT replaced (dialog close just nulls `confirm_action`), so this fallback branch is never covered by the new tests despite the `WR-02:` comment suggesting it was addressed.

**Fix:** Focus a stable, always-present landmark such as the admin shell or main heading, e.g.:
```js
} else {
  var fallback = document.querySelector('.sg-admin-shell') || document.body;
  if (fallback && fallback.focus) {
    if (fallback === document.body) fallback.setAttribute('tabindex', '-1');
    fallback.focus();
  }
}
```

### WR-03: Platform-admin breadcrumb assertion is weaker than its stated intent (scope reconstruction not actually verified)

**File:** `test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts:113-119`
**Issue:** Step 7 comments "Return via breadcrumb — URL must have ?q= param (scope reconstructed)" and "Breadcrumb back-link carries the filtered list scope (D-12)", but the actual assertion only checks:

```js
expect(usersHref).toMatch(/\/admin\/users/);
```

`/\/admin\/users/` matches the bare list URL with no query string, so the test passes even if scope/`?q=` reconstruction is completely broken — the exact FLOW-01/D-12 property this step claims to guard. The earlier assertion at line 99-102 does check `/return_to|\/admin\/users\?/`, but step 7's audit-page breadcrumb is asserted only against the bare path.

**Fix:** Tighten to the documented contract:
```js
expect(usersHref).toMatch(/\/admin\/users\?.*(q=|return_to=)/);
```

### WR-04: `data-tone="danger"` empty-state guard targets a tone value the design system does not appear to emit

**File:** `test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts:209-212`
**Issue:** The "empty ≠ broken" guard asserts there is no error-tone styling on the empty search result:

```js
const errorEl = page.locator('[data-tone="danger"], .sg-status-pill[data-tone="danger"]').filter({
  hasText: /error|failed/i,
});
await expect(errorEl).toHaveCount(0);
```

Across the reviewed LiveViews the risk tone value emitted is `"risk"` (e.g. `user_show_live.ex:442` `{"Locked", "risk"}`, `data-tone={tone}` at line 111) and notices use `tone={:risk}` (branding_live.ex:108). No `data-tone="danger"` was observed in the reviewed sources. A selector that can never match makes `toHaveCount(0)` vacuously true — the guard provides false assurance that an error style is absent. This is a test-correctness defect (the assertion does not test what it claims), not a product bug.

**Fix:** Assert against the tone the system actually emits (`risk`), and confirm the value by grepping the rendered admin markup before committing:
```js
const errorEl = page.locator('[data-tone="risk"]').filter({ hasText: /error|failed/i });
await expect(errorEl).toHaveCount(0);
```

## Info

### IN-01: `admin_hooks.js` is duplicated byte-for-byte across template and example with no sync guard

**File:** `priv/templates/sigra.install/admin/admin_hooks.js` and `test/example/assets/js/admin_hooks.js`
**Issue:** The two files are identical (1141 lines each) and were edited in lockstep in this diff. Per the project's known "installer template drift" hazard (MEMORY: `reference_installer_template_drift.md`), hand-maintaining two copies invites silent divergence where the example passes but generated hosts ship stale JS. There is no test asserting the two are equal.
**Fix:** Add a cheap CI/test guard asserting the two files are identical (e.g. a byte-comparison in an existing template-parity test), or generate one from the other.

### IN-02: Misleading `WR-02:` inline comment references a finding the code does not fully resolve

**File:** `priv/templates/sigra.install/admin/admin_hooks.js:482-484`
**Issue:** The comment block labeled `WR-02:` documents the `document.body.focus()` fallback as the fix for trigger-removed focus return, but as noted in WR-02 above the fallback does not actually move focus. Carrying a prior review-finding ID inline as if resolved can mask the residual gap in future reviews.
**Fix:** Update the comment to describe actual behavior, or implement a real focus target (see WR-02).

### IN-03: `assertScopeChrome` org-vs-global label assumption is brittle and undocumented at call sites

**File:** `test/example/priv/playwright/helpers/adminFlows.ts:120-129`
**Issue:** `assertScopeChrome` asserts an exact `"Admin"` text and a substring `scopeLabel`. For org scope the comment notes the chrome renders `"Org · {name}"`, so passing `'Acme Corp'` relies on substring matching tolerating the prefix glyph. If the chrome copy changes the prefix (e.g. to `"Organization:"`), the substring still matches by name, but a regression that drops the scope distinction entirely (org rendering "Global") would not be caught by the org specs since they only assert the org name substring. Low risk, but the helper hides a coupling worth a note.
**Fix:** Optionally assert the scope-kind marker explicitly for org calls (e.g. that `"Org"` or a tenant chip is present) rather than name-only.

### IN-04: Repeated sudo + impersonation boilerplate duplicated across two specs

**File:** `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts:110-124, 217-232, 277-287`
**Issue:** The "preserve detail URL → goto /users/sudo?return_to → fill password → Confirm → Start impersonation" sequence is copy-pasted three times within the file. `adminFlows.ts` already centralizes login/theme/scope helpers; this journey fragment is a natural candidate for a shared helper to avoid drift between the happy-path, keyboard, and theme variants.
**Fix:** Extract a `startImpersonation(page, detailUrl, password)` helper into `adminFlows.ts`.

### IN-05: Unused imports in flow specs

**File:** `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts:35` and `admin-flow-platform-admin.spec.ts:38`
**Issue:** `DEMO_ADMIN_EMAIL` is imported but not referenced in either support-investigator or platform-admin specs (only `DEMO_ADMIN_PASSWORD` is used in the support spec; platform spec uses neither `DEMO_ADMIN_EMAIL` nor `DEMO_ADMIN_PASSWORD` beyond the password in the keyboard/theme blocks — confirm with the linter). Dead imports add noise and can mask real removals.
**Fix:** Remove unused named imports; rely on `loginDemoAdmin()` which encapsulates the credentials.

---

_Reviewed: 2026-06-17T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
