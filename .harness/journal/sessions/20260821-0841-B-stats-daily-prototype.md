# Statistics daily prototype

Goal: build a standalone HTML/CSS/JS prototype that simplifies the current statistics page around a daily application clock while leaving the production Home and tracking stack unchanged.

Service side: unchanged. The prototype does not read or write either TimeArc database and uses a fixed privacy-safe fixture shaped like foreground application segments.

UI side: the prototype consumes the fixture in browser-only JavaScript, renders individual applications inside AM/PM clock sectors, enlarges the hovered or locked application sector, and progressively reveals category, timeline, and ranking detail.

Expected files: `docs/prototypes/timearc-stats-rework-v1.html`, its colocated CSS/JS, one focused Node behavior test, and concise progress/report documentation. Frozen files, QML, C++, service code, schemas, and build files are out of scope.

Rule files requiring updates: None. The prototype is documentation-only and does not alter the production UI contract.

Progress:

- [x] Audit current Home, statistics, shell navigation, PRODUCT.md, and DESIGN.md.
- [x] Confirm the daily-first clock design with the user.
- [x] Write failing behavior tests for application sectors and focus state.
- [x] Implement the standalone interactive prototype.
- [x] Verify behavior, desktop layout, accessibility, and visual output.

Completed: Desktop statistics prototype with individual application sectors, focus enlargement, daily timeline, ranking, privacy mode, and simplified week/month/year views.
Incomplete: Production `DesktopStatsPage.qml` migration, real `UsageStatManager` wiring, and a standalone Plan surface are intentionally outside this prototype.
Verification: Node behavior test, JavaScript syntax check, Chrome desktop DOM/visual smoke, `git diff --check`, and harness check.
Next: Review the desktop prototype with the maintainer, then open a separate Track B slice to port the approved structure into QML.
Risks: The browser fixture proves information hierarchy and interaction only; production data density, very short sessions, localization, and Qt SVG/Canvas performance still require QML validation.
