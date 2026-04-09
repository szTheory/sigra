defmodule Sigra.AuditSensitiveDataTest do
  use ExUnit.Case, async: true

  # Wave 0 D-23 regression net.
  #
  # For every forbidden metadata key, assert the changeset rejects it in
  # both atom and string form. Plan 02 implements Sigra.Audit.Changeset
  # and forbidden_keys/0; this test goes green when it lands.
  #
  # NOTE: Forbidden keys are looked up at RUNTIME, not via @attribute, so
  # this file compiles even before Plan 02 defines the module.
  #
  # The full parameterized sweep over D-26 operations (driving Auth/MFA/OAuth)
  # is added as part of Plan 03 task completion — see PLAN.md notes.

  test "Changeset rejects every forbidden key (atom + string variants)" do
    forbidden = Sigra.Audit.Changeset.forbidden_keys()

    for key <- forbidden, variant <- [key, Atom.to_string(key)] do
      attrs = %{
        action: "test.event.one",
        outcome: "success",
        occurred_at: DateTime.utc_now(),
        metadata: %{variant => "SENSITIVE"}
      }

      cs =
        Sigra.Audit.Changeset.changeset(
          %Sigra.Test.AuditEvent{},
          attrs,
          allow_reserved: true
        )

      refute cs.valid?, "expected forbidden key #{inspect(variant)} to be rejected"
    end
  end

  test "forbidden_keys/0 includes the canonical D-23 set" do
    keys = Sigra.Audit.Changeset.forbidden_keys()

    # Anchor a non-empty subset that MUST be present per Phase 1 D-17 +
    # Phase 9 D-23. Plan 02 may extend this list, but never shrink it.
    for required <- [:password, :password_hash, :token, :refresh_token, :totp_code] do
      assert required in keys, "expected forbidden_keys to include #{required}"
    end
  end
end
