# Checklist — Before Coding

Run through this every time you open a session, before writing any new code.
Total time: ~2 minutes once the project is familiar.

## Orient yourself

- [ ] Read [`../AGENTS.md`](../AGENTS.md) §1 — what TimeArc is.
- [ ] **Pick your track** — A (Stabilize) / B (Feature) / C (Debug).
      See [`../tracks/README.md`](../tracks/README.md). Then read
      `../tracks/<letter>-*.md` for its entry/exit deltas.
- [ ] Scan [`../CHARTER.md`](../CHARTER.md) §3 — the frozen-files list.
- [ ] Confirm which layer your change touches (see
      [`../rules/01-architecture.md`](../rules/01-architecture.md)).
- [ ] Open the rule files that match your layer(s); do not skim all six by
      default.

## Understand scope

- [ ] Write one sentence stating the goal of this session. Put it at the top
      of a new `journal/sessions/YYYYMMDD-HHMM-<slug>.md`. If you cannot state
      it in one sentence, the task is not ready.
- [ ] List the files you expect to touch. If any is in the frozen-files list,
      stop and file a change proposal first.
- [ ] List the files you **don't** expect to touch but could be tempted by
      (e.g., main CMakeLists, Charter, schema). Keep hands off.

## Check state

- [ ] `git status` — what's uncommitted? Is the tree clean enough to be
      auditable at commit time? If not, commit or stash first.
- [ ] `git log --oneline -5` — are you on the branch you think you are?
- [ ] Skim [`../journal/INDEX.md`](../journal/INDEX.md) for open issues that
      may overlap your change.

## Build once, clean

- [ ] Can you build the project on your platform *before* changing anything?
      Record the baseline. If the baseline is broken, **that** is your first
      task and it gets an error-report entry.

## Commit to the loop

- [ ] Plan to record every build failure, runtime error, or agent-visible
      mistake via `../tools/record_error.py` (or by hand using
      `../templates/error-report.md` if the tool is still a stub).

When everything above is ✅, you may start coding.
