# Error Report - cairosvg-unavailable

## Metadata

- Level: **L3**
- Track: **C**
- Topic: cairosvg-unavailable
- Recorded: 2026-08-25T05:21:12Z
- Session: .harness/journal/sessions/20260825-1317-C-windows-native-icon.md
- Platform: windows
- Tooling: bundled workspace Python

## 1. What happened

Bundled workspace Python has Pillow but not CairoSVG, so the planned SVG raster conversion dependency is unavailable

## 2. Evidence

```
ModuleNotFoundError: No module named 'cairosvg'
```

## 3. Root cause

- Immediate cause: CairoSVG is not installed in the bundled Python runtime.
- Underlying cause: the initial conversion approach assumed an optional image library.
- Why the harness/checklists did not prevent it: image tooling availability is environment-specific.

## 4. Fix

- Files changed: `tools/generate-windows-icon.py`
- Short description: generate the simple SVG geometry with available Pillow only; no new project dependency.
- Commit:

## 5. Prevention

One-off environment discovery; the committed generator now declares and uses Pillow only.

## 6. Lessons for agents (L3)

- Wrong assumption: CairoSVG was part of the bundled workspace image stack.
- Earlier signal available: an import probe before implementation exposed the missing module.
- Rule file to update: none.
