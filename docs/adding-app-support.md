# 添加桌面软件支持

桌面软件支持通过“新增一个 adapter 文件并注册”完成。

## 步骤

1. 在 `src/services/adapters/apps/` 下新增一个 header。
2. 返回一个 `TimeArcAdapters::AdapterDefinition`。
3. 在 `src/services/adapters/desktop_app_adapter_registry.h` 里注册该 adapter。
4. 如果行为重要，在 `tests/db_smoke.cpp` 中补 smoke 覆盖。
5. 运行 harness build 和 smoke test。

## Adapter 示例

```cpp
inline AdapterDefinition exampleAppAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("app:example");
  adapter.sourceType = QStringLiteral("desktopApp");
  adapter.displayName = QStringLiteral("Example");
  adapter.category = QStringLiteral("应用");
  adapter.iconLabel = QStringLiteral("E");
  adapter.brandColor = QStringLiteral("#D8D1CA");
  adapter.appIdentifiers = {QStringLiteral("com.example.app")};
  adapter.processNames = {QStringLiteral("Example.exe"),
                          QStringLiteral("Example")};
  return adapter;
}
```

## 匹配规则

优先使用：

- app identifier 或 bundle identifier
- process name
- 已有的 executable path 或 app name 信号

不要做：

- 检查私人文件
- 读取聊天内容
- 读取编辑器 buffer
- 截图
- 用网络 IP 地址作为 app 身份

## 图标

桌面软件通常可以通过可执行文件路径和 `image://appicon/` provider 渲染原生图标。adapter 仍然应该提供稳定的 `iconLabel` 和 `brandColor`，保证 UI 在图标缺失时有安全 fallback。
