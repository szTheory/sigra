# Phase 149: Launch Evidence And Announcement Pack - Pattern Map

**Mapped:** 2026-06-01
**Files analyzed:** 9
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `docs/launch/v1.0/announcement.md` | docs | request-response | `README.md` | role-match |
| `docs/launch/v1.0/alternatives.md` | docs | transform | `guides/introduction/migrating-from-pow-guardian-ueberauth.md` | exact |
| `docs/launch/v1.0/evidence.md` | docs | transform | `docs/ga-evidence.md` | exact |
| `README.md` | docs | request-response | `README.md` | exact |
| `CHANGELOG.md` | docs | transform | `CHANGELOG.md` | exact |
| `mix.exs` | config | transform | `mix.exs` | exact |
| `doc/llms.txt` | docs | transform | `doc/llms.txt` | exact |
| `llms.txt` (optional root pointer) | docs | transform | `doc/llms.txt` | role-match |
| `scripts/ci/launch-pack-contract.sh` (optional) | test | batch | `scripts/ci/getting-started-contract.sh` | role-match |

## Pattern Assignments

### `docs/launch/v1.0/announcement.md` (docs, request-response)

**Analog:** `README.md`

**Lane-routing pattern** ([README.md](../../../../README.md#L17)):
```markdown
## Pick your lane

| You are… | Do this first |
|----------|----------------|
| **Evaluating** | Start with the [Demo Showcase](guides/introduction/demo-showcase.md) ... |
| **Existing Sigra app / upgrade** | Follow [Upgrading to v1.0](guides/introduction/upgrading-to-v1.0.md) ... |
```

**Boundary language pattern** ([README.md](../../../../README.md#L181)):
```markdown
... evidence hub ... That material is **not** a compliance certificate ...
```

**Use:** Keep announcement short, map-style, and link outward to contract/migration/evidence docs.

---

### `docs/launch/v1.0/alternatives.md` (docs, transform)

**Analog:** `guides/introduction/migrating-from-pow-guardian-ueberauth.md`

**Comparative table pattern** ([guides/introduction/migrating-from-pow-guardian-ueberauth.md](../../../../guides/introduction/migrating-from-pow-guardian-ueberauth.md#L38)):
```markdown
## Ownership boundary table
| Ecosystem | Typical ownership center | Sigra comparison boundary |
| --- | --- | --- |
```

**“When not to migrate/choose” pattern** ([guides/introduction/migrating-from-pow-guardian-ueberauth.md](../../../../guides/introduction/migrating-from-pow-guardian-ueberauth.md#L16)):
```markdown
## When not to migrate
Do not migrate yet if:
- ...
```

**Anti-overclaim phrasing pattern** ([guides/introduction/migrating-from-phx-gen-auth.md](../../../../guides/introduction/migrating-from-phx-gen-auth.md#L3)):
```markdown
... not a drop-in migration promise and not an automated conversion path.
```

---

### `docs/launch/v1.0/evidence.md` (docs, transform)

**Analog:** `docs/ga-evidence.md`

**Evidence-router pattern** ([docs/ga-evidence.md](../../../../docs/ga-evidence.md#L1)):
```markdown
# Release evidence router
This page routes maintainers and reviewers to the canonical release-evidence surfaces...
It does not duplicate the release gate matrix.
```

**Pinned-tag proof rule pattern** ([docs/ga-evidence.md](../../../../docs/ga-evidence.md#L21)):
```markdown
... use pinned `v<version>` links.
Do not use `main` blob URLs for release evidence.
```

**Gate/waiver row pattern** ([docs/release-runbook-v1-0.md](../../../../docs/release-runbook-v1-0.md#L10)):
```markdown
| Library tests | ... | release tag | ... | If unavailable ... `gate`, `reason`, `approver`, `evidence URL`, `expiry` |
```

**Proof-boundary pattern** ([guides/introduction/demo-showcase.md](../../../../guides/introduction/demo-showcase.md#L37)):
```markdown
## Proof Boundary And Limitations
... are **not production certification** and **not compliance evidence**.
```

---

### `README.md` (docs, request-response)

**Analog:** `README.md` (existing section extension)

**Section style pattern** ([README.md](../../../../README.md#L179)):
```markdown
## Release evidence (maintainers and auditors)
... short paragraph ...
- [GA evidence and audit posture](docs/ga-evidence.md)
```

**Use:** Add one launch-pack entrypoint section; keep it concise and pointer-oriented.

---

### `CHANGELOG.md` (docs, transform)

**Analog:** `CHANGELOG.md`

**SemVer-vs-planning guardrail pattern** ([CHANGELOG.md](../../../../CHANGELOG.md#L8)):
```markdown
## Planning milestones vs Hex releases
... SemVer headings are installable truth ...
```

**Unreleased docs routing pattern** ([CHANGELOG.md](../../../../CHANGELOG.md#L33)):
```markdown
## [Unreleased]
### Documentation
- ... routing notes ...
```

---

### `mix.exs` (config, transform)

**Analog:** `mix.exs`

**ExDoc extras inclusion pattern** ([mix.exs](../../../../mix.exs#L186)):
```elixir
extras: [
  "README.md",
  ...
  "docs/uat-ci-coverage.md",
  "docs/ga-evidence.md",
  ...
]
```

**Docs grouping pattern** ([mix.exs](../../../../mix.exs#L238)):
```elixir
groups_for_extras: [
  Introduction: ~r{guides/introduction/.?},
  ...
]
```

**Source-link truth pattern** ([mix.exs](../../../../mix.exs#L182)):
```elixir
source_ref: "v#{@version}"
```

---

### `doc/llms.txt` (docs, transform)

**Analog:** `doc/llms.txt`

**TOC-first routing pattern** ([doc/llms.txt](../../../../doc/llms.txt#L5)):
```markdown
## Pages
- [Sigra](readme.md)
- Introduction
  - [Installation](installation.md)
  - [Sigra 1.0 Contract](contract.md)
  - [Migrating from ...](...)
  - [Demo Showcase ...](demo-showcase.md)
```

**Docs subsection pattern** ([doc/llms.txt](../../../../doc/llms.txt#L62)):
```markdown
- Docs
  - [Security Policy](security.md)
  - [GA UAT — CI vs human coverage ...](uat-ci-coverage.md)
  - [Release evidence router](ga-evidence.md)
```

**Use:** Keep one canonical vocabulary and place 1.0 launch/evidence routes near Installation/Contract/Migration.

---

### `llms.txt` (optional root pointer, docs, transform)

**Analog:** `doc/llms.txt`

**Pointer-only pattern:** keep minimal root file that points to canonical generated index (`doc/llms.txt` / HexDocs equivalent), no second taxonomy.

---

### `scripts/ci/launch-pack-contract.sh` (optional, test, batch)

**Analog:** `scripts/ci/getting-started-contract.sh`

**Contract test shell structure** ([scripts/ci/getting-started-contract.sh](../../../../scripts/ci/getting-started-contract.sh#L1)):
```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${ROOT}/guides/introduction/getting-started.md"
```

**Required-string assertions pattern** ([scripts/ci/getting-started-contract.sh](../../../../scripts/ci/getting-started-contract.sh#L52)):
```bash
for needle in "..."; do
  grep -Fq "${needle}" "${DOC}" || { echo "FAIL ..."; exit 1; }
done
```

**Link-resolution loop pattern** ([scripts/ci/getting-started-contract.sh](../../../../scripts/ci/getting-started-contract.sh#L22)):
```bash
... parse markdown links ... fail on missing relative targets ...
```

## Shared Patterns

### Proof Boundary Language
**Source:** [guides/introduction/demo-showcase.md](../../../../guides/introduction/demo-showcase.md#L37), [docs/ga-evidence.md](../../../../docs/ga-evidence.md#L1)  
**Apply to:** announcement + alternatives + evidence pages
```markdown
This evidence/routes page does not certify compliance or production safety; it links bounded proof.
```

### Version-Axis Clarity
**Source:** [guides/introduction/contract.md](../../../../guides/introduction/contract.md#L5), [CHANGELOG.md](../../../../CHANGELOG.md#L8)  
**Apply to:** announcement, changelog note, llms routing blurbs
```markdown
Hex SemVer is installable truth; planning milestones are internal coordination labels.
```

### Pinned Release Evidence Links
**Source:** [docs/ga-evidence.md](../../../../docs/ga-evidence.md#L21)  
**Apply to:** launch evidence doc + release-note references
```markdown
Use pinned `v<version>` links for release proof; avoid `main` blob links.
```

### ExDoc Integration
**Source:** [mix.exs](../../../../mix.exs#L186), [mix.exs](../../../../mix.exs#L238)  
**Apply to:** new launch docs under ExDoc extras and grouping
```elixir
extras: [...], groups_for_extras: [...]
```

### Docs-Contract Verification
**Source:** [scripts/ci/getting-started-contract.sh](../../../../scripts/ci/getting-started-contract.sh#L10), [.github/workflows/ci.yml](../../../../.github/workflows/ci.yml#L1065)  
**Apply to:** optional launch-pack route/claim checks
```bash
set -euo pipefail
grep/link assertions + CI invocation
```

## No Analog Found

None. All likely Phase 149 files have close analogs in current docs/release surfaces.

## Metadata

**Analog search scope:** `README.md`, `CHANGELOG.md`, `mix.exs`, `doc/`, `docs/`, `guides/introduction/`, `scripts/ci/`, `.github/workflows/ci.yml`  
**Files scanned:** 16  
**Pattern extraction date:** 2026-06-01
