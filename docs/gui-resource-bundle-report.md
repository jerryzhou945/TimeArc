# GUI 资源外置与 macOS 双程序布局报告

日期：2026-07-27

## 目标

缩小桌面主程序体积，保持现有 QML 资源 URL 不变，并把 macOS 的 UI 与
后台采集程序统一放入 `TimeArc.app/Contents/MacOS`。

## 范围

- QML、JS、许可文本、应用 SVG 与正在使用的导航 SVG 继续内嵌。
- 日/夜背景、站点图标、12 张月度回顾图分别外置为
  `timearc-backgrounds.rcc`、`timearc-site-icons.rcc` 和
  `timearc-monthly-recap.rcc`，互不重叠但保留原 `qrc:` 别名。
- 未被 `src/` 或 `qml/` 引用的旧 Memory Lake 位图以及 `chat.svg`、
  `user.svg` 不再进入发布输入；源文件仍保留。
- Android 继续把同一 QRC 内容内嵌到应用包。
- Windows 发布脚本把缺少 service 或 GUI RCC 视为致命错误。
- macOS 构建后把 `TimeArc` 与 `time-arc-service` 同置于
  `Contents/MacOS`，LaunchAgent 放入 `Contents/Library/LaunchAgents`，
  三个 RCC 放入 `Contents/Resources/assets`。
- `tools/build-macos.sh` 负责 Release 构建、测试、`macdeployqt`、签名及 DMG，
  打包时把三组 RCC 与许可文本保留在可替换的外置位置。

## 变更文件

构建与资源清单、UI 启动注册、Windows 发布脚本、资源 smoke 测试及相关
README/规则/平台差异文档。

## 验证

- 变更前后均通过 harness 包装构建。
- `timearc_resource_bundle_smoke` 分别注册/卸载三个 RCC，验证功能边界、
  2 张背景、26 个站点图标、12 张月度图及旧 Memory Lake 位图缺席。
- `resource_manifest_static_test.py` 校验 40 个别名无重复、无跨功能归档，
  且每个源文件存在。
- Mobile UI 静态检查通过。
- macOS 产物包含两个 arm64 可执行文件和三个外置 RCC；主程序由约
  53 MB 降至 34 MB，三个 RCC 合计约 7.9 MB。

## 已知缺口

Windows 实机打包尚未在本次 macOS 会话执行；macOS 自动包装链路已补，
仍需 Developer ID/公证凭证实测及 clean-machine QA。运行期采集与
Accessibility 权限不属于本次资源布局变更。

## 回滚

回退本次资源/CMake/启动注册改动即可；数据库和用户配置无需恢复。
