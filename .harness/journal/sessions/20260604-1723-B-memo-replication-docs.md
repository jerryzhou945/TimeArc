# Session 20260604-1723 · Track B · Memo-page replication docs

## Track
B (Feature) — authoring replication documentation for the Memory Lake
**备忘 / 黑板 (memo / blackboard)** page, paralleling the existing home-page
doc ecosystem. No code change; docs only.

## Goal
Produce replication documentation for the memo page covering:
1. **Art** — how the blackboard's blurred/frosted dark texture + dotted paper
   is composed; how the toolbar / sticky notes / page-folder / pomodoro UI
   surfaces are rendered; overlay open/close + pomodoro animations.
2. **Functionality** — full behaviour/state model extracted from the v88
   `<script>` (tools, canvas pen/eraser, sticky+text objects, per-page model,
   pomodoro timer + collapse/expand + particle/complete animations), and the
   QML architecture to replicate it. Mark features the design leaves
   incomplete (user will fill later).
3. **复刻规则 / 复刻标准 / 复刻方式步骤** — rules, acceptance standards, stepwise method.

## Source of truth
`MemoryLakeDesign/TimeArcDesign_v88.html` (18,744 lines). Memo DOM 14674–14886
+ 18367; memo JS 16236–17750. CSS in version-layered overrides (V40–V88).

## Existing ecosystem to match / cite
- `docs/memory-lake-art-lighting-qml-cookbook.md` (token/technique dictionary)
- `docs/memory-lake-home-art-implementation-spec.md` (法规 / acceptance clauses)
- `docs/memory-lake-home-render-pipeline-replication.md` (pipeline 1:1 method)

## Method
Workflow #1: 7 parallel extraction agents (one per subsystem) → structured findings.
Author docs from findings. Workflow #2: adversarial verification of every cited
line number / CSS / JS value against the HTML. Then harness_check before finishing.

## Constraints
Frozen: top-level + src CMakeLists, service shared headers, harness files.
`resources/CMakeLists.txt` NOT frozen (shader/asset path open). `qml/` not frozen.
No memo QML component exists yet — greenfield.

## Deliverables (decided)
- `docs/memory-lake-memo-render-pipeline-replication.md` (art / render pipeline)
- `docs/memory-lake-memo-functional-replication.md` (functionality / state / steps)
- Cross-link into the existing ecosystem (cookbook = techniques, specs = clauses).
