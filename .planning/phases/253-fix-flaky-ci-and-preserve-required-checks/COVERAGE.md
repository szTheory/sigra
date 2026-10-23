# API coverage — Phase253 GitHub evidence and publication

Canonical coverage promoted after independent plan review. The exact proposal remains preserved at 28b326e0e; no existing coverage file was replaced. Scope: bounded evidence/publication for this approved phase, not a general GitHub client. Decisions start from the full GitHub capability-family surface and opt-outs state scope reasons.

| capability | decision | reason |
|---|---|---|
| REST rate-limit and actual response headers/status | INTEGRATE | Measured request/rate hard stops |
| Effective branch rules and legacy required-status protection reads | INTEGRATE | Exact five context/app/source proof |
| GitHub app/check source read identity | INTEGRATE | Independent required-check producer identity |
| Workflow registration/read/dispatch | INTEGRATE | Registered ci.yml scoped fixture |
| Workflow run/attempt discovery and terminal reads | INTEGRATE | Positive source identity and one bounded watcher |
| Attempt jobs/steps and native check-run/check-suite reads | INTEGRATE | Literal producer and PR source outcomes |
| Artifact list/metadata/digest and bounded ZIP/log downloads | INTEGRATE | Independent retained proof |
| Explicit pagination/redirect hops | INTEGRATE | Every failed/page/hop request charged |
| Exact fixture run cancellation | INTEGRATE | One positively identified synthetic source run only |
| Diagnosed infrastructure-only run retry | INTEGRATE | One frozen retry reserve per authorized window |
| Git blob/tree/commit create/read, inline UTF-8 tree content | INTEGRATE | Actual object publication before refs |
| Scoped branch ref create/read | INTEGRATE | Create-only exact candidate/fixture/docs identity |
| PR draft create/read/compare diff and native source/check collection | INTEGRATE | Normal and real docs-only families |
| Existing source/helper/action pin verification | INTEGRATE | Clean source and read-only ordinary workflow |
| Force/update/delete refs, tag/merge/release publication | OPT-OUT | Explicit create-only/unmerged phase boundary |
| Repository/rules/branch-protection/admin/settings mutations | OPT-OUT | Five required checks are read and preserved |
| PR merge/auto-merge/review/comment/notification mutations | OPT-OUT | Explicit no merge/notification scope |
| Issues/projects/discussions/labels/milestones mutations | OPT-OUT | Unrelated to the approved evidence workflow |
| User/org/team/membership/account/token/key administration | OPT-OUT | No account/security-model changes authorized |
| Codespaces/Copilot/enterprise/billing/license capabilities | OPT-OUT | No product or paid-runner changes |
| Package/container/Pages/deployment/environment publication | OPT-OUT | No release/deploy/Pages secret artifacts |
| Security advisory/Dependabot/code-scanning/secret-scanning configuration | OPT-OUT | No broad dependency or platform configuration changes |
| Repository transfer/fork/create/delete/import and generic contents edits | OPT-OUT | Objects/refs are narrowly scoped to evidence; repo remains intact |
| Webhook/subscription/notification/star/watch interactions | OPT-OUT | No messages or new external delivery surfaces |
| Git smart transport publication/git push | OPT-OUT | REST object calls keep every publication request measurable |
| Other actions cache/runner/secrets/variables/OIDC administration | OPT-OUT | Preserve current stack, runner and read-only pins |

Full API service families are explicitly decided; no silent implied permission to use opt-out mutations.

Current primary documentation informs deterministic REST choices:
- [Git commits: explicit tree/parents/author/committer/message](https://docs.github.com/en/rest/git/commits#create-a-commit).
- [Git trees: content entries and base_tree](https://docs.github.com/en/rest/git/trees#create-a-tree).
- [Create reference requires an existing object SHA](https://docs.github.com/en/rest/git/refs#create-a-reference).
- [Effective branch rules](https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch).
- [workflow_dispatch input limits](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).
- [Git push/object transport](https://git-scm.com/docs/git-push) and [curl no-follow behavior](https://curl.se/docs/manpage.html).

GitHub's character bound is not declared a byte bound; the additional conservative UTF-8 byte check is stated separately. No transport/API capability is claimed implemented by this planning proposal.

