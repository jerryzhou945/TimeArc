from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def require_line_budget(rel):
    count = len(read(rel).splitlines())
    if count > 100:
        raise AssertionError(f"{rel} has {count} lines; limit is 100")


def main():
    rule = read(".harness/rules/08-git-workflow.md")
    agents = read(".harness/AGENTS.md")

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
    require(
        agents,
        "rules/08-git-workflow.md",
        "mandatory workflow rule routing",
    )
    require_line_budget(".harness/rules/08-git-workflow.md")
    require_line_budget(".harness/AGENTS.md")

    print("harness Git workflow static checks passed")


if __name__ == "__main__":
    main()
