# Cross-Device Sync E0 Delivery Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strengthen TimeArc's existing Git workflow rule so every independently
verifiable small feature is committed separately, every Epic is delivered by PR
to `dev`, merged branches are cleaned safely, and every work session records
completed and incomplete work.

**Architecture:** Extend the existing `.harness/rules/08-git-workflow.md` instead
of creating another workflow rule. Route agents to Rule 08 from the frozen
`.harness/AGENTS.md`, enforce the same contract in the before-coding and
before-commit checklists, and add one static test that prevents the workflow
markers from silently disappearing.

**Tech Stack:** Markdown harness rules, Python 3.12 static test, SHA-256 frozen
file registry, Git/GitHub PR workflow.

## Global Constraints

- Work on Track B and run `.\\.local-python\\Python312\\python.exe .harness/tools/preflight.py --track B` first.
- Execute from a clean isolated worktree based on the latest `dev`.
- Use branch `codex/cross-sync-e0-delivery-rules`.
- Do not create `07-delivery-workflow.md`; Rule 07 is already product AI cards.
- File a change proposal before editing frozen `.harness/AGENTS.md`.
- Keep every Markdown file below the harness limit of 100 lines.
- Do not modify product source, QML, either SQLite schema, or cloud resources.
- Do not run a Qt/CMake build for this docs-and-harness-only Epic.
- Use the existing `rules/08-git-workflow.md` as the single workflow authority.
- Each task ends in its own independently revertible commit.
- Target the Epic PR at `dev`; merge only after checks pass.
- Delete branches only after updated local `dev` contains the merge.

---

## File Map

| File | Responsibility |
|---|---|
| `.harness/rules/08-git-workflow.md` | Normative definitions for small feature, Epic, status record, PR, merge, and cleanup |
| `.harness/AGENTS.md` | Routes branch/commit/PR work to Rule 08 |
| `.harness/checklists/before-coding.md` | Requires an active progress tracker before implementation |
| `.harness/checklists/before-commit.md` | Blocks commits without verification and five-part status reporting |
| `.harness/journal/sessions/20260724-1200-B-git-workflow-rule-proposal.md` | Frozen-file change proposal for `.harness/AGENTS.md` |
| `.harness/state/frozen-files.json` | Stores the updated SHA-256 for `.harness/AGENTS.md` |
| `tests/harness_git_workflow_static_test.py` | Guards all required workflow markers and line limits |
| `docs/cross-device-sync-progress.md` | Records E0 task state, evidence, PR URL, completed and incomplete work |
| `docs/cross-device-sync-e0-delivery-workflow-report.md` | Human-facing Chinese E0 completion report |
| `docs/implementation-backlog.md` | Links the remaining E1-E9 cross-device sync backlog |
| `.harness/state/open-issues.md` | Keeps the unfinished cross-device cloud work visible |

### Task 1: Codify the workflow contract and frozen-file route

**Files:**

- Create: `.harness/journal/sessions/20260724-1200-B-git-workflow-rule-proposal.md`
- Create: `tests/harness_git_workflow_static_test.py`
- Modify: `.harness/rules/08-git-workflow.md`
- Modify: `.harness/AGENTS.md:31-37`
- Modify: `.harness/state/frozen-files.json`

**Interfaces:**

- Consumes: the existing Rule 08 branch/commit/PR contract and frozen-file audit.
- Produces: exact workflow markers consumed by the checklists and guarded by
  `tests/harness_git_workflow_static_test.py`.

- [ ] **Step 1: Run Feature Track preflight and confirm the isolated branch**

Run:

```powershell
.\.local-python\Python312\python.exe .harness/tools/preflight.py --track B
git branch --show-current
git status --short
```

Expected:

- Preflight prints `harness_check.py: clean`.
- Current branch is `codex/cross-sync-e0-delivery-rules`.
- Status contains no unrelated changes.

- [ ] **Step 2: File the frozen-file change proposal before editing AGENTS**

Create `.harness/journal/sessions/20260724-1200-B-git-workflow-rule-proposal.md`
with this complete content:

```markdown
# Change Proposal — Git workflow completion contract

## Metadata

- Author: Codex
- Track: **B (Feature)**
- Date: 2026-07-24 12:00 (Asia/Shanghai)
- Session goal: Route all delivery work to the existing Rule 08 and require auditable completion status.
- Branch: `codex/cross-sync-e0-delivery-rules`
- Related design: `docs/superpowers/specs/2026-07-24-cross-device-sync-design.md`

## 1. Frozen files touched

- `.harness/AGENTS.md` — add the Rule 08 routing entry.

## 2. Motivation

The project already defines branch, commit, PR, merge, and cleanup behavior in
Rule 08, but the mandatory reading router does not point delivery work to it and
the rule does not require the five-part status record requested for cross-device
delivery.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | None; the native collector and service database are unchanged. |
| Consumer | None at runtime; only agent delivery behavior changes. |

## 4. Migration plan

No on-disk application data impact.

## 5. Rollback plan

Revert the E0 PR; no data restoration is required.

## 6. Test plan

- Pre-change: the new workflow static test fails on missing route/status markers.
- Post-change: the static test and full harness audit pass.
- New artifact: `tests/harness_git_workflow_static_test.py`.

## 7. Sign-off

- [x] `rules/08-git-workflow.md` will reflect the new reality.
- [ ] `state/frozen-files.json` will be regenerated after the frozen edit.
- [x] No CHARTER version bump is required.
- [x] No user-visible README change is required.
```

Verify:

```powershell
(Get-Content '.harness\journal\sessions\20260724-1200-B-git-workflow-rule-proposal.md').Count
```

Expected: an integer no greater than `100`.

- [ ] **Step 3: Write the failing workflow static test**

Create `tests/harness_git_workflow_static_test.py`:

```python
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

    require(rule, "independently verifiable checklist item",
            "small feature definition")
    require(rule, "documented Epic or milestone",
            "large feature definition")
    require(rule, "update the active progress checklist",
            "pre-commit progress update")
    require(rule, "Completed, Incomplete, Verification, Next, and Risks",
            "five-part status record")
    require(rule, "PR targeting `dev`", "dev PR target")
    require(rule, "confirming local `dev` contains the merge",
            "safe local branch cleanup")
    require(agents, "rules/08-git-workflow.md",
            "mandatory workflow rule routing")
    require_line_budget(".harness/rules/08-git-workflow.md")
    require_line_budget(".harness/AGENTS.md")

    print("harness Git workflow static checks passed")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the new test and verify it fails for the intended reason**

Run:

```powershell
.\.local-python\Python312\python.exe tests/harness_git_workflow_static_test.py
```

Expected: FAIL with `missing small feature definition`.

Record this expected TDD failure in the E0 session log, not as a harness error.

- [ ] **Step 5: Extend Rule 08 with exact small-feature and status contracts**

Under `## 2. Commit Shape`, insert:

```markdown
A small feature is one independently verifiable checklist item: one migration
plus its test, one endpoint plus its authorization test, one resolver rule group
plus its test, or one UI state plus its visual/runtime verification.

- Finish and verify one such item before starting the next commit.
- Before committing, update the active progress checklist with its result.
```

Under `## 3. Completion Report`, insert:

```markdown
Every session log and active progress checklist update must record exactly these
five facts: Completed, Incomplete, Verification, Next, and Risks. Empty sections
must say `None`; do not omit them.
```

At the start of `## 4. Push And PR`, insert:

```markdown
A large feature is one documented Epic or milestone. It is complete only when
all of its checklist items and required verification pass.
```

Keep the complete Rule 08 file at or below 100 lines.

- [ ] **Step 6: Add the mandatory AGENTS routing entry**

In `.harness/AGENTS.md` section 3, after the licensing bullet, insert exactly:

```markdown
   - branch / commit / PR / merge / cleanup -> `rules/08-git-workflow.md`
```

The file was 99 lines before this change, so this single-line insertion must
produce exactly 100 lines. Do not add another blank line.

- [ ] **Step 7: Verify only the intended frozen file changed**

Run:

```powershell
git diff --name-only -- AGENTS.md .harness/AGENTS.md .harness/CHARTER.md CMakeLists.txt src/CMakeLists.txt src/service/CMakeLists.txt src/service/shared
```

Expected: only `.harness/AGENTS.md`.

- [ ] **Step 8: Refresh the frozen registry and verify the exact registry diff**

Run:

```powershell
.\.local-python\Python312\python.exe .harness/tools/harness_check.py --bootstrap
git diff -- .harness/state/frozen-files.json
```

Expected:

- Bootstrap reports `updated 1 hashes`.
- Only the `.harness/AGENTS.md` SHA-256 value changes.

- [ ] **Step 9: Run the static test and full harness**

Run:

```powershell
.\.local-python\Python312\python.exe tests/harness_git_workflow_static_test.py
.\.local-python\Python312\python.exe .harness/tools/harness_check.py
```

Expected:

- `harness Git workflow static checks passed`
- `harness_check.py: clean`

- [ ] **Step 10: Commit the normative workflow contract**

Run:

```powershell
git add .harness/AGENTS.md .harness/rules/08-git-workflow.md .harness/state/frozen-files.json .harness/journal/sessions/20260724-1200-B-git-workflow-rule-proposal.md tests/harness_git_workflow_static_test.py
git diff --cached --check
git commit -m "Strengthen Git workflow completion contract"
```

Expected: one commit containing only the five listed artifacts.

### Task 2: Enforce the contract in coding and commit checklists

**Files:**

- Modify: `tests/harness_git_workflow_static_test.py`
- Modify: `.harness/checklists/before-coding.md`
- Modify: `.harness/checklists/before-commit.md`
- Modify: `docs/cross-device-sync-progress.md`

**Interfaces:**

- Consumes: the exact Rule 08 markers created in Task 1.
- Produces: checklist gates that prevent work from starting or committing
  without an active tracker and five-part status record.

- [ ] **Step 1: Extend the static test with failing checklist assertions**

In `main()`, after reading `agents`, add:

```python
    before_coding = read(".harness/checklists/before-coding.md")
    before_commit = read(".harness/checklists/before-commit.md")
```

Before the line-budget calls, add:

```python
    require(before_coding, "Name the active progress checklist",
            "before-coding progress tracker gate")
    require(before_commit,
            "Completed / Incomplete / Verification / Next / Risks",
            "before-commit five-part status gate")
    require_line_budget(".harness/checklists/before-coding.md")
    require_line_budget(".harness/checklists/before-commit.md")
```

- [ ] **Step 2: Run the test and verify the new assertion fails**

Run:

```powershell
.\.local-python\Python312\python.exe tests/harness_git_workflow_static_test.py
```

Expected: FAIL with `missing before-coding progress tracker gate`.

- [ ] **Step 3: Add the active progress tracker gate before coding**

In `.harness/checklists/before-coding.md`, under `## Understand scope`, add:

```markdown
- [ ] Name the active progress checklist for this work. If none exists, create
      one before implementation; mark exactly one item `[-]` while working.
```

- [ ] **Step 4: Add the five-part status gate before commit**

In `.harness/checklists/before-commit.md`, under `## 7. Harness hygiene`, add:

```markdown
- [ ] The session log and active progress checklist contain
      `Completed / Incomplete / Verification / Next / Risks`; empty sections
      explicitly say `None`.
```

If this pushes the checklist above 100 lines, join the existing two-line
`Session log ... outcome` item into one line without changing its meaning.

- [ ] **Step 5: Update the E0 progress tracker before committing**

In `docs/cross-device-sync-progress.md`:

- Mark the Rule 08, AGENTS routing, small/large boundary, five-part record,
  frozen hash, and harness items `[x]`.
- Leave `PR 合并到 dev 并清理分支` unchecked.
- Add a dated record whose five headings are `完成`, `未完成`, `验证证据`,
  `下一步`, and `风险`.
- Under `未完成`, state that the PR, merge, and cleanup remain.
- Under `验证证据`, record both passing commands from Task 1 and the passing
  checklist test from this task.

- [ ] **Step 6: Run tests and the full harness**

Run:

```powershell
.\.local-python\Python312\python.exe tests/harness_git_workflow_static_test.py
.\.local-python\Python312\python.exe .harness/tools/harness_check.py
```

Expected: both pass.

- [ ] **Step 7: Commit checklist enforcement**

Run:

```powershell
git add tests/harness_git_workflow_static_test.py .harness/checklists/before-coding.md .harness/checklists/before-commit.md docs/cross-device-sync-progress.md
git diff --cached --check
git commit -m "Enforce delivery status in harness checklists"
```

Expected: a second independently revertible commit.

### Task 3: Publish the E0 completion report and open the Epic PR

**Files:**

- Create: `docs/cross-device-sync-e0-delivery-workflow-report.md`
- Modify: `docs/cross-device-sync-progress.md`
- Modify: `docs/implementation-backlog.md`
- Modify: `.harness/state/open-issues.md`
- Modify: `.harness/journal/sessions/20260724-1200-B-git-workflow-rule-proposal.md`

**Interfaces:**

- Consumes: the passing workflow contract and checklist tests.
- Produces: an auditable E0 handoff and a visible E1-E9 backlog.

- [ ] **Step 1: Push the branch and open a draft PR to obtain its URL**

Run:

```powershell
git push -u origin codex/cross-sync-e0-delivery-rules
```

Create a draft PR targeting `dev` with:

- Title: `Strengthen Git delivery workflow for cross-device sync`
- Base: `dev`
- Head: `codex/cross-sync-e0-delivery-rules`
- Body sections: Goal, Commits, Verification, Completed, Incomplete, Risks,
  Rollback.

Expected: a draft PR URL. Copy that exact URL into the progress tracker and
completion report; do not invent a PR number.

- [ ] **Step 2: Write the Chinese completion report**

Create `docs/cross-device-sync-e0-delivery-workflow-report.md` with these
sections and concrete content:

```markdown
# 跨端同步 E0 交付规则完成报告

## 目标

统一小功能提交、Epic PR、合并后分支清理和五段式状态记录。

## 完成

- Rule 08 定义可独立验证的小功能和有明确边界的 Epic。
- AGENTS 强制把 Git 交付工作路由到 Rule 08。
- 编码前必须指定进度表，提交前必须记录完成、未完成、验证、下一步和风险。
- 静态测试与 harness 审计保护这些规则。

## 未完成

- E1-E9 跨端同步产品功能尚未实现。
- 本报告所附 PR 尚待检查、合并和分支清理。

## 验证

- `python tests/harness_git_workflow_static_test.py`
- `python .harness/tools/harness_check.py`

## 风险

- 工作流规则依赖维护者继续执行 PR 审查，不能代替 GitHub 分支保护。

## 回滚

回滚本 Epic 的 PR merge commit；无应用数据迁移或恢复操作。
```

Append the actual draft PR URL returned in Step 1 under a `## PR` heading.

- [ ] **Step 3: Keep the remaining cross-device work visible**

Add one unchecked item to `docs/implementation-backlog.md`:

```markdown
- [ ] **X1 跨端账号与选择性使用时长同步（E1-E9）** — 中国大陆首发，
  设计与进度见 `cross-device-sync-progress.md`；下一项为 E1 CloudBase Auth
  与基础设施。
```

Add one concise item to `.harness/state/open-issues.md` under Storage or a new
Cloud section:

```markdown
- **Cross-device sync E1-E9 is not implemented.** Approved design and live
  checklist: `docs/superpowers/specs/2026-07-24-cross-device-sync-design.md`
  and `docs/cross-device-sync-progress.md`.
```

Keep both `.harness` Markdown files within 100 lines by replacing stale or
completed text rather than merely appending when necessary.

- [ ] **Step 4: Update the session proposal outcome**

Append:

```markdown
## 8. Outcome

Completed: Rule 08, AGENTS routing, checklist enforcement, static test, report.

Incomplete: PR merge and branch cleanup.

Verification: workflow static test and full harness pass.

Next: merge the E0 PR, clean its branch, then write the E1 execution plan.

Risks: GitHub branch protection remains an external repository setting.
```

- [ ] **Step 5: Run final local verification**

Run:

```powershell
.\.local-python\Python312\python.exe tests/harness_git_workflow_static_test.py
.\.local-python\Python312\python.exe .harness/tools/harness_check.py
git diff --check
```

Expected: test pass, harness clean, and no whitespace errors.

- [ ] **Step 6: Commit and push the E0 report**

Run:

```powershell
git add docs/cross-device-sync-e0-delivery-workflow-report.md docs/cross-device-sync-progress.md docs/implementation-backlog.md .harness/state/open-issues.md .harness/journal/sessions/20260724-1200-B-git-workflow-rule-proposal.md
git diff --cached --check
git commit -m "Document cross-device sync E0 completion"
git push
```

Expected: the draft PR updates with the third E0 commit.

### Task 4: Merge, verify, record, and clean the Epic branch

**Files:**

- No repository file changes after merge.
- Update the merged PR with a completion comment containing the merge SHA and
  cleanup result.

**Interfaces:**

- Consumes: a green E0 draft PR.
- Produces: merged `dev`, deleted feature branch, and an external completion
  record without creating a recursive post-merge documentation PR.

- [ ] **Step 1: Confirm the PR is reviewable**

Verify:

- All required GitHub checks pass.
- The PR contains exactly the three E0 commits.
- The PR diff contains no product source, QML, database, or cloud changes.
- The Chinese completion report and progress tracker are present.

Mark the draft PR ready for review.

- [ ] **Step 2: Merge the PR into `dev`**

Use the repository's normal merge method. Expected: the PR reports `Merged`
and returns a merge commit SHA.

- [ ] **Step 3: Verify updated local dev contains the merge**

Run outside the E0 worktree if necessary:

```powershell
git switch dev
git pull --ff-only origin dev
$e0MergeSha = gh pr view codex/cross-sync-e0-delivery-rules --json mergeCommit --jq '.mergeCommit.oid'
if ([string]::IsNullOrWhiteSpace($e0MergeSha)) { throw 'Merged PR has no merge SHA' }
git merge-base --is-ancestor $e0MergeSha dev
```

Expected: `gh` returns the actual merge SHA and `git merge-base` exits `0`;
never guess an identifier.

- [ ] **Step 4: Delete the merged branches**

Delete the remote branch through GitHub, then delete the local branch:

```powershell
git branch -d codex/cross-sync-e0-delivery-rules
```

Expected: Git confirms deletion. Do not use `-D`.

- [ ] **Step 5: Add the final PR completion record**

Comment on the merged PR with:

- `Completed`: E0 merged into `dev`.
- `Incomplete`: E1-E9 remain.
- `Verification`: static test, harness, and merge-base all passed.
- `Next`: create the E1 CloudBase/Auth plan.
- `Risks`: branch protection remains external.
- Actual merge SHA and confirmation that remote/local E0 branches were deleted.

This PR comment is the post-merge record; it avoids a recursive documentation
commit solely to describe the merge that just occurred.

---

## Plan Self-Review

- Spec coverage: E0 covers Rule 08, AGENTS routing, change proposal, frozen
  hash, checklists, five-part status, per-task commits, PR to `dev`, merge
  verification, and safe branch cleanup.
- Scope: no E1 cloud, product, database, or UI implementation is included.
- Type/name consistency: all tasks use Rule 08, branch
  `codex/cross-sync-e0-delivery-rules`, the same proposal path, and the same
  static test path.
- Placeholder scan: dynamic PR URL and merge SHA are explicitly taken from
  GitHub results; no invented identifiers are permitted.
