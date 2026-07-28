// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_app_lifecycle.h"

#include <QWindow>

#import <AppKit/AppKit.h>

// Re-issues a deferred close once AppKit finishes animating out of full
// screen. Closing (or hiding) a window while it still owns a full-screen Space
// leaves a black screen behind — see
// journal/errors/20260728-150542-C-macos-fullscreen-close-black-screen.md.
@interface TimeArcFullScreenCloseObserver : NSObject {
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

@implementation TimeArcFullScreenCloseObserver

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
  // The window is windowed again, so the close QML rejected a moment ago is
  // now safe. beginWindowClose() will accept it on this second pass.
  if (qtWindow) qtWindow->close();
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

// Qt installs its own NSApplication delegate and does not reopen hidden or
// closed windows on a Dock click. Rather than replace Qt's delegate, this
// proxy takes the delegate slot, handles the one message we care about, and
// forwards everything else to Qt's original delegate.
@interface TimeArcAppReopenDelegate : NSObject <NSApplicationDelegate> {
 @private
  MacAppLifecycle* lifecycle_;
  id<NSApplicationDelegate> previousDelegate_;
  BOOL installed_;
}

- (instancetype)initWithLifecycle:(MacAppLifecycle*)lifecycle;
- (void)install;
- (void)uninstall;

@end

@implementation TimeArcAppReopenDelegate

- (instancetype)initWithLifecycle:(MacAppLifecycle*)lifecycle {
  self = [super init];
  if (self) {
    lifecycle_ = lifecycle;
  }
  return self;
}

- (void)install {
  if (installed_ || !NSApp) return;
  // Retained so the slot stays valid even if Qt drops its own reference while
  // this proxy is still forwarding to it.
  previousDelegate_ = [[NSApp delegate] retain];
  [NSApp setDelegate:self];
  installed_ = YES;
}

- (void)uninstall {
  if (!installed_) return;
  if (NSApp && [NSApp delegate] == self) {
    [NSApp setDelegate:previousDelegate_];
  }
  [previousDelegate_ release];
  previousDelegate_ = nil;
  installed_ = NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication*)application
                    hasVisibleWindows:(BOOL)hasVisibleWindows {
  BOOL handled = YES;
  if ([previousDelegate_ respondsToSelector:_cmd]) {
    handled = [previousDelegate_ applicationShouldHandleReopen:application
                                            hasVisibleWindows:hasVisibleWindows];
  }
  if (!hasVisibleWindows && lifecycle_) {
    lifecycle_->restoreWindow();
  }
  return handled;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  if ([super respondsToSelector:aSelector]) return YES;
  return [previousDelegate_ respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
  if ([previousDelegate_ respondsToSelector:aSelector]) return previousDelegate_;
  return [super forwardingTargetForSelector:aSelector];
}

- (void)dealloc {
  [self uninstall];
  [super dealloc];
}

@end

namespace {

NSWindow* nativeWindowFor(QWindow* window) {
  if (!window || !window->handle()) return nil;
  NSView* view = reinterpret_cast<NSView*>(window->winId());
  return view.window;
}

}  // namespace

MacAppLifecycle::MacAppLifecycle(QObject* parent) : QObject(parent) {
  fullScreenCloseObserver_ = [[TimeArcFullScreenCloseObserver alloc] init];
  reopenDelegate_ = [[TimeArcAppReopenDelegate alloc] initWithLifecycle:this];
}

MacAppLifecycle::~MacAppLifecycle() {
  removeReopenHandler();
  [static_cast<TimeArcAppReopenDelegate*>(reopenDelegate_) release];
  reopenDelegate_ = nullptr;
  [static_cast<TimeArcFullScreenCloseObserver*>(fullScreenCloseObserver_)
      cancel];
  [static_cast<TimeArcFullScreenCloseObserver*>(fullScreenCloseObserver_)
      release];
  fullScreenCloseObserver_ = nullptr;
}

void MacAppLifecycle::attach(QWindow* window) {
  window_ = window;
  if (!window_) {
    removeReopenHandler();
    return;
  }
  installReopenHandler();
}

bool MacAppLifecycle::beginWindowClose() {
  if (!window_) return true;

  @autoreleasepool {
    NSWindow* nativeWindow = nativeWindowFor(window_);
    if (!nativeWindow ||
        !(nativeWindow.styleMask & NSWindowStyleMaskFullScreen)) {
      return true;
    }

    auto* observer =
        static_cast<TimeArcFullScreenCloseObserver*>(fullScreenCloseObserver_);
    // A second red-button click during the exit animation must not restart it.
    if ([observer isObserving]) return false;

    [observer beginObservingWindow:nativeWindow qtWindow:window_];
    [nativeWindow toggleFullScreen:nil];
    return false;
  }
}

void MacAppLifecycle::restoreWindow() {
  if (!window_) return;

  if (window_->visibility() == QWindow::Minimized) {
    window_->showNormal();
  } else {
    // After a close the platform window is gone; show() recreates it.
    window_->show();
  }
  window_->raise();
  window_->requestActivate();
}

void MacAppLifecycle::installReopenHandler() {
  @autoreleasepool {
    [static_cast<TimeArcAppReopenDelegate*>(reopenDelegate_) install];
  }
}

void MacAppLifecycle::removeReopenHandler() {
  @autoreleasepool {
    [static_cast<TimeArcAppReopenDelegate*>(reopenDelegate_) uninstall];
  }
}
