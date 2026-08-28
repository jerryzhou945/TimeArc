# TimeArc Bilingual Learning Guide Design

## Purpose

Create a beginner-friendly Chinese/English curriculum that explains how TimeArc was conceived, structured, implemented, tested, and shipped. A learner should be able to navigate the repository and explain the project accurately in a technical interview.

## Audience

- A beginner who knows only basic programming concepts.
- The project author preparing Chinese understanding and English technical vocabulary.
- A future contributor who needs a current architecture map before changing code.

## Source-of-truth order

1. Current implementation and tests.
2. `.harness/CHARTER.md` invariants.
3. Root `README.md` and `src/service/README.md`.
4. Current decision and audit documents under `docs/`.
5. `C:\TimeArc\learning\learning` as teaching-style reference only.

Historical learning claims must not override current code. In particular, the retired JSONL/live-snapshot pipeline and `usage_config.json` must be described only as history.

## Information architecture

The guide lives under `docs/learning/`. `00-README.md` is the reading map. Numbered chapters follow the actual development sequence: product requirements, foundations, architecture, build, collectors, storage, application layer, UI, aggregation, lifecycle, quality, design reconstruction, and interviews.

Each chapter is independently readable and includes:

- `本章目标 / Learning goals`
- a plain-Chinese explanation
- English terms and reusable interview sentences
- verified source paths
- simplified flow or code examples where useful
- design rationale and alternatives
- beginner pitfalls
- interview prompts
- review questions with short answers

## Planned chapters

1. Orientation and study paths.
2. Product problem, privacy, and requirements.
3. Technology foundations.
4. Two-process architecture and one disk contract.
5. Repository and build system.
6. UI and service startup.
7. Windows collector and sampling loop.
8. Tracking policies and session state machines.
9. macOS, Android, and platform boundaries.
10. SQLite contract and database ownership.
11. Repository, service, and manager layers.
12. C++/Qt to QML bridge.
13. Desktop and mobile QML UI.
14. Statistics, interval union, and identity adapters.
15. Configuration, lifecycle, privacy, and failure handling.
16. Tests, harness, packaging, and release.
17. Reconstructing the project from zero.
18. Architecture trade-offs and future evolution.
19. Interview playbook and model answers.
20. Bilingual glossary and source-reading exercises.

## Accuracy rules

- Mark platform implementation status explicitly.
- Distinguish service database tables from GUI database tables.
- Do not imply that planning documents represent shipped behavior.
- Do not claim process existence alone is sufficient for background tracking.
- Explain that foreground and media intervals are unioned to avoid double counting.
- State that the GUI does not write automatic tracking history.
- Use exact class, file, table, and configuration names from source.

## Maintenance

`docs/README.md` links to the curriculum. Individual chapters link to stable source paths rather than line numbers. A final automated check verifies links, banned stale-contract claims, relative-time wording, and the project harness.

## Non-goals

- Reproducing every source line.
- Teaching all of C++, Qt, QML, Windows APIs, Swift, or Android in isolation.
- Promising unfinished Linux or release work.
- Rewriting historical reports.
