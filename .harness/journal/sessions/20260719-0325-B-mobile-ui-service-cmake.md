# Change Proposal — mobile-ui-service-cmake

## Metadata

- Author: Codex
- Track: **B (Feature)**
- Date: 2026-07-19 03:25 (local)
- Session goal: 把手机端壁纸导入与图片分享收敛为一个可供 QML 使用的 UI 私有服务。
- Branch: `codex/mobile-qml-full-ui`
- Related error reports: none

## 1. Frozen files touched

- `src/CMakeLists.txt` — 把新增的 `mobile_ui_service.h/.cpp` 加入 UI
  可执行目标的源文件清单。

## 2. Motivation

QML 不能可靠地持久读取 Android `content://` 图片，也不应直接执行文件 IO。
若不增加该服务，自定义壁纸在重启后可能失效，分享海报也无法安全交给 Android
系统分享面板。

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | 无影响；后台采集进程、源码和构建目标均不引用新服务。 |
| Consumer | UI 目标新增一个 QObject，用于应用私有壁纸文件和分享图片。 |

## 4. Migration plan

No on-disk impact. 新文件位于 GUI 应用数据目录，不改变两个 SQLite 数据库、
service 配置或任何既有记录的解释方式。

## 5. Rollback plan

回退功能提交并从 `src/CMakeLists.txt` 移除两个源文件即可；用户壁纸/分享 PNG
是可安全遗留或删除的 UI 私有文件，无需数据库恢复。

## 6. Test plan

- Pre-change: QML 没有可靠的壁纸导入或 Android 系统图片分享 API。
- Post-change: 桌面移动预览可导入/清除壁纸并保存 PNG；Android 可从图库导入并
  通过 FileProvider 调起系统分享。
- New artifacts: `tests/mobile_ui_static_test.py`，扩展 `tests/db_smoke.cpp`。

## 7. Sign-off

- [x] `rules/*.md` 无需更新；现有 UI 私有文件和 QObject 规则保持准确。
- [ ] `CHARTER.md` version bumped (not required; no charter amendment).
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [ ] Main `README.md` updated if user-visible.
