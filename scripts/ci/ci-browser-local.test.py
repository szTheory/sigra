#!/usr/bin/env python3
import socket
import unittest
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

spec = spec_from_file_location("ci_browser_local", Path(__file__).with_name("ci-browser-local.py"))
local = module_from_spec(spec)
spec.loader.exec_module(local)
port_available = local.port_available


class BrowserLocalSafetyTests(unittest.TestCase):
    def test_rejects_an_already_bound_port_without_releasing_it(self):
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen()
        try:
            port = listener.getsockname()[1]
            self.assertFalse(port_available(port))
            self.assertEqual(listener.getsockname()[1], port)
        finally:
            listener.close()


if __name__ == "__main__":
    unittest.main()
