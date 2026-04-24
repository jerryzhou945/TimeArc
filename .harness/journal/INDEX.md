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
| _(none yet)_         |     |              |                                                 |        |

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
