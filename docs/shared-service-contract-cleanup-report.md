# 共享服务契约清理报告

## 目标

删除已经没有代码消费者的旧聚合 session 契约，统一以跨语言表写入桥和
`timearc_service.db` 三张服务表作为当前契约。

## 范围

- 删除旧聚合 C 结构头及其独立协议说明。
- 从 service CMake 源清单和冻结文件注册表移除旧头。
- 将 Charter 升至 v0.10，并同步架构、平台、检查清单和项目文档。
- 保留历史迁移文档中的 JSONL 叙述；它们记录的是当时真实存在的迁移输入。

## 主要变更文件

- `src/service/CMakeLists.txt`：不再登记旧聚合头。
- `.harness/CHARTER.md`、`rules/01-architecture.md`、
  `rules/02-platform-boundaries.md`：以 bridge + SQLite 表描述共享契约。
- `README.md`、`src/service/README.md`：指向权威数据契约规则。
- 相关 kickoff、backlog 和 harness 检查清单：移除失效的头/schema 引用。

## 验证

- 全仓活动文件搜索：旧头、旧协议文档、旧 schema 和聚合类型/API 均无引用。
- `python .harness/tools/build.py`：通过。
- `ctest --test-dir build --output-on-failure`：1/1 通过。
- `python .harness/tools/harness_check.py`：通过。

## 已知缺口

无运行时缺口。本次不改变表结构、磁盘路径、session 切分或 UI 读取语义。

## 回滚

回退本次变更即可恢复旧文件；没有磁盘数据迁移，不需要恢复数据库。
