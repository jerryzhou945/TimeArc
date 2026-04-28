#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Record one error into the TimeArc harness journal.

See .harness/tools/README.md for the full machine-interface contract.

Exit codes:
    0  success (report written, jsonl appended, INDEX updated)
    1  usage error or malformed args
    2  filesystem error
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

LEVELS = ("L1", "L2", "L3")
TRACKS = ("A", "B", "C")
PLATFORMS = ("windows", "macos", "linux", "n-a")
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,39}$")

HARNESS_ROOT = Path(__file__).resolve().parent.parent
JOURNAL = HARNESS_ROOT / "journal"
ERRORS_DIR = JOURNAL / "errors"
JSONL = JOURNAL / "errors.jsonl"
INDEX = JOURNAL / "INDEX.md"


def die(msg, code=1):
    print(f"record_error.py: {msg}", file=sys.stderr)
    return code


def parse_args(argv):
    p = argparse.ArgumentParser(
        prog="record_error.py",
        description="Record one error into the TimeArc harness journal.",
    )
    p.add_argument("--level", required=True, choices=LEVELS)
    p.add_argument("--track", required=True, choices=TRACKS)
    p.add_argument("--topic", required=True,
                   help="kebab-case slug, [a-z0-9-], <= 40 chars")
    p.add_argument("--summary", required=True)
    p.add_argument("--file", default=None)
    p.add_argument("--platform", default="n-a", choices=PLATFORMS)
    p.add_argument("--session", default=None)
    return p.parse_args(argv)


def cell(text, limit=120):
    text = str(text).replace("|", "\\|").replace("\n", " ").strip()
    if len(text) > limit:
        text = text[: limit - 1] + "\u2026"
    return text


def write_report(path, args, ts_iso):
    if args.file:
        log_path = Path(args.file)
        try:
            tail = "\n".join(
                log_path.read_text(encoding="utf-8", errors="replace")
                .splitlines()[-80:]
            )
            evidence = "\n```\n" + tail + "\n```\n"
        except OSError as e:
            evidence = "\n```\n(failed to read " + str(log_path) + ": " + str(e) + ")\n```\n"
    else:
        evidence = "\n```\n(paste relevant log excerpt here)\n```\n"

    lines = []
    lines.append("# Error Report - " + args.topic)
    lines.append("")
    lines.append("## Metadata")
    lines.append("")
    lines.append("- Level: **" + args.level + "**")
    lines.append("- Track: **" + args.track + "**")
    lines.append("- Topic: " + args.topic)
    lines.append("- Recorded: " + ts_iso)
    lines.append("- Session: " + (args.session or "(unknown)"))
    lines.append("- Platform: " + args.platform)
    lines.append("- Tooling: (fill in)")
    lines.append("")
    lines.append("## 1. What happened")
    lines.append("")
    lines.append(args.summary)
    lines.append("")
    lines.append("## 2. Evidence")
    lines.append(evidence)
    lines.append("## 3. Root cause")
    lines.append("")
    lines.append("- Immediate cause:")
    lines.append("- Underlying cause:")
    lines.append("- Why the harness/checklists did not prevent it:")
    lines.append("")
    lines.append("## 4. Fix")
    lines.append("")
    lines.append("- Files changed:")
    lines.append("- Short description:")
    lines.append("- Commit:")
    lines.append("")
    lines.append("## 5. Prevention")
    lines.append("")
    lines.append("Concrete harness upgrade, or 'one-off, no harness change'.")
    lines.append("")
    if args.level == "L3":
        lines.append("## 6. Lessons for agents (L3)")
        lines.append("")
        lines.append("- Wrong assumption:")
        lines.append("- Earlier signal available:")
        lines.append("- Rule file to update:")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def append_jsonl(ts_iso, args, report_rel):
    rec = {
        "timestamp": ts_iso,
        "level": args.level,
        "track": args.track,
        "topic": args.topic,
        "summary": args.summary,
        "platform": args.platform,
        "session": args.session,
        "file": report_rel,
    }
    with JSONL.open("a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def update_index(ts_iso, args, report_rel):
    text = INDEX.read_text(encoding="utf-8")
    new_row = ("| " + cell(ts_iso, 20) + " | " + cell(args.level, 3)
               + " | " + cell(args.topic, 18) + " | "
               + cell(args.summary, 60) + " | [report](" + report_rel + ") |")
    out, inserted, in_errors, drop_ph = [], False, False, False
    for line in text.splitlines():
        if drop_ph:
            drop_ph = False
            if "_(none yet)_" in line:
                continue
        if line.startswith("## Error entries"):
            in_errors = True
        elif line.startswith("## "):
            in_errors = False
        out.append(line)
        if in_errors and not inserted and line.startswith("|---"):
            out.append(new_row)
            inserted = True
            drop_ph = True
    if not inserted:
        out.extend(["", "<!-- record_error.py: error table not found -->",
                    new_row])
    tail_nl = "\n" if text.endswith("\n") else ""
    INDEX.write_text("\n".join(out) + tail_nl, encoding="utf-8")


def main(argv):
    args = parse_args(argv)
    if not SLUG_RE.match(args.topic):
        return die("invalid --topic " + repr(args.topic)
                   + " (must match [a-z0-9-], <= 40 chars)")
    try:
        ERRORS_DIR.mkdir(parents=True, exist_ok=True)
        JSONL.touch(exist_ok=True)
    except OSError as e:
        return die("cannot prepare journal: " + str(e), code=2)

    ts = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    ts_iso = ts.isoformat().replace("+00:00", "Z")
    slug_ts = ts.strftime("%Y%m%d-%H%M%S")
    report_name = slug_ts + "-" + args.track + "-" + args.topic + ".md"
    report_rel = "errors/" + report_name
    report_path = ERRORS_DIR / report_name
    if report_path.exists():
        return die("report already exists: " + str(report_path), code=2)
    try:
        write_report(report_path, args, ts_iso)
        append_jsonl(ts_iso, args, report_rel)
        update_index(ts_iso, args, report_rel)
    except OSError as e:
        return die("filesystem error: " + str(e), code=2)

    print(str(report_path))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
