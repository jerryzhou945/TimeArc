# Adding Website Support

Website support is added by creating one adapter file and registering it.

## Steps

1. Add a new header under `src/services/adapters/websites/`.
2. Return a `TimeArcAdapters::AdapterDefinition`.
3. Register the adapter in `src/services/adapters/website_adapter_registry.h`.
4. Add smoke coverage in `tests/db_smoke.cpp` when the behavior is important.
5. Run the harness build and smoke test.

## Adapter Shape

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

## Matching Rules

Preferred signals:

- Domain
- Hostname
- URL pattern

Allowed fallback:

- Window title hints already captured by the service, used locally and with lower confidence

Do not:

- Save full sensitive URLs in adapter metadata
- Read webpage body text
- Read input fields
- Take screenshots
- Use IP address as the default website identity

## Icons

Prefer this order:

1. Repo-local icon path when licensing and quality are acceptable.
2. Future browser-provided favicon or high-resolution icon URL, sanitized by the capture layer.
3. `iconLabel` and `brandColor` fallback.

If the adapter only knows the hostname, keep icon metadata minimal.

