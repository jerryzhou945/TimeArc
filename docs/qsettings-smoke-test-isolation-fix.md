# QSettings Smoke 测试隔离修复

## 目标

修复 Windows 上 `timearc_db_smoke` 偶发或稳定无法种入 legacy QSettings 数据的问题，使迁移幂等测试完全使用测试目录，不访问真实用户设置。

## 范围与改动

- `SettingsRepository` 的命名 legacy 设置显式使用 `QSettings::defaultFormat()` 与 `UserScope`。
- `db_smoke` 的 legacy 种子使用相同构造方式。
- 生产默认格式仍为 NativeFormat；测试设置为 IniFormat 后，命名设置会进入隔离目录。

## 验证

- 修改前：`timearc_db_smoke` 稳定失败于 `Legacy project migration was not idempotent.`。
- 修改后：目标重新构建成功，`ctest -R timearc_db_smoke` 通过。

## 已知缺口

无。此修复不改变设置键、数据库结构或迁移完成标记。

## 回滚

如需回滚，revert 本修复 PR 的 merge commit；无需数据迁移。
