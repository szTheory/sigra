---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Passkey sign-in options endpoint answers differently for an existing email than for an unknown one
area: security
severity: major
source: Phase 259 enumeration parity harness
files:
  - priv/templates/sigra.install/core/session_controller.ex
  - priv/templates/sigra.install/passkeys/router_injection.ex
  - test/example/lib/example_web/controllers/session_controller.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/session_controller.ex
  - test/fixtures/brand/public-surfaces.json
  - test/example/test/example_web/enumeration_parity_test.exs
---

Registry row: `passkey-signin-options` in `test/fixtures/brand/public-surfaces.json` (state `known_divergence`, compared dimensions `status` and `json_keys`). This todo is the fix tracking for that row.

## Observed behaviour

`POST /users/log_in/passkey/options` with an email looks the account up and answers differently depending on the result.

- `priv/templates/sigra.install/core/session_controller.ex:141-146`: `passkey_authentication_options/2` calls `Auth.get_user_by_email(email)`; an unknown email returns `json(conn, %{error: "unavailable"})` (line 146).
- `priv/templates/sigra.install/core/session_controller.ex:148-153`: an existing email issues a challenge and returns an object with the key `options`.
- Same shape in the example host: `test/example/lib/example_web/controllers/session_controller.ex:171-190` (unknown email at lines 175-176).
- The generated output carries it: `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/session_controller.ex:146`.
- The route is added by `priv/templates/sigra.install/passkeys/router_injection.ex:13`; the route string is in the frozen surface (`test/fixtures/brand/frozen-surface.json:660`), so a fix changes the response, not the route or the action name.

The harness asserts both answers carry HTTP 200 and differ on exactly one dimension, the top-level JSON keys (`error` versus `options`). That is the whole of what it compares; the body values are not compared because the existing-email body holds a per-request challenge.

Read in source, not compared by the harness: for an existing email the `options` object also carries `allowCredentials` built from that account's stored passkeys (`priv/templates/sigra.install/core/session_controller.ex:370` and `:385-391`: credential id and transports), so the existing-email answer discloses more than the fact that the account exists.

Not affected: the email-less conditional flow (`conditional: "true"`, `priv/templates/sigra.install/core/session_controller.ex:134-139`) involves no identity. The harness asserts two anonymous calls match on status and JSON keys.

## Why it matters

Any anonymous caller can ask, one address at a time, whether an address has an account, without a password and without sending an email. The parity registry therefore cannot list this surface as `parity`, and no document may cite it as evidence that sign-in is protected against account discovery. Nothing in this phase changes the behaviour: Phase 259 ships zero bytes under `priv/` and `lib/`.

## Proposed fix direction

Pick one, then prove it with the harness:

1. Answer an unknown email with an object that has the same top-level keys as the existing-email answer (a decoy challenge and an empty or decoy `allowCredentials`), so the two are the same on the compared dimensions; or
2. Stop accepting an email on this endpoint and drive the whole sign-in through the discoverable (conditional) flow, which carries no identity.

A change to `priv/templates/sigra.install/core/session_controller.ex` also needs the example host copy updated (`test/example/lib/example_web/controllers/session_controller.ex`) and the golden install fixture reblessed (`mix test test/sigra/install/golden_diff_test.exs --only snapshot`, then commit `test/fixtures/install_golden/`), so a green parity claim for this surface needs that later `priv/templates` plan, not a registry edit. Adopters who already generated their host keep the old controller until they copy the change; say so in the changelog entry.

## Shrink discipline

The harness test "every known_divergence row still differs on exactly the registered dimensions" goes red the moment this is fixed. Fixing it requires removing or changing the `passkey-signin-options` row in `test/fixtures/brand/public-surfaces.json` (to `parity` with the dimensions actually compared, or removing it), updating `@expected_divergence_dims` in `test/example/test/example_web/enumeration_parity_test.exs`, and then closing this todo and dropping its path from the row. A `parity` row would still be bounded to the compared dimensions: status and top-level JSON keys for one request.
