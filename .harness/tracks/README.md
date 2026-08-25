# Tracks

TimeArc 每次开发会话只选择一个 track，让行为变化、问题修复和纯质量工作可以独立审查。

| Track | 判断问题 | 常见工作 | 入口 |
| --- | --- | --- | --- |
| **A Stabilize** | 对外行为是否保持不变？ | 重构、性能、可维护性 | [A-stabilize.md](A-stabilize.md) |
| **B Feature** | 是否增加以前没有的能力？ | 页面、策略、平台能力 | [B-feature.md](B-feature.md) |
| **C Debug** | 是否修复今天已知的错误？ | 漏记、误记、崩溃、回归 | [C-debug.md](C-debug.md) |

## 选择规则

- “现在就是错的” → C。
- “以前没有，现在要新增” → B。
- “结果完全一样，只改善内部质量” → A。
- 同时命中多个 → 拆成独立 session 和 commit。

## 所有 track 的共同要求

1. 开始前运行 `preflight.py --track <A|B|C>`。
2. 按需阅读 CHARTER、对应 track 和触及的 rules。
3. 每个错误通过 `record_error.py` 记录。
4. 任何构建只使用 `build.py`。
5. Qt/QML 运行后扫描日志。
6. commit 前运行完整 `harness_check.py`。

## 命名

Session：

```text
journal/sessions/YYYYMMDD-HHMM-<A|B|C>-kebab-slug.md
```

Error：

```text
journal/errors/YYYYMMDD-HHMMSS-<A|B|C>-kebab-slug.md
```

Commit 的首个动词遵循对应 track 文档。一个 commit 不跨 track。
