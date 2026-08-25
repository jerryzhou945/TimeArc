# Harness Tools

这些脚本是 TimeArc 工程门禁的机器接口。非零退出码都是阻塞信号；全部只使用 Python
标准库。Windows Store 的 `python.exe` alias 不可用时，请显式使用真实 Python 路径。

## 命令速查

| 工具 | 何时运行 | 成功结果 |
| --- | --- | --- |
| `preflight.py` | 每次会话开始 | 快速审计、track 与 session 提示 |
| `build.py` | 任何构建 | 构建完成并写 build log |
| `record_error.py` | 任何错误 | Markdown + JSONL + INDEX 原子记录 |
| `scan_qt_log.py` | Qt/QML 运行后 | 消费日志并记录新 warning |
| `harness_check.py` | commit 前 | 7 项审计通过 |

## preflight.py

```powershell
python .harness/tools/preflight.py --track B
```

退出码：`0` clean、`1` drift、`2` internal。退出 1 时先修复 drift。

## build.py

禁止直接用 `cmake --build` 替代。

```powershell
python .harness/tools/build.py --track B
python .harness/tools/build.py --build-dir build --track C -- --target all
```

构建日志写入 `journal/build-logs/<timestamp>-build.log`；失败会自动创建 L1。

## record_error.py

```powershell
python .harness/tools/record_error.py `
  --level L2 --track C --topic media-state `
  --summary "Windows media state did not close"
```

`topic` 只能是小写 kebab-case，最长 40 字符。可选 `--file`、`--platform`、
`--session`。退出码：`0` success、`1` usage、`2` filesystem。

## scan_qt_log.py

```powershell
python .harness/tools/scan_qt_log.py --track C
python .harness/tools/scan_qt_log.py --dry-run
```

默认读取 `QStandardPaths::GenericDataLocation/TimeArc/logs/harness-qt.log`，
按 `(severity, location, message)` 去重并轮转已消费日志。

## harness_check.py

```powershell
python .harness/tools/harness_check.py
python .harness/tools/harness_check.py --fast
```

七项检查：

1. harness Markdown 行数；
2. frozen-file hash；
3. CMake 结构；
4. service 平台隔离；
5. journal 一致性；
6. session/error slug；
7. track discipline。

`--bootstrap` 只用于已批准的 CHARTER/frozen-file 变更，不能作为绕过失败的手段。

## Python 解释器

工具间调用使用 `sys.executable`。需要固定解释器时：

```powershell
$env:TIMEARC_PYTHON = "C:\path\to\python.exe"
& $env:TIMEARC_PYTHON .harness/tools/preflight.py --track B
```

更多流程见 [../README.md](../README.md) 与 [../AGENTS.md](../AGENTS.md)。
