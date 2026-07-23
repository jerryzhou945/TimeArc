// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Foundation

@main
struct TimeArcService {
  static func main() async {
    let application = LiveServiceApplication.make()

    let exitCode = await application.run(
      arguments: Array(CommandLine.arguments.dropFirst())
    )

    exit(exitCode.rawValue)
  }
}

private enum LiveServiceApplication {
  static func make() -> ServiceApplication {
    let paths = ServicePaths.live()
    let clock = SystemClock()
    let console = StandardConsole()

    let workspaceHandler = NSWorkspaceHandler()
    let windowHandler = AXWindowHandler()
    let idleHandler = CGEventIdleHandler()
    let assertionHandler = IOPMAssertionHandler()

    let frontmostProbe = MacFrontmostProbe(
      workspace: workspaceHandler,
      windows: windowHandler
    )

    let idleProbe = MacIdleProbe(handler: idleHandler)

    let mediaProbe = MacMediaProbe(
      assertions: assertionHandler,
      workspace: workspaceHandler,
      classifier: MediaAssertionClassifier()
    )

    let journal = CBridgeJournalWriter()

    let coordinator = TrackingCoordinator(
      clock: clock,
      frontmostProbe: frontmostProbe,
      idleProbe: idleProbe,
      mediaProbe: mediaProbe,
      foregroundTracker: ForegroundTracker(),
      mediaTracker: MediaTracker(),
      journal: journal
    )

    let runtime = TrackingRuntime(
      paths: paths,
      configLoader: JSONServiceConfigLoader(paths: paths),
      instanceLock: FileInstanceLock(path: paths.runtimeLock),
      eventSource: MacRuntimeEventSource(),
      coordinator: coordinator,
      journal: journal
    )

    let lifecycle = LaunchAgentController(
      identity: .timeArc,
      paths: paths,
      processMonitor: ServiceProcessMonitor(paths: paths)
    )

    return ServiceApplication(
      parser: CommandParser(),
      runtime: runtime,
      lifecycle: lifecycle,
      statusService: StatusService(
        paths: paths,
        lifecycle: lifecycle
      ),
      doctorService: DoctorService(
        paths: paths,
        lifecycle: lifecycle,
        frontmostProbe: frontmostProbe,
        idleProbe: idleProbe,
        mediaProbe: mediaProbe
      ),
      console: console
    )
  }
}
