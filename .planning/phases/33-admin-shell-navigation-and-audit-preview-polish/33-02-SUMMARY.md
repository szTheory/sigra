# Phase 33 / Plan 02 Summary — INT-05 Recent Audit Presenter

## Path

- **D-02 / flip-in-place:** `recent_audit_preview/3` now loads events, builds `users_by_id` via cloned `load_audit_users/2` (mirrors `Sigra.Admin.Audit.Explorer` `load_users/2`), and returns `Sigra.Admin.Audit.Presenter.present(events, users_by_id)`. No `recent_audit_preview_presented/3` helper.

## Contract

- `@spec recent_audit_preview(map(), Scope.t(), binary()) :: [map()]`
- `@doc` lists guaranteed keys: `:id`, `:inserted_at`, `:action`, `:action_label`, `:action_badge`, `:actor_label`, `:effective_user_label`, `:actor_summary`, `:outcome`, with guidance that preview renderers must not invent fields outside Presenter.

## UserShowLive

- Recent Audit block: `:for={row <- @detail.recent_audit}` with subset render: conditional `row.action_badge` badge (`badge badge-warning badge-sm`), `row.action_label`, `row.actor_summary`, `Calendar.strftime(row.inserted_at, ...)`. Raw `row.action` / `outcome` / split actor labels not shown. View full audit CTA unchanged.

## Tests

- `test/sigra/admin/users_actions_test.exs`: third assertion replaced with `assert Enum.all?(preview, &(&1.action in ["session.delete", "session.revoke_all"]))` because `:target_id` is not a Presenter key.

## External callers

- Grep at execution: `recent_audit_preview` external assertion usage remains the single `users_actions_test.exs` block updated above; `Detail.load!/3` internal call unchanged.
