if Code.ensure_loaded?(Credo.Check) do
  defmodule Sigra.Credo.NoLogSafe2InLib do
    @moduledoc """
    Forbids arity-2 `Sigra.Audit.log_safe/2` calls in `lib/sigra/**`.

    Arity-2 is a shim that passes `nil` scope. Library code MUST use the
    3-arity form so that the scope is visible at every call site, even
    when it is explicitly `nil`. This prevents drift under future phases.

    Allowed locations:

      * The shim definition itself in `lib/sigra/audit.ex`
      * Anywhere under `test/**`
      * Host-app generated code outside `lib/sigra/**`

    The module is guarded behind `Code.ensure_loaded?(Credo.Check)` so
    downstream host apps that depend on Sigra as a hex package do not
    need Credo in their own dep graph — the check is dev-only tooling.

    ## Known limitation

    The walker matches alias parts against both the fully-qualified
    `[:Sigra, :Audit]` form and the bare `[:Audit]` form (the latter
    covers `alias Sigra.Audit` at the top of the calling file). If a
    future module under `lib/sigra/**` aliases a non-Sigra `.Audit`
    module (e.g. `alias MyApp.SomethingElse.Audit`) and then calls
    `Audit.log_safe/2` on it, this check will false-positive on that
    call because it does not resolve alias declarations against the
    file's AST header.

    Today there is nothing in `lib/sigra/**` that aliases a non-Sigra
    `Audit` module, so the risk is latent. If you hit this case, the
    escape hatch is a Credo disable comment above the call site:

        # credo:disable-for-next-line Sigra.Credo.NoLogSafe2InLib
        Audit.log_safe("my.event", opts)
    """

    use Credo.Check,
      id: "SIGRA0001",
      base_priority: :high,
      category: :warning,
      explanations: [
        check: ~S'''
        Use Sigra.Audit.log_safe/3 with an explicit scope argument (or nil)
        instead of the arity-2 shim. Library code MUST make the scope
        positional argument visible at every call site.

          Bad:  arity-2 call that passes only (action, opts)
          Good: arity-3 call that passes (action, scope, opts)
          Good: arity-3 call that passes (action, nil, opts) for
                truly-anonymous pre-auth sites.
        '''
      ]

    @impl true
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__)
      path = source_file.filename

      cond do
        String.contains?(path, "/test/") ->
          []

        String.ends_with?(path, "lib/sigra/audit.ex") ->
          []

        not String.contains?(path, "lib/sigra/") ->
          []

        true ->
          result = Credo.Code.prewalk(source_file, &walk/2, ctx)
          result.issues
      end
    end

    # Qualified call: Foo.Bar.log_safe(arg1, arg2) — arity 2, alias must
    # resolve to Sigra.Audit or its aliased form `Audit`.
    defp walk({{:., _, [{:__aliases__, _, alias_parts}, :log_safe]}, meta, args} = ast, ctx)
         when length(args) == 2 do
      if alias_parts in [[:Sigra, :Audit], [:Audit]] do
        {ast, put_issue(ctx, issue_for(ctx, meta))}
      else
        {ast, ctx}
      end
    end

    defp walk(ast, ctx), do: {ast, ctx}

    defp issue_for(ctx, meta) do
      format_issue(
        ctx,
        message: "Use Sigra.Audit.log_safe/3 (with explicit scope) in library code, not /2",
        trigger: "Sigra.Audit.log_safe/2",
        line_no: meta[:line] || 0
      )
    end
  end
end
