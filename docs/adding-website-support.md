# 添加网站支持

网站支持通过“新增一个 adapter 文件并注册”完成。

## 步骤

1. 在 `src/services/adapters/websites/` 下新增一个 header。
2. 返回一个 `TimeArcAdapters::AdapterDefinition`。
3. 在 `src/services/adapters/website_adapter_registry.h` 里注册该 adapter。
4. 如果行为重要，在 `tests/db_smoke.cpp` 中补 smoke 覆盖。
5. 运行 harness build 和 smoke test。

## Adapter 示例

```cpp
inline AdapterDefinition exampleWebsiteAdapter() {
  AdapterDefinition adapter;
  adapter.identifier = QStringLiteral("site:example");
  adapter.sourceType = QStringLiteral("website");
  adapter.displayName = QStringLiteral("Example");
  adapter.category = QStringLiteral("网站");
  adapter.domain = QStringLiteral("example.com");
  adapter.iconLabel = QStringLiteral("E");
  adapter.brandColor = QStringLiteral("#BFD7EA");
  adapter.hostnames = {QStringLiteral("example.com")};
  adapter.urlPatterns = {
      QStringLiteral(R"(https?://([^/]+\.)?example\.com/.*)")};
  adapter.titleHints = {QStringLiteral("example")};
  return adapter;
}
```

## 匹配规则

优先信号：

- domain
- hostname
- URL pattern

允许的 fallback：

- service 已经捕获到的窗口标题 hint。这个 hint 只在本地使用，并且应该给较低置信度。

不要做：

- 在 adapter metadata 中保存完整敏感 URL
- 读取网页正文
- 读取输入框
- 截图
- 默认用 IP 地址作为网站身份

## 图标

推荐优先级：

1. 在授权和质量可接受时使用 repo-local icon path。
2. 未来由浏览器侧提供 favicon 或高分辨率 icon URL，并由 capture 层先做脱敏。
3. 使用 `iconLabel` 和 `brandColor` fallback。

如果 adapter 只知道 hostname，就保持 icon metadata 简洁，不要为了图标引入额外隐私风险。
