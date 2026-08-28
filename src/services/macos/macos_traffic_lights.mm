// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_traffic_lights.h"

#include <QGuiApplication>
#include <QWindow>

#import <AppKit/AppKit.h>

namespace {

// QWindow::winId() returns an opaque WId whose type belongs to whichever QPA
// plugin is loaded: it is a real NSView* only under "cocoa". Under offscreen /
// minimal it is a small fabricated counter, so reinterpret_cast-ing it and
// sending an Objective-C message dereferences a non-pointer -- objc_msgSend
// faults reading the isa word from address 0x1. Checking the plugin is the only
// way to know the cast is legal; a null-check on the *result* runs too late,
// because the fault happens while computing it.
// See journal/errors/20260828-071233-C-offscreen-teardown-segfault.md.
bool windowsAreNativeCocoa() {
  return QGuiApplication::platformName() == QLatin1String("cocoa");
}

}  // namespace

MacTrafficLightsController::MacTrafficLightsController(QObject* parent)
    : QObject(parent) {}

MacTrafficLightsController::~MacTrafficLightsController() {
  QObject::disconnect(visibilityConnection_);
  destroyNativeViews();
}

void MacTrafficLightsController::attach(QWindow* window) {
  if (window_ == window && nativeWindow_) return;

  QObject::disconnect(visibilityConnection_);
  destroyNativeViews();
  window_ = window;
  if (!window_) return;

  // On macOS the red button closes the window, so Qt destroys the platform
  // window and builds a fresh NSWindow when the app is reopened from the Dock.
  // The cached AppKit buttons must follow that lifetime or they dangle.
  visibilityConnection_ = QObject::connect(
      window_, &QWindow::visibleChanged, this, [this](bool visible) {
        if (visible) {
          createNativeViews();
        } else {
          destroyNativeViews();
        }
      });

  window_->winId();
  createNativeViews();
}

void MacTrafficLightsController::setVisible(bool visible) {
  visible_ = visible;
  updateWindowState();
}

void MacTrafficLightsController::performTitlebarDoubleClickAction() {
  @autoreleasepool {
    NSWindow* nativeWindow = static_cast<NSWindow*>(nativeWindow_);
    if (!nativeWindow ||
        (nativeWindow.styleMask & NSWindowStyleMaskFullScreen) != 0) {
      return;
    }

    NSString* action = [[NSUserDefaults standardUserDefaults]
        stringForKey:@"AppleActionOnDoubleClick"];
    if (!action) {
      action = @"Maximize";
    }

    if ([action caseInsensitiveCompare:@"Minimize"] == NSOrderedSame) {
      if (nativeWindow.miniaturizable) {
        [nativeWindow performMiniaturize:nil];
      }
      return;
    }

    if ([action caseInsensitiveCompare:@"Fill"] == NSOrderedSame) {
      if (window_) {
        window_->showMaximized();
      }
      return;
    }

    if ([action caseInsensitiveCompare:@"Maximize"] == NSOrderedSame ||
        [action caseInsensitiveCompare:@"Zoom"] == NSOrderedSame) {
      if (nativeWindow.zoomable) {
        [nativeWindow performZoom:nil];
      }
    }
  }
}

void MacTrafficLightsController::createNativeViews() {
  if (!window_) return;
  // Without this the app could not start headless at all -- the crash was in
  // main(), before the event loop, on every non-cocoa plugin.
  if (!windowsAreNativeCocoa()) return;

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
