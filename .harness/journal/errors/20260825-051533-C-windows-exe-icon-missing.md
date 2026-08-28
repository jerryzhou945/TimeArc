# Error Report - windows-exe-icon-missing

## Metadata

- Level: **L2**
- Track: **C**
- Topic: windows-exe-icon-missing
- Recorded: 2026-08-25T05:15:33Z
- Session: .harness/journal/sessions/20260825-1313-C-windows-exe-icon.md
- Platform: windows
- Tooling: MinGW `objdump`, PowerShell shortcut inspection

## 1. What happened

Installed TimeArc.exe has no Windows PE icon resource, so Explorer shortcuts and the taskbar can show the generic application icon

## 2. Evidence

```
Installed TimeArc.exe sections: .text, .data, .rdata, .qtversion, .pdata,
.xdata, .bss, .edata, .idata, .CRT, .tls, .reloc, debug sections.
No .rsrc section is present.

src/main.cpp sets a QRC SVG with QGuiApplication::setWindowIcon at runtime.
No Windows application .ico/.rc exists in the build inputs.
```

## 3. Root cause

- Immediate cause: Windows falls back to its generic executable icon because `TimeArc.exe` contains no native icon resource.
- Underlying cause: the project supplies runtime SVG, Android PNG, and macOS ICNS assets but never converts/embeds a multi-resolution Windows ICO through an RC source.
- Why the harness/checklists did not prevent it: release verification checked linkage and archive integrity, not the executable's Windows icon resource.

## 4. Fix

- Files changed: `CMakeLists.txt`, `resources/bundle/windows/TimeArc.{ico,rc}`, `tools/generate-windows-icon.py`, `tests/windows_executable_icon_test.py`
- Short description: embed a seven-size native Windows icon and verify the built PE icon resource types.
- Commit: pending

## 5. Prevention

Added a Windows PE-resource check that requires both icon and group-icon resource types in `TimeArc.exe`.
