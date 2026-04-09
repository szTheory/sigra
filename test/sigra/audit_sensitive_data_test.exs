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

  # --- Plan 09-03 regression net ---
  #
  # One test per D-26 subsystem touched in Plan 09-03 Task 2. Each test
  # builds the metadata map that the subsystem integration site passes
  # into Sigra.Audit.log_safe/3, then asserts via Sigra.Audit.Changeset
  # that the metadata is clean (no forbidden keys). This is a static
  # regression against D-23; it does not require a live Repo because
  # the property under test is metadata-shape purity.
  #
  # Full end-to-end tests (driving the real subsystem functions through
  # a sandboxed repo) land in a later wave that wires up real DB fixtures.

  defp assert_metadata_clean(metadata) do
    attrs = %{
      action: "test.event.one",
      outcome: "success",
      occurred_at: DateTime.utc_now(),
      metadata: metadata
    }

    cs =
      Sigra.Audit.Changeset.changeset(
        %Sigra.Test.AuditEvent{},
        attrs,
        allow_reserved: true
      )

    assert cs.valid?,
      "expected metadata #{inspect(metadata)} to pass Sigra.Audit.Changeset; errors: #{inspect(cs.errors)}"
  end

  @tag :sensitive_data
  test "MFA integration metadata contains no forbidden keys" do
    # Derived from lib/sigra/mfa.ex integration sites (Plan 09-03 Task 2)
    metadatas = [
      %{method: "totp"},
      %{method: "backup_code"},
      %{method: "totp", attempts: 3},
      %{method: "totp", duration: 900},
      %{remaining: 5},
      %{admin: false},
      %{admin: true},
      %{count: 8}
    ]

    for meta <- metadatas, do: assert_metadata_clean(meta)
  end

  @tag :sensitive_data
  test "OAuth integration metadata contains no forbidden keys" do
    # Derived from lib/sigra/oauth.ex integration sites (Plan 09-03 Task 2).
    # Critically: no access_token, refresh_token, oauth_secret, client_secret.
    metadatas = [
      %{provider: "google"},
      %{provider: "github", outcome: "registered"},
      %{provider: "google", outcome: "logged_in"},
      %{provider: "google", reason: "provider_error"},
      %{provider: "gitlab"}
    ]

    for meta <- metadatas, do: assert_metadata_clean(meta)
  end

  @tag :sensitive_data
  test "APIToken integration metadata contains no forbidden keys" do
    # Derived from lib/sigra/api_token.ex integration sites.
    # Critically: no raw token, no hashed_token, no bearer_token.
    metadatas = [
      %{name: "ci_deploy_key", scopes: ["profile:read"]},
      %{reason: "invalid_token"},
      %{reason: "token_revoked"},
      %{reason: "token_expired"},
      %{token_id: "abc-123"}
    ]

    for meta <- metadatas, do: assert_metadata_clean(meta)
  end

  @tag :sensitive_data
  test "Account integration metadata contains no forbidden keys" do
    # Derived from lib/sigra/account.ex integration sites.
    # Critically: no password, password_hash, password_confirmation.
    metadatas = [
      %{},
      %{forced: false},
      %{forced: true},
      %{forced: false, source: "oauth_set"}
    ]

    for meta <- metadatas, do: assert_metadata_clean(meta)
  end
end
