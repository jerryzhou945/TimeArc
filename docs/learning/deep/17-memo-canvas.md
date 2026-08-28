# 17｜Memo 黑板：Canvas、对象层、持久化与撤销

> 本章目标：通过 TimeArc 最复杂的 QML 交互之一，学习图层分离、手势状态、序列化、debounce 和 undo/redo。
> Source map: `MemoOverlay.qml`, `MemoInkCanvas.qml`, `StickyNote.qml`, `TextLayer.qml`.

## 1. Memo 不是一个普通表单

它同时包含：

- 位图笔迹；
- 橡皮擦；
- 便签和文字对象；
- 多页文档；
- 选择、复制、移动、缩放；
- 撤销/重做；
- 自动保存；
- 与番茄钟、待办投影联动。

这种功能必须先建立数据模型和图层，不适合把所有事件写进一个 MouseArea。

## 2. 三层渲染模型

```text
底层 Background
  暗色背景、点阵、模糊快照
中层 Ink Canvas
  pen / eraser bitmap
上层 Object Layer
  sticky notes / text / selection handles
```

橡皮只使用 Canvas 的 `destination-out` 清除笔迹，不会擦掉独立的点阵和便签。这是图层分离带来的自然正确性。

## 3. Canvas 如何画一段线

`MemoInkCanvas.qml`：

```qml
ctx.globalCompositeOperation = tool === "eraser"
        ? "destination-out" : "source-over"
ctx.lineWidth = tool === "eraser" ? eraserWidth : penWidth
ctx.beginPath()
ctx.moveTo(lastX, lastY)
ctx.lineTo(x, y)
ctx.stroke()
```

- `source-over`：新颜色盖在旧像素上；
- `destination-out`：用新形状挖掉已有 alpha；
- `round` cap/join：线条转角更自然；
- `lastX/lastY`：连接上一个 pointer position。

## 4. 为什么 Canvas 使用 Image + Threaded

```qml
renderTarget: Canvas.Image
renderStrategy: Canvas.Threaded
```

Image target 便于 `toDataURL()` 做持久化；Threaded 尽量把绘制放在 render thread，减少 GUI thread 卡顿。

但 `toDataURL` 仍可能产生大 Base64 string，频繁调用会消耗内存和 CPU，所以保存使用 debounce。

## 5. tool 决定 hit testing

```qml
MouseArea {
    enabled: ink.tool === "pen" || ink.tool === "eraser"
}
```

选择 note/text 工具时，Canvas MouseArea 禁用，让点击穿透到对象层。若只是把 opacity 设为 0，它仍可能抢事件。

这叫 **input ownership（输入所有权）**。

## 6. 多页文档模型

```qml
property var pagesData: [
  { label: "Page 1", objects: [], canvas: "" }
]
property int currentPage: 0
```

每页拥有对象数组和 Canvas PNG data URL。切页顺序：

1. `_writeCurrent()` 把 live objects/ink 写回旧页；
2. 改 `currentPage`；
3. `_applyPage()` 把新页装入 live model；
4. 清选择；
5. schedule save；
6. reset page-local history。

如果先改 index 再保存，就会把旧页面内容写进新页面。

## 7. 对象为什么要 stable id

旧便签可能没有 id，加载时 `_backfillNoteIds()` 补齐。stable id 支持：

- 待办投影定位原便签；
- 更新时不依赖数组 index；
- 页面重排后 identity 不变；
- 将来同步/冲突解决有基础。

数组位置是 presentation order，不应充当永久 identity。

## 8. 序列化

`saveDoc()` 把纯数据写入 SettingsRepository：

```qml
JSON.stringify({
  v: 2,
  pages: pagesData,
  current: currentPage,
  pen: { pw, ew, color }
})
```

为什么只序列化纯对象？QML Item、Canvas context、signal connection 不能直接 JSON 化。必须把 runtime view state 映射成稳定 document model。

## 9. 兼容旧 document

`loadDoc()` 如果没有 `pages`，就把旧 v1 单页结构包装为一页。这叫 **read-time migration（读取时迁移）**。

优点是旧用户内容不丢；后续保存自然写成 v2。真实产品中还应考虑备份、尺寸上限与损坏恢复。

## 10. debounce 与强制 flush

每一笔都立即序列化整张 Canvas 会卡顿。`scheduleSave()` 重启 600ms 单次 Timer：连续绘制期间推迟，停下后保存。

但 debounce 带来风险：用户在 600ms 内关窗。root window 的 close handler 会调用 `flushPendingSave()`，停止 timer 并立即保存。

这是经典组合：

```text
平时 debounce 保护性能
生命周期边界 flush 保护数据
```

## 11. undo/redo 快照

每个历史帧保存：

```text
objects snapshot + canvas data URL
```

`_histAt` 指当前帧。新编辑发生在 undo 之后时，redo tail 会被删除；超过 `_histMax` 删除最旧帧。

这是 **linear history（线性历史）**，简单可靠，但大 Canvas 快照会占内存。更高级实现可使用 command pattern、stroke log 或增量 tiles。

## 12. 异步图像加载陷阱

Canvas `loadImage()` 完成后触发 `onImageLoaded`。代码必须区分：

- 当前页面待恢复图片 `_pendingUrl`；
- 复制/移动待贴图 `_pendingStamps`。

用完后清空 `_pendingUrl`，否则以后任何 image loaded event 都可能把旧页重新画回来，形成 ghost ink。

这说明异步 callback 必须带明确 **request ownership（请求归属）**。

## 13. 面试表达

> The memo feature separates background, bitmap ink, and object layers so tools have clear rendering and input ownership. Pages serialize a pure document model containing object records and a canvas snapshot. Autosave is debounced for performance but forcibly flushed at window-lifecycle boundaries. Undo and redo use bounded page-local snapshots, and asynchronous image restoration keeps explicit pending-request state to avoid ghost redraws.

## 14. 本章练习

1. 为什么橡皮不会擦掉便签？
2. 切页时 `_writeCurrent()` 为什么必须在改 index 前执行？
3. debounce 解决什么问题，又产生什么风险？
4. 如果要把 snapshot undo 改成 command pattern，需要定义哪些 command？

下一章：[测试、构建与发布](18-testing-build-release.md)
