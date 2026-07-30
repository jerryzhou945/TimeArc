# Error Report - macos-menu-bar-self-bound-window

## Metadata

- Level: **L3**
- Track: **B**
- Topic: macos-menu-bar-self-bound-window
- Recorded: 2026-07-28T20:15:46Z
- Session: `../sessions/20260729-0325-B-macos-menu-bar-design.md`
- Platform: macOS
- Tooling: QML runtime probe (console.log of the menu bar's gate properties)

## 1. What happened

MacMenuBar was given 'appWindow: appWindow'; the RHS resolved to the object's own property, so hostWindow stayed null and every window-gated command greyed out. My runtime check only measured the closed-window state, where false was the expected value, so the always-false gate went unnoticed.

## 2. Evidence

User report: "why are most commands grey and unusable?" A temporary probe in
`main.qml`, logged while the window was open:

```
PROBE window.visible= true shellItem= DesktopAppShell_QMLTYPE_68(0x118b39580)
PROBE bar.appWindow= null bar.shell= DesktopAppShell(0x118b39580) hasWindow= false hasShell= true canNavigate= false
```

`shell` (a name that does not collide) arrived; `appWindow` did not. After
renaming to `hostWindow`/`hostShell`:

```
PROBE hostWindow= ApplicationWindow(0x11662e520) hasWindow= true hasShell= true canNavigate= true
      view/记忆湖.enabled= true file/关闭窗口.enabled= true window/最小化.enabled= true
```

## 3. Root cause

- Immediate cause: `MacMenuBar { appWindow: appWindow }` in `main.qml`. In a
  QML binding the right-hand side resolves against the scope object first, so
  `appWindow` found the MacMenuBar's own property, not main.qml's window id.
  The binding was a self-assignment that stays null, and it produces no
  warning — no binding loop, no type error, nothing in the Qt log.
- Underlying cause: naming an injected property after the id it is fed from.
- Why the harness/checklists did not prevent it: nothing static can see it;
  the QML compiles and runs. Only a runtime read of the property shows it.

## 4. Fix

- Files changed: `qml/desktop/MacMenuBar.qml`, `qml/main.qml`,
  `tests/macos_menu_bar_static_test.py`
- Short description: renamed the injected properties to `hostWindow` /
  `hostShell` so neither shadows a `main.qml` id; the static test now requires
  those names and forbids re-introducing `property var appWindow` on the bar.
- Commit: not applicable (uncommitted at time of writing)

## 5. Prevention

Verify a gate in the state where it is supposed to be **true**, not only where
it is supposed to be false. The close→reopen probe read `hasWindow=false` while
the window was closed and that was the expected value there, so an
always-false gate passed as correct. One assertion in the open state would have
caught it immediately. Worth adding to `rules/04-ui-conventions.md` as a QML
naming rule: never name an injected property after the id that feeds it.

## 6. Lessons for agents (L3)

- Wrong assumption: that observing the expected value in one state confirms
  the binding; a constant produces the expected value half the time.
- Earlier signal available: yes — the same probe could have printed the gates
  while the window was open. Also, the user could see the greyed menus
  immediately, which means the check I ran did not match what the user sees.
- Rule file to update: `rules/04-ui-conventions.md` (QML property naming;
  do not name an injected property after the id bound into it).
