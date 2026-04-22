---
phase: 41
slug: backup-codes-ga-product-closure
status: draft
shadcn_initialized: false
preset: none
created: 2026-04-20
---

# Phase 41 — UI Design Contract

> Regenerate backup codes + MFA settings surfaces. Locked to **41-CONTEXT** (D-41-01..D-41-05); no visual redesign beyond what security copy requires.

---

## Design System

| Property | Value |
|----------|-------|
| Component library | Existing Phoenix CoreComponents + Tailwind utility classes in **`mfa_settings_live.ex`** |
| Icon library | Heroicons (`hero-*`) as already used on the page |
| Layout | In-card gray panel (`bg-gray-50`, `border-gray-200`) matching current MFA settings card |

---

## Surfaces in Scope

| Surface | Route / entry | Notes |
|---------|----------------|-------|
| Regenerate panel | Same LiveView as today: `show_regenerate` → `#mfa_regenerate_form` | Must stop flashing success without rotation |
| Post-rotation codes | Reuse **`render_backup_codes/1`** path (`@enrollment_step == :backup_codes` or equivalent assign) | Same acknowledge / download UX as enrollment |
| Router | `/users/settings/mfa` | Must use **`pipe_through [:browser, :require_authenticated, :require_sudo]`** (install golden reference) |

---

## Interaction Contract

1. **Step-up:** User must already be in **sudo** session to load MFA settings (router), matching passkey POST scopes.
2. **Regenerate gate:** Submitting the form sends **TOTP only** (six digits). **Do not** accept backup codes as proof of rotation (D-41-01).
3. **Passkey (target before close):** When passkeys exist for the user, offer **passkey assertion** as an alternative to TOTP in the **same** regenerate panel (single settings flow; preferred when enrolled). Exact CTA labels TBD in implementation but must not imply backup codes can authorize rotation.
4. **Success:** On `{:ok, %{backup_codes: codes}}`, show new codes once (existing backup code render), clear regenerate panel, refresh `backup_remaining`.
5. **Failure:** Map `{:error, _}` to **error** flash (not info); preserve form or clear per existing error patterns on this LiveView.

---

## Copywriting (minimum)

| State | Copy constraint |
|-------|-----------------|
| Regenerate intro | Must state old codes **stop working** after success (replacement semantics). |
| No TOTP + no passkey | Honest message: cannot rotate here; point to account recovery / admin — **no** fake success. |
| Lockout / invalid | Reuse vocabulary consistent with disable / verify errors on the same page. |

---

## Out of Scope

- GA-02..05 evidence matrix (phase 42).
- AUD-06 batch for other MFA `log_safe` sites.
- New standalone route for regeneration (keep LiveView event model).
