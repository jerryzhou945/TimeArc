# Windows 安装器与原生图标修复（2026-08-25）

## 目标

修复 Windows 测试安装器把 `install.ps1` 当文本打开，以及安装后快捷方式、资源管理器和任务栏显示通用程序图标的问题。

## 范围

- 安装器从不支持配置的 `7zS2.sfx` 切换到 `7zSD.sfx`，并允许从系统目录解析 PowerShell。
- 增加无安装副作用的 SFX 执行 smoke，防止再次只校验“能解压、不能执行”。
- 基于现有 TimeArc SVG 几何和配色生成 16/24/32/48/64/128/256px Windows ICO。
- 通过 Windows RC 将图标编译进 GUI `TimeArc.exe`；服务、macOS 和 Android 构建不变。
- 增加 PE 行为测试，要求构建产物同时包含 `RT_ICON` 和 `RT_GROUP_ICON`。

## 关键文件

- `tools/package-installer.ps1`
- `tests/windows_installer_packaging_static_test.py`
- `tests/windows_installer_sfx_smoke_test.ps1`
- `tools/generate-windows-icon.py`
- `resources/bundle/windows/TimeArc.ico`
- `resources/bundle/windows/TimeArc.rc`
- `tests/windows_executable_icon_test.py`
- `CMakeLists.txt`

## 验证

- 安装器静态配置与临时 SFX 真执行 smoke。
- Harness 包装的 Release 构建。
- PE 图标资源测试与 `objdump` `.rsrc` 检查。
- ICO 七尺寸检查、CTest、链接验证、静态 UI 测试和 harness 审计。

## 已知边界

- 本轮按产品要求不重新发布安装包；最终安装包等待其他协作者修改合并后统一生成。
- Windows 可能缓存旧快捷方式或已固定任务栏图标；新安装包发布时需在 clean-machine QA 中验证，旧固定项必要时重新固定。
- 测试安装器仍未签名，也尚未注册“应用和功能”卸载项。

## 回滚

回退本修复对应的 PR 即可；不涉及数据库、配置或历史数据迁移。
