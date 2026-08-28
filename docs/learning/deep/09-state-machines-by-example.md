# 09｜状态机实战：把“连续世界”变成可靠记录

> 本章目标：不要求数学基础，用具体时间线学会读 TimeArc 的 foreground、audio 和 agent 状态机。
> English focus: **state, event, transition, invariant, checkpoint, idempotence**.

## 1. 为什么轮询程序需要状态机

一次采样只能告诉你“现在是什么”。用户真正需要的是“从什么时候到什么时候发生了什么”。

```text
sample: 10:00 Chrome
sample: 10:01 Chrome
sample: 10:02 VS Code

希望得到：
Chrome  [10:00, 10:02)
VS Code [10:02, ...)
```

从离散 sample 还原连续 interval，需要记住过去，这就是状态机。

## 2. 五个基础词

- **state（状态）**：程序当前记住的信息；
- **event/input（事件/输入）**：新的采样或退出信号；
- **transition（转换）**：收到输入后从旧状态变成新状态；
- **output（输出）**：转换时产生的 closed session；
- **invariant（不变量）**：任何时候都必须成立的规则。

前台状态机的不变量示例：

- CLOSED 时没有可累计的 session；
- active time 不应超过 wall duration 太多；
- app identity 切换时旧 session 必须先导出；
- checkpoint 不能改变当前 app identity；
- shutdown 后回到 CLOSED。

## 3. foreground 转换表

| 当前状态 | 输入 | 输出 | 新状态 |
|---|---|---|---|
| CLOSED | 有 app + active | 无 | ACTIVE |
| CLOSED | 有 app + idle | 无 | IDLE |
| ACTIVE | 同 app + active | 累计 elapsed | ACTIVE |
| ACTIVE | 同 app + idle/lease 过期 | 先累计 elapsed | IDLE |
| IDLE | 同 app + input/lease | 不累计上一 idle 段 | ACTIVE |
| ACTIVE/IDLE | 不同 app | 导出旧 session | 按新 sample 建 session |
| ACTIVE/IDLE | checkpoint | 导出当前片段 | 保留 mode/app，重置片段起点 |
| ACTIVE/IDLE | shutdown | 导出最后片段 | CLOSED |

注意 `sample.has_app == false` 时，当前实现不会立即因一次获取失败而切换 app；它仍会推进和更新 mode。这种容错避免瞬时 probe failure 制造虚假 app 边界。

## 4. 逐步手算 active time

假设 lease 为 2 秒：

```text
t=0  Chrome, input=true             → start ACTIVE
t=1  Chrome, input=false, auto=true → advance 1s active; lease 到 t=3
t=2  Chrome, input=false, auto=false→ lease 有效; advance 1s active
t=4  Chrome, input=false, auto=false→ advance 上一 ACTIVE 段 2s; 转 IDLE
t=6  VS Code, input=true            → IDLE 段不累计; 导出 Chrome
```

Chrome wall duration 是 6 秒，active 约 4 秒。真正实现依赖采样边界，所以单元测试必须使用明确 timestamps 推演，而不能依赖真实 sleep。

## 5. 为什么状态机尽量纯

`foreground_state.c` 不直接调用 Windows API，也不打开 SQLite。其输入是普通 struct，输出也是普通 struct。这带来：

- Linux/macOS 之外也能编译测试核心逻辑；
- 测试可以人工构造时间；
- 不必真的切换窗口；
- 错误更容易归因于 policy 而非系统环境。

这叫 **functional core, imperative shell（函数式核心、命令式外壳）**：核心做确定性转换，外壳负责 I/O。

## 6. checkpoint 的状态含义

checkpoint 不是关闭整个逻辑 session，而是切开持久化片段：

```text
内存概念 session:
[--------------------------------------]

数据库片段:
[----------][----------][----------][--]
           checkpoint  checkpoint  stop
```

为什么允许数据库有多个相邻片段？因为查询层可以聚合，而崩溃时只丢最后一个尚未写出的短片段。

## 7. audio 状态机与 foreground 的区别

audio 没有 ACTIVE/IDLE 两态；每个 app slot 主要是 OPEN/CLOSED：

```text
成功 probe 且出现 app → start/update
成功 probe 且 app 消失 → close
probe 失败             → keep unknown state
到 checkpoint          → persist and continue
shutdown               → flush all
```

关键 invariant：失败不能提供“已停止”的证据。

## 8. agent activity 状态机

后台 agent work 的问题更难：counter 不是持续增长，每次只在真正工作时跳动。因此它用 lease 把零散活动合成合理 interval：

```text
counter delta > 0 → open/renew lease
短暂停顿          → lease 内保持 active
lease 过期        → close
checkpoint        → 持久化长任务的一段
```

它与 foreground state 分开，是因为 agent 可能在浏览器位于前台时继续工作。把它们强行合为一个状态机会产生错误 ownership。

## 9. 状态机 bug 的常见类型

### Off-by-one / boundary error

在切换点把 elapsed 同时算给旧 app 和新 app，造成重叠。

### Missing flush

正常运行正确，但退出前最后一段永远不写。

### Probe failure as absence

一次系统 API 错误关闭所有 session。

### Identity drift

同一 app 的标题变化被错误当成 app 切换，或不同 app 被错误合并。

### Clock mixing

用 wall clock 计算 elapsed，系统校时后得到负 duration。

## 10. 怎样测试状态机

`tests/windows_foreground_state_test.c` 的价值不在于覆盖 C 语法，而在于构造确定时间线。好的测试模式是：

```text
Arrange：初始化 state，准备 samples
Act：按顺序 step
Assert：检查何时返回 closed、start/end/active_ms
```

应该覆盖：

- 首个 sample；
- 同 app 连续 active；
- active → idle → active；
- app 切换；
- autonomous lease；
- checkpoint；
- shutdown；
- 时间不前进或倒退；
- null input。

## 11. interval 的半开区间

时间数据库通常把 session 理解为 `[start, end)`：包含 start，不包含 end。这样相邻记录：

```text
Chrome  [10:00, 10:05)
VS Code [10:05, 10:10)
```

在 10:05 不重叠。即使 schema 没把括号写出来，设计查询和 union 时也应采用一致边界语义。

## 12. 幂等和去重思维

状态机输出后外层调用 persistence。如果未来需要更强崩溃恢复，就要考虑同一 closed session 被重试两次会怎样。理想写入应具有 **idempotence（幂等性）** 或唯一键去重。

当前实现的重点是单实例、顺序写入和 checkpoint；面试时可把幂等键、transactional outbox 或 crash-recovery journal 作为可演进方向，而不要假装已经实现。

## 13. 面试表达

> Polling gives us snapshots, while users need intervals. We therefore model foreground, audio, and background-agent activity as separate state machines. The state machines are mostly pure: they consume timestamped samples and emit closed sessions. Platform probing and SQLite persistence remain in the outer loop, which makes boundary behavior deterministic and testable.

## 14. 本章练习

1. 自己编一组 8 个 sample，手算最终 session。
2. 给“probe 失败三次后恢复”画 audio 状态图。
3. 为什么 checkpoint 后不应把 mode 设为 CLOSED？
4. 在 `tests/windows_foreground_state_test.c` 找一个断言，写出它保护的不变量。

下一章：[跨平台后端](10-platform-backends.md)
