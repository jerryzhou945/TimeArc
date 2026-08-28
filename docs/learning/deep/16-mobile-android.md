# 16｜Android 与移动端：UsageStats、JNI、同步和 Mobile Shell

> 本章目标：以零基础理解 Android 数据怎样跨过 Java/C++/QML 三层，并解释移动 UI 为什么不是桌面页面缩小版。
> Source map: Android Java sources, `android_usage_jni_bridge.cpp`, `mobile_usage_*`, `qml/mobile/`.

## 1. Android 的根本限制

桌面 service 可以长期在用户会话内轮询。Android 为了电池与隐私，限制任意后台常驻。TimeArc 因此依赖系统 Usage Access：

- `UsageEvents`：app 前后台事件；
- `UsageStats`：系统汇总 usage；
- `WorkManager`：受系统调度的后台工作；
- 用户必须在系统设置中授予 usage access。

这是平台约束驱动架构，而不是开发者偏好。

## 2. 数据链路

```text
Android system service
  → Java collector / worker
  → JNI native callback
  → android_usage_jni_bridge.cpp
  → MobileUsageRepository
  → MobileUsageService
  → context property
  → MobileHomePage / Stats / History
```

每个边界都要完成数据格式和线程语义转换。

## 3. UsageEvents 与 UsageStats 的差别

可以把它们理解为：

- events：更像原始“app X at timestamp entered foreground”；
- stats：系统已经按时间范围聚合的总量。

事件适合重建 session，聚合适合快速 summary。Android 版本、厂商和权限可能造成精度差异，因此实现要有 fallback 和健康状态。

## 4. WorkManager 为什么不是精确定时器

WorkManager 保证的是“满足条件时最终执行”，不是“每 60 秒准时执行”。系统可能因省电、Doze、网络、电量和后台限制推迟任务。

因此移动 UI 应显示 last sync / permission / availability，而不能把延迟伪装成实时数据。

## 5. JNI bridge 的责任

`src/services/mobile/android_usage_jni_bridge.cpp` 位于语言边界。它通常需要：

1. 暴露 Java 能调用的 native symbol；
2. 将 `jstring/jlong/object array` 转换为 Qt/C++ 类型；
3. 把结果交给正确 repository/service；
4. 确保 GUI-related update 回到 Qt thread；
5. 处理 Java exception 和空值。

JNI 不应塞入统计页面业务，它只做 **boundary translation（边界翻译）**。

## 6. MobileUsageRepository

Repository 负责持久化/查询移动 usage records。它把 platform payload 变成 Qt 应用可重复读取的数据，而不是让 QML 直接持有一次 JNI callback 的临时列表。

这同时支持：

- app 重新打开后仍有历史；
- 页面切换不丢数据；
- service 可重新聚合；
- 测试不需要真实 Java callback。

## 7. MobileUsageService

Service 负责：

- 请求立即同步；
- 暴露 permission/availability；
- 查询首页与统计需要的数据；
- 在 app 回到 active 时刷新。

`main.cpp` 监听 Android `applicationStateChanged`，在变为 `ApplicationActive` 时请求 immediate sync。原因是用户可能刚从设置页面授予权限返回。

## 8. MobileUiService

移动 UI 还有与 usage 数据无关的系统交互，例如 status bar、share、edge-to-edge 等。把这些放在 `MobileUiService`，避免 usage service 变成万能类。

这是按 capability 分服务，而不是按“Android 都放一起”。

## 9. Mobile Shell

`qml/mobile/MobileAppShell.qml` 管理底部 tab、移动主题、页面切换、launch overlay 与 share/report overlays。页面包括：

```text
MobileHomePage.qml
MobileHistoryPage.qml
MobileStatsPage.qml
MobileSettingsPage.qml
```

移动端通常采用 bottom navigation、单列内容、大触摸目标和 edge-to-edge；桌面端采用 sidebar、多栏和 hover。共享的是数据能力，不应强行共享完整页面布局。

## 10. 移动端组件系统

`qml/mobile/components/` 包含：

- `MobileSettingRow`, `MobileSwitch`；
- `MobileTabButton`, `MobileSymbolIcon`；
- ranking、share overlay、monthly story；
- safe rounded frame 与 glass panel。

这些组件内置触控尺寸、状态和 mobile tokens，使页面只负责组合。

## 11. 权限 UX

Usage access 不是普通 runtime permission dialog，用户通常要跳到系统设置。好的流程是：

```text
解释为什么需要
  → 打开系统 Usage Access
  → 用户授权
  → 回到 app
  → application active 触发重查
  → 页面显示成功或可操作错误
```

不要只显示“permission denied”；要告诉用户下一步在哪里。

## 12. 跨设备同步的边界

当前 repository 中有 cross-device sync 相关工作与交付文档，但学习时要区分：

- 本地 Android UsageStats ingestion；
- GUI 私有 mobile records；
- 真正跨设备 transport、identity、conflict policy。

“移动端能显示数据”不自动等于“所有桌面数据已实时云同步”。面试要明确完成范围。

## 13. 测试策略

- Python static tests：Java manifest/class/method wiring；
- C++ repository/service tests 或 smoke；
- QML static tests：组件与 context names；
- Android device/emulator：权限返回、后台调度、edge-to-edge；
- release APK：签名、resource、真实厂商行为。

移动平台不能只靠桌面编译通过。

## 14. 面试表达

> Android cannot reuse the desktop polling model because background execution is constrained. We read OS-provided usage history in Java, schedule refreshes with WorkManager, and bridge normalized records into the Qt C++ layer through JNI. The mobile shell consumes a repository-backed model and exposes permission and freshness states instead of pretending the data is always real time.

## 15. 本章练习

1. 为什么 WorkManager 不能保证精确每分钟运行？
2. JNI 层应该做什么、不应该做什么？
3. 用户从权限设置返回时为什么触发 immediate sync？
4. 列出 mobile shell 与 desktop shell 的三个结构差异。

下一章：[Memo 画布与复合交互](17-memo-canvas.md)
