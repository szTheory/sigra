[
  import_deps: [:ecto, :phoenix],
  inputs: [
    "*.{ex,exs}",
    "{config,lib}/**/*.{ex,exs}",
    # Do not use a blanket `test/**` — `test/example/_build` and `deps` contain
    # non-Elixir *.ex copies of install templates that break `mix format`.
    "test/{sigra,support,mix}/**/*.{ex,exs}",
    "test/fixtures/{css,prohibitions}/**/*.{ex,exs}",
    "test/*.{ex,exs}",
    "test/example/{lib,config,test,priv}/**/*.{ex,exs}",
    "test/example/mix.exs"
  ],
  export: [locals_without_parens: []]
]
