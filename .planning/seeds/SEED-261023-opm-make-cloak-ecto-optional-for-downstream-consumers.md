---
id: SEED-261023-opm
status: dormant
planted: 2026-10-23
planted_during: "v1.50 CI-SPEED-AND-RELIABILITY / Phase 254; downstream request capture only"
trigger_when: "At the next milestone scope review after v1.50, regardless of theme; also before the next dependency-security or Hex release maintenance batch"
scope: "Small dependency and generator compatibility fix, with isolated consumer regression and verified Hex release"
related:
  - .planning/seeds/SEED-261023-9t1-evaluate-built-in-aes-gcm-ecto-encryption.md
---

# SEED-261023-opm: Make cloak_ecto optional for downstream consumers

## Why This Matters

The scrypath project reports that `scrypath_ops` declares `{:sigra, "~> 1.5.0", optional: true}` and inherits Hex audit findings through Sigra's required `cloak_ecto` dependency. Making Sigra optional in scrypath_ops does not remove Sigra's required transitive dependencies when Sigra is selected. Consumers that do not use generated at-rest encryption should not install Cloak.

The requested near-term fix is `{:cloak_ecto, "~> 1.3", optional: true}` in Sigra, with explicit host dependency handling wherever generators emit Cloak code. Hosts that need encryption will still install the affected packages; optionality does not patch those packages or suppress their audit findings.

## When to Surface

**Trigger:** Review for inclusion at the first milestone scope review after v1.50, regardless of theme, or sooner in a separately scoped dependency-security/Hex maintenance batch. Do not silently add this product change to Phase 254's running CI recovery or Phase 255. Do not defer it until a full encryption redesign.

OpenGSD's `$gsd-new-milestone` seed scan should present this request for explicit scope selection. If a maintenance release is planned before that review, include this seed in its triage. Capture is complete; implementation, runtime verification, and publication are all pending.

## Findings Checked on 2026-10-23

Source inspected at HEAD `7d9884ec3`:

- `mix.exs:118` declares `{:cloak_ecto, "~> 1.3"}` without `optional: true`.
- Both `priv/templates/sigra.install/core/vault.ex` and `priv/templates/sigra.gen.oauth/vault.ex` configure `Cloak.Ciphers.AES.GCM`. Their encrypted-binary templates use `Cloak.Ecto.Binary`.
- A search of `lib/` and `priv/templates/` found no AES.CTR or PBKDF2 usage. Cloak names in `lib/` are documentation, comments, or instruction strings; no direct Cloak compile-time use was found. A clean compile without Cloak has NOT been run and remains a required acceptance check.
- `lib/mix/tasks/sigra.gen.oauth.ex:182` checks the host project's dependency list and raises with the exact dependency declaration and `mix deps.get` instruction if absent.
- `lib/sigra/install/features/core.ex:261` emits the real vault/type when `encrypts_anything?/1` is true. Check this implementation, rather than assuming all installer logic remains in the Mix task.
- `lib/sigra/upgrade.ex:354` also emits Cloak-dependent code when promoting an existing encryption stub. Include that route in dependency checks and regression coverage.
- Doctor obtains encryption posture from `Sigra.OptionalDeps.encryption_active?/1`, which examines the host encryption module's marker and does not load Cloak. Preserve the distinction between a real vault and a plaintext stub.
- Hex API metadata on the capture date reports cloak **1.1.4**, cloak_ecto **1.3.0**, and Sigra **1.20.0** as latest stable. Both Sigra 1.7.1 and 1.20.0 release requirements mark cloak_ecto `optional: false`. This checkout's `mix.exs` and `.release-please-manifest.json` still say **1.5.0**. Reconcile the intended release branch and published versions before choosing a new version; do not publish an already-used version or infer release readiness from the local version field.

Primary advisory records, checked on the capture date:

- [EEF-CVE-2026-95105](https://cna.erlef.org/cves/CVE-2026-95105.html): HIGH, AES-CTR ciphertext can be altered without authentication. The advisory recommends AES-GCM. Its vulnerable cipher paths are absent from the inspected Sigra templates; this is a source-based applicability assessment, not an exemption for arbitrary host customizations.
- [EEF-CVE-2026-94206](https://cna.erlef.org/cves/CVE-2026-94206.html): MEDIUM, Cloak.Ecto.PBKDF2 uses the size value as its iteration count. That field is absent from the inspected templates.
- Release metadata: [cloak](https://hex.pm/api/packages/cloak), [cloak_ecto](https://hex.pm/api/packages/cloak_ecto), [Sigra 1.7.1](https://hex.pm/api/packages/sigra/releases/1.7.1), [Sigra 1.20.0](https://hex.pm/api/packages/sigra/releases/1.20.0). Recheck release/advisory status when implementing; no fixed current release was identified at capture.

## Implementation and Acceptance

1. Make cloak_ecto optional in Sigra's package dependencies. Inspect the resulting Hex package dependency metadata as well as source.
2. Before emitting Cloak-dependent vault/type code, either safely add `{:cloak_ecto, "~> 1.3"}` to the host's mix.exs or fail with an actionable instruction to add it, run `mix deps.get`, and retry. Cover installer encryption feature combinations, OAuth generation, and upgrade vault promotion. Keep repeated runs safe and avoid leaving an unexplained partial install. Existing host declarations must continue to work.
3. Add an isolated consumer fixture/subprocess check that declares Sigra without cloak_ecto, resolves its dependencies, asserts BOTH `cloak` and `cloak_ecto` are absent from the resolved graph, and compiles Sigra with warnings treated as errors. Use a separate build/deps directory so root development dependencies and precompiled BEAM files cannot hide a missing guard. A root project compile or assertion about the optional flag alone is insufficient: Mix can install optional dependencies in their declaring project.
4. Exercise `mix sigra.doctor` in that absent-dependency consumer. The `encryption (cloak_ecto vault)` row must report an appropriate missing/disabled state and a useful hint without crashing. Preserve the existing failure behavior when a configured feature requires encryption but has only a stub or missing type.
5. Test a host explicitly declaring cloak_ecto: generated vault/type compile, encryption round-trips succeed, and tampering is rejected. Verify installer, OAuth, and upgrade paths, including their missing-dependency instructions. Keep plaintext stubs from being reported as encryption.
6. Add a CHANGELOG migration note: hosts using Sigra's at-rest encryption for MFA/TOTP secrets, OAuth tokens, or passkeys must explicitly declare cloak_ecto. State that generated vaults use authenticated AES-GCM and do not use the AES-CTR or PBKDF2 paths in these advisories. Do not claim optionality fixes Cloak for encryption hosts. Update relevant install/upgrade guidance; follow MAINTAINING.md's template-update instructions if templates change.
7. Deliver a tested patch/minor through the repository's normal release process (`MAINTAINING.md`, release-please configuration, CI gate, Hex publication). Record the actual published version, tag/commit, and package metadata showing optionality. Report that version for scrypath_ops to adopt, and verify an updated downstream consumer excludes both packages when it does not opt in. `~> 1.5.0` excludes 1.6+; a release in a later minor requires a changed downstream requirement. Do not invent a version during planning or mark a tag alone as a published Hex release.

## Breadcrumbs

- `mix.exs`, `.release-please-manifest.json`, `release-please-config.json`, `.github/workflows/release-please.yml`, `MAINTAINING.md`, `CHANGELOG.md`
- `priv/templates/sigra.install/core/{vault,encrypted_binary,encrypted}.ex`
- `priv/templates/sigra.gen.oauth/{vault,encrypted_binary}.ex`
- `lib/sigra/install/features/core.ex`, `lib/sigra/upgrade.ex`, `lib/mix/tasks/sigra.gen.oauth.ex`
- `lib/sigra/doctor.ex`, `lib/mix/tasks/sigra.doctor.ex`, `lib/sigra/optional_deps.ex`
- `test/sigra/install/vault_promotion_test.exs`, `test/sigra/install/oauth_generator_test.exs`, `test/upgrade_test.exs`, `test/sigra/doctor_test.exs`, `test/sigra/mix/tasks/doctor_task_test.exs`, `test/sigra/optional_deps_test.exs`

## Scope Boundary

This seed records the downstream request and the implementation checks; no dependency, generator, changelog, version, or release was changed during capture. The separate built-in AES-GCM seed must not block this smaller fix. The user supplied the downstream project details; scrypath_ops itself was not inspected.
