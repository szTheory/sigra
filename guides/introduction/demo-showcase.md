# Demo Showcase — Vaultr Example App

This is the canonical evaluator-first path for Sigra. It is a runnable, source-backed walkthrough of the seeded Vaultr demo app in `test/example`.

## Run Demo Showcase

Recommended path from the Sigra repo root:

```bash
scripts/uat/up.sh
```

The script starts a project-scoped Postgres container on available localhost ports, creates and migrates the demo database, seeds the personas, and prints the exact Phoenix server command. Run that printed command in a second terminal, then open the printed `/demo/credentials` URL. That page is the first live stop and shows the current seeded personas, emails, and passwords.

Need the URLs again later?

```bash
scripts/uat/status.sh
```

If you already have PostgreSQL available and want the plain Phoenix path, this also works from `test/example`:

```bash
mix setup && mix phx.server
```

If first-run verification fails after setup, run `mix sigra.doctor` and use the fixes in [Troubleshooting install](troubleshooting-install.md).

## Evaluator Persona Map

These six personas come from `Example.Demo.Personas.feature_map/0` and are the source of truth for what the showcase proves.

- `admin@demo.sigra.dev`: admin/operator surface, TOTP MFA, passkey display row, multi-org ownership/membership, and audit trail inspection via `/admin` and `/admin/audit`.
- `alice@demo.sigra.dev`: happy-path confirmed login baseline.
- `bob@demo.sigra.dev`: second TOTP/MFA-enabled user plus org-owner coverage.
- `carol@demo.sigra.dev`: seeded GitHub OAuth-linked identity row for inspection; live GitHub OAuth still requires evaluator-supplied provider credentials.
- `dave@demo.sigra.dev`: locked and unconfirmed rough edge for enumeration-resistant login behavior.
- `frank@demo.sigra.dev`: scheduled deletion lifecycle state while still active.

## Screenshot Grid

| Credentials | Admin Users |
| --- | --- |
| ![Credentials view with six seeded personas](assets/demo-credentials-demo-showcase-chromium.png) | ![Admin users list view](assets/admin-user-list-demo-showcase-chromium.png) |

| Admin User Detail | Audit Explorer |
| --- | --- |
| ![Admin user detail including MFA and passkey rows](assets/admin-user-detail-demo-showcase-chromium.png) | ![Audit explorer view with seeded events](assets/audit-explorer-demo-showcase-chromium.png) |

## Proof Boundary And Limitations

This showcase and screenshot grid are evaluator proof and inspection aids. They are **not production certification** and **not compliance evidence**.

## Not Evaluating Right Now?

- [Installation](installation.html)
- [Upgrading to v1.0](upgrading-to-v1.0.html)
- [Migrating from phx.gen.auth](migrating-from-phx-gen-auth.html)
- [Migrating from Pow / Guardian / Ueberauth](migrating-from-pow-guardian-ueberauth.html)
- [Deployment](../recipes/deployment.html)
- Local companion app details: `test/example/README.md`
