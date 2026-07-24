import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENTS_PATH = ".harness/AGENTS.md"
AGENTS_ROUTE = (
    "   - branch / commit / PR / merge / cleanup -> "
    "`rules/08-git-workflow.md`"
)


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def require_line_budget(rel):
    count = len(read(rel).splitlines())
    if count > 100:
        raise AssertionError(f"{rel} has {count} lines; limit is 100")


def require_agents_route(agents):
    heading = "## 3. Mandatory reading order"
    next_heading = "## 4. Working loop"
    if heading not in agents or next_heading not in agents:
        raise AssertionError("missing mandatory reading router boundaries")
    router = agents.split(heading, 1)[1].split(next_heading, 1)[0]
    route_count = router.splitlines().count(AGENTS_ROUTE)
    if route_count != 1:
        raise AssertionError(
            "expected exactly one complete mandatory workflow rule route; "
            f"found {route_count}"
        )


def require_agents_frozen_hash():
    registry = json.loads(read(".harness/state/frozen-files.json"))
    entries = [
        entry for entry in registry["files"] if entry["path"] == AGENTS_PATH
    ]
    if len(entries) != 1:
        raise AssertionError(
            f"expected one {AGENTS_PATH} frozen entry; found {len(entries)}"
        )
    actual = hashlib.sha256((ROOT / AGENTS_PATH).read_bytes()).hexdigest()
    expected = entries[0]["sha256"]
    if actual != expected:
        raise AssertionError(
            f"{AGENTS_PATH} frozen hash mismatch: "
            f"expected {expected}, got {actual}"
        )


def main():
    rule = read(".harness/rules/08-git-workflow.md")
    agents = read(".harness/AGENTS.md")
    before_coding = read(".harness/checklists/before-coding.md")
    before_commit = read(".harness/checklists/before-commit.md")

    require(
        rule,
        "independently verifiable checklist item",
        "small feature definition",
    )
    require(rule, "documented Epic or milestone", "large feature definition")
    require(
        rule,
        "update the active progress checklist",
        "pre-commit progress update",
    )
    require(
        rule,
        "Completed, Incomplete, Verification, Next, and Risks",
        "five-part status record",
    )
    require(rule, "PR targeting `dev`", "dev PR target")
    require(
        rule,
        "confirming local `dev` contains the merge",
        "safe local branch cleanup",
    )
    require_agents_route(agents)
    require_agents_frozen_hash()
    require(
        before_coding,
        "Name the active progress checklist",
        "before-coding progress tracker gate",
    )
    require(
        before_commit,
        "Completed / Incomplete / Verification / Next / Risks",
        "before-commit five-part status gate",
    )
    require_line_budget(".harness/checklists/before-coding.md")
    require_line_budget(".harness/checklists/before-commit.md")
    require_line_budget(".harness/rules/08-git-workflow.md")
    require_line_budget(".harness/AGENTS.md")

    print("harness Git workflow static checks passed")


if __name__ == "__main__":
    main()
