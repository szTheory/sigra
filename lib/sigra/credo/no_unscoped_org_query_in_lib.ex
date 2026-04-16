if Code.ensure_loaded?(Credo.Check) do
defmodule Sigra.Credo.NoUnscopedOrgQueryInLib do
  @moduledoc """
  Flags obvious unscoped Repo reads on org-scoped schemas in `lib/sigra/**`.

  This check is intentionally narrow. It only matches direct
  `Repo.all/one/get/get_by` calls where the schema argument is an alias for
  a known org-scoped Sigra schema. Queries already wrapped in `for_org/2`,
  dynamic schema references, and broader query-shape proofs are left to the
  existing `for_org/2` discipline and `prepare_query/3` enforcement.

  Allowed locations:

    * Anywhere under `test/**`
    * Files outside `lib/sigra/**`
    * Calls that pass `skip_org_check: true`
  """

  use Credo.Check,
    id: "SIGRA0002",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: ~S'''
      Scope org-aware reads through Sigra.Organizations.Query.for_org/2
      before calling Repo. This check only covers obvious direct schema
      calls in lib/sigra/** and exists as defense-in-depth for DX-09.
      '''
    ]

  @repo_calls %{all: 1, one: 1, get: 2, get_by: 2}
  @scoped_schemas [[:Sigra, :Schema, :OrganizationInvitation], [:Sigra, :Schema, :OrganizationMembership]]
  @scoped_schema_names [:OrganizationInvitation, :OrganizationMembership]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    ctx = Context.build(source_file, params, __MODULE__)
    path = source_file.filename

    cond do
      String.contains?(path, "/test/") -> []
      not String.contains?(path, "lib/sigra/") -> []
      true -> Credo.Code.prewalk(source_file, &walk/2, ctx).issues
    end
  end

  defp walk({{:., _, [repo_ast, fun]}, meta, args} = ast, ctx) when is_list(args) do
    if repo_call?(repo_ast, fun) and unscoped_schema_call?(fun, args) do
      {ast, put_issue(ctx, issue_for(ctx, meta, fun))}
    else
      {ast, ctx}
    end
  end

  defp walk(ast, ctx), do: {ast, ctx}

  defp repo_call?({:__aliases__, _, alias_parts}, fun),
    do: is_integer(Map.get(@repo_calls, fun)) and List.last(alias_parts) == :Repo

  defp repo_call?({name, _, _}, fun) when is_atom(name),
    do: is_integer(Map.get(@repo_calls, fun)) and name == :repo
  defp repo_call?(_, _), do: false

  defp unscoped_schema_call?(fun, args) do
    required = Map.fetch!(@repo_calls, fun)
    length(args) in [required, required + 1] and
      schema_arg?(List.first(args)) and
      not skip_org_check?(Enum.at(args, required))
  end

  defp schema_arg?({:__aliases__, _, alias_parts}),
    do: alias_parts in @scoped_schemas or List.last(alias_parts) in @scoped_schema_names
  defp schema_arg?(_), do: false

  defp skip_org_check?(opts) when is_list(opts), do: Keyword.get(opts, :skip_org_check) == true
  defp skip_org_check?(_), do: false

  defp issue_for(ctx, meta, fun) do
    format_issue(
      ctx,
      message: "Scope org-aware Repo.#{fun} calls through Sigra.Organizations.Query.for_org/2",
      trigger: "Repo.#{fun}",
      line_no: meta[:line] || 0
    )
  end
end
end
