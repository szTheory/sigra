# Phase 241 Plan 04: Composite action pinning evidence

**Captured at:** 2026-09-19  
**Commit under test:** `1e0c3417` (before this evidence commit)

## Reproducible contract runs

### Bare `uses:` known-bad fixture: RED

```bash
bash -c 'set -o pipefail; SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs 2>&1 | tee /tmp/241-04-bare.txt; rc=${PIPESTATUS[0]}; test "$rc" -ne 0 || { echo "bare-uses fixture did not red — the relaxation is unproven"; exit 1; }; grep -q "phase241-composite-unpinned-bare-uses" /tmp/241-04-bare.txt; grep -q "has non-immutable action ref" /tmp/241-04-bare.txt'
```

Captured result: exit nonzero as required; the guard itself reported
`test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml:63 has non-immutable action ref "v6"`.
The run finished with `8 tests, 1 failure`.

### Dashed `- uses:` known-bad fixture: RED

```bash
bash -c 'set -o pipefail; SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/phase241-composite-unpinned-dashed-uses.yml mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs 2>&1 | tee /tmp/241-04-dashed.txt; rc=${PIPESTATUS[0]}; test "$rc" -ne 0 || { echo "dashed fixture did not red"; exit 1; }; grep -q "phase241-composite-unpinned-dashed-uses" /tmp/241-04-dashed.txt; grep -q "has non-immutable action ref" /tmp/241-04-dashed.txt'
```

Captured result: exit nonzero as required; the guard itself reported
`test/fixtures/prohibitions/phase241-composite-unpinned-dashed-uses.yml:49 has non-immutable action ref "v1"`.
The run finished with `8 tests, 1 failure`.

### Real tree: GREEN

```bash
bash -c 'set -eo pipefail; mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs 2>&1 | tee /tmp/241-04-green.txt'
```

Captured result: `8 tests, 0 failures`.

### Regex-relaxation negative control: GREEN

```bash
bash -c 'set -eo pipefail; mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs:92 2>&1 | tee /tmp/241-04-negative-control.txt'
```

Captured result: `1 test, 0 failures (7 excluded)`. That test first runs the bare fixture
through the pre-relaxation `^\\s*-\\s+uses:` pattern and proves the floating bare reference is
absent, then runs it through the relaxed `^\\s*(?:-\\s+)?uses:` pattern and proves the same
reference is present and rejected with the guard's `non-immutable action ref` diagnostic.

### Measured inventory before and after regex relaxation

```bash
bash -c "set -eo pipefail; mix run --no-start -e 'paths = [\".github/workflows/release-please.yml\", \".github/workflows/hex-publish.yml\"] ++ Path.wildcard(\".github/actions/*/action.yml\"); pre = ~r/^\\s*-\\s+uses:\\s+([^\\s#]+)(?:\\s+#\\s*(.+))?\\s*$/; relaxed = ~r/^\\s*(?:-\\s+)?uses:\\s+([^\\s#]+)(?:\\s+#\\s*(.+))?\\s*$/; for {name, pattern} <- [{\"pre-relaxation\", pre}, {\"relaxed\", relaxed}] do count = Enum.flat_map(paths, fn path -> File.read!(path) |> String.split(\"\\n\") |> Enum.filter(&Regex.match?(pattern, &1)) end) |> length(); IO.puts(\"#{name}=#{count}\") end'"
```

Captured result:

```text
pre-relaxation=9
relaxed=16
```

The relaxation therefore adds seven visible references in the already-widened three-file
universe; the guard's numeric floor is the measured final inventory of 16. The release-workflow
universe remains exactly its original two entries; the composite-action glob is distinct.

## Scope boundaries retained

The Dependabot `github-actions` entry for the composite action was **not** added. It remains on
the pending todo because adding it requires changing the contract test that locks Dependabot to
three entries.

`ci.yml`'s own action pins also remain unguarded. DEBT-04 closes the composite-action surface,
not the whole repository action-pinning surface.

## Rejected alternative (D-21)

The rejected approach was temporarily unpinning the live `action.yml`, running a transcript, and
restoring it with `git stash`. It leaves no committed known-bad artifact and cannot prove the RED
again at a future HEAD. These committed fixtures instead drive the real guard through a
function-resolved subject without mutating the live composite action.
