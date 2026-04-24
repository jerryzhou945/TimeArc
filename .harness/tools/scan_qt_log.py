#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Convert Qt-message-handler log into L2 error reports."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import os
import subprocess
import sys
from pathlib import Path

HARNESS = Path(__file__).resolve().parent.parent
RECORD = HARNESS / "tools" / "record_error.py"


def default_log_path():
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
    elif sys.platform == "darwin":
        base = os.path.expanduser("~/Library/Application Support")
    else:
        base = os.environ.get("XDG_DATA_HOME") \
            or os.path.expanduser("~/.local/share")
    return Path(base) / "TimeArc" / "logs" / "harness-qt.log"


def parse_args(argv):
    p = argparse.ArgumentParser(prog="scan_qt_log.py")
    p.add_argument("--log", default=None)
    p.add_argument("--track", default="C", choices=("A", "B", "C"))
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args(argv)


def parse_line(line):
    parts = line.rstrip("\n").split("\t", 4)
    if len(parts) != 5:
        return None
    ts, sev, category, file_line, msg = parts
    return {"ts": ts, "sev": sev, "category": category,
            "file_line": file_line, "msg": msg}


def slug_from(rec):
    h = hashlib.sha1(
        (rec["sev"] + "|" + rec["file_line"] + "|" + rec["msg"])
        .encode("utf-8", "replace")
    ).hexdigest()[:10]
    tag = rec["sev"].lower()
    return f"qt-{tag}-{h}"


def main(argv):
    args = parse_args(argv)
    log_path = Path(args.log) if args.log else default_log_path()
    if not log_path.exists():
        print(f"scan_qt_log.py: no log at {log_path}", file=sys.stderr)
        return 0

    lines = log_path.read_text(encoding="utf-8", errors="replace") \
        .splitlines()
    recorded = 0
    for line in lines:
        if not line.strip():
            continue
        rec = parse_line(line)
        if rec is None:
            continue
        topic = slug_from(rec)
        summary = f"[{rec['sev']}] {rec['file_line']} - {rec['msg']}"
        if args.dry_run:
            print(f"would record: {topic} :: {summary}")
            continue
        cmd = [
            sys.executable, str(RECORD),
            "--level", "L2", "--track", args.track,
            "--topic", topic[:40],
            "--summary", summary[:200],
        ]
        proc = subprocess.run(cmd)
        if proc.returncode == 0:
            recorded += 1

    if not args.dry_run:
        ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        rotated = log_path.with_suffix(log_path.suffix + f".consumed.{ts}")
        try:
            log_path.replace(rotated)
        except OSError as e:
            print(f"scan_qt_log.py: rotate failed: {e}", file=sys.stderr)
            return 2

    print(f"scan_qt_log.py: recorded {recorded} L2 report(s)",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
