# Phase 148: evaluator-funnel-and-first-run-dx - Pattern Map

**Mapped:** 2026-05-31  
**Files analyzed:** 7  
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `README.md` | config | request-response | `README.md` | exact |
| `mix.exs` | config | transform | `mix.exs` | exact |
| `doc/llms.txt` | config | transform | `doc/llms.txt` | exact |
| `guides/introduction/demo-showcase.md` | component | request-response | `guides/introduction/demo-showcase.md` | exact |
| `guides/introduction/troubleshooting-install.md` | component | request-response | `guides/introduction/troubleshooting-install.md` | exact |
| `test/example/README.md` | component | request-response | `test/example/README.md` | exact |
| `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` (implied docs-contract test) | test | transform | `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` | role-match |

## Pattern Assignments

### `README.md` (config, request-response)

**Analog:** `README.md`

**Lane-routing table pattern** (`README.md:17-24`):
```markdown
## Pick your lane

| You are… | Do this first |
|----------|----------------|
| **Evaluating** | ... |
| **Integrating** | ... |
```

**Map-not-spec boundary language** (`README.md:176`):
```markdown
... the README stays a map, not a spec.
```

**Reference-host pointer pattern** (`README.md:189-191`):
```markdown
## Reference host: `test/example`
... executable contract ...
```

---

### `mix.exs` (config, transform)

**Analog:** `mix.exs`

**Package description pattern** (`mix.exs:37-40`):
```elixir
description:
  "Authentication for Phoenix 1.8+ and Ecto. ... See https://hexdocs.pm/sigra and the README for details."
```

**ExDoc assets/extras pattern** (`mix.exs:185-210`):
```elixir
assets: %{"guides/assets" => "assets"},
extras: [
  "README.md",
  ...
  "guides/introduction/demo-showcase.md",
  ...
]
```

**Grouping pattern for introduction pages** (`mix.exs:238-244`):
```elixir
groups_for_extras: [
  Introduction: ~r{guides/introduction/.?},
  ...
]
```

---

### `doc/llms.txt` (config, transform)

**Analog:** `doc/llms.txt`

**Hierarchical intro index pattern** (`doc/llms.txt:13-30`):
```markdown
- Introduction
  - [Installation](installation.md)
  ...
  - [Demo Showcase — Vaultr Example App](demo-showcase.md)
```

**Task semantics pattern for doctor** (`doc/llms.txt:300-304`):
```markdown
- [mix sigra.doctor](Mix.Tasks.Sigra.Doctor.md): Diagnoses ... status matrix ...
```

---

### `guides/introduction/demo-showcase.md` (component, request-response)

**Analog:** `guides/introduction/demo-showcase.md`

**Canonical runnable start block** (`guides/introduction/demo-showcase.md:5-12`):
```markdown
## Running the Demo

```bash
cd test/example
mix setup && mix phx.server
```
```

**Screenshot grid pattern (committed assets)** (`guides/introduction/demo-showcase.md:16,22,24,39`):
```markdown
![...](assets/demo-credentials-demo-showcase-chromium.png)
![...](assets/admin-user-detail-demo-showcase-chromium.png)
![...](assets/admin-user-list-demo-showcase-chromium.png)
![...](assets/audit-explorer-demo-showcase-chromium.png)
```

**Persona narrative pattern** (`guides/introduction/demo-showcase.md:26-55`):
```markdown
Log in as `admin@demo.sigra.dev` ...
**Alice** ...
**Bob** ...
**Dave** ...
**Frank** ...
**Carol** ...
```

**Limitation-language pattern** (`guides/introduction/demo-showcase.md:55`):
```markdown
... requires real GitHub OAuth application credentials ...
```

---

### `guides/introduction/troubleshooting-install.md` (component, request-response)

**Analog:** `guides/introduction/troubleshooting-install.md`

**Symptom/Fix section pattern** (`guides/introduction/troubleshooting-install.md:5-47`):
```markdown
## <issue>
**Symptom:** ...
**Fix:** ...
```

**Optional-dependency host-ownership wording** (`guides/introduction/troubleshooting-install.md:23-28`):
```markdown
Sigra keeps optional integrations as **host** deps by design.
```

---

### `test/example/README.md` (component, request-response)

**Analog:** `test/example/README.md`

**Try-it-locally flow pattern** (`test/example/README.md:5-29`):
```markdown
## Try it locally
### Prerequisites
...
### One-command setup
```bash
cd test/example
mix setup && mix phx.server
```
```

**Persona table contract pattern** (`test/example/README.md:30-42`):
```markdown
## Demo Personas
| Email | Password | Feature demonstrated |
| ... |
```

**Cross-link back to canonical showcase pattern** (`test/example/README.md:56-58`):
```markdown
- [Demo Showcase guide](https://hexdocs.pm/sigra/demo-showcase.html)
```

---

### `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` (test, transform)

**Analog:** `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs`

**Test module and file-read helper pattern** (`test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs:1-17`):
```elixir
defmodule ... do
  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end
end
```

**Cross-surface docs-contract assertions pattern** (`test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs:39-63`):
```elixir
readme = read!("README.md")
mix_exs = read!("mix.exs")
...
assert readme =~ ...
assert mix_exs =~ ~s("guides/introduction/...")
```

**Evidence-boundary assertions pattern** (`test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs:87-111`):
```elixir
assert evidence =~ ...
refute evidence =~ ...
```

## Shared Patterns

### Canonical First Command Consistency
**Source:** `guides/introduction/demo-showcase.md:7-10`, `test/example/README.md:23-26`  
**Apply to:** `README.md`, `doc/llms.txt`, `guides/introduction/demo-showcase.md`, `test/example/README.md`
```bash
cd test/example
mix setup && mix phx.server
```

### Persona Source Of Truth
**Source:** `test/example/lib/example/demo/personas.ex:36-38`, `test/example/lib/example/demo/personas.ex:125-134`  
**Apply to:** `guides/introduction/demo-showcase.md`, `test/example/README.md`, docs-contract tests
```elixir
Example.Demo.Personas.all()
Example.Demo.Personas.feature_map()
```

### Doctor Vocabulary + Exit Contract
**Source:** `lib/mix/tasks/sigra.doctor.ex:45-48`, `lib/mix/tasks/sigra.doctor.ex:130-181`, `guides/recipes/deployment.md:217-220`  
**Apply to:** `guides/introduction/troubleshooting-install.md`, `guides/introduction/demo-showcase.md`, `doc/llms.txt`
```text
states: missing | available | loaded | misconfigured
exit 0: wired (or unconfigured)
exit 1: configured-but-broken wiring
```

### Docs Contract Test Style
**Source:** `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs:39-63`  
**Apply to:** new `test/sigra/planning/phase_148_*.exs` if added
```elixir
assert readme =~ ...
assert mix_exs =~ ...
assert llms =~ ...
assert demo_showcase =~ ...
assert example_readme =~ ...
```

## No Analog Found

None.

## Metadata

**Analog search scope:** `README.md`, `mix.exs`, `doc/llms.txt`, `guides/introduction/`, `guides/recipes/`, `test/example/`, `test/sigra/planning/`  
**Files scanned:** 12  
**Pattern extraction date:** 2026-05-31
