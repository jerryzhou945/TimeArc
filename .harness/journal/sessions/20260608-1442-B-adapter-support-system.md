# Adapter 支持系统

## 目标

为 TimeArc 建立网站和桌面软件 adapter 基础，让高频网站和软件可以被归一化成更友好的 metadata，同时保持原始使用记录采集逻辑不变。

## 服务侧

后台服务继续只写出现有 foreground/audio 记录：平台、来源、app id/name、窗口或媒体标题、路径、开始时间和持续时间。本次不修改 service schema，不读取网页正文，不截图，不用 IP 识别，不读取浏览器历史。

## UI 侧

UI 的读取和聚合层会把每条原始记录交给本地 adapter registry 解析。adapter metadata 只作为增强信息：展示名称、分类、来源类型、图标或 fallback、域名和置信度。如果 adapter 没命中或失败，仍然回退到原有 app/title 显示逻辑。

## 规则文件

本次主要触及 UI manager、QML 和 docs，相关规则是 architecture、data-contract 和 UI conventions。冻结的磁盘契约文件没有被修改。
