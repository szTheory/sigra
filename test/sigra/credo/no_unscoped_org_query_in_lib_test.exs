defmodule Sigra.Credo.NoUnscopedOrgQueryInLibTest do
  use Credo.Test.Case

  alias Sigra.Credo.NoUnscopedOrgQueryInLib

  setup_all do
    case Application.ensure_all_started(:credo) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end

    :ok
  end

  test "fires on Repo.all/1 with an org-scoped schema in lib/sigra/**" do
    """
    defmodule Sample do
      alias Sigra.Schema.OrganizationMembership
      alias Sigra.Repo

      def list_memberships, do: Repo.all(OrganizationMembership)
    end
    """
    |> to_source_file("lib/sigra/sample.ex")
    |> run_check(NoUnscopedOrgQueryInLib)
    |> assert_issue()
  end

  test "fires on Repo.get_by/2 with an org-scoped schema in lib/sigra/**" do
    """
    defmodule Sample do
      def fetch(repo), do: repo.get_by(Sigra.Schema.OrganizationInvitation, email: "x@example.com")
    end
    """
    |> to_source_file("lib/sigra/sample.ex")
    |> run_check(NoUnscopedOrgQueryInLib)
    |> assert_issue()
  end

  test "stays silent on for_org/2-scoped Repo calls" do
    """
    defmodule Sample do
      alias Sigra.Organizations.Query
      alias Sigra.Schema.OrganizationMembership
      alias Sigra.Repo

      def list_memberships(scope), do: Query.for_org(OrganizationMembership, scope) |> Repo.all()
    end
    """
    |> to_source_file("lib/sigra/sample.ex")
    |> run_check(NoUnscopedOrgQueryInLib)
    |> refute_issues()
  end

  test "stays silent on documented skip_org_check exceptions" do
    """
    defmodule Sample do
      alias Sigra.Schema.OrganizationMembership

      def list_memberships(repo), do: repo.all(OrganizationMembership, skip_org_check: true)
    end
    """
    |> to_source_file("lib/sigra/sample.ex")
    |> run_check(NoUnscopedOrgQueryInLib)
    |> refute_issues()
  end

  test "stays silent on files outside lib/sigra/**" do
    """
    defmodule Sample do
      def list_memberships(repo), do: repo.all(Sigra.Schema.OrganizationMembership)
    end
    """
    |> to_source_file("lib/my_app/sample.ex")
    |> run_check(NoUnscopedOrgQueryInLib)
    |> refute_issues()
  end
end
