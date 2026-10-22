ARG PLAYWRIGHT_IMAGE=mcr.microsoft.com/playwright@sha256:eac9b0a5312cdab40ee8c2429df5bf19bffdccf8f3bf3c42268e173f97541645
FROM ${PLAYWRIGHT_IMAGE}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git unzip libncurses6 libsctp1 && rm -rf /var/lib/apt/lists/*
COPY assets /assets
RUN cd /assets && sha256sum -c SHA256SUMS && \
    mkdir -p /opt/otp /opt/elixir /opt/node && \
    tar -xzf otp.tar.gz --strip-components=1 -C /opt/otp && /opt/otp/Install -minimal /opt/otp && \
    unzip -q elixir.zip -d /opt/elixir && \
    tar -xJf node.tar.xz --strip-components=1 -C /opt/node && rm -rf /assets
ENV PATH=/opt/node/bin:/opt/elixir/bin:/opt/otp/bin:$PATH \
    MIX_ENV=dev PORT=4011 PGHOST=localhost PGPORT=5432 PGUSER=postgres \
    PGPASSWORD=postgres PGDATABASE=sigra_admin_eval_render \
    SIGRA_EXAMPLE_URL=http://localhost:4011 CI=true \
    ERL_AFLAGS="+JMsingle true"
# User-space x64 emulation needs this VM flag; native CI did not use it.
# https://github.com/erlang/otp/issues/10355
COPY source /work
COPY full-prefix.config.ts /work/test/example/priv/playwright/.phase253-linux.config.ts
WORKDIR /work/test/example
RUN mix local.hex --force && mix local.rebar --force && \
    mix deps.get && mix compile --warnings-as-errors
WORKDIR /work/test/example/priv/playwright
RUN mkdir -p /diagnostic && npm ci && node node_modules/playwright/cli.js test tests/admin-eval.spec.ts \
    --config=.phase253-linux.config.ts --list --reporter=json > /diagnostic/collection.json
COPY in_container.py /diagnostic/in_container.py
ENTRYPOINT ["python3", "/diagnostic/in_container.py"]
