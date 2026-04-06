# Sigra

Comprehensive authentication library for Phoenix 1.8+.

Sigra fills the critical gap left by Pow's incompatibility with Phoenix 1.8+. It uses a hybrid
lib+generator architecture: security-critical code lives in the library (updated via
`mix deps.update`), while customizable application code (schemas, routes, LiveViews) is generated
into your project.

## Installation

Add `sigra` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sigra, "~> 0.1.0"}
  ]
end
```

Then run the install generator:

```bash
mix sigra.install Accounts User users
```

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/sigra).

## License

MIT License. See [LICENSE](LICENSE) for details.
