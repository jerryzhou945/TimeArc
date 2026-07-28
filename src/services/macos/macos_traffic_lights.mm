// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_traffic_lights.h"

#include <QWindow>

#import <AppKit/AppKit.h>

@interface TimeArcFullScreenExitObserver : NSObject {
 @private
  QPointer<QWindow> qtWindow_;
  NSWindow* nativeWindow_;
  BOOL observing_;
}

- (BOOL)isObserving;
- (void)beginObservingWindow:(NSWindow*)nativeWindow
                    qtWindow:(QWindow*)qtWindow;
- (void)cancel;

@end

@implementation TimeArcFullScreenExitObserver

- (BOOL)isObserving {
  return observing_;
}

- (void)beginObservingWindow:(NSWindow*)nativeWindow
                    qtWindow:(QWindow*)qtWindow {
  [self cancel];
  nativeWindow_ = nativeWindow;
  qtWindow_ = qtWindow;
  observing_ = YES;
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(windowDidExitFullScreen:)
             name:NSWindowDidExitFullScreenNotification
           object:nativeWindow];
}

- (void)windowDidExitFullScreen:(NSNotification*)notification {
  if (!observing_ || notification.object != nativeWindow_) return;
  const QPointer<QWindow> qtWindow = qtWindow_;
  [self cancel];
  if (qtWindow) qtWindow->hide();
}

- (void)cancel {
  if (observing_) {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  }
  observing_ = NO;
  nativeWindow_ = nil;
  qtWindow_.clear();
}

- (void)dealloc {
  [self cancel];
  [super dealloc];
}

@end

MacTrafficLightsController::MacTrafficLightsController(QObject* parent)
    : QObject(parent) {
  fullScreenExitObserver_ = [[TimeArcFullScreenExitObserver alloc] init];
}

MacTrafficLightsController::~MacTrafficLightsController() {
  destroyNativeViews();
  [static_cast<TimeArcFullScreenExitObserver*>(fullScreenExitObserver_) release];
  fullScreenExitObserver_ = nullptr;
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

void MacTrafficLightsController::hideToTray() {
  if (!window_) return;

  @autoreleasepool {
    NSWindow* nativeWindow = static_cast<NSWindow*>(nativeWindow_);
    if (!nativeWindow ||
        !(nativeWindow.styleMask & NSWindowStyleMaskFullScreen)) {
      window_->hide();
      return;
    }

    auto* observer =
        static_cast<TimeArcFullScreenExitObserver*>(fullScreenExitObserver_);
    if ([observer isObserving]) return;

    [observer beginObservingWindow:nativeWindow qtWindow:window_];
    [nativeWindow toggleFullScreen:nil];
  }
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
  [static_cast<TimeArcFullScreenExitObserver*>(fullScreenExitObserver_) cancel];
  nativeWindow_ = nullptr;
  closeButton_ = nullptr;
  minimizeButton_ = nullptr;
  zoomButton_ = nullptr;
}
