# JSONL 历史存储退役报告

## 目标

完成 A1 S5：以 `timearc_service.db` 作为自动使用记录的唯一历史存储，移除服务端旧历史流写入和 UI fallback/parity 读路径。`usage_current.json` 与 `usage_config.json` 继续保留。

## 范围

- 服务端：`usage_storage` 初始化 SQLite 与 live snapshot，不再创建或追加旧历史文件；完成 session 只进入数据库事务。
- UI：`UsageStatManager` 只增量读取只读 service DB；数据库缺失或异常时显示空历史。设置页存储统计改为 service DB + GUI DB。
- 契约：Charter 升至 v0.8；live JSON schema 补齐 `live`、`updated_unix_sec`；架构、平台、数据契约与 README 同步。
- 迁移：旧版本遗留文件不再读写，但不会自动删除，避免升级时误删未成功回填的用户历史。

## 主要文件

- `src/service/windows/storage/{usage_storage.c,usage_storage.h,storage_context.h}`
- `src/services/usage_stat_manager.{cpp,h}`
- `qml/desktop/pages/DesktopProfilePage.qml`
- `.harness/CHARTER.md`、`.harness/rules/01-04*.md`
- `README.md`、`docs/implementation-backlog.md`

## 验证

- `python .harness/tools/build.py --track B --topic jsonl-retirement-ui-build -- --target time-arc`：通过。
- Windows storage C 文件在当前 Linux 主机执行 C11 syntax-only 检查：通过。
- live snapshot schema 使用 `jq` 校验新增必填字段：通过。
- 活跃源码/QML/契约扫描：无旧历史流、fallback 环境变量或 parity API 引用。
- 全目标 baseline：Qt app 与 `timearc_db_smoke` 均完成编译；最终因 Linux service 的既有空 `main.c` 链接失败。
- `ctest`：既有 legacy project migration idempotence 断言失败，已记 L2；与本轮 storage/reader 变更无调用关系。

## 已知缺口

- 当前主机不能执行 Windows/macOS service 运行 smoke；Windows 构建与 60 秒双进程实测仍需目标机完成。
- 遗留旧历史文件不会自动清理，可在后续提供独立、显式且带备份检查的清理工具。
- Windows `usage_current.json` 替换仍存在 remove→rename 的短暂不可见窗口。

## 回滚

回滚本次改动即可恢复旧双写/fallback 代码。SQLite schema 和已有数据未迁移，无需还原数据库；遗留旧文件亦未被删除。
