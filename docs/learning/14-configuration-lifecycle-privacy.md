# 14 · 配置、生命周期、隐私与失败处理 / Configuration, Lifecycle, Privacy, and Failure Handling

## 本章目标 / Learning goals

理解控制文件如何安全更新、服务怎样启动停止、敏感信息怎样被限制，以及系统如何面对失败。

## 1. `service_config.json` v1

配置文件位于平台 config 目录，而不是数据库目录。核心结构：

```json
{
  "schema_version": 1,
  "tracking": {
    "enabled": true,
    "sampling": {
      "poll_period_sec": 1,
      "min_session_sec": 1,
      "max_session_sec": 300
    },
    "frontmost": {
      "enabled": true,
      "idle_threshold_sec": 60,
      "video_overrides_idle": true
    },
    "media": { "enabled": true }
  },
  "database": { "dir": null }
}
```

当前 Windows service reader 已接 `tracking.enabled` 与 `tracking.frontmost.idle_threshold_sec`；其他高级叶子在公开 UI 前仍需完全接线。配置 schema 表达设计目标不等于所有字段已生效。

## 2. 原子 read-modify-write

GUI 修改 idle 或 database directory 时，必须保留文件里的其他 key：读完整 JSON → 只改目标 leaf → 写临时文件 → 原子替换。

如果两个功能各自重写整份文件，就会互相抹掉设置。这是 configuration ownership 的典型问题。

## 3. 缺失和无效配置

服务以编译期安全默认值初始化，再覆盖通过类型和范围校验的字段。配置缺失或损坏不应让 tracker 写出不确定数据。

例如 idle seconds 必须是 0 到 86400 的整数；0 是合法语义，不能与“字段不存在”混淆。

## 4. Windows 生命周期

GUI 通过 service CLI：

- `--start` 幂等启动当前用户 tracker。
- `--stop` 设置停止 event，让 tracker flush 后退出。
- `--status --json` 提供结构化运行态。
- `--install/--uninstall` 管理当前用户自启语义。

“是否登录自启”和“此刻是否正在采集”是两个不同状态。

首次成功启动可以默认启用当前用户登录自启，但用户关闭后留下 decision marker，后续启动不能擅自恢复。

## 5. macOS 生命周期

服务自己拥有 LaunchAgent 注册、enable/disable 和 start/stop。GUI 只能调用 CLI；它不直接安装 launch agent。服务实例间控制 socket 会验证同 executable identity。

## 6. 隐私边界

- 不采聊天正文、截图/OCR、原始音频。
- 不默认采浏览历史或完整 URL。
- 窗口/媒体标题可能敏感，只作为本地受限元数据。
- 分享先匿名化，隐藏原始标题、联系人、URL 和包名。
- 原始 `timearc_service.db` 不应作为普通测试反馈上传。

## 7. 失败分类

| 失败 | 正确反应 |
| --- | --- |
| 本轮前台探针失败 | 不制造一个虚假 app |
| 音频 probe 失败 | 不把“没结果”当作“确认停止” |
| app upsert 失败 | 不继续插入孤立 session |
| 配置字段无效 | 记录诊断并保留安全默认值 |
| QML 创建失败 | GUI 退出并留下日志 |
| 服务已运行 | 新实例正常退出，保持幂等 |

## 8. 可观察性 / Observability

Qt warning/critical/fatal 被 tee 到 Harness 日志；tracker 可用 `TIMEARC_TRACKER_DIAGNOSTICS` 输出受控诊断；CLI status 支持机器可读 JSON。诊断不能泄露超过必要范围的敏感内容。

## 面试表达 / Interview answer

“Configuration is versioned and updated atomically with key preservation. Lifecycle commands are idempotent, shutdown is cooperative so open sessions can flush, and invalid observations fail closed instead of generating fabricated history.”

## 源码入口 / Source entry points

- `src/service/windows/service_config.c`
- `src/service/shared/database_path.c`
- `src/services/database_manager.cpp`
- `src/services/settings_repository.cpp`
- `src/service/windows/service/win_service.c`
- `src/service/macos/Autostart/` and `Control/`

## 复习题 / Review

1. 为什么配置更新必须保留未知 key？——多个设置共享一个文件，版本也可能增加新字段。
2. stop 为什么不硬杀？——需要 flush 开放会话并释放数据库。
3. probe failure 与 confirmed absence 区别？——前者信息未知，后者是可靠的状态变化。
