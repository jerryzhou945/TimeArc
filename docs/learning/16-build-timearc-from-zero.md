# 16 · 从零制作 TimeArc / Building TimeArc from Zero

## 本章目标 / Learning goals

用正确依赖顺序重建项目思路。重点是“先证明哪一件事，再增加哪一层”，不是复述 Git 历史。

## 阶段 1：产品与隐私

先写用户故事和禁止事项：自动记录真实活动；本地保存；不采正文、截图、原始音频；不做价值判断。输出可测试的 acceptance criteria。

## 阶段 2：最小采集 spike

用小型 Windows C 程序读取前台窗口、PID、exe path 和 idle，只打印规范化 snapshot。先证明系统 API 可靠，再设计产品代码。

## 阶段 3：Session 状态机

把 snapshots 输入纯状态机，定义 identity、start、continue、idle、change、shutdown。用可控时钟写事件序列测试。

## 阶段 4：SQLite 契约

定义 `apps`、`frontmost_sessions`、`media_sessions`，加入约束、索引、事务和固定路径，再创建 C ABI bridge。

## 阶段 5：独立服务

加入命名 mutex、stop event、CLI 和 checkpoint。确保 GUI 不存在时仍运行，stop 能 flush。

## 阶段 6：最小 Qt/QML GUI

创建 application、QML engine 和只读 repository；只显示今天总时长与列表，证明 OS → DB → QtSql → QML 完整链路。

## 阶段 7：媒体与去重

接 WASAPI/GSMTC，先测播放、暂停、消失和探针失败，再实现多会话 tracker；读层做 interval union。

## 阶段 8：应用层

拆 Repository、StatsService、UsageStatManager 和 view models，加入增量缓存、日历范围和 DST 测试。

## 阶段 9：产品 UI

建立 desktop/mobile shell、主题 tokens、页面和组件。先实现空态、加载态、错误态，再做玻璃效果、Canvas 和动效。

## 阶段 10：配置与生命周期

设计 versioned `service_config.json`，原子 RMW；加入自启 opt-out、status 和数据库目录指针。

## 阶段 11：跨平台

先冻结共享语义，再实现 macOS Swift/Apple frameworks 与 Android Usage API/JNI。不要因目录存在就宣称 Linux 支持。

## 阶段 12：发行工程

加入资源完整性、动态链接、许可证、安装升级、签名、公证、哈希和 clean-machine 测试。

## 为什么这个顺序有效

每阶段都产生一个 vertical slice 或可测试 contract。UI 依赖底层事实，跨平台依赖稳定语义，发行依赖可运行产品；反过来做会让大量界面建立在错误数据上。

## 面试表达 / Interview answer

“I would build TimeArc from the evidence pipeline outward: prove native observations, stabilize session semantics, persist them behind a contract, expose a read model to Qt, and only then invest in rich QML presentation and additional platforms.”

## 复习题 / Review

1. 为什么先状态机后数据库？——先确定语义，避免把错误模型固化到 schema。
2. 为什么先最小 UI 后完整视觉？——尽早证明端到端链路。
3. 跨平台为什么较晚？——需要先稳定共享契约和验收语义。
