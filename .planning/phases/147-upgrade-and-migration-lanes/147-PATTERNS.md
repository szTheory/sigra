# Phase 147: Upgrade And Migration Lanes - Pattern Map

**Mapped:** 2026-05-31
**Files analyzed:** 10
**Analogs found:** 10 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `guides/introduction/upgrading-to-v1.0.md` | config | request-response | `guides/introduction/upgrading-to-v1.1.md` | exact |
| `guides/introduction/migration-from-phx-gen-auth.md` (or combined migration guide section) | config | transform | `guides/introduction/upgrading-to-v1.8.md` | role-match |
| `guides/introduction/migration-from-pow-guardian-ueberauth.md` (or combined migration guide section) | config | transform | `guides/introduction/upgrading-to-v1.8.md` | role-match |
| `scripts/ci/upgrade-smoke.sh` | utility | batch | `scripts/ci/install-smoke.sh` | exact |
| `.github/workflows/ci.yml` | config | batch | `.github/workflows/ci.yml` (`install_smoke`, `example_http_smoke`) | exact |
| `mix.exs` | config | transform | `mix.exs` (`docs/0` extras + groups) | exact |
| `README.md` | config | request-response | `README.md` (“Topic map → guides”, “Release evidence”) | exact |
| `doc/llms.txt` | config | transform | `doc/llms.txt` (“Pages” nested sectioning) | exact |
| `docs/ga-evidence.md` | config | request-response | `docs/ga-evidence.md` (“Canonical sources”) | exact |
| `docs/uat-ci-coverage.md` (if lane is documented there) | config | transform | `docs/uat-ci-coverage.md` (SEED table + “Where to run this”) | exact |

## Pattern Assignments

### `guides/introduction/upgrading-to-v1.0.md` (config, request-response)

**Analog:** `guides/introduction/upgrading-to-v1.1.md`

**Structure pattern** ([guides/introduction/upgrading-to-v1.1.md](/Users/jon/projects/sigra/guides/introduction/upgrading-to-v1.1.md):5):
```markdown
## Before you start
## 1. Update the dependency
## 2. ...
## 3. Run the schema upgrade
## 4. Run migrations and compile
## ...
## 7. Verify with the same tested path
## 8. Smoke-check the upgraded app
## Related
```

**Command formatting pattern** ([guides/introduction/upgrading-to-v1.1.md](/Users/jon/projects/sigra/guides/introduction/upgrading-to-v1.1.md):31):
```markdown
    mix sigra.upgrade --yes
    mix ecto.migrate
    mix compile
```

**Truth-boundary language pattern** ([guides/introduction/upgrading-to-v1.1.md](/Users/jon/projects/sigra/guides/introduction/upgrading-to-v1.1.md):74):
```markdown
The guide deliberately does not promise more than the repo proves.
```

### `guides/introduction/migration-from-phx-gen-auth.md` and `...pow-guardian-ueberauth.md` (config, transform)

**Analog:** `guides/introduction/upgrading-to-v1.8.md`

**Maintainer/adopter framing pattern** ([guides/introduction/upgrading-to-v1.8.md](/Users/jon/projects/sigra/guides/introduction/upgrading-to-v1.8.md):3):
```markdown
This page tracks maintainer-facing and adopter-facing expectations...
```

**Checklist style pattern** ([guides/introduction/upgrading-to-v1.8.md](/Users/jon/projects/sigra/guides/introduction/upgrading-to-v1.8.md):11):
```markdown
## Library / host upgrade checklist
1. ...
2. ...
3. ...
```

**Cross-link footer pattern** ([guides/introduction/upgrading-to-v1.8.md](/Users/jon/projects/sigra/guides/introduction/upgrading-to-v1.8.md):19):
```markdown
## See also
- ...
```

### `scripts/ci/upgrade-smoke.sh` (utility, batch)

**Analog:** `scripts/ci/install-smoke.sh`

**Script contract pattern** ([scripts/ci/install-smoke.sh](/Users/jon/projects/sigra/scripts/ci/install-smoke.sh):1):
```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Env defaults + reproducibility pattern** ([scripts/ci/install-smoke.sh](/Users/jon/projects/sigra/scripts/ci/install-smoke.sh):20):
```bash
SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_APP_DIR="${TMP_APP_DIR:-/tmp/tmp_app}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
```

**Step logging + failure semantics pattern** ([scripts/ci/install-smoke.sh](/Users/jon/projects/sigra/scripts/ci/install-smoke.sh):57):
```bash
echo "==> ...: fetching deps"
mix deps.get
mix compile --warnings-as-errors
mix ecto.create
mix ecto.migrate
```

### `.github/workflows/ci.yml` (config, batch)

**Analog:** existing smoke jobs (`install_smoke`, `example_http_smoke`)

**Job skeleton pattern** ([.github/workflows/ci.yml](/Users/jon/projects/sigra/.github/workflows/ci.yml):295):
```yaml
install_smoke:
  name: Install smoke (...)
  runs-on: ubuntu-latest
  needs: release_ref_guard
  services:
    postgres:
      image: postgres:15
```

**Step ordering pattern** ([.github/workflows/ci.yml](/Users/jon/projects/sigra/.github/workflows/ci.yml):329):
```yaml
- name: Install Hex + Rebar
- name: Install phx_new archive
- name: Fetch ... deps
- name: Run ... smoke harness
```

**Smoke env wiring pattern** ([.github/workflows/ci.yml](/Users/jon/projects/sigra/.github/workflows/ci.yml):338):
```yaml
env:
  PGUSER: postgres
  PGPASSWORD: postgres
  PGHOST: localhost
  GITHUB_WORKSPACE: ${{ github.workspace }}
```

### `mix.exs` (config, transform)

**Analog:** `docs/0` extras and groups patterns

**Extras insertion pattern** ([mix.exs](/Users/jon/projects/sigra/mix.exs):186):
```elixir
extras: [
  "guides/introduction/...md",
  ...
  "docs/uat-ci-coverage.md",
  "docs/ga-evidence.md"
]
```

**Grouping pattern** ([mix.exs](/Users/jon/projects/sigra/mix.exs):235):
```elixir
groups_for_extras: [
  Introduction: ~r{guides/introduction/.?},
  ...
  Docs: ~r{^docs/|^SECURITY\.md$}
]
```

### `README.md` (config, request-response)

**Analog:** topic-map table + evidence links

**Guide-index table row pattern** ([README.md](/Users/jon/projects/sigra/README.md):141):
```markdown
| Topic | Guide |
| Upgrade notes | [v1.0 → v1.1](...) · [toward v1.7](...) · ... |
```

**Evidence section pattern** ([README.md](/Users/jon/projects/sigra/README.md):177):
```markdown
## Release evidence (maintainers and auditors)
- [GA evidence and audit posture](docs/ga-evidence.md)
- [UAT versus CI coverage](docs/uat-ci-coverage.md)
```

### `doc/llms.txt` (config, transform)

**Analog:** “Pages” grouped bullets

**Nested docs index pattern** ([doc/llms.txt](/Users/jon/projects/sigra/doc/llms.txt):13):
```text
- Introduction
  - [Installation](installation.md)
  - [Upgrading ...](upgrading-to-v1-1.md)
...
- Docs
  - [GA UAT — CI vs human coverage ...](uat-ci-coverage.md)
  - [Release evidence router](ga-evidence.md)
```

### `docs/ga-evidence.md` (config, request-response)

**Analog:** canonical-source router style

**Canonical routing pattern** ([docs/ga-evidence.md](/Users/jon/projects/sigra/docs/ga-evidence.md):6):
```markdown
## Canonical sources
- [Release runbook ...](...)
- [UAT ↔ CI coverage](...)
```

**Proof-link policy pattern** ([docs/ga-evidence.md](/Users/jon/projects/sigra/docs/ga-evidence.md):12):
```markdown
## GitHub-hosted proof links policy
... use pinned v<version> links.
```

### `docs/uat-ci-coverage.md` (config, transform)

**Analog:** evidence table + execution-location section

**Coverage table pattern** ([docs/uat-ci-coverage.md](/Users/jon/projects/sigra/docs/uat-ci-coverage.md):5):
```markdown
| SEED | Topic | CI / automated substitute | Residual ... |
```

**Script/job referencing pattern** ([docs/uat-ci-coverage.md](/Users/jon/projects/sigra/docs/uat-ci-coverage.md):77):
```markdown
## Where to run this
- GitHub Actions: `.github/workflows/ci.yml` — jobs ...
```

## Shared Patterns

### ExDoc surfacing + grouping
**Source:** [mix.exs](/Users/jon/projects/sigra/mix.exs):186 and [mix.exs](/Users/jon/projects/sigra/mix.exs):235  
**Apply to:** any new `guides/introduction/*` migration/upgrade docs
```elixir
extras: [ ... "guides/introduction/<new>.md", ... ]
groups_for_extras: [Introduction: ~r{guides/introduction/.?}, ...]
```

### README + AI-index discovery parity
**Source:** [README.md](/Users/jon/projects/sigra/README.md):141 and [doc/llms.txt](/Users/jon/projects/sigra/doc/llms.txt):13  
**Apply to:** new upgrade/migration docs
```markdown
README topic-map row + matching llms.txt Introduction/Docs bullet entries
```

### Smoke lane contract
**Source:** [scripts/ci/install-smoke.sh](/Users/jon/projects/sigra/scripts/ci/install-smoke.sh):14 and [.github/workflows/ci.yml](/Users/jon/projects/sigra/.github/workflows/ci.yml):295  
**Apply to:** `scripts/ci/upgrade-smoke.sh` and its new CI job
```bash
set -euo pipefail
... deps.get -> compile --warnings-as-errors -> ecto.create/migrate -> boot/runtime assertion
```

### Evidence routing consistency
**Source:** [docs/ga-evidence.md](/Users/jon/projects/sigra/docs/ga-evidence.md):6 and [docs/uat-ci-coverage.md](/Users/jon/projects/sigra/docs/uat-ci-coverage.md):77  
**Apply to:** any phase-147 docs mentions of the new upgrade lane
```markdown
Use router-style links to canonical pages/jobs; avoid duplicating gate matrices.
```

## No Analog Found

None.

## Metadata

**Analog search scope:** `guides/introduction`, `scripts/ci`, `.github/workflows`, repo root docs (`README.md`, `mix.exs`, `doc/llms.txt`, `docs/*`)  
**Files scanned:** 11  
**Pattern extraction date:** 2026-05-31

