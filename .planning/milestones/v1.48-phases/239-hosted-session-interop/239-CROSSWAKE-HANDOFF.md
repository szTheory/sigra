# Crosswake Release Handoff for Phase 239

This artifact is an executable cross-repository dependency, not a claim that the SIGRA workspace can modify Crosswake. Run the change in a clean checkout of `szTheory/crosswake`, then return the published package version, immutable Git tag/commit SHA, and Hex checksum to the Phase 239 executor.

## Locked Contract

- Per D-01, `Crosswake.Companions.Sigra.Contracts.SessionAuthorityLane` and its lane-derived `AuthContext` accept exactly `org_id: nil` for a personal account or a trimmed nonblank string for an organization account. Blank/non-string values remain invalid. No sentinel or fabricated organization is permitted.
- Per D-02, reference fields remain opaque and no raw session token, token hash, credential, provider payload, or OAuth token is added to any public contract.
- Per D-05, `AuthReturn` remains evidence/navigation only and rejects session, subject, organization, authority, token, and access-grant claims.
- Existing organization-scoped callers remain backward compatible.

## Crosswake-Owned Files

- `packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex`
- `packages/crosswake_sigra/test/crosswake/companions/sigra/contracts_test.exs`
- `packages/crosswake_sigra/test/crosswake/proof/phase57_auth_return_boundaries_test.exs`
- `packages/crosswake_sigra/mix.exs`
- `packages/crosswake_sigra/CHANGELOG.md`

If a personal hosted-return attempt record is exercised by the released path, apply the same personal-or-nonblank-organization rule to that record and test it. Do not add unused persistence merely to satisfy this handoff.

## Required Crosswake Proof

From the Crosswake repository root:

1. Add failing ExUnit cases first for personal `nil`, organization nonblank, and blank/non-string rejection in every touched contract.
2. Implement one shared validator and preserve lane-to-context derivation of `org_id: nil`.
3. Extend the AuthReturn boundary matrix to reject authority-smuggling fields and prove an evidence-only envelope is not evaluator authority.
4. Run:
   - `mix format --check-formatted packages/crosswake_sigra/test/crosswake/companions/sigra/contracts_test.exs packages/crosswake_sigra/test/crosswake/proof/phase57_auth_return_boundaries_test.exs`
   - `cd packages/crosswake_sigra && mix test test/crosswake/companions/sigra/contracts_test.exs`
   - `cd packages/crosswake_sigra && mix test test/crosswake/proof/phase57_auth_return_boundaries_test.exs`
   - `cd packages/crosswake_sigra && mix test`
5. Bump to the next available backward-compatible release, update the changelog, create an immutable tag, publish to Hex, and record the Hex checksum.

## Return Receipt

The SIGRA executor must receive all fields below before changing `test/example/mix.exs`:

- `package`: `crosswake_sigra`
- `version`: published successor version
- `requirement`: exact compatible Mix requirement selected from that version
- `git_tag`: immutable release tag
- `git_sha`: full commit SHA targeted by the tag
- `hex_checksum`: registry checksum
- `contracts_test`: passing command and result
- `auth_return_test`: passing command and result
- `published_at`: UTC timestamp

The executor records these values in `239-CROSSWAKE-RELEASE.json`, verifies them against Hex/GitHub without printing credentials, and stops if any field is absent or inconsistent.

## Machine-Readable Release Proof

The Return Receipt is discovery input, not sufficient proof. Before Plan 01 proceeds, Wave 0 must use a clean checkout at the public tag, reconcile the peeled full SHA and Hex version/checksum, execute all four commands under `Required Crosswake Proof`, and generate `.planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE-PROOF.json` with:

- `schema`: `sigra.phase239.crosswake-release-proof.v1`
- `repository`, `package`, `version`, `requirement`, `git_tag`, full `git_sha`, `hex_checksum`, `published_at`, and `verified_at`
- `commands`: exactly four records, with no missing, extra, duplicate, or reordered entries; their command strings are the documented four in exact order, and every unfiltered record has a process-derived numeric `exit_status` of `0` and `outcome` exactly `passed`

No pass-shaped artifact may be written when metadata conflicts, a test file is absent, the checkout is dirty, or any command fails. Plans 01 and 06 mechanically validate this artifact; maintainer-supplied result text cannot substitute for it.
