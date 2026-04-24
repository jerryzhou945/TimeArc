#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TimeArc harness structure validator.

See .harness/tools/README.md for the full machine-interface contract.

Exit codes:
    0  all passes clean
    1  one or more passes reported drift
    2  internal error
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

HARNESS = Path(__file__).resolve().parent.parent
PROJECT = HARNESS.parent
FROZEN_FILE = HARNESS / "state" / "frozen-files.json"
JOURNAL = HARNESS / "journal"
ERRORS_DIR = JOURNAL / "errors"
SESSIONS_DIR = JOURNAL / "sessions"
JSONL = JOURNAL / "errors.jsonl"
TRACK_FILE = HARNESS / "state" / "current-track"

MD_LINE_LIMIT = 100

SESSION_SLUG_RE = re.compile(
    r"^\d{8}-\d{4}-[ABC]-[a-z0-9][a-z0-9-]{0,39}\.md$"
)
ERROR_SLUG_RE = re.compile(
    r"^\d{8}-\d{6}-[ABC]-[a-z0-9][a-z0-9-]{0,39}\.md$"
)

QT_INCLUDE = re.compile(r'#\s*include\s*[<"]Q[A-Z][A-Za-z0-9_]*[>"]')
SHARED_FORBID = re.compile(
    r'#\s*include\s*[<"](windows\.h|Cocoa/|AppKit/|X11/|wayland-)'
)
SERVICE_EXTS = (".c", ".cpp", ".h", ".hpp", ".swift", ".mm")
SRC_EXT = (".c", ".cpp", ".h", ".hpp", ".qml", ".swift", ".mm")

CMAKE_REQUIRED = {
    "CMakeLists.txt": [
        r"project\(time-arc",
        r"qt_add_executable\(time-arc",
        r"install\(TARGETS time_arc_service",
    ],
    "src/CMakeLists.txt": [
        r"TIME_ARC_APP_SOURCES",
        r"TIME_ARC_INCLUDE_DIRS",
        r"PARENT_SCOPE",
    ],
    "src/service/CMakeLists.txt": [
        r"add_executable\(time_arc_service",
        r"if\(APPLE\)",
        r"elseif\(WIN32\)",
        r"elseif\(UNIX\)",
    ],
    "qml/CMakeLists.txt": [r"TIME_ARC_QML_FILES"],
    "resources/CMakeLists.txt": [r"TIME_ARC_RESOURCE_FILES"],
    "thirdparty/CMakeLists.txt": [r"TIME_ARC_THIRDPARTY_LIBS"],
}


def sha256_of(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def pass_header(n, name):
    print(f"[pass {n}] {name}", file=sys.stderr)


def drift(msg):
    print(f"  DRIFT: {msg}", file=sys.stderr)


def info(msg):
    print(f"  ok:    {msg}", file=sys.stderr)


def pass_line_budget():
    pass_header(1, "line-budget (<=100 lines per .md in .harness/)")
    v = 0
    for md in sorted(HARNESS.rglob("*.md")):
        n = sum(1 for _ in md.open("r", encoding="utf-8", errors="replace"))
        if n > MD_LINE_LIMIT:
            drift(f"{md.relative_to(PROJECT)}: {n} lines (limit {MD_LINE_LIMIT})")
            v += 1
    return v


def load_frozen():
    if not FROZEN_FILE.exists():
        raise SystemExit(f"state/frozen-files.json missing: {FROZEN_FILE}")
    return json.loads(FROZEN_FILE.read_text(encoding="utf-8"))


def pass_frozen_hash():
    pass_header(2, "frozen-file hashes")
    data = load_frozen()
    v = 0
    nulls = 0
    for entry in data["files"]:
        rel = entry["path"]
        p = PROJECT / rel
        if not p.exists():
            drift(f"frozen file missing: {rel}")
            v += 1
            continue
        actual = sha256_of(p)
        expected = entry.get("sha256")
        if expected is None:
            nulls += 1
            continue
        if actual != expected:
            drift(f"{rel}: hash mismatch")
            v += 1
    if nulls:
        print(f"  note:  {nulls} frozen entries have null sha256 "
              "(run --bootstrap to populate)", file=sys.stderr)
    return v


def bootstrap_frozen():
    data = load_frozen()
    updated = 0
    for entry in data["files"]:
        p = PROJECT / entry["path"]
        if not p.exists():
            print(f"  WARN: cannot hash missing file {entry['path']}",
                  file=sys.stderr)
            continue
        new_hash = sha256_of(p)
        if entry.get("sha256") != new_hash:
            entry["sha256"] = new_hash
            updated += 1
    out = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    FROZEN_FILE.write_text(out, encoding="utf-8")
    print(f"bootstrap: updated {updated} hashes in {FROZEN_FILE}",
          file=sys.stderr)
    return 0


def pass_cmake_structure():
    pass_header(3, "CMake structure")
    v = 0
    for rel, patterns in CMAKE_REQUIRED.items():
        p = PROJECT / rel
        if not p.exists():
            drift(f"missing: {rel}")
            v += 1
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        for pat in patterns:
            if not re.search(pat, text):
                drift(f"{rel}: missing expected pattern /{pat}/")
                v += 1
    return v


def pass_platform_isolation():
    pass_header(4, "platform isolation under src/service/")
    service_dir = PROJECT / "src" / "service"
    shared_dir = service_dir / "shared"
    v = 0
    if not service_dir.exists():
        info("src/service/ missing - skipping")
        return 0
    for p in sorted(service_dir.rglob("*")):
        if p.suffix not in SERVICE_EXTS or not p.is_file():
            continue
        rel = p.relative_to(PROJECT)
        text = p.read_text(encoding="utf-8", errors="replace")
        if QT_INCLUDE.search(text):
            drift(f"{rel}: Qt header included under src/service/")
            v += 1
        is_shared_header = (shared_dir in p.parents
                            and p.suffix in (".h", ".hpp"))
        if is_shared_header and SHARED_FORBID.search(text):
            drift(f"{rel}: platform SDK header under src/service/shared/")
            v += 1
    return v


def pass_journal_hygiene():
    pass_header(5, "journal hygiene (errors/*.md <-> errors.jsonl)")
    v = 0
    md_files = set()
    if ERRORS_DIR.exists():
        for p in ERRORS_DIR.glob("*.md"):
            if p.stat().st_size > 0:
                md_files.add(p.name)
    jsonl_files = set()
    if JSONL.exists():
        for i, line in enumerate(
                JSONL.read_text(encoding="utf-8").splitlines(), 1):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError as e:
                drift(f"errors.jsonl line {i}: invalid JSON ({e})")
                v += 1
                continue
            jsonl_files.add(Path(rec.get("file", "")).name)
    for name in sorted(md_files - jsonl_files):
        drift(f"errors/{name} has no matching errors.jsonl row")
        v += 1
    for name in sorted(jsonl_files - md_files):
        drift(f"errors.jsonl references errors/{name}, file missing")
        v += 1
    return v


def pass_slug_shape():
    pass_header(6, "slug shape (journal/sessions + journal/errors)")
    v = 0
    if ERRORS_DIR.exists():
        for p in sorted(ERRORS_DIR.glob("*.md")):
            if p.stat().st_size == 0:
                continue
            if not ERROR_SLUG_RE.match(p.name):
                drift(f"errors/{p.name}: bad slug; expected "
                      "YYYYMMDD-HHMMSS-[ABC]-kebab.md")
                v += 1
    if SESSIONS_DIR.exists():
        for p in sorted(SESSIONS_DIR.glob("*.md")):
            if p.stat().st_size == 0:
                continue
            if not SESSION_SLUG_RE.match(p.name):
                drift(f"sessions/{p.name}: bad slug; expected "
                      "YYYYMMDD-HHMM-[ABC]-kebab.md")
                v += 1
    return v


def _git_status():
    try:
        proc = subprocess.run(
            ["git", "-C", str(PROJECT), "status", "--porcelain"],
            capture_output=True, text=True, timeout=10)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    added, modified = [], []
    for line in proc.stdout.splitlines():
        if len(line) < 4:
            continue
        code, path = line[:2], line[3:]
        s = code.strip()
        if s in ("A", "??", "AM"):
            added.append(path)
        elif s in ("M", "MM", "RM", "AD"):
            modified.append(path)
    return added, modified


def pass_track_discipline():
    pass_header(7, "track discipline (current-track vs git diff)")
    if not TRACK_FILE.exists():
        info("no current-track set - skipping "
             "(run preflight --track X first)")
        return 0
    raw = TRACK_FILE.read_text(encoding="utf-8").strip()
    if raw[:1] not in ("A", "B", "C"):
        drift(f"state/current-track: invalid {raw!r}")
        return 1
    track = raw[:1]
    gs = _git_status()
    if gs is None:
        info("git status unavailable - skipping")
        return 0
    added, modified = gs
    touched = added + modified
    v = 0
    if track == "A":
        new_src = [f for f in added if f.endswith(SRC_EXT)]
        for f in new_src:
            drift(f"track A (Stabilize) but new source file: {f}")
            v += 1
    elif track == "B":
        new_src = [f for f in added if f.endswith(SRC_EXT)]
        if new_src:
            rule_touched = any(
                f.startswith(".harness/rules/") or f == "README.md"
                for f in touched)
            if not rule_touched:
                drift("track B adds source files without rules/ or "
                      f"README update: {new_src}")
                v += 1
    elif track == "C":
        c_sessions = sorted(SESSIONS_DIR.glob("*-C-*.md")) \
            if SESSIONS_DIR.exists() else []
        if not c_sessions:
            drift("track C but no journal/sessions/*-C-*.md")
            v += 1
        else:
            latest = c_sessions[-1]
            body = latest.read_text(encoding="utf-8", errors="replace")
            if not re.search(r"errors/\S+\.md", body):
                drift(f"track C session {latest.name} does not link "
                      "any journal/errors/*.md")
                v += 1
    return v


def parse_args(argv):
    p = argparse.ArgumentParser(prog="harness_check.py")
    p.add_argument("--bootstrap", action="store_true")
    p.add_argument("--fast", action="store_true")
    return p.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    if args.bootstrap:
        return bootstrap_frozen()
    total = 0
    total += pass_line_budget()
    total += pass_frozen_hash()
    if not args.fast:
        total += pass_cmake_structure()
        total += pass_platform_isolation()
        total += pass_journal_hygiene()
        total += pass_slug_shape()
        total += pass_track_discipline()
    if total == 0:
        print("harness_check.py: clean", file=sys.stderr)
        return 0
    print(f"harness_check.py: {total} drift finding(s)", file=sys.stderr)
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except SystemExit:
        raise
    except Exception as e:
        print(f"harness_check.py: internal error: {e}", file=sys.stderr)
        sys.exit(2)
