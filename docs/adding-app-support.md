# Adding Desktop App Support

Desktop app support is added by creating one adapter file and registering it.

## Steps

1. Add a new header under `src/services/adapters/apps/`.
2. Return a `TimeArcAdapters::AdapterDefinition`.
3. Register the adapter in `src/services/adapters/desktop_app_adapter_registry.h`.
4. Add smoke coverage in `tests/db_smoke.cpp` when the behavior is important.
5. Run the harness build and smoke test.

## Adapter Shape

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

## Matching Rules

Preferred signals:

- App identifier or bundle identifier
- Process name
- Existing executable path or app name signal

Do not:

- Inspect private files
- Read chat content
- Read editor buffers
- Capture screenshots
- Use network IP address as app identity

## Icons

For desktop apps, TimeArc can usually use the executable path and `image://appicon/` provider to render the native icon. Adapters should still provide a stable `iconLabel` and `brandColor` so the UI has a safe fallback.

