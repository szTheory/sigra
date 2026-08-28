defmodule Example.RateLimit do
  @moduledoc "Host-owned Hammer ETS limiter for Sigra authentication ceremonies."
  use Hammer, backend: :ets
end
