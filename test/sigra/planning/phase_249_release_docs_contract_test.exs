defmodule Sigra.Planning.Phase249ReleaseDocsContractTest do
  use ExUnit.Case, async: true

  defp root, do: Path.expand("../../..", __DIR__)

  defp read!(rel), do: root() |> Path.join(rel) |> File.read!()

  defp job!(workflow, name) do
    [_before, rest] = String.split(workflow, "  #{name}:\n", parts: 2)

    case String.split(rest, ~r/^  [a-zA-Z_][a-zA-Z0-9_-]*:\s*$/m, parts: 2) do
      [job, _after] -> job
      [job] -> job
    end
  end

  test "candidate capture is bound to trusted main and one stable fixed PR identity" do
    workflow = read!(".github/workflows/release-please.yml")
    release_job = job!(workflow, "release-please")
    helper = read!("scripts/ci/refresh-release-docs.sh")

    assert release_job =~ "if: ${{ github.ref == 'refs/heads/main' }}"
    assert release_job =~ "id: capture-candidate"
    assert release_job =~ "--expected-main-sha \"$WORKFLOW_SHA\""
    assert release_job =~ "GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}"

    assert release_job =~
             "candidate_identity: ${{ steps.capture-candidate.outputs.candidate_identity }}"

    assert helper =~ "--state open --base main"
    assert helper =~ "--head \"$RELEASE_BRANCH\""
    assert helper =~ "autorelease: pending"
    assert helper =~ ".headRepository.nameWithOwner == $repository"
    assert helper =~ "candidate identity changed during the two-read selection"
  end

  test "candidate docs build is read-only, credential-free, and checks out the captured SHA" do
    workflow = read!(".github/workflows/release-please.yml")
    build_job = job!(workflow, "build-release-docs")

    assert build_job =~ "permissions:\n      contents: read\n      pull-requests: read"
    refute build_job =~ "environment: release-automation"
    refute build_job =~ "secrets.RELEASE_PLEASE_TOKEN"
    assert build_job =~ "ref: ${{ needs.release-please.outputs.candidate_head_sha }}"
    assert build_job =~ "persist-credentials: false"
    assert build_job =~ "run: mix docs --warnings-as-errors"
    assert build_job =~ "refresh-release-docs.sh package"
    assert build_job =~ "--output-dir \"$RUNNER_TEMP/release-docs-artifact\""
    assert build_job =~ "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
  end

  test "the release credential is preflighted and exposed only to the narrow writer step" do
    workflow = read!(".github/workflows/release-please.yml")
    writer_job = job!(workflow, "write-release-docs")
    helper = read!("scripts/ci/refresh-release-docs.sh")
    token_refs = Regex.scan(~r/\$\{\{\s*secrets\.RELEASE_PLEASE_TOKEN\s*\}\}/, writer_job)

    assert writer_job =~ "environment: release-automation"
    assert writer_job =~ "--require-release-token \"$RELEASE_PLEASE_TOKEN_PRESENT\""
    assert length(token_refs) == 1
    assert writer_job =~ "id: write-candidate"
    assert writer_job =~ "GH_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}"
    assert writer_job =~ "refresh-release-docs.sh write"
    assert helper =~ "gh auth setup-git --hostname github.com"

    assert helper =~
             "git -C \"$REPO_DIR\" push --porcelain origin \"HEAD:refs/heads/$RELEASE_BRANCH\""

    refute helper =~ "--force"
    refute helper =~ "gh pr merge"
  end

  test "artifact and write races fail closed and fresh CI is bound to the new head" do
    helper = read!("scripts/ci/refresh-release-docs.sh")

    assert helper =~ "EXPECTED_ARTIFACT_ENTRIES"
    assert helper =~ "validate_index_file \"$ARTIFACT_DIR/$INDEX_PATH\""
    assert helper =~ "candidate doc directory must be a regular directory"
    assert helper =~ "candidate doc/llms.txt destination must be a regular file"
    assert helper =~ "candidate identity or head changed immediately before push"
    assert helper =~ "non-force candidate push failed"
    assert helper =~ "--commit \"$sha\""
    assert helper =~ ".event == \"push\""
    assert helper =~ ".headSha == $sha"
    assert helper =~ "ordinary CI push run for the exact refreshed SHA was not registered"
    assert helper =~ "fresh_ci_url=$ci_url"
    assert helper =~ "- Ordinary CI: [%s](%s)"
  end

  test "ordinary CI and the existing merger remain the only route to automatic merge" do
    ci = read!(".github/workflows/ci.yml")
    merge = read!(".github/workflows/release-pr-automerge.yml")
    merge_job = job!(merge, "guarded-merge")
    release = read!(".github/workflows/release-please.yml")

    assert ci =~ "push:\n    branches: [main, release-please--branches--main]"
    assert merge =~ "workflows: [\"CI\"]"
    assert merge =~ "types: [completed]"
    assert merge_job =~ "github.event.workflow_run.conclusion == 'success'"
    assert merge_job =~ "head_branch == 'release-please--branches--main'"
    assert merge =~ "select(.name == \"ci-gate\")"
    assert merge =~ "--match-head-commit \"$PR_HEAD_SHA\""
    refute job!(release, "write-release-docs") =~ "gh pr merge"
  end
end
