defmodule ExampleWeb.LoginSubmitSelectorTest do
  @moduledoc """
  Phase 259 Plan 03 (BCOPY-06): deterministic proof that the copy-independent
  Playwright login-submit selector is not ambiguous.

  Playwright strict-mode locators throw when a selector matches more than one
  element, so the selector in `priv/playwright/helpers/loginSubmit.ts` must
  resolve to exactly ONE element on the password login form. Playwright is not
  installed locally, so the browser-runtime proof of the specs is the PR's
  `example_playwright_shard` CI lanes. These tests are the local proof of the
  selector itself.

  The selector is read out of the helper file by regex, so this test and the
  Playwright helper share one source of truth (the helper must keep
  `LOGIN_SUBMIT_SELECTOR` as a single-quoted string literal).

  1. `GET /users/log_in` on the example host renders exactly one match.
  2. Planted controls prove the count assertion can fail (two submit buttons
     give 2) and that `type="button"` controls are ignored (one submit plus
     one `type="button"` gives 1).
  3. The GENERATED login markup cannot be rendered in the example host, so the
     third group is a SOURCE assertion against the templates under
     `priv/templates/sigra.install/core/` (read only, never written): the
     password form block holding `id="login_form"` contains exactly one
     `sigra_auth_button` call and no `type="button"`, and the component's
     `type` attr defaults to `"submit"`. It is not a render.
  """
  use ExampleWeb.ConnCase, async: true

  @moduletag :example_app

  @helper_path Path.expand("../../priv/playwright/helpers/loginSubmit.ts", __DIR__)
  @templates_dir Path.expand("../../../../priv/templates/sigra.install/core", __DIR__)

  describe "GET /users/log_in (example host render)" do
    test "the extracted selector matches exactly one element", %{conn: conn} do
      selector = selector()

      conn = get(conn, ~p"/users/log_in")
      body = html_response(conn, 200)

      count = body |> LazyHTML.from_document() |> LazyHTML.query(selector) |> Enum.count()

      assert count == 1,
             "expected the login submit selector to match exactly 1 element on " <>
               "/users/log_in, matched #{count}"
    end
  end

  describe "planted controls" do
    test "two submit buttons inside the login form are counted as two" do
      selector = selector()

      html = """
      <form id="login_form">
        <button>Log in</button>
        <button type="submit">Log in again</button>
      </form>
      """

      count = count_matches(html, selector)

      assert count == 2
    end

    test "a type=button control inside the login form is ignored" do
      selector = selector()

      html = """
      <form id="login_form">
        <button type="button">Use a passkey</button>
        <button>Anything at all</button>
      </form>
      """

      count = count_matches(html, selector)

      assert count == 1
    end

    test "buttons outside the login form are not matched" do
      selector = selector()

      html = """
      <form id="login_form"><button>Go</button></form>
      <form id="passkey_login_form"><button>Passkey</button></form>
      <form id="magic_link_form"><button>Email me</button></form>
      """

      count = count_matches(html, selector)

      assert count == 1
    end
  end

  describe "generated login markup (source assertion, not a render)" do
    test "the password form block has exactly one auth button and no type=button" do
      source = File.read!(Path.join(@templates_dir, "login_html.ex"))

      block = login_form_block(source)

      assert block =~ ~s(id="login_form")
      assert block =~ "</.form>"
      assert count_occurrences(block, "<.sigra_auth_button") == 1
      refute block =~ ~s(type="button")
    end

    test "the auth button component defaults its type attr to submit" do
      source = File.read!(Path.join(@templates_dir, "sigra_auth_components.ex"))

      assert source =~ ~r/^\s*attr :type, :string, default: "submit"/m
    end

    test "planted control: a second auth button in the block is detected" do
      source = """
      <.form id="login_form" action="/x">
        <.sigra_auth_button>One</.sigra_auth_button>
        <.sigra_auth_button>Two</.sigra_auth_button>
      </.form>
      """

      block = login_form_block(source)

      assert count_occurrences(block, "<.sigra_auth_button") == 2
    end
  end

  # Reads the single-quoted LOGIN_SUBMIT_SELECTOR literal out of the Playwright
  # helper so the test and the helper cannot drift apart.
  defp selector do
    source = File.read!(@helper_path)

    case Regex.run(~r/LOGIN_SUBMIT_SELECTOR\s*=\s*'([^']+)'/, source) do
      [_, selector] -> selector
      nil -> flunk("LOGIN_SUBMIT_SELECTOR single-quoted literal not found in #{@helper_path}")
    end
  end

  defp count_matches(html, selector) do
    html |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count()
  end

  # Slice from the line holding id="login_form" through the next closing form tag.
  defp login_form_block(source) do
    lines = String.split(source, "\n")

    case Enum.drop_while(lines, &(not String.contains?(&1, ~s(id="login_form")))) do
      [] ->
        flunk(~s(no line containing id="login_form" found in template source))

      from_open ->
        {block, rest} = Enum.split_while(from_open, &(not String.contains?(&1, "</.form>")))

        closing = Enum.take(rest, 1)
        Enum.join(block ++ closing, "\n")
    end
  end

  defp count_occurrences(haystack, needle) do
    haystack |> String.split(needle) |> length() |> Kernel.-(1)
  end
end
