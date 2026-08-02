# HarmonyOS 卓易通安全启动设计

## 目标

让 Android APK 在 Pura 90 Pro 的卓易通兼容环境中先稳定显示 TimeArc 主界面；Android 使用情况权限或后台同步不可用时必须降级，而不是在启动阶段退出。

## 设计

- Android 启动固定使用 OpenGL RHI，避开兼容容器可能不完整的自动图形后端选择。
- QML 首帧和启动动画完成后，才执行使用情况权限检测；首次启动只引导到设置页，不自动拉起系统权限 Activity。
- 禁止 WorkManager 通过 AndroidX Startup 在进程创建时自动初始化，改为首次同步请求时按需初始化。
- Java 平台桥接捕获兼容环境缺失 API、Activity 和 WorkManager 初始化失败，并向 C++ 返回失败状态。
- C++ JNI 边界检查并清除 Java 异常，将失败映射成可见的同步状态。

## 验证

- 静态测试确认自动初始化被移除、启动检测已延迟、Java/C++ 边界具备失败返回。
- Windows 基线构建与现有测试不回归。
- Android arm64-v8a APK 构建成功并核对包名、SDK、ABI、签名和哈希。
- 真机结论以 Pura 90 Pro 通过卓易通安装后的运行结果为准。

## 非目标

- 本次不实现原生 HarmonyOS HAP。
- 不承诺卓易通提供 Android UsageStats 数据；不支持时应用仍可进入界面并使用其他功能。
