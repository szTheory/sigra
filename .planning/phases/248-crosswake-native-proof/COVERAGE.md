# Phase 248 External Package/API Coverage

The deterministic API coverage detector fired for the released Crosswake package integration. The phase integrates the complete capability surface needed by XW-01 and explicitly excludes unrelated released capabilities.

| capability | decision | reason |
|---|---|---|
| `crosswake` 0.2.0 native shell/core contract | INTEGRATE | D-03 requires the released native-shell boundary for both host-owned example shells. |
| `Crosswake.Offline.Journal` entry vocabulary | INTEGRATE | D-02 maps the native outbox identity onto the released journal fields. |
| `Crosswake.Offline.Replay` request vocabulary | INTEGRATE | D-02 requires released request construction for replay correlation. |
| `Crosswake.Offline.Replay` accepted/rejected/conflict outcomes | INTEGRATE | D-02 requires exact mapping while the Phoenix host remains terminal authority. |
| `Crosswake.Companions.Sigra.AuthReturn.NativeEvidence` | INTEGRATE | D-03/D-04 require typed fact-only native return evidence after local validation. |
| `Crosswake.Companions.Sigra.AuthReturn.Envelope` | INTEGRATE | The existing host adapter validates the released return envelope before evaluation. |
| `Crosswake.Companions.Sigra.Evaluator` route decision | INTEGRATE | D-01 extends the existing fresh-host projection seam without moving authority. |
| `Crosswake.Companions.Sigra.Telemetry` allowlist/filter | INTEGRATE | D-04/D-15 require bounded native outcome telemetry and forbidden-field filtering. |
| Crosswake auth handoff contracts | OPT-OUT | Phase 246 hosted PKCE and one-time code exchange remain the sole native login ceremony. |
| Crosswake passkey return contracts | OPT-OUT | Phase 248 proves hosted public-client login, not a passkey ceremony. |
| Crosswake step-up contracts | OPT-OUT | Step-up issuance and consumption are outside XW-01/NAT-01/NAT-02. |
| Crosswake OAuth evidence contracts | OPT-OUT | OAuth/OIDC delegation belongs to Lockspire and is outside the first-party session proof. |
| Crosswake route registry generation | OPT-OUT | The example extends an existing host-owned route projection and does not publish a registry or SDK. |
| Crosswake reusable native SDK/UI surface | OPT-OUT | D-03 and milestone exclusions permit only host-owned example shells and phase evidence. |

