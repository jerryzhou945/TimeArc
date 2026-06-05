# Error Report - build-env-missing-mingw-path

## Metadata

- Level: **L3**
- Track: **B**
- Topic: build-env-missing-mingw-path
- Recorded: 2026-06-04T14:18:27Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

build.py 失败但日志/错误报告无任何 g++ 诊断：根因是本会话 PowerShell 的 PATH 缺少 mingw/Qt bin（C:\Qt\Tools\mingw1310_64\bin;C:\Qt\6.11.1\mingw_64\bin），cc1plus 及运行时 DLL 加载失败、g++ 静默退出 1，对每个 TU 报 FAILED 但零输出（误导成代码错误）。设好 PATH 后 build.py 成功，证明 MemoOverlay/MemoDotTexture/Shell 改动可编译。预防：build.py 应在调用 cmake 前显式把 Qt mingw bin 前置进 PATH（或缺失时报 DRIFT），并把 g++ stderr 一并 tee 进 build-log。早先用 2>&1 探查也会把原生 stderr 包成 ErrorRecord 吞掉，应避免。

## 2. Evidence

```
(paste relevant log excerpt here)
```

## 3. Root cause

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description:
- Commit:

## 5. Prevention

Concrete harness upgrade, or 'one-off, no harness change'.

## 6. Lessons for agents (L3)

- Wrong assumption:
- Earlier signal available:
- Rule file to update:
