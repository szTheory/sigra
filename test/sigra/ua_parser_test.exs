defmodule Sigra.UAParserTest do
  use ExUnit.Case, async: true

  @moduletag :phase4

  alias Sigra.UAParser

  describe "parse/1" do
    test "parses Chrome on macOS" do
      ua =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

      result = UAParser.parse(ua)

      assert result.browser == "Chrome"
      assert result.browser_version == "120"
      assert result.os == "macOS"
    end

    test "parses Firefox on Windows" do
      ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"

      result = UAParser.parse(ua)

      assert result.browser == "Firefox"
      assert result.browser_version == "121"
      assert result.os == "Windows"
    end

    test "parses Safari on macOS" do
      ua =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"

      result = UAParser.parse(ua)

      assert result.browser == "Safari"
      assert result.browser_version == "17"
      assert result.os == "macOS"
    end

    test "parses Edge on Windows" do
      ua =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"

      result = UAParser.parse(ua)

      assert result.browser == "Edge"
      assert result.browser_version == "120"
      assert result.os == "Windows"
    end

    test "parses Opera on Linux" do
      ua =
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 OPR/106.0.0.0"

      result = UAParser.parse(ua)

      assert result.browser == "Opera"
      assert result.browser_version == "106"
      assert result.os == "Linux"
    end

    test "parses Samsung Internet on Android" do
      ua =
        "Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/23.0 Chrome/115.0.0.0 Mobile Safari/537.36"

      result = UAParser.parse(ua)

      assert result.browser == "Samsung Internet"
      assert result.browser_version == "23"
      assert result.os == "Android"
    end

    test "parses Chrome on iOS" do
      ua =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/120.0.6099.119 Mobile/15E148 Safari/604.1"

      result = UAParser.parse(ua)

      assert result.browser == "Chrome"
      assert result.browser_version == "120"
      assert result.os == "iOS"
    end

    test "parses Chrome on Chrome OS" do
      ua =
        "Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

      result = UAParser.parse(ua)

      assert result.browser == "Chrome"
      assert result.browser_version == "120"
      assert result.os == "Chrome OS"
    end

    test "returns Unknown for unrecognized UA" do
      result = UAParser.parse("SomeUnknownBot/1.0")

      assert result.browser == "Unknown"
      assert result.browser_version == nil
      assert result.os == "Unknown"
    end

    test "returns Unknown for nil input" do
      result = UAParser.parse(nil)

      assert result.browser == "Unknown"
      assert result.browser_version == nil
      assert result.os == "Unknown"
    end

    test "returns Unknown for empty string" do
      result = UAParser.parse("")

      assert result.browser == "Unknown"
      assert result.browser_version == nil
      assert result.os == "Unknown"
    end
  end

  describe "friendly_name/1" do
    test "returns 'Chrome 120 on macOS' from parsed map" do
      parsed = %{browser: "Chrome", browser_version: "120", os: "macOS"}

      assert UAParser.friendly_name(parsed) == "Chrome 120 on macOS"
    end

    test "returns browser and os without version when version is nil" do
      parsed = %{browser: "Firefox", browser_version: nil, os: "Linux"}

      assert UAParser.friendly_name(parsed) == "Firefox on Linux"
    end

    test "returns 'Unknown browser' when browser is 'Unknown'" do
      parsed = %{browser: "Unknown", browser_version: nil, os: "Unknown"}

      assert UAParser.friendly_name(parsed) == "Unknown browser"
    end

    test "returns 'Edge 120 on Windows' from parsed map" do
      parsed = %{browser: "Edge", browser_version: "120", os: "Windows"}

      assert UAParser.friendly_name(parsed) == "Edge 120 on Windows"
    end
  end
end
