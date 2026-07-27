// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_launch_agent.h"

#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>

namespace {

QString fromNSString(NSString* value) {
  if (!value) return {};
  return QString::fromUtf8(value.UTF8String);
}

MacLaunchAgentRegistration failure(NSString* message) {
  return {
      false,
      false,
      fromNSString(message),
  };
}

MacLaunchAgentRegistration failure(NSError* error,
                                   SMAppServiceStatus initialStatus) {
  if (!error) {
    return failure([NSString
        stringWithFormat:@"SMAppService registration failed after status %ld.",
                         static_cast<long>(initialStatus)]);
  }

  NSString* reason = error.localizedFailureReason;
  NSString* message = [NSString
      stringWithFormat:@"%@ (domain=%@, code=%ld, initialStatus=%ld)%@%@",
                       error.localizedDescription,
                       error.domain,
                       static_cast<long>(error.code),
                       static_cast<long>(initialStatus),
                       reason ? @": " : @"",
                       reason ?: @""];
  return failure(message);
}

}  // namespace

MacLaunchAgentRegistration registerMacLaunchAgent() {
  @autoreleasepool {
    if (@available(macOS 13.0, *)) {
      SMAppService* service = [SMAppService
          agentServiceWithPlistName:@"com.timearc.service.plist"];
      const SMAppServiceStatus initialStatus = service.status;
      switch (initialStatus) {
        case SMAppServiceStatusEnabled:
          return {true, false, {}};
        case SMAppServiceStatusRequiresApproval:
          return {true, true, {}};
        case SMAppServiceStatusNotFound:
        case SMAppServiceStatusNotRegistered:
          break;
      }

      NSError* error = nil;
      if (![service registerAndReturnError:&error]) {
        return failure(error, initialStatus);
      }
      return {
          true,
          service.status == SMAppServiceStatusRequiresApproval,
          {},
      };
    }
    return failure(@"SMAppService requires macOS 13 or newer.");
  }
}
