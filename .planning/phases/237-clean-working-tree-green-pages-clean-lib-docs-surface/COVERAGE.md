# API Coverage — GitHub Pages and repository evidence

> Full coverage by default. Opt-outs are explicit, reasoned decisions.

Phase 237 used GitHub's REST API to repoint and verify the repository's existing
Pages site. This retrospective matrix records the complete Pages capability
surface relevant to that operation, plus the repository/issue reads used as
evidence. It does not authorize new mutations.

| capability | decision | reason |
|---|---|---|
| `GET /repos/{owner}/{repo}` | INTEGRATE | Read repository metadata, including the authenticated caller's effective admin permission, before changing Pages configuration. |
| `GET /repos/{owner}/{repo}/pages` | INTEGRATE | Capture the pre-change configuration and independently read back the resulting source and build status. |
| `PUT /repos/{owner}/{repo}/pages` | INTEGRATE | Repoint the existing site from `main` to the dedicated `gh-pages` publish branch after committing the literal revert value. |
| `POST /repos/{owner}/{repo}/pages/builds` | INTEGRATE | Request a build after changing the source. |
| `GET /repos/{owner}/{repo}/pages/builds` | INTEGRATE | Observe the requested build's commit, status, timestamps, duration, and error payload. |
| `GET /repos/{owner}/{repo}/pages/builds/latest` | INTEGRATE | Re-read the latest build as independent evidence that the `gh-pages` source reached `built`. |
| `GET /repos/{owner}/{repo}/issues/{issue_number}` | INTEGRATE | Verify that issue #231 remained open for its owning follow-up phase. |
| `POST /repos/{owner}/{repo}/pages` | OPT-OUT | The Pages site already existed; creating a second site configuration was neither needed nor safe for this corrective change. |
| `DELETE /repos/{owner}/{repo}/pages` | OPT-OUT | Deleting the public site is destructive and directly contradicts the phase goal of restoring it. |
| Pages custom-domain and DNS health capabilities | OPT-OUT | The site uses the repository's `github.io` URL and Phase 237 did not add or change a custom domain. |
| HTTPS enforcement capability | OPT-OUT | The published `github.io` endpoint already served HTTPS; changing its policy was outside the source-branch repair. |
| GitHub Actions workflow/run/job capabilities | OPT-OUT | Phase 237 verified the Pages build and live HTTP surface directly; it did not dispatch, rerun, cancel, delete, or reinterpret Actions runs. |
| Issue create/comment/edit/close capabilities | OPT-OUT | Issue #231 was deliberately owned by Phase 240; Phase 237 only confirmed it stayed open and made no issue mutation. |

