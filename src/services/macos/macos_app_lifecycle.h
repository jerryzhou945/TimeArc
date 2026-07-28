// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QPointer>

class QWindow;

// macOS window-lifecycle adapter.
//
// On macOS the red traffic light closes the *window*; the process stays alive
// in the Dock and menu bar, and clicking the Dock icon reopens the window.
// This class owns the two AppKit pieces that convention needs: a forwarding
// NSApplication delegate proxy that answers the reopen request, and the
// full-screen exit sequencing that must run before a full-screen window may
// close.
//
// UI layer only (rules/01 §1): AppKit + Qt headers, no service-layer include.
class MacAppLifecycle final : public QObject {
  Q_OBJECT

 public:
  explicit MacAppLifecycle(QObject* parent = nullptr);
  ~MacAppLifecycle() override;

  void attach(QWindow* window);

  // Returns true when the window may close right now. Returns false when the
  // close was deferred: the window is full screen, so the native full-screen
  // exit is started and the close is re-issued once AppKit reports it done.
  Q_INVOKABLE bool beginWindowClose();

  // Brings the window back — used by the Dock reopen handler and by the
  // status-item menu. Recreates the platform window if it was closed.
  Q_INVOKABLE void restoreWindow();

 private:
  void installReopenHandler();
  void removeReopenHandler();

  QPointer<QWindow> window_;
  void* reopenDelegate_ = nullptr;
  void* fullScreenCloseObserver_ = nullptr;
};
