defmodule Sigra.AuthFixturesScenarioTest do
  @moduledoc """
  Content tests for the generated AuthFixtures template's scenario fixtures
  (Phase 10, DX-03). These tests validate the raw `.ex` template file, not
  the compiled/rendered output — rendering requires host-app bindings that
  only exist inside a generated Phoenix project. An integration smoke test
  that exercises the rendered module at runtime is deferred to plan 10-06
  via the committed `test/example/` app.

  Behaviors asserted (map to 10-02 PLAN behaviors 1-9):

    1. `anonymous_fixture/0` defined
    2. `authenticated_fixture/1` defined and returns `%{user, session, conn}`
    3. `mfa_pending_fixture/1` defined, delegates to the existing primitive,
       and does NOT include `:conn`
    4. `mfa_complete_fixture/1` defined with a standard-type session and
       includes `:conn`
    5. `sudo_fixture/1` defined with `sudo_session_fixture` composition
    6. `locked_fixture/1` defined via `locked_user_fixture` composition,
       no `:conn`
    7. `unconfirmed_fixture/1` defined, returns just the user, no `:conn`
    8. `scenario/2` dispatcher with head + 7 atom clauses (8 total `def scenario`
       occurrences)
    9. No `def scenario(... is_binary ...)` clause — strings are rejected
       (Open Q5 resolution)

  Plus guard rails from the plan's acceptance criteria:

    - No atom-typed session `type: :standard` / `type: :mfa_pending` (Pitfall 2)
    - No `mfa_verified_at` field references (Pitfall 3)
    - `log_in_user` import from the generated ConnCaseHelpers module
    - `build_conn/0` import from `Phoenix.ConnTest`
  """

  use ExUnit.Case, async: true

  @template_path Path.expand(
                   "../../priv/templates/sigra.install/core/auth_fixtures.ex",
                   __DIR__
                 )

  setup do
    content = File.read!(@template_path)
    %{content: content}
  end

  describe "scenario fixture function definitions" do
    test "defines anonymous_fixture/0", %{content: content} do
      assert content =~ "def anonymous_fixture"
    end

    test "defines authenticated_fixture/1", %{content: content} do
      assert content =~ "def authenticated_fixture(attrs"
    end

    test "defines mfa_pending_fixture/1", %{content: content} do
      assert content =~ "def mfa_pending_fixture(attrs"
    end

    test "defines mfa_complete_fixture/1", %{content: content} do
      assert content =~ "def mfa_complete_fixture(attrs"
    end

    test "defines sudo_fixture/1", %{content: content} do
      assert content =~ "def sudo_fixture(attrs"
    end

    test "defines locked_fixture/1", %{content: content} do
      assert content =~ "def locked_fixture(attrs"
    end

    test "defines unconfirmed_fixture/1", %{content: content} do
      assert content =~ "def unconfirmed_fixture(attrs"
    end

    test "defines all seven scenario fixture functions", %{content: content} do
      pattern =
        ~r/def (anonymous|authenticated|mfa_pending|mfa_complete|sudo|locked|unconfirmed)_fixture/

      matches = Regex.scan(pattern, content)
      # Seven unique names, one def each.
      names = matches |> Enum.map(fn [_, name] -> name end) |> Enum.uniq()
      assert length(names) == 7, "expected 7 scenario fixture functions, got: #{inspect(names)}"
    end
  end

  describe "scenario return shapes (D-04, D-07)" do
    test "anonymous_fixture returns %{conn: ...}", %{content: content} do
      assert content =~ ~r/def anonymous_fixture.*?%\{conn: build_conn\(\)\}/s
    end

    test "authenticated_fixture returns user, session, and logged-in conn", %{content: content} do
      authenticated = extract_function(content, "authenticated_fixture")
      assert authenticated =~ "user_fixture"
      assert authenticated =~ "session_fixture"
      assert authenticated =~ "log_in_user(build_conn()"
      assert authenticated =~ "user: user"
      assert authenticated =~ "session: session"
      assert authenticated =~ "conn:"
    end

    test "mfa_pending_fixture delegates to the existing primitive", %{content: content} do
      body = extract_function(content, "mfa_pending_fixture")
      assert body =~ "mfa_pending_session_fixture"
    end

    test "mfa_pending_fixture does NOT build a conn (D-07)", %{content: content} do
      body = extract_function(content, "mfa_pending_fixture")
      refute body =~ "log_in_user",
             "mfa_pending_fixture must not log in a conn (caller hasn't passed the challenge)"
    end

    test "mfa_complete_fixture uses standard-type session and logs in a conn", %{content: content} do
      body = extract_function(content, "mfa_complete_fixture")
      assert body =~ "mfa_user_fixture"
      assert body =~ ~s|type: "standard"|
      assert body =~ "log_in_user(build_conn()"
      assert body =~ "totp_secret"
    end

    test "sudo_fixture composes sudo_session_fixture and logs in a conn", %{content: content} do
      body = extract_function(content, "sudo_fixture")
      assert body =~ "sudo_session_fixture"
      assert body =~ "log_in_user(build_conn()"
    end

    test "locked_fixture composes locked_user_fixture and returns no conn (D-07)", %{content: content} do
      body = extract_function(content, "locked_fixture")
      assert body =~ "locked_user_fixture"
      refute body =~ "log_in_user"
      refute body =~ "session:"
    end

    test "unconfirmed_fixture returns just the user and no conn (D-06, D-07)", %{content: content} do
      body = extract_function(content, "unconfirmed_fixture")
      assert body =~ "user_fixture"
      refute body =~ "log_in_user"
      refute body =~ "session:"
    end
  end

  describe "scenario/2 dispatcher (D-03, Open Q5, D-10.1-13)" do
    test "has a head plus 7 atom clauses plus catch-all (9 total def scenario)", %{
      content: content
    } do
      count = Regex.scan(~r/def scenario\(/, content) |> length()

      assert count == 9,
             "expected 9 def scenario occurrences (head + 7 atom clauses + 1 is_atom catch-all), got #{count}"
    end

    test "dispatches all seven scenario atoms", %{content: content} do
      for atom <-
            ~w(anonymous authenticated mfa_pending mfa_complete sudo locked unconfirmed) do
        assert content =~ "def scenario(:#{atom}",
               "expected dispatcher clause for :#{atom}"
      end
    end

    test "does NOT define a string-accepting clause (Open Q5)", %{content: content} do
      refute Regex.match?(~r/def scenario\([^)]*is_binary/, content),
             "scenario/2 must raise on string input, not define an is_binary clause"
    end

    test "defines @valid_scenarios module attribute with all seven atoms (D-10.1-13)", %{
      content: content
    } do
      assert content =~ "@valid_scenarios",
             "expected @valid_scenarios module attribute adjacent to scenario/2"

      for atom <-
            ~w(anonymous authenticated mfa_pending mfa_complete sudo locked unconfirmed) do
        assert content =~ ":#{atom}",
               "expected :#{atom} to appear in @valid_scenarios list"
      end
    end

    test "@valid_scenarios appears before the first def scenario( head (D-10.1-13 placement)", %{
      content: content
    } do
      attr_index =
        case :binary.match(content, "@valid_scenarios") do
          {i, _} -> i
          :nomatch -> nil
        end

      def_index =
        case :binary.match(content, "def scenario(") do
          {i, _} -> i
          :nomatch -> nil
        end

      assert is_integer(attr_index) and is_integer(def_index),
             "expected both @valid_scenarios and def scenario( in template"

      assert attr_index < def_index,
             "expected @valid_scenarios to be declared before the first def scenario( head, " <>
               "got attr@#{attr_index} vs def@#{def_index}"
    end

    test "catch-all clause uses is_atom guard and raises ArgumentError (D-10.1-13)", %{
      content: content
    } do
      assert Regex.match?(~r/def scenario\(other, _attrs\) when is_atom\(other\)/, content),
             "expected catch-all clause `def scenario(other, _attrs) when is_atom(other)`"

      assert content =~ "raise ArgumentError",
             "expected catch-all clause to raise ArgumentError"

      assert content =~ "unknown scenario",
             "expected ArgumentError message to start with `unknown scenario`"

      assert content =~ "Valid scenarios:",
             "expected ArgumentError message to list valid scenarios"
    end
  end

  describe "imports and helpers" do
    test "imports build_conn/0 from Phoenix.ConnTest", %{content: content} do
      assert content =~ "import Phoenix.ConnTest"
      assert content =~ "build_conn: 0"
    end

    test "imports log_in_user from the generated ConnCaseHelpers", %{content: content} do
      assert content =~ "ConnCaseHelpers"
      assert content =~ "log_in_user"
    end
  end

  describe "pitfall guard rails" do
    test "no atom-typed session.type (Pitfall 2)", %{content: content} do
      refute content =~ "type: :standard"
      refute content =~ "type: :mfa_pending"
    end

    test "no mfa_verified_at field references (Pitfall 3)", %{content: content} do
      refute content =~ "mfa_verified_at"
    end
  end

  # Extracts the body of a `def <name>` through its matching terminator.
  # Simple heuristic: grab everything from `def <name>` up to the next
  # top-level `def ` or `# ---` section marker. Good enough for content
  # assertions since the template is small and flat.
  defp extract_function(content, name) do
    case Regex.run(~r/def #{name}[^\n]*\n(.*?)(?=\n  def |\n  # ---|\nend\n)/s, content) do
      [match, _body] -> match
      _ -> ""
    end
  end
end
