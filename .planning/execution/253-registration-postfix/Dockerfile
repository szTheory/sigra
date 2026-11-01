FROM sigra-phase253-registration-linux:original-4ff6c50e4
ENV HEX_OFFLINE=1 SIGRA_DEBUG_ROOT=/work
COPY source.tar source-manifest.json commit.raw /postfix/
COPY npm-content /root/.npm/_cacache/content-v2/
COPY in_container.py inspect_compiled_endpoint.exs /postfix/
RUN python3 /postfix/in_container.py --install-source
WORKDIR /work/test/example/priv/playwright
RUN npm ci --offline --ignore-scripts --no-audit --no-fund
WORKDIR /work/test/example
RUN mix deps.compile sigra --force && mix compile --force --warnings-as-errors
RUN elixir /postfix/inspect_compiled_endpoint.exs > /postfix/endpoint.json
RUN elixir -e 'ExUnit.start(); Code.require_file("/work/test/sigra/planning/phase_253_ci_static_runtime_test.exs")'
WORKDIR /work/test/example/priv/playwright
RUN python3 /postfix/in_container.py --collect > /postfix/collection.json
ENTRYPOINT ["python3", "/postfix/in_container.py"]
