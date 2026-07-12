# TimeArc Future Coding Harness

## Purpose

This document records project-specific development rules for future Codex,
Claude Code, and human sessions. It does not replace `AGENTS.md`; it adds
product and workflow knowledge that agents should consult before feature work.

## Agent Entry Points

- Codex starts from `AGENTS.md`, then follows `.harness/AGENTS.md`.
- Claude Code starts from `CLAUDE.md`, then follows the same harness.
- Both agents must run:

```powershell
python .harness/tools/preflight.py --track <A|B|C>
```

Track choice:

- `A`: cleanup only, behavior unchanged.
- `B`: new capability, product docs, new UI, new data model.
- `C`: fix a known or observed bug; requires an error report.

## Commit Rules

Commit messages are English, imperative, and scoped to one track.

Allowed first words:

- Track A: `Refine`, `Clean up`, `Polish`, `Simplify`, `Rename`, `Reorder`.
- Track B: `Add`, `Implement`, `Enable`, `Introduce`, `Support`.
- Track C: `Fix`.

Rules:

- First line <= 72 characters.
- One commit should map to one session log.
- After each completed feature implementation, create one focused commit once
  verification has passed or documented blockers have been recorded.
- Every completed feature must also update docs with what is implemented,
  what is not implemented yet, and future adjustment directions.
- Do not mix feature work, cleanup, and bug fixes.
- Mention subtle rule/data-contract implications in the commit body.
- Do not commit generated build output, local IDE state, or temporary files.

## Branch And PR Rules

Prefer feature branches over pushing directly to `dev`.

- Create a short-lived branch for each feature or workflow change.
- Push the branch and open a pull request for review/merge.
- Keep `dev` as the integration branch so completed work can be reverted more
  easily.
- After the pull request is merged, delete the short-lived local and remote
  branch.
- Remote short-lived branch cleanup is automated by
  `.github/workflows/cleanup-merged-branch.yml` for merged same-repository pull
  requests.
- Direct pushes to `dev` are reserved for explicit user requests or emergency
  recovery work.

## Delivery Workflow Automation

Implemented:

- Completed feature work must include docs that describe implemented behavior,
  missing pieces, and future adjustment directions.
- Short-lived feature branches are preferred over direct `dev` pushes.
- Merged same-repository pull requests automatically delete their remote head
  branch unless it is `dev`, `main`, `master`, or under `release/`.

Not implemented yet:

- Local branch cleanup after merge is still manual on each developer machine.
- Fork pull request branches are not deleted by this repository's workflow.
- PR template enforcement for the documentation checklist is not automated yet.

Future adjustment directions:

- Add a pull request template with implemented/not-implemented/future sections.
- Add CI checks that warn when feature PRs do not update docs.
- Add a local helper script to prune merged branches after syncing `dev`.

## Product Gates

Before implementing Daily Card or AI work, read:

- `docs/life-timeline-product-direction.md`
- `docs/card-ai-development-spec.md`
- `.harness/rules/07-product-ai-cards.md`

Required product gates:

1. Card data model is UI-agnostic JSON-like data.
2. AI reads filtered summaries, not raw logs.
3. Sensitive app and browser-title policy exists before AI launch.
4. Desktop implementation comes before mobile technology lock-in.
5. Mobile must consume the same card model as desktop.

## Minimum Runnable Rule

Agents must prefer the smallest complete vertical slice that can run and be
verified. Do not build broad infrastructure first unless the slice cannot work
without it.

For implementation work, the preferred loop is:

```text
model -> local logic -> existing UI surface -> smoke verification -> docs
```

Avoid detours:

- Do not choose final mobile technology before the card model stabilizes.
- Do not add dependencies for simple classification or formatting.
- Do not start AI generation before local template cards work.
- Do not refactor unrelated pages while implementing a feature.
- Do not change the service schema for derived UI concepts.

If a larger idea is useful but not required for the current slice, record it as
a follow-up instead of implementing it immediately.

## Architecture Gates

Respect the two-process contract:

- Service samples and writes disk records.
- UI reads disk records and renders summaries.
- No sockets, shared memory, or direct UI-service linking.
- Control from UI to service, if needed, must be a file contract.

Daily Card should start in the UI layer:

- `UsageStatManager` remains the reader of usage history.
- A future `DailyInsightManager` may aggregate cards and summaries.
- QML displays cards but does not parse raw logs.

Schema changes are expensive:

- Prefer derived summary/card files before changing the service tables.
- If `data_bridge.h` or the SQLite table contract changes, file a change
  proposal first.
- If a new session kind is added, update the bridge, schema, and reader logic
  together.

## AI Development Rules

AI may:

- summarize local daily summaries,
- name days, blocks, and cards,
- suggest categories,
- polish card copy,
- produce weekly/monthly review text.

AI must not:

- collect data,
- read raw usage logs directly,
- read chat contents,
- receive screenshots or raw audio,
- infer private content from redacted fields,
- judge the user morally.

Every AI-facing payload must pass:

```text
raw records -> local summary -> privacy filter -> user confirmation -> AI
```

## Documentation Rules

Update docs when behavior or product direction changes:

- User-visible feature: update `README.md`.
- Product/card/AI direction: update `docs/*.md`.
- Harness or workflow rule: update `.harness/rules` or this document.
- Data contract: update schema docs and file a change proposal.

Keep `.harness/*.md` files under 100 lines. Put long product notes in `docs/`.

## Verification Rules

Use project tools:

- Build through `python .harness/tools/build.py`.
- After Qt/QML runtime, run `python .harness/tools/scan_qt_log.py`.
- Before commit, run `python .harness/tools/harness_check.py`.

If the environment cannot build because the toolchain is missing, record that
as L1 and state clearly that behavior was not verified.

## External References Checked

- Claude Code memory:
  https://code.claude.com/docs/en/memory
- Claude Code settings and sensitive-file deny rules:
  https://code.claude.com/docs/en/settings
- Claude Code skills / slash commands:
  https://code.claude.com/docs/en/slash-commands
- Claude Code hooks:
  https://code.claude.com/docs/en/hooks
- Codex use cases:
  https://developers.openai.com/codex/use-cases

These references explain available agent features. TimeArc still treats
`.harness` as the source of truth for coding behavior.
