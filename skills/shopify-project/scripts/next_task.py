#!/usr/bin/env python3
"""Summarise TASKS.md: phase, counts, open tasks in order, blockers. Usage: next_task.py [path/to/TASKS.md]"""
import re, sys
from pathlib import Path


def find_tasks():
    if len(sys.argv) > 1:
        return Path(sys.argv[1])
    for d in [Path.cwd(), *Path.cwd().parents]:
        if (d / "TASKS.md").exists():
            return d / "TASKS.md"
    sys.exit("TASKS.md not found")


text = find_tasks().read_text()
phase = re.search(r"\*\*Current phase:\*\*\s*(.+)", text)
print("Current phase:", phase.group(1).strip() if phase else "?")

section, counts, open_tasks = None, {"x": 0, "~": 0, " ": 0, "!": 0}, []
for line in text.splitlines():
    if line.startswith("## "):
        section = line[3:].strip()
        if section.lower().startswith(("blockers", "activity")):
            section = None
        continue
    m = re.match(r"- \[([ x~!])\] (.+)", line)  # top-level tasks only
    if not section or not m or "approved" in m.group(2).lower():
        continue
    counts[m.group(1)] += 1
    if m.group(1) != "x":
        open_tasks.append((section, m.group(1), m.group(2)[:160]))

print(f"done {counts['x']} · partial {counts['~']} · todo {counts[' ']} · blocked {counts['!']}")
print("\nOpen tasks (work top-down; skip [!]):")
for sec, mark, t in open_tasks:
    print(f"  [{mark}] {t}   ({sec.split('—')[0].strip()})")

b = re.search(r"## Blockers[^\n]*\n(.*?)(\n## |\Z)", text, re.S)
if b:
    items = [l for l in b.group(1).splitlines() if l.startswith("- ")]
    print(f"\nBlockers / open questions: {len(items)}")
    for l in items[:8]:
        print("  " + l[:160])
