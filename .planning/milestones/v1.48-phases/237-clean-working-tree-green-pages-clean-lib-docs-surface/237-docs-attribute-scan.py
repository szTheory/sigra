#!/usr/bin/env python3
"""Scan @moduledoc/@doc/@shortdoc/@typedoc heredoc ranges under lib/ for
planning-bookkeeping tokens. Reproduces 237-RESEARCH.md §E.2/§E.6.

Usage: python3 docscan.py [lib_dir]
"""
import re
import sys
import glob
import os

root = sys.argv[1] if len(sys.argv) > 1 else "lib"

tokens = re.compile(
    r"(\.planning/|\bPhase \d{1,3}\b|\bphase[-_]\d{1,3}\b|\bD-\d{2}\b|"
    r"\bSC-\d\b|\bREQ-[A-Z0-9]|\bPitfall \d\b|\bINV-\d|"
    r"-PLAN\.md|-CONTEXT\.md|-SUMMARY\.md|\btodos/\b)"
)
start = re.compile(r'^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"""')
oneline = re.compile(r'^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"')

total_hits = 0
sites = set()
files_hit = set()
file_counts = {}

for path in sorted(glob.glob(os.path.join(root, "**", "*.ex"), recursive=True)) + \
            sorted(glob.glob(os.path.join(root, "**", "*.exs"), recursive=True)):
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    in_block = False
    for i, line in enumerate(lines, start=1):
        if not in_block:
            if start.match(line):
                in_block = True
                # check the same line for tokens too (heredoc opener line)
                for m in tokens.finditer(line):
                    total_hits += 1
                    sites.add((path, i))
                    files_hit.add(path)
                    file_counts[path] = file_counts.get(path, 0) + 1
                continue
            if oneline.match(line) and '"""' not in line:
                # single-quoted one-line doc attribute (rare); treat this line only
                for m in tokens.finditer(line):
                    total_hits += 1
                    sites.add((path, i))
                    files_hit.add(path)
                    file_counts[path] = file_counts.get(path, 0) + 1
                continue
        else:
            if '"""' in line:
                in_block = False
                # tokens on the closing line still count if present before the triple-quote
                for m in tokens.finditer(line):
                    total_hits += 1
                    sites.add((path, i))
                    files_hit.add(path)
                    file_counts[path] = file_counts.get(path, 0) + 1
                continue
            for m in tokens.finditer(line):
                total_hits += 1
                sites.add((path, i))
                files_hit.add(path)
                file_counts[path] = file_counts.get(path, 0) + 1

print(f"total_hits={total_hits}")
print(f"distinct_sites={len(sites)}")
print(f"distinct_files={len(files_hit)}")
print("top_files:")
for path, count in sorted(file_counts.items(), key=lambda x: -x[1])[:15]:
    print(f"  {count}\t{path}")
