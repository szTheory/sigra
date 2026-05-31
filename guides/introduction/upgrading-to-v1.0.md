# Upgrading to v1.0

Sigra v1.0 is a direct Hex release target from the latest published `0.3.x` line. This guide is operational by design: branch first, run exact commands, review generated-host changes intentionally, and verify against the same proof surfaces used in this repo.

## Version axis and target posture

- Source posture: latest published `0.3.x`, resolved by `scripts/ci/upgrade-smoke.sh`.
- Target posture: direct `1.0.0` release line.
- Planning milestones (`v1.x` in `.planning/`) are coordination labels, not a second installable version axis.

## Breaking-change review categories

| Category | What to review | Why it matters |
| --- | --- | --- |
| Generated host auth files | Any diffs under your host auth context, controllers, LiveViews, templates, plugs | Sigra owns library behavior; you own generated-host integration decisions |
| Router and pipeline wiring | Session routes, OAuth routes, plugs, scope flow | Incorrect route/plugs wiring can break login/logout and scope guarantees |
| Schema and migrations | New/changed migrations, indexes, constraints, data migrations | Upgrade correctness depends on migration order and idempotent rollout |
| Optional integration config | Oban, Hammer, OAuth/provider config, mailer hooks | Optional deps are host-owned wiring and can fail at boot if mismatched |
| Audit and security posture | Required audit schema presence and configured callbacks | Avoid silent auth behavior drift during upgrade |

## Preflight

1. Create a dedicated upgrade branch.
2. Confirm you can restore production data from backup.
3. Ensure your app compiles and migrates cleanly before starting.
4. Prefer a clean working tree before running upgrade tasks.
5. Note rollback anchor: current commit SHA and currently deployed package version.

## 1. Bump dependency and fetch

Update your app `mix.exs` to the `1.0.0` target line, then fetch:

    mix deps.get

## 2. Run Sigra upgrade task

Run the generated-file and migration injector:

    mix sigra.upgrade --yes

Use `--allow-dirty` only if you explicitly accept reduced rollback safety.

## 3. Review generated-file changes before migrate

Label your review in these buckets before continuing:

- Session and auth controller/template diffs
- Scope/current-user/current-scope wiring
- OAuth and provider callback routes
- Admin and settings surfaces touched by generator output
- Any host policy callback seam changes

This guide does not promise automatic ecosystem migration or drop-in compatibility across other auth stacks. Generated-host ownership remains with your app.

## 4. Migration and schema impact

After review, run DB changes:

    mix ecto.migrate

Checklist:

- Confirm migration ordering is stable for your deployment model.
- Confirm data migrations (if present) are run by your deploy pipeline.
- Confirm constraints/indexes align with your production DB posture.
- Confirm no unexpected destructive schema edits were introduced.

## 5. Compile with warnings as errors

    mix compile --warnings-as-errors

Treat warnings as release blockers until resolved.

## 6. Verification commands (repo proof surfaces)

Run the same focused checks used by this repo:

    mix test test/upgrade_test.exs -x
    bash scripts/ci/upgrade-smoke.sh

These checks validate the published-consumer upgrade posture and targeted upgrade contract.

## 7. Minimal manual boot smoke

Start your upgraded app and validate core route and auth behavior:

    mix phx.server

Manual checks:

1. Login still succeeds for an existing user.
2. Session creation and logout behavior remain correct.
3. Key auth pages load without 500s.
4. Any required organization/scope landing behavior is intact.

## Rollback notes

If verification fails:

1. Stop deploy rollout.
2. Revert to pre-upgrade commit and pre-upgrade Sigra dependency version.
3. Restore DB from backup if migrations were destructive or unrecoverable.
4. Re-run preflight and re-attempt with narrower diff review.

If verification passes but production issues appear:

- Roll back app artifact first.
- Roll back DB only per your migration rollback policy and backup posture.
- Capture failing diff category (generated file, migration, optional integration) before retrying.

## Related docs

- [Contract](contract.html)
- [Upgrading to v1.1](upgrading-to-v1.1.html)
- [Upgrading notes - toward v1.8](upgrading-to-v1.8.html)
