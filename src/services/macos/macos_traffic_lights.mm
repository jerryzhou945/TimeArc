// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_traffic_lights.h"

#include <QWindow>

#import <AppKit/AppKit.h>

MacTrafficLightsController::MacTrafficLightsController(QObject* parent)
    : QObject(parent) {}

MacTrafficLightsController::~MacTrafficLightsController() {
  destroyNativeViews();
}

void MacTrafficLightsController::attach(QWindow* window) {
  if (window_ == window && nativeWindow_) return;
  destroyNativeViews();
  window_ = window;
  if (!window_) return;

  window_->winId();
  createNativeViews();
}

void MacTrafficLightsController::setVisible(bool visible) {
  visible_ = visible;
  updateWindowState();
}

void MacTrafficLightsController::createNativeViews() {
  if (!window_) return;

  @autoreleasepool {
    NSView* qtView = reinterpret_cast<NSView*>(window_->winId());
    NSWindow* nativeWindow = qtView.window;
    if (!nativeWindow) return;

    // QML creates the window with ExpandedClientAreaHint and
    // NoTitleBarBackgroundHint. AppKit remains responsible only for its real
    // title-bar controls; no post-creation geometry or style mutation belongs
    // here because Qt must establish the expanded client area during creation.
    nativeWindow.titleVisibility = NSWindowTitleHidden;
    nativeWindow.titlebarAppearsTransparent = YES;
    if (@available(macOS 11.0, *)) {
      nativeWindow.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    }
    NSButton* closeButton =
        [nativeWindow standardWindowButton:NSWindowCloseButton];
    NSButton* minimizeButton =
        [nativeWindow standardWindowButton:NSWindowMiniaturizeButton];
    NSButton* zoomButton =
        [nativeWindow standardWindowButton:NSWindowZoomButton];
    if (!closeButton || !minimizeButton || !zoomButton) return;

    nativeWindow_ = nativeWindow;
    closeButton_ = closeButton;
    minimizeButton_ = minimizeButton;
    zoomButton_ = zoomButton;
    updateWindowState();
  }
}

void MacTrafficLightsController::updateWindowState() {
  const BOOL hidden = !visible_;
  if (closeButton_) {
    static_cast<NSButton*>(closeButton_).hidden = hidden;
  }
  if (minimizeButton_) {
    static_cast<NSButton*>(minimizeButton_).hidden = hidden;
  }
  if (zoomButton_) {
    static_cast<NSButton*>(zoomButton_).hidden = hidden;
  }
}

void MacTrafficLightsController::destroyNativeViews() {
  nativeWindow_ = nullptr;
  closeButton_ = nullptr;
  minimizeButton_ = nullptr;
  zoomButton_ = nullptr;
}
