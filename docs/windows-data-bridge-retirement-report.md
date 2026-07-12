# Windows 存储适配层退役报告

## 目标

删除 `src/service/windows/storage/`，让 Windows 前台与音频采集代码直接使用
`shared/data_bridge.h` 已有的表写入 API。

## 范围与改动

- 前台 session 结束时调用 `update_apps` 与 `update_frontmost`。
- 音频 session 结束时调用 `update_apps` 与 `update_media`。
- Windows 启动配置读取迁移到 `windows/service_config.*`。
- 构建清单移除 Windows storage 目录，并同步架构、平台与数据契约说明。
- `src/service/shared/` 未作任何修改；SQLite 文件名、表结构与 UI 只读路径不变。

## 验证

- CMake 配置成功，harness 管理的 `time-arc` GUI target 构建成功。
- 完整构建已编译并链接 GUI 与数据库 smoke target；最终仅在已知的空
  `linux/main.c` 上因缺少 `main` 失败，harness 已记录该 L1。
- 使用严格告警（`-Wall -Wextra -Werror`）对改动后的 Windows config 与 tracker
  源文件完成定向 C11 语法检查。
- `git diff --check` 检查补丁格式。
- 全仓搜索确认 Windows 构建和代码不再引用 `windows/storage`、
  `usage_storage.*`、`TimeArcStorageContext` 或 `ta_write_usage_record*`。
- 仍需在 Windows Qt 工具链上完成真实编译与 60 秒采集 smoke test。

## 已知缺口

当前环境不是 Windows，无法在本机执行 Win32 采集与 SQLite 落盘 smoke test。

## 回滚

回滚本次变更即可恢复原 Windows storage 适配层；磁盘 schema 未变，不需要恢复数据。
