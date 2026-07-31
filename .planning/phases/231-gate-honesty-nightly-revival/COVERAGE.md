# API Coverage — GitHub

> Full coverage by default. Opt-outs are explicit, reasoned decisions.

This phase extends Sigra's GitHub automation through the `gh` CLI and the
GitHub REST API. The matrix covers the Actions, Issues, Labels, and Pages
capabilities changed or introduced by Phase 231, plus the adjacent destructive
operations that are deliberately excluded.

| capability | decision | reason |
|---|---|---|
| actions.resolve-commit | INTEGRATE | |
| actions.list-workflow-runs | INTEGRATE | |
| actions.inspect-run-jobs | INTEGRATE | |
| actions.dispatch-workflow | INTEGRATE | |
| actions.cancel-or-delete-runs | OPT-OUT | Phase 231 observes and, when needed, dispatches the canonical workflow; destructive run management is outside the gate-verification scope. |
| issues.find-open-by-label | INTEGRATE | |
| issues.create | INTEGRATE | |
| issues.comment | INTEGRATE | |
| issues.close-edit-or-delete | OPT-OUT | The notifier deliberately accumulates occurrences on one durable open issue and must not mutate or remove operator-owned issue history. |
| labels.list | INTEGRATE | |
| labels.create | INTEGRATE | |
| labels.update-or-delete | OPT-OUT | The self-heal only creates the missing fixed label; changing or deleting repository labels is an owner action. |
| pages.read-configuration | INTEGRATE | |
| pages.create-site | INTEGRATE | |
| pages.update-source | INTEGRATE | |
| pages.request-build | INTEGRATE | |
| pages.delete-site-or-manage-domain | OPT-OUT | The publisher maintains a branch-backed Pages source only; deleting the site or changing its custom-domain policy is outside Phase 231. |
