# 05｜开发护栏：Harness 为什么也是架构的一部分

> 本章目标：零基础理解 TimeArc 为什么不鼓励直接运行任意构建命令，以及怎样在不破坏项目约束的情况下开发。
> English focus: **development harness, preflight, invariant, frozen file, verification**.

## 1. 先理解“护栏”是什么

程序架构不只有运行时的类和函数，还包括团队怎样安全地修改程序。TimeArc 把这套开发规则放在 `.harness/` 中，称为 **development harness（开发护栏）**。

可以把它想象成机场的检查流程：

- 代码是准备起飞的飞机；
- 测试是机械检查；
- `preflight.py` 是起飞前检查单；
- `harness_check.py` 是最终放行；
- journal 是黑匣子，记录本次修改和遇到的问题。

这不是业务功能，却能降低“一个人修好 A、同时悄悄破坏 B”的概率。

## 2. 从根入口开始读

先读项目根目录的 `AGENTS.md`，再按它的指针读：

```text
.harness/AGENTS.md
.harness/CHARTER.md
.harness/tracks/A-stabilize.md
.harness/tracks/B-feature.md
.harness/tracks/C-debug.md
.harness/OPTIMIZE.md
```

三个 track 表示三类修改意图：

| Track | 中文理解 | 典型任务 |
|---|---|---|
| A — Stabilize | 稳定，不改变产品行为 | 文档、重构、补测试 |
| B — Feature | 增加新能力 | 新页面、新采集策略 |
| C — Debug | 修复已知错误 | 崩溃、错误统计、状态机 bug |

为什么必须先分类？因为 feature 和 bug fix 的风险、验证方式、允许触碰的文件都不同。**Intent classification（意图分类）** 是安全开发的第一步。

## 3. 一次标准会话

以文档任务为例：

```powershell
python .harness/tools/preflight.py --track A
```

如果是功能开发则选择 `--track B`。预检不是“形式主义”；它会把当前工程状态、必读规则和潜在冲突提前暴露出来。

遇到错误时，项目要求记录：

```powershell
python .harness/tools/record_error.py `
  --level L2 `
  --track A `
  --topic documentation `
  --summary "what happened"
```

这里的价值叫 **institutional memory（组织记忆）**：下一次开发者不必再次踩完全相同的坑。

## 4. 为什么有 frozen files

`.harness/CHARTER.md` 定义了 **invariants（不变量）** 和 frozen files（冻结文件）。冻结不是“永远不准修改”，而是：

1. 这些文件影响范围大；
2. 修改前必须先写 change proposal；
3. proposal 让动机、风险和验证方法可审查；
4. hash lock 防止无意中绕过流程。

例如顶层构建文件改变后可能影响 GUI、后台服务、测试和安装包，所以它比修改一个普通 QML 组件需要更强的证据。

## 5. 为什么构建必须走 wrapper

TimeArc 规定构建使用：

```powershell
python .harness/tools/build.py
```

而不是直接 `cmake --build`。wrapper 的意义通常包括：

- 统一 build directory 和 generator；
- 运行项目特有的前置检查；
- 保存一致日志；
- 避免不同开发者形成不同的“本机秘方”。

这叫 **reproducible workflow（可复现工作流）**。面试时可以说：

> We wrapped the build and verification commands in a project harness so local workflows remain reproducible and policy violations are detected early.

## 6. 静态测试、动态测试和人工验证

TimeArc 有多种验证层：

- C/C++ unit tests：验证状态机和 manager；
- Python static tests：验证资源清单、平台脚本和源码结构约束；
- JavaScript tests：验证 QML 使用的纯逻辑模块；
- smoke tests：验证数据库、资源或服务进程能实际启动；
- Qt log scan：运行 GUI 后检查 warning、binding loop、加载失败。

初学者常误以为“测试 = 调用函数看返回值”。实际上，桌面跨平台项目还必须验证构建系统、资源打包、安装脚本和平台生命周期。

## 7. 你修改一行代码时应怎样思考

假设要改空闲判断：

```text
需求
  ↓
选择 Track C 或 B
  ↓
预检 + 阅读对应规则
  ↓
找到状态机边界和已有测试
  ↓
先定义失败场景
  ↓
最小实现
  ↓
状态机单测 + 静态检查 + 构建
  ↓
运行后扫描 Qt/服务日志
  ↓
harness_check
```

每一步都在回答一个问题：**How do we know this change is safe?（我们凭什么知道这次修改是安全的？）**

## 8. 常见误解

### 误解 A：文档修改不用验证

文档也可能引用不存在的文件、描述已经退休的数据格式、产生断链。文档任务至少要检查 Markdown links、代码路径和当前 contract。

### 误解 B：测试通过就一定正确

测试只能证明覆盖到的场景。还要检查需求、架构边界和未覆盖的平台差异。

### 误解 C：冻结文件完全不能动

能动，但必须先提出 change proposal，让高风险变更具备明确理由和审查路径。

## 9. 面试表达

中文：

> 我们把开发流程本身当成架构的一部分。项目通过 track 分类、预检、冻结文件、统一构建入口和最终检查来保护跨平台与双进程边界。这样新成员不会仅凭本地经验随意修改高风险文件。

English:

> We treat the development workflow as part of the architecture. Changes are classified by intent, checked by a preflight step, and verified through a common build wrapper and a final harness check. High-impact files are frozen behind an explicit change proposal.

## 10. 本章练习

1. 分别举一个适合 Track A、B、C 的例子。
2. 解释为什么 build wrapper 比 README 中的一条命令更可靠。
3. 找到 `.harness/CHARTER.md` 中的不变量，用自己的话解释其中两条。
4. 回答：如果测试全部通过，但修改违反“双进程、一个磁盘契约”，它算成功吗？为什么？

下一章：[Windows 服务入口与采集循环](06-windows-service-loop.md)
