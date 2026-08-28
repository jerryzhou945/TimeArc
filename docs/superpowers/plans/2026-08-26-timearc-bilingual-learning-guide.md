# TimeArc Bilingual Learning Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a source-verified bilingual beginner curriculum for learning and presenting TimeArc.

**Architecture:** Create a discoverable `docs/learning/` book split into focused chapters. Use current code and contracts as factual sources, and treat the external older textbook as a teaching reference only.

**Tech Stack:** Markdown, Qt 6, QML, C++17, C11, Swift, Java/Android, SQLite, CMake, Python harness.

**Spec:** `docs/superpowers/specs/2026-08-26-timearc-bilingual-learning-guide-design.md`

## Global Constraints

- Documentation-only change; application behavior remains unchanged.
- Current source and `.harness/CHARTER.md` override historical documents.
- Every chapter includes Chinese explanation and reusable English terminology.
- No frozen file may be edited.
- Retired JSONL, live snapshot, and `usage_config.json` designs appear only as history.

---

### Task 1: Create the learning map and architecture foundation

**Files:**
- Create: `docs/learning/00-README.md`
- Create: `docs/learning/01-product-and-requirements.md`
- Create: `docs/learning/02-technology-foundations.md`
- Create: `docs/learning/03-two-process-architecture.md`
- Create: `docs/learning/04-repository-and-build.md`

**Interfaces:**
- Consumes: root README, charter, CMake source tree.
- Produces: terminology and architecture model used by later chapters.

- [ ] Write the audience, reading paths, current platform scope, and source-of-truth warning.
- [ ] Explain the product problem, local-first privacy constraints, and measurable requirements.
- [ ] Teach only the C/C++/Qt/QML/SQLite/CMake concepts needed for this repository.
- [ ] Explain the two-process boundary, allowed communication, dependency direction, and failure isolation.
- [ ] Map directories and build targets to runtime responsibilities.
- [ ] Verify every named path exists.

### Task 2: Document runtime collection and platform implementations

**Files:**
- Create: `docs/learning/05-startup-and-composition.md`
- Create: `docs/learning/06-windows-collector.md`
- Create: `docs/learning/07-tracking-policies.md`
- Create: `docs/learning/08-platform-implementations.md`

**Interfaces:**
- Consumes: architecture vocabulary from Task 1.
- Produces: observations and sessions consumed by the storage chapters.

- [ ] Trace GUI and native-service startup from their entry points.
- [ ] Explain Windows foreground, idle, media, voice, Agent, and game signals.
- [ ] Explain observation identity, session boundaries, idle semantics, and interval deduplication.
- [ ] Compare Windows C, macOS Swift, Android Java/JNI, and Linux status without overstating parity.
- [ ] Verify claims against service source and targeted tests.

### Task 3: Document persistence and application layers

**Files:**
- Create: `docs/learning/09-data-contract-and-databases.md`
- Create: `docs/learning/10-cpp-application-layers.md`
- Create: `docs/learning/11-qt-qml-bridge.md`

**Interfaces:**
- Consumes: collector session records from Task 2.
- Produces: query models and QML-facing objects used by Task 4.

- [ ] Document `timearc_service.db`, `timearc.db`, ownership, paths, tables, indexes, and migrations.
- [ ] Distinguish Repository, Service, and Manager responsibilities with actual class examples.
- [ ] Trace construction, dependency injection, context properties, signals, properties, and invokable methods.
- [ ] Verify database table names against current DDL.

### Task 4: Document UI, statistics, and lifecycle

**Files:**
- Create: `docs/learning/12-qml-ui.md`
- Create: `docs/learning/13-statistics-and-identity.md`
- Create: `docs/learning/14-configuration-lifecycle-privacy.md`

**Interfaces:**
- Consumes: QML-facing models from Task 3.
- Produces: the end-to-end user-visible explanation used in interviews.

- [ ] Map desktop/mobile shells, navigation, pages, reusable components, and theme structure.
- [ ] Explain interval union, period aggregation, read filters, custom display names, and adapters.
- [ ] Explain `service_config.json`, service lifecycle, local privacy, fallbacks, and failure handling.
- [ ] Verify QML pages and registered context names exist.

### Task 5: Document quality, reconstruction, and interviews

**Files:**
- Create: `docs/learning/15-testing-build-release.md`
- Create: `docs/learning/16-build-timearc-from-zero.md`
- Create: `docs/learning/17-tradeoffs-and-evolution.md`
- Create: `docs/learning/18-interview-playbook.md`
- Create: `docs/learning/19-glossary-and-exercises.md`
- Modify: `docs/README.md`

**Interfaces:**
- Consumes: all earlier chapters.
- Produces: study plan, interview scripts, and maintainable documentation entry point.

- [ ] Explain unit/static/smoke tests, harness tracks, build wrapper, log scan, and release gates.
- [ ] Reconstruct the project in implementation order with milestones and acceptance criteria.
- [ ] State trade-offs, limitations, and credible evolution paths.
- [ ] Provide 30-second, two-minute, and deep-dive interview narratives plus model Q&A.
- [ ] Add a bilingual glossary, exercises, and answers.
- [ ] Link the guide from `docs/README.md`.

### Task 6: Verify the curriculum

**Files:**
- Verify: `docs/learning/*.md`
- Verify: `docs/README.md`

**Interfaces:**
- Consumes: completed curriculum.
- Produces: a validated documentation handoff.

- [ ] Check all Markdown links and referenced repository paths.
- [ ] Search for stale contracts presented as current behavior.
- [ ] Search for relative-time wording and placeholders.
- [ ] Confirm no frozen files changed.
- [ ] Run `harness_check.py` with the bundled Python runtime.
- [ ] Update the session log outcome and file list.
