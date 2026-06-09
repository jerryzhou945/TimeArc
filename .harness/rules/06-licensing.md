# Rule 06 — Licensing

TimeArc is **GPL-3.0-or-later**. Any change that affects how third-party code
enters the build must pass this rule.

## 1. Current inventory

| Component | License                | Linkage         | Notes                                      |
|-----------|------------------------|-----------------|--------------------------------------------|
| Qt        | LGPL-3.0 (with exceptions) | **must be dynamic** | Main README TO-DO item. Satisfy before first release. |
| SQLite    | Public domain          | static          | Bundled as `thirdparty/sqlite3`.           |
| Parson    | MIT                    | static          | Bundled as `thirdparty/parson`. For config JSON.       |

All three are listed in `README.md` under *Third-Party Components*. Keep that
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

The main `README.md` To-Do contains:

> Include licenses for all third-party code in the UI.

When a licensing page is added to the QML UI, it must:

1. Show, for each third-party component, the component name, version, and
   full license text.
2. Be reachable without a network connection (texts shipped in `resources/`).
3. Be updated whenever `thirdparty/CMakeLists.txt` gains a new component.

Update this rule and the main README together when this lands.

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
