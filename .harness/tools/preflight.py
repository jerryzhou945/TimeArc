#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Session-start bootstrap for Codex.

See .harness/tools/README.md.

- Writes state/current-track (consumed by harness_check.py pass 7).
- Runs harness_check.py --fast.
- Prints track doc hint and open-issues hint to stderr.
- Prints a ready-to-fill session-log path to stdout.

Exit mirrors harness_check.py.
"""
from __future__ import annotations

import argparse
import datetime as dt
import subprocess
import sys
from pathlib import Path

HARNESS = Path(__file__).resolve().parent.parent
TRACKS = ("A", "B", "C")


def parse_args(argv):
    p = argparse.ArgumentParser(prog="preflight.py")
    p.add_argument("--track", choices=TRACKS, default=None)
    return p.parse_args(argv)


def write_track(track):
    if not track:
        return
    path = HARNESS / "state" / "current-track"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(track + "\n", encoding="utf-8")


def run_check():
    cmd = [sys.executable,
           str(HARNESS / "tools" / "harness_check.py"), "--fast"]
    return subprocess.call(cmd)


def print_track_doc(track):
    if track is None:
        print("preflight: --track not specified. Pick A/B/C next.",
              file=sys.stderr)
        return
    doc_name = {"A": "A-stabilize.md", "B": "B-feature.md",
                "C": "C-debug.md"}[track]
    print(f"preflight: your track doc is .harness/tracks/{doc_name}",
          file=sys.stderr)


def print_open_issues_hint():
    issues = HARNESS / "state" / "open-issues.md"
    if issues.exists():
        print(f"preflight: review open issues at {issues}",
              file=sys.stderr)


def print_session_slug(track):
    ts = dt.datetime.now().strftime("%Y%m%d-%H%M")
    t = track if track else "X"
    path = HARNESS / "journal" / "sessions" / f"{ts}-{t}-<slug>.md"
    print(str(path))


def main(argv):
    args = parse_args(argv)
    write_track(args.track)
    rc = run_check()
    print_track_doc(args.track)
    print_open_issues_hint()
    print_session_slug(args.track)
    if rc != 0:
        print("preflight: harness_check reported drift; fix before coding.",
              file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
