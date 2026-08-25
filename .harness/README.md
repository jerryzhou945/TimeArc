# TimeArc Harness

TimeArc 的轻量工程门禁，供 Codex、其他 Agent 与人工审查共同使用。它把架构边界、
构建流程、错误记录和提交前检查变成可执行规则。

> 每个 `.harness/**/*.md` 必须不超过 100 行。细节按主题拆分并链接，不堆进单文件。

## 从这里开始

| 角色 | 首先阅读 |
| --- | --- |
| Codex / Agent | [AGENTS.md](AGENTS.md) |
| 人工贡献者 | [CHARTER.md](CHARTER.md) + 对应 checklist |
| 审查者 | [checklists/review.md](checklists/review.md) |
| 排查历史错误 | [journal/INDEX.md](journal/INDEX.md) |

## 一次会话的固定流程

```text
preflight -> 选择 A/B/C track -> 修改与验证 -> harness_check -> commit
```

```powershell
python .harness/tools/preflight.py --track B
python .harness/tools/build.py --track B
python .harness/tools/harness_check.py
```

Qt/QML 运行后追加：

```powershell
python .harness/tools/scan_qt_log.py
```

任何构建、运行或 Agent 自身错误都要用 `record_error.py` 记录。

## 三条 track

| Track | 用途 | 入口 |
| --- | --- | --- |
| A Stabilize | 行为不变的质量改进 | [tracks/A-stabilize.md](tracks/A-stabilize.md) |
| B Feature | 新能力 | [tracks/B-feature.md](tracks/B-feature.md) |
| C Debug | 已知错误修复 | [tracks/C-debug.md](tracks/C-debug.md) |

一次会话只选一条；混合目标应拆分提交。

## 目录

```text
.harness/
├── AGENTS.md       # 权威 Agent playbook
├── CHARTER.md      # 不变量与 frozen files
├── rules/          # 按改动面读取的规则
├── checklists/     # 编码前、提交前、审查
├── tracks/         # A/B/C 工作流
├── tools/          # 可执行门禁
├── journal/        # session、error、build log
└── state/          # 当前 track、open issues、hash lock
```

## 当前能力

- `preflight.py`：会话开始快速审计并检查 track。
- `build.py`：唯一允许的构建入口，失败自动记录 L1。
- `record_error.py`：原子写入 Markdown、JSONL 与 INDEX。
- `scan_qt_log.py`：把 Qt warning/critical/fatal 转为 L2 报告。
- `harness_check.py`：7 项提交前审计。
- CMake hook：提供 `harness-check` target。

完整 CLI 见 [tools/README.md](tools/README.md)，架构红线见 [CHARTER.md](CHARTER.md)。
