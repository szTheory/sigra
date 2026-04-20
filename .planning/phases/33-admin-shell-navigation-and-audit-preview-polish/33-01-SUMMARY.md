# Phase 33 / Plan 01 Summary — INT-04 Admin Shell Users Navigation

## Delivered

- **Top-bar:** `<.scope_switch_link href={users_link(@admin_scope)} active={users_active?(@admin_scope)}>` for Users, placed before Global/Organization (matches example).
- **Desktop sidebar:** Operations block moved before Overview (D-11); first Operations item is a live `<a href={users_link(@admin_scope)}>` for Users; dead `<li><span...>Users</span></li>` removed.
- **Mobile bottom-nav:** Users `<a>` with `btm-nav-label` inserted first, before Global.
- **Helpers:** `users_link/1` (org + global clauses) added before `audit_link/1`; `users_active?/1` stub added. `audit_link/1` and all other untouched helpers left unchanged per D-12.

## Drift guard

- Fixture id: `fix #18 — admin_shell users nav + mobile bottom-nav` in `test/sigra/templates/installer_drift_test.exs` (17 → 18 fixtures).

## Example app test

- `test/example/test/example_web/admin_shell_test.exs`: added `assert html =~ "href=\"/admin/users\""` after the existing `"Users"` assertion (link liveness).

## Parity fix (drift gate)

- `test/example/lib/example_web/live/confirmation_live.ex`: added `_user = socket.assigns.current_scope.user` inside token `handle_params` so fix #9 template/example drift passes (unrelated to INT-04 but required for green `installer_drift_test.exs`).

## Deviations

- None from `33-PATTERNS.md`; implementation follows the plan verbatim.
