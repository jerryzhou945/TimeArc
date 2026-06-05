#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TimeArc harness-wrapped build driver.

Wrap `cmake --build <dir>`. On non-zero exit the tail of the build log is
captured and fed to record_error.py as an L1 error, so a failed build
ALWAYS produces a journal entry.

Usage:
    python .harness/tools/build.py
    python .harness/tools/build.py --build-dir build-debug
    python .harness/tools/build.py --track B --topic service-build
    python .harness/tools/build.py -- --target time-arc   # args after -- go to cmake

Exit code mirrors `cmake --build`. 0 clean, otherwise non-zero.
"""
from __future__ import annotations

import argparse
import datetime as dt
import subprocess
import sys
from pathlib import Path

HARNESS = Path(__file__).resolve().parent.parent
PROJECT = HARNESS.parent
LOG_DIR = HARNESS / "journal" / "build-logs"
FALLBACK_LOG_DIR = HARNESS / "tmp" / "build-logs"
RECORD = HARNESS / "tools" / "record_error.py"


def parse_args(argv):
    if "--" in argv:
        i = argv.index("--")
        own, extra = argv[:i], argv[i + 1 :]
    else:
        own, extra = argv, []
    p = argparse.ArgumentParser(prog="build.py")
    p.add_argument("--build-dir", default="build")
    p.add_argument("--track", default="B", choices=("A", "B", "C"))
    p.add_argument("--topic", default="build-failure")
    p.add_argument("--session", default=None)
    return p.parse_args(own), extra


def main(argv):
    args, extra = parse_args(argv)
    log_dir = LOG_DIR
    try:
        log_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        log_dir = FALLBACK_LOG_DIR
        log_dir.mkdir(parents=True, exist_ok=True)
    ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    log_path = log_dir / f"{ts}-build.log"

    cmd = ["cmake", "--build", args.build_dir] + extra
    print(f"build.py: {' '.join(cmd)}", file=sys.stderr)
    print(f"build.py: log -> {log_path}", file=sys.stderr)

    try:
        log = log_path.open("wb")
    except OSError:
        log_dir = FALLBACK_LOG_DIR
        log_dir.mkdir(parents=True, exist_ok=True)
        log_path = log_dir / f"{ts}-build.log"
        print(f"build.py: primary log unavailable; fallback -> {log_path}",
              file=sys.stderr)
        log = log_path.open("wb")

    with log:
        proc = subprocess.run(cmd, cwd=str(PROJECT),
                              stdout=log, stderr=subprocess.STDOUT)

    if proc.returncode == 0:
        print("build.py: success", file=sys.stderr)
        return 0

    print(f"build.py: build failed (exit {proc.returncode})", file=sys.stderr)
    rec_cmd = [
        sys.executable, str(RECORD),
        "--level", "L1",
        "--track", args.track,
        "--topic", args.topic,
        "--summary", f"cmake --build exited {proc.returncode}",
        "--file", str(log_path),
    ]
    if args.session:
        rec_cmd += ["--session", args.session]
    rec_proc = subprocess.run(rec_cmd)
    if rec_proc.returncode != 0:
        print("build.py: record_error.py failed; see log at "
              f"{log_path}", file=sys.stderr)
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
