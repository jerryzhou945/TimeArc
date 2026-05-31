# Journal Index

Rolling, human-friendly index of everything that has gone wrong and been
recorded. The authoritative machine-readable log is `errors.jsonl` — this file
is regenerated (or maintained by hand) from it.

## Conventions

- Newest entries at the top.
- Each line: ISO date, level, topic, one-line summary, link to full report.
- One-liners only. Put detail in the report.
- `errors.jsonl` is the source of truth. When in doubt, `jq` it.

## Error entries

| Date (UTC)           | Lvl | Topic        | Summary                                         | Report |
|----------------------|-----|--------------|-------------------------------------------------|--------|
| 2026-05-31T08:21:45Z | L3 | git-revert-inde... | git revert failed to create .git/index.lock with Permissi... | [report](errors/20260531-082145-B-git-revert-index-lock.md) |
| 2026-05-30T10:00:42Z | L3 | merge-main-read... | Merging origin/main into dev produced a README.md content... | [report](errors/20260530-100042-C-merge-main-readme-conflict.md) |

## Session entries

Sessions are logged under `sessions/` (one file per session). A session gets an
INDEX entry when it contains a charter amendment, a frozen-file change
proposal, or an unusually long L3 takeaway worth finding again.

| Date          | Kind               | Slug                                  | Link |
|---------------|--------------------|---------------------------------------|------|
| _(none yet)_  |                    |                                       |      |

## Open issues

Live issues — things we know are wrong but have not fixed — are tracked in
[`../state/open-issues.md`](../state/open-issues.md).
