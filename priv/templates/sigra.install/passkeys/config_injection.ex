
# Sigra passkeys
config :<%= otp_app %>, :sigra_config,
  passkeys: [
    rp_id: "localhost",
    rp_name: "<%= app_name %>",
    origin: "http://localhost:4000",
    timeout_ms: 60_000,
    attestation: :none,
    user_verification: :preferred,
    ceremony_rate_limit: [limit: 5, window_ms: 60_000],
    passkey_primary_enabled: true,
    user_passkey_schema: <%= context_module %>.UserPasskey
  ]
