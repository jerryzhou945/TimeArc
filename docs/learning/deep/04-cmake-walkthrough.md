# 04 · CMake 装配图 / CMake Walkthrough

## 1. CMake 不直接等于编译器

CMake 读取项目描述，生成 Ninja、Makefiles、Visual Studio 等具体构建规则。之后真正的编译器才把每个 `.c/.cpp/.swift` 变成 object files，并由 linker 组合成 executable。

## 2. 项目开场

```cmake
cmake_minimum_required(VERSION 3.16)
project(time-arc VERSION 0.1 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
```

这定义最低 CMake、项目名、版本和语言标准。Apple 分支额外 `enable_language(Swift)` 与 `OBJCXX`。

## 3. 查找 Qt

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Quick Svg Sql Widgets)
qt_standard_project_setup(REQUIRES 6.8)
```

`REQUIRED` 表示缺少模块立即停止。找到后得到 `Qt6::Core` 等 imported targets，而不是手工写 DLL 路径。

## 4. 子目录是怎样返回文件清单的

顶层：

```cmake
add_subdirectory(thirdparty)
add_subdirectory(src)
add_subdirectory(qml)
add_subdirectory(resources)
```

子目录变量默认有自己的 scope。`src/CMakeLists.txt` 最后用：

```cmake
set(TIME_ARC_APP_SOURCES ${TIME_ARC_APP_SOURCES} PARENT_SCOPE)
```

把清单交给父目录。这样文件名放在离文件最近的位置，顶层只负责装配。

## 5. GUI target

```cmake
qt_add_executable(time-arc ${TIME_ARC_APP_SOURCES})

set_target_properties(time-arc PROPERTIES
    OUTPUT_NAME "TimeArc"
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)
```

`time-arc` 是 CMake 内部 target；磁盘输出名是 `TimeArc`。Windows GUI flag 防止双击弹 console；macOS bundle flag 生成 `.app` 结构。

## 6. QML module

```cmake
qt_add_qml_module(time-arc
    URI time_arc
    VERSION 1.0
    QML_FILES ${TIME_ARC_QML_FILES}
    RESOURCES ${TIME_ARC_RESOURCE_FILES}
)
```

QML 不再是随意放在磁盘的文本，而是 target 的正式资源。运行时加载路径 `qrc:/qt/qml/time_arc/qml/main.qml` 与 URI/资源布局对应。

## 7. 服务 target

```cmake
add_executable(time_arc_service ${TIME_ARC_SERVICE_SOURCES})
set_target_properties(time_arc_service PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
    OUTPUT_NAME "time-arc-service"
)
```

服务没有 Qt 对象，关闭 moc/uic/rcc。它仍链接 vendored SQLite 与 Parson，但不链接 Qt。

## 8. 平台源文件选择

```cmake
if(APPLE)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES ...Swift files...)
elseif(WIN32)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES ...C files...)
elseif(UNIX)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES linux/main.c)
else()
    message(FATAL_ERROR "Unsupported platform")
endif()
```

配置阶段只选择一组。平台隔离不是靠开发者“记得别调用”，而是让不相关文件根本不进入 target。

## 9. 链接库

```cmake
target_link_libraries(time_arc_service PRIVATE
    ${TIME_ARC_THIRDPARTY_LIBS}
)

if(WIN32)
    target_link_libraries(time_arc_service PRIVATE
        user32 psapi ole32 uuid)
endif()
```

Windows 系统库分别支持窗口、进程和 COM。Apple 分支链接 AppKit、ApplicationServices、CoreAudio、CoreGraphics、IOKit、ServiceManagement。

## 10. PUBLIC / PRIVATE

`PRIVATE` 依赖只服务当前 target。第三方库对自己的 include directory 使用 `PUBLIC`，于是链接该库的 target 自动得到头文件搜索路径。

现代 CMake 的核心不是全局 `include_directories()`，而是让使用需求跟着 target 传播。

## 11. Generator expression

```cmake
$<$<CONFIG:Debug>:TIMEARC_DEBUG>
```

这在生成/构建阶段根据配置决定值。普通 `if()` 在配置时执行；generator expression 可以针对 Debug/Release、语言或最终 target file 路径延迟判断。

Apple Swift bridging options 也只在 `COMPILE_LANGUAGE:Swift` 时生效。

## 12. 资源包

桌面大型资源被编译为独立 `.rcc`，构建后复制到 `assets/`。GUI 启动时注册 backgrounds、site-icons、monthly-recap 三个包；任意必需包缺失就拒绝启动。

Android 则使用 `qt_add_resources` 合入 Android 产物，避免依赖桌面目录布局。

## 13. 测试 targets

顶层还创建：

- `timearc_resource_bundle_smoke`
- `timearc_db_smoke`
- `timearc_pomodoro_test`
- Windows foreground/audio policy tests

`add_test()` 把 executable 注册给 CTest。测试复用 production source list，可发现实际链接或 schema 问题。

## 14. 为什么构建不能裸跑

项目要求 `.harness/tools/build.py` 包装构建。它保存完整日志，并在失败时自动生成错误报告。CMake 描述“怎么构建”，Harness 规定“以什么可审计流程构建”。

## English vocabulary

configure step, build step, target, source list, include directory, link dependency, imported target, generator expression, platform gate, output name, resource bundle, test target.

## Interview sentence

“CMake builds two independent targets and selects native collector sources at configure time. Qt packages the QML module into the GUI, while the service disables Qt code generation and links only native platform frameworks plus SQLite and Parson.”

## 练习

1. 从 `qml/CMakeLists.txt` 找到一个页面，追到 `qt_add_qml_module`。
2. 解释 target `time_arc_service` 与输出 `time-arc-service.exe` 的关系。
3. 为什么 macOS helper 要被复制进 `.app/Contents/MacOS`？
