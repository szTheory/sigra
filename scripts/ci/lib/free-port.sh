#!/usr/bin/env bash
# scripts/ci/lib/free-port.sh
#
# Source from CI/local smoke scripts that need to boot Phoenix without assuming
# localhost:4000 is available.

find_free_port() {
  elixir -e '
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_ip, port}} = :inet.sockname(socket)
    :gen_tcp.close(socket)
    IO.write(port)
  '
}
