# Statistics desktop layout revision

Goal: correct the statistics HTML prototype after maintainer feedback that its content topology still resembled a mobile stack despite the desktop sidebar.

Service side: unchanged. No tracker, database, schema, or QML code is touched.

UI side: preserve the application clock interaction while aligning the prototype with the current desktop shell: 232px rounded sidebar, full-width period toolbar, four-column overview, wide clock/analysis workbench, and horizontal timeline/ranking row. Narrow viewports collapse the sidebar only; they never create mobile bottom navigation.

Progress:

- [x] Re-audit the production desktop shell and statistics page.
- [x] Confirm the corrected wide-screen topology with the maintainer.
- [x] Add and observe a failing desktop-layout regression test.
- [x] Implement the revised HTML/CSS layout without changing tracking behavior.
- [x] Verify the 1440×900 daily render and weekly browser DOM.

Completed: Desktop-first statistics prototype revision with the existing clock interaction retained.
Incomplete: Production QML port and real usage-data wiring remain outside this prototype.
Verification: Desktop layout and clock behavior Node tests pass; JavaScript syntax, 1440×900 Chromium render, weekly DOM smoke, diff check, and harness check are the final gates.
Next: Maintainer refreshes the open prototype and reviews the desktop hierarchy before authorizing a QML port.
Risks: The HTML validates desktop composition, while Qt/QML sizing and real high-density datasets still require a separate implementation slice.
