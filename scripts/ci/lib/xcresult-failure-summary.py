#!/usr/bin/env python3
"""Print a bounded, redacted failure summary from xcresult test JSON."""

from __future__ import annotations

import json
import pathlib
import re
import sys


MAX_LINES = 80
MAX_LINE_LENGTH = 500


def sanitize(value: str, private_values: list[str]) -> str:
    result = value
    for private in private_values:
        if private:
            result = result.replace(private, "[REDACTED]")
    result = re.sub(r"[A-Fa-f0-9]{8}-[A-Fa-f0-9-]{27,}", "[REDACTED]", result)
    result = re.sub(r"\b[A-Z0-9]{10}\b", "[REDACTED]", result)
    result = re.sub(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", "[REDACTED]", result)
    result = re.sub(
        r"(?i)\b(access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|bearer)\b"
        r"(?:\s*[:=]\s*|\s+)[^\s,;]+",
        "[REDACTED]",
        result,
    )
    result = re.sub(r"\b[A-Za-z0-9_-]{32,}\b", "[REDACTED]", result)
    return result[:MAX_LINE_LENGTH]


def failed_lines(nodes: object, private_values: list[str]) -> list[str]:
    output: list[str] = []

    def walk(node: object, failed_parent: bool = False) -> None:
        if not isinstance(node, dict) or len(output) >= MAX_LINES:
            return
        node_type = str(node.get("nodeType", ""))
        result = str(node.get("result", ""))
        failed = failed_parent or result == "Failed"
        if result == "Failed" or (failed and node_type in {"Failure Message", "Runtime Warning"}):
            name = sanitize(str(node.get("name", "")), private_values)
            details = sanitize(str(node.get("details", "")), private_values)
            parts = [part for part in (node_type, name, details) if part]
            if parts:
                output.append("xcresult: " + " | ".join(parts))
        for child in node.get("children", []) if isinstance(node.get("children"), list) else []:
            walk(child, failed)

    for root in nodes if isinstance(nodes, list) else []:
        walk(root)
    return output[:MAX_LINES]


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        raise SystemExit("usage: xcresult-failure-summary.py TESTS_JSON [PRIVATE_VALUE ...]")
    payload = json.loads(pathlib.Path(argv[1]).read_text(encoding="utf-8"))
    lines = failed_lines(payload.get("testNodes"), argv[2:])
    if not lines:
        print("xcresult: no structured failure nodes were available")
        return
    print("\n".join(lines))


if __name__ == "__main__":
    main(sys.argv)
