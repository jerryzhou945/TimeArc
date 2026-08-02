# Rule 06 — Licensing

TimeArc is **GPL-3.0-or-later**. Any change that affects how third-party code
enters the build must pass this rule.

## 1. Current inventory

| Component | License                | Linkage         | Notes                                      |
|-----------|------------------------|-----------------|--------------------------------------------|
| Qt        | LGPL-3.0 (with exceptions) | **dynamic** | Dynamically linked (objdump: Qt6*.dll imports); `tools/verify-linkage.ps1` asserts pre-release. |
| SQLite    | Public domain          | static          | Bundled as `thirdparty/sqlite3`.           |
| Parson    | MIT                    | static          | Bundled as `thirdparty/parson`. For config JSON.       |
| Material Symbols | Apache-2.0       | asset / qrc     | Selected Google SVG icons under `resources/app/icons/mobile`. |

All components are listed in `README.md` under *Third-Party Components*. Keep that
list in sync with this one.

## 2. Before adding any dependency

Answer, in writing, in the change proposal for the new dep:

1. What does it replace? (Or: why must it be a new dep and not inlined?)
2. License? Is it GPL-3.0-or-later compatible?
3. How is it linked (static or dynamic)? Does that create an LGPL/GPL
   combination problem?
4. Is it bundled in `thirdparty/` or fetched at build time?
5. Does it need attribution surfaced in the UI?

If you cannot answer any of these, do not add the dep.

## 3. GPL-compatible license summary

The following licenses are **generally compatible** with GPL-3.0-or-later:

- Public domain
- MIT / Expat
- BSD-2-Clause / BSD-3-Clause
- Apache-2.0 (GPL-3 only, not GPL-2)
- LGPL-2.1+ / LGPL-3+ (with the usual dynamic-linking posture)
- MPL-2.0

Incompatible or risky:

- Apache-2.0 under GPL-2 only (TimeArc is `-or-later`, so this is OK here, but
  document it.)
- Proprietary or "source-available" licenses.
- CDDL, NPL.
- Custom "all rights reserved" terms.

Consult the Free Software Foundation's list when in doubt.

## 4. Third-party license surfacing

Shipped (F2). Location: Settings → 「关于与开源许可」 tab in
`qml/desktop/pages/DesktopProfilePage.qml`. Texts live in `resources/licenses/*.txt`
(F1-S2 artifact: same files distributed with the package), embedded in the qrc via
`resources/CMakeLists.txt` and loaded by normalizing the `Qt.resolvedUrl` `qrc:/…`
to the `:/` resource prefix and calling `SettingsRepository::readTextFile()` (`QFile`
reads `:/` resources). A pure-QML `XMLHttpRequest` GET on `qrc:` was tried but is
blocked by Qt's default (`QML_XHR_ALLOW_FILE_READ` off) — see L3
`f2-qrc-xhr-blocked-use-readtextfile`. The page must keep satisfying:

1. Show, for each third-party component, the component name, version, and
   full license text. (SQLite is public domain and has no license text: it ships
   the author's blessing + an explicit "public domain, no license text" note —
   a documented, intentional deviation from the full-text requirement.)
2. Be reachable without a network connection (texts shipped in `resources/`).
3. Be updated whenever `thirdparty/CMakeLists.txt` gains a new component: add
   `resources/licenses/<name>.txt`, register it in `resources/CMakeLists.txt`, and
   add a row to `licenseComponents` in `DesktopProfilePage.qml`.

Keep this rule, the README Third-Party table, and the page in sync when components change.

## 5. Qt specifically

Qt modules currently linked:

- `Qt6::Core`, `Qt6::Quick`, `Qt6::Svg`, `Qt6::Sql`, `Qt6::Widgets`

Additional Qt modules — particularly any module gated under a commercial-only
or GPL-only posture (e.g., Qt Charts, Qt Data Visualization) — require
explicit sign-off in a change proposal.

## 6. Copyright notices

New files that are meaningful by themselves (managers, trackers, storage,
shared headers) should begin with:

```
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) <year> <author>
```

The existing `data_bridge.h`, `app_info.h`, and Swift service files already
follow this; extend it to newly created sources.
