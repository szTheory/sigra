defmodule Sigra.Credo.NoLogSafe2InLibTest do
  use Credo.Test.Case

  alias Sigra.Credo.NoLogSafe2InLib

  # Credo is compiled with `runtime: false` in Sigra's mix.exs, so the
  # `Credo.Application` supervision tree is NOT auto-started. Credo's test
  # helpers rely on the SourceFileAST agent from that tree. Start it once
  # per test module before any test runs.
  setup_all do
    case Application.ensure_all_started(:credo) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end

    :ok
  end

  test "fires on arity-2 Sigra.Audit.log_safe in lib/sigra/**" do
    """
    defmodule Sample do
      def do_it do
        Sigra.Audit.log_safe("sample.event", repo: MyRepo, audit_schema: MySchema, metadata: %{})
      end
    end
    """
    |> to_source_file("lib/sigra/sample.ex")
    |> run_check(NoLogSafe2InLib)
    |> assert_issue()
  end

  test "fires on arity-2 aliased Audit.log_safe in lib/sigra/**" do
    """
    defmodule Sample do
      alias Sigra.Audit

      def do_it do
        Audit.log_safe("sample.event", repo: MyRepo, audit_schema: MySchema, metadata: %{})
      end
    end
    """
    |> to_source_file("lib/sigra/sample.ex")
    |> run_check(NoLogSafe2InLib)
    |> assert_issue()
  end

  test "stays silent on arity-3 form with explicit nil scope" do
    """
    defmodule Sample do
      def do_it do
        Sigra.Audit.log_safe("sample.event", nil, repo: MyRepo, audit_schema: MySchema, metadata: %{})
      end
    end
    """
    |> to_source_file("lib/sigra/sample.ex")
    |> run_check(NoLogSafe2InLib)
    |> refute_issues()
  end

  test "stays silent on lib/sigra/audit.ex (the shim definition itself)" do
    """
    defmodule Sigra.Audit do
      def log_safe(action, opts) when is_binary(action) and is_list(opts) do
        log_safe(action, nil, opts)
      end
    end
    """
    |> to_source_file("lib/sigra/audit.ex")
    |> run_check(NoLogSafe2InLib)
    |> refute_issues()
  end

  test "stays silent on test/ files" do
    """
    defmodule SampleTest do
      def do_it do
        Sigra.Audit.log_safe("test.event", repo: TestRepo, audit_schema: TestSchema, metadata: %{})
      end
    end
    """
    |> to_source_file("test/sigra/sample_test.exs")
    |> run_check(NoLogSafe2InLib)
    |> refute_issues()
  end

  test "stays silent on files outside lib/sigra/**" do
    """
    defmodule MyApp.Sample do
      def do_it do
        Sigra.Audit.log_safe("sample.event", repo: MyRepo, audit_schema: MySchema, metadata: %{})
      end
    end
    """
    |> to_source_file("lib/my_app/sample.ex")
    |> run_check(NoLogSafe2InLib)
    |> refute_issues()
  end
end
