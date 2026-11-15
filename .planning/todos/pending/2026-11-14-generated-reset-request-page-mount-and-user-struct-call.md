---
created: 2026-11-14T00:00:00.000Z
status: pending
title: Generated password-reset request page may crash on mount, and the generated callers pass a user struct to a binary-only function head
area: auth
severity: major
source: Phase 259 verification gap closure
files:
  - lib/sigra/install/features/core.ex
  - priv/templates/sigra.install/core/reset_password_live.ex
  - priv/templates/sigra.install/core/reset_password_controller.ex
  - priv/templates/sigra.install/core/auth.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/reset_password_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/reset_password_controller.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
  - guides/flows/password-reset.md
  - test/fixtures/brand/public-surfaces.json
  - test/example/test/example_web/enumeration_parity_test.exs
---

Duplicate check before filing: searched `.planning/todos/pending` and `.planning/seeds` for `reset-password`, `ResetPasswordLive`, `reset_password_live` and `deliver_user_reset_password_instructions`. Two files matched and neither covers either defect: `2026-11-13-lockout-and-rate-limit-enumeration-channels.md` cites the same generated callers only as evidence for the enumeration-timing channel, and `SEED-010-auth-pages-daisyui-unbranding.md` lists the template for class unbranding. No pending todo records the request page mount crash or the user-struct call, so this one is new.

Labels used below: **executed** means a test or a run reproduced it. **read in source, not executed** means the claim comes from reading the file at the cited line and nothing was run against a generated host.

## Registry row

`password-reset-request` in `test/fixtures/brand/public-surfaces.json` is parity for the EXAMPLE host only. The example host (`test/example`) was repaired in Plan 259-14, which is what let the row flip to `parity`. This todo tracks the generated host, which the row does not compare. A green row says nothing about what `mix sigra.install` writes into an adopter app.

## Observed behaviour, defect 1: the request page may raise on mount for a `--live` install

- `lib/sigra/install/features/core.ex:410-411` emits `live "/reset-password", ResetPasswordLive` (no live action) and `live "/reset-password/:token", ResetPasswordLive, :edit`. The committed golden router shows the same shape (`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex:119-120`).
- The generated view decides everything by live action. `priv/templates/sigra.install/core/reset_password_live.ex:15` renders `live_action: :new`, `:49` renders `live_action: :edit`, and `mount/3` does `case socket.assigns.live_action do` at `:132` with only `:new` and `:edit` clauses.
- A route with no action leaves `live_action` as `nil`, so for a `--live` install the request page appears to raise a `CaseClauseError` at mount, and the `:new` render clause cannot match either. This is **read in source, not executed**: no browser test, no `install_smoke` step and no generated-host probe mounts `/users/reset-password` (see the coverage gap in `2026-07-28-w3-generated-auth-runtime-coverage-is-login-only.md`).
- The example host reproduced exactly this and it was **executed**: before Plan 259-14 the parity suite showed five failures, all `CaseClauseError ... nil` raised from `ResetPasswordLive.mount/3`. Plan 259-14 repaired it there with `live "/reset-password", ResetPasswordLive, :new` (`test/example/lib/example_web/router.ex:119`). The generated installer was not touched.
- The non-live installer branch (`lib/sigra/install/features/core.ex:416-419`, `ResetPasswordController`) does not route through a live action, so defect 1 is specific to the `--live` flavor. **Read in source, not executed.**

## Observed behaviour, defect 2: a user struct is passed to a head that requires a binary

- The generated context defines exactly one head: `def deliver_user_reset_password_instructions(email, reset_password_url_fun) when is_binary(email) and is_function(reset_password_url_fun, 1)` at `priv/templates/sigra.install/core/auth.ex:428-429`. The committed golden shows the same single head (`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex:428-429`).
- Both generated callers look the account up first and pass the struct. The controller at `priv/templates/sigra.install/core/reset_password_controller.ex:23-29` (`if user = ...get_user_by_email(email)` then `deliver_user_reset_password_instructions(user, ...)`), and the LiveView at `priv/templates/sigra.install/core/reset_password_live.ex:154-160`. The committed golden shows the same calls (`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/reset_password_controller.ex:23-28`, `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/reset_password_live.ex:154-159`).
- For an existing account this reads as a `FunctionClauseError`, because a struct is not a binary. **Read in source, not executed** for the generated host. It was **executed** for the example host: restoring the user-struct call in the example turned five parity tests red with `FunctionClauseError ... deliver_user_reset_password_instructions/2` (Plan 259-14 mutation proof).
- An unknown address never reaches the function, so the request appears to succeed for an unknown address and to crash for a known one. That is itself an account-existence signal, on top of being a plain defect. Read in source, not executed.
- The context function is designed to be the enumeration-safe entry point (it looks the account up itself and answers `{:ok, :sent}` for an unknown address), so the callers' `if user = ...` precheck is also redundant and bypasses the limiter and the dummy-hash timing work for unknown addresses; that part is tracked in `2026-11-13-lockout-and-rate-limit-enumeration-channels.md`.

## Other places that still carry the struct call

- The example host's unrouted `ExampleWeb.ResetPasswordController` copy still passes the struct (`test/example/lib/example_web/controllers/reset_password_controller.ex:24-28`). It is not routed in the example, so nothing runs it; it only misleads a reader.
- The published guide shows it twice: the request-handler snippet (`guides/flows/password-reset.md:20-25`, a handler named `send_reset`, where the generated one is `send_instructions`) and the testing snippet (`guides/flows/password-reset.md:140`, `deliver_user_reset_password_instructions(user, ...)`). Plan 259-10 already softened the surrounding claim ("is meant to show"); the snippets themselves are unchanged.
- No template-versus-example parity guard exists (`2026-09-17-fut-01-template-example-parity-guard.md`), which is why the example repair did not carry over to the template and why this gap stayed invisible.

## Suggested fix (not done here)

1. Route the live action in `lib/sigra/install/features/core.ex`: `live "/reset-password", ResetPasswordLive, :new`. `test/sigra/install/generator_wiring_test.exs:190` asserts `live "/reset-password", ResetPasswordLive` as a substring, so it keeps passing.
2. Call the context with the binary email unconditionally in both generated callers (drop the `get_user_by_email` precheck and let the context own the lookup), in `reset_password_controller.ex` and `reset_password_live.ex`.
3. Update the guide snippets (request handler and the testing snippet) to pass the binary email.
4. Rebless the golden install fixture under the pinned `phx_new` 1.8.8 archive (`mix test test/sigra/install/golden_diff_test.exs --only snapshot`, then commit `test/fixtures/install_golden/`).
5. Add a runtime check, either `install_smoke` or a generated-host browser test, that mounts `/users/reset-password` for a `--live` install and submits it for an existing and for an unknown address, and asserts the token row (one `reset_password` token for the existing account, none for the unknown one) and the same flash for both.
6. Adopters who already generated their host keep the old files until they copy the change, so the changelog entry has to say so.

## Why this was not fixed in Phase 259

Phase 259 ships zero bytes under `lib/` and `priv/`. The example host is test code and was repaired in Plan 259-14 so the parity row could be proven honestly; the generated host is a shipped byte. Repairing only the example without filing this would have hidden a real adopter defect behind a green row, so it is filed here. No entry is opened in `.planning/WINDOWS.md`, because an open entry blocks shipping and this is a scope limit of the phase, not a defect introduced by it.

## Shrink discipline

When the generated host is fixed and a generated-host probe exists, the "generated host not compared" sentence in the `password-reset-request` row note can be retired and this todo closed. Until then the row's `todo` field keeps this path, and `test/example/test/example_web/enumeration_parity_test.exs` asserts that the path stays in the registry and stays a real file, so a registry edit that drops the reference goes red.
