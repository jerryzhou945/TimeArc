# TimeArc Adapter 系统

TimeArc adapter 系统是一套轻量的支持注册表，用来把原始活动信号转换成更友好、可展示、且隐私安全的 metadata。

它不会在第一版试图支持所有网站和所有桌面软件。第一版只优先覆盖高频网站和高频软件，然后通过文档让 contributors 后续逐步添加更多 adapter。

## 目标

- 网站通过 domain、hostname 或 URL pattern 识别。
- 桌面软件通过 app identifier、process name、app name 或可执行文件路径信号识别。
- adapter 返回统一 metadata，供聚合层和 UI 使用。
- 原始使用记录字段保持不变，保证旧数据兼容。
- adapter metadata 只是增强信息；adapter 失败不能影响时间记录。
- 不采集私人内容。

## 当前 Metadata

adapter metadata 可以包含：

- `sourceType`：`website` 或 `desktopApp`
- `identifier`：稳定支持 ID，例如 `site:youtube` 或 `app:vscode`
- `displayName`：UI 友好名称
- `title`：usage record 中已经存在的窗口标题或媒体标题
- `domain`：已知网站的标准化域名
- `iconUrl`：可选远程图标 URL
- `iconPath`：本地 app 路径或 repo/qrc 图标路径
- `iconLabel`：无图标时的短标签 fallback
- `brandColor`：稳定 fallback 色
- `category`：友好分类
- `supportsMediaDetection`：是否适合结合媒体播放信号
- `confidence`：匹配置信度

序列化后的 adapter metadata 不包含完整 URL，避免保存敏感链接。

## 隐私原则

TimeArc 只记录时间轮廓和基础 metadata。

明确禁止：

- 录屏
- 截图
- 读取聊天内容
- 保存网页正文
- 保存用户输入框内容
- 上传用户私密内容
- 默认用 IP 地址作为识别方案

网站识别优先使用 domain、hostname 和 URL pattern。桌面软件识别优先使用 app identifier 和 process name。窗口标题只能作为本地、低置信度的补充线索，而且只使用已经存在于 usage record 中的标题。

## 代码位置

adapter 系统位于：

- `src/services/adapters/adapter_metadata.h`
- `src/services/adapters/activity_adapter_registry.h`
- `src/services/adapters/website_adapter_registry.h`
- `src/services/adapters/desktop_app_adapter_registry.h`
- `src/services/adapters/websites/*.h`
- `src/services/adapters/apps/*.h`

当前实现是 header-only，这样可以先建立基础能力而不触碰冻结的 CMake 文件。如果后续 adapter 变多、逻辑变重，再通过 harness 批准的构建系统变更迁移到 compiled sources。

## 数据流

```text
usage_records.jsonl / usage_current.json
  -> UsageStatManager 解析原始 app/window/audio 记录
  -> adapter registry 根据 app 和网站信号解析 metadata
  -> 原始字段继续保留在 QVariantMap
  -> adapter 字段作为增强字段追加
  -> QML 优先使用 adapter 字段，缺失时回退到原始字段
```

当前暴露给 QML 的增强字段包括：

- `adapterIdentifier`
- `sourceType`
- `adapterDisplayName`
- `adapterCategory`
- `adapterConfidence`
- `domain`
- `siteDomain`
- `iconUrl`
- `iconPath`
- `iconSource`
- `iconLabel`
- `brandColor`
- `supportsMediaDetection`

## 第一批支持

网站：

- YouTube
- Bilibili
- Spotify Web
- QQ Music Web

桌面软件：

- Chrome
- Edge
- VSCode
- Spotify
- WeChat
- QQ

## 高像素图标策略

TimeArc 应优先使用 repo-local 图标或系统可提供的高质量图标：

- 桌面软件：使用可执行文件路径和 Qt app icon image provider 获取原生图标。
- 已知网站：在授权和质量可接受时优先使用 repo-local qrc 图标。
- 后续浏览器扩展支持可以提供 `favIconUrl` 或挑选后的高分辨率图标 URL，但 adapter 层默认不能保存完整敏感 URL。

未知网站宁可使用 `iconLabel` 和 `brandColor` fallback，也不要默认保存低质量或隐私风险不明确的图标来源。
