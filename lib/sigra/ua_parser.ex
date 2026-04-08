defmodule Sigra.UAParser do
  @moduledoc """
  Lightweight user-agent string parser.

  Extracts browser name, version, and operating system from User-Agent
  header strings using regex matching. Designed for session display
  ("Chrome 120 on macOS") rather than comprehensive UA analysis.

  ## Supported Browsers

  Edge, Opera, Samsung Internet, Chrome (including CriOS on iOS),
  Firefox, Safari. Match order is significant: Edge and Opera are
  checked before Chrome since their UA strings contain "Chrome".

  ## Supported Operating Systems

  iOS, Android, Chrome OS, macOS, Windows, Linux.
  """

  @type parsed :: %{
          browser: String.t(),
          browser_version: String.t() | nil,
          os: String.t()
        }

  @doc """
  Parses a user-agent string into a structured map.

  Returns `%{browser: String.t(), browser_version: String.t() | nil, os: String.t()}`.
  Returns `%{browser: "Unknown", browser_version: nil, os: "Unknown"}` for
  `nil`, empty, or unrecognized input.

  ## Examples

      iex> Sigra.UAParser.parse("Mozilla/5.0 ... Chrome/120.0.0.0 Safari/537.36")
      %{browser: "Chrome", browser_version: "120", os: ...}

      iex> Sigra.UAParser.parse(nil)
      %{browser: "Unknown", browser_version: nil, os: "Unknown"}

  """
  @doc since: "0.1.0"
  @spec parse(String.t() | nil) :: parsed()
  def parse(nil), do: %{browser: "Unknown", browser_version: nil, os: "Unknown"}
  def parse(""), do: %{browser: "Unknown", browser_version: nil, os: "Unknown"}

  def parse(ua) when is_binary(ua) do
    %{
      browser: detect_browser(ua),
      browser_version: detect_browser_version(ua),
      os: detect_os(ua)
    }
  end

  @doc """
  Returns a human-readable name from a parsed user-agent map.

  ## Examples

      iex> Sigra.UAParser.friendly_name(%{browser: "Chrome", browser_version: "120", os: "macOS"})
      "Chrome 120 on macOS"

      iex> Sigra.UAParser.friendly_name(%{browser: "Unknown", browser_version: nil, os: "Unknown"})
      "Unknown browser"

  """
  @doc since: "0.1.0"
  @spec friendly_name(parsed()) :: String.t()
  def friendly_name(%{browser: "Unknown"}), do: "Unknown browser"

  def friendly_name(%{browser: browser, browser_version: nil, os: os}) do
    "#{browser} on #{os}"
  end

  def friendly_name(%{browser: browser, browser_version: version, os: os}) do
    "#{browser} #{version} on #{os}"
  end

  # Browser detection — order matters!
  # Edge before Chrome (Edge UA contains "Chrome")
  # Opera before Chrome (Opera UA contains "Chrome")
  # Samsung Internet before Chrome
  # Chrome before Safari (Chrome UA contains "Safari")
  defp detect_browser(ua) do
    cond do
      ua =~ ~r/Edg[e\/]/ -> "Edge"
      ua =~ ~r/OPR\// -> "Opera"
      ua =~ ~r/SamsungBrowser\// -> "Samsung Internet"
      ua =~ ~r/CriOS\// -> "Chrome"
      ua =~ ~r/Chrome\// -> "Chrome"
      ua =~ ~r/Firefox\// -> "Firefox"
      ua =~ ~r/Version\/.*Safari\// -> "Safari"
      true -> "Unknown"
    end
  end

  defp detect_browser_version(ua) do
    patterns = [
      ~r/Edg[e\/](\d+)/,
      ~r/OPR\/(\d+)/,
      ~r/SamsungBrowser\/(\d+)/,
      ~r/CriOS\/(\d+)/,
      ~r/Chrome\/(\d+)/,
      ~r/Firefox\/(\d+)/,
      ~r/Version\/(\d+).*Safari\//
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, ua) do
        [_, version] -> version
        _ -> nil
      end
    end)
  end

  defp detect_os(ua) do
    cond do
      ua =~ ~r/iPhone|iPad|iPod/ -> "iOS"
      ua =~ ~r/Android/ -> "Android"
      ua =~ ~r/CrOS/ -> "Chrome OS"
      ua =~ ~r/Macintosh|Mac OS X/ -> "macOS"
      ua =~ ~r/Windows/ -> "Windows"
      ua =~ ~r/Linux/ -> "Linux"
      true -> "Unknown"
    end
  end
end
