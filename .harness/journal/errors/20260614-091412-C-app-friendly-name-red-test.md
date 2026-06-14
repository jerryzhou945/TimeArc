# Error Report - app-friendly-name-red-test

## Metadata

- Level: **L2**
- Track: **C**
- Topic: app-friendly-name-red-test
- Recorded: 2026-06-14T09:14:12Z
- Session: (unknown)
- Platform: Windows desktop / Qt smoke test
- Tooling: `build\timearc_db_smoke.exe`

## 1. What happened

TDD red test: timearc_db_smoke fails because WeChat/JianyingPro friendly app names are not registered yet

## 2. Evidence

```
Desktop app adapter match failed: app:wechat
```

## 3. Root cause

- Immediate cause: WeChat adapter still displayed `WeChat`; JianyingPro had no registered desktop adapter.
- Underlying cause: friendly-name coverage was adapter-specific and did not include these common Chinese apps.
- Why the harness/checklists did not prevent it: existing smoke cases expected the old English WeChat name and had no JianyingPro case.

## 4. Fix

- Files changed: `tests/db_smoke.cpp`, `src/services/adapters/apps/wechat_adapter.h`, `src/services/adapters/apps/jianying_adapter.h`, `src/services/adapters/desktop_app_adapter_registry.h`, `src/services/usage_stat_manager.cpp`.
- Short description: updated the expected names, registered JianyingPro/CapCut, and aligned group/display mapping.
- Commit: `5c8e939`

## 5. Prevention

Covered by the new `timearc_db_smoke` adapter cases.
