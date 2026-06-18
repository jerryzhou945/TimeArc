// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

final class TimeArcService {
	private struct ActiveSession {
		let appID: String
		let appName: String
		let windowTitle: String
		let iconPath: String
		let start: Int64
	}

	private let platform = "macos"
	private let pollInterval: TimeInterval = 1.0
	private let idleThreshold: Double = 60.0

	func run() -> Int32 {
		if ta_storage_init() != 0 {
			fputs("TimeArc macOS service: failed to initialize storage\n", stderr)
			return 1
		}
		defer {
			ta_clear_current_usage()
			ta_storage_shutdown()
		}

		var env = AppEnv()
		var session: ActiveSession? = nil

		while true {
			let now = Int64(Date().timeIntervalSince1970)
			env.update()

			if env.getIdleSeconds() >= idleThreshold {
				close(session, at: now)
				session = nil
				ta_clear_current_usage()
				Thread.sleep(forTimeInterval: pollInterval)
				continue
			}

			guard let appID = env.appID, !appID.isEmpty else {
				Thread.sleep(forTimeInterval: pollInterval)
				continue
			}

			let title = env.windowTitle ?? ""
			let appName = env.getAppName()
			let iconPath = env.getAppIcon()

			if let current = session {
				if current.appID != appID || current.windowTitle != title {
					close(current, at: now)
					session = ActiveSession(appID: appID, appName: appName,
					                        windowTitle: title, iconPath: iconPath,
					                        start: now)
				}
			} else {
				session = ActiveSession(appID: appID, appName: appName,
				                        windowTitle: title, iconPath: iconPath,
				                        start: now)
			}

			if let current = session {
				writeCurrent(current, at: now)
			}

			Thread.sleep(forTimeInterval: pollInterval)
		}

		return 0
	}

	private func close(_ session: ActiveSession?, at end: Int64) {
		guard let session = session, end > session.start else {
			return
		}
		withCStringArgs(session) { platformPtr, appIDPtr, appNamePtr, titlePtr, pathPtr in
			_ = ta_write_usage_record(platformPtr, appIDPtr, appNamePtr, titlePtr,
			                          pathPtr, session.start,
			                          UInt64(end - session.start))
		}
	}

	private func writeCurrent(_ session: ActiveSession, at now: Int64) {
		guard now >= session.start else {
			return
		}
		withCStringArgs(session) { platformPtr, appIDPtr, appNamePtr, titlePtr, pathPtr in
			_ = ta_write_current_usage(platformPtr, appIDPtr, appNamePtr, titlePtr,
			                           pathPtr, session.start,
			                           UInt64(now - session.start), now)
		}
	}

	private func withCStringArgs(
		_ session: ActiveSession,
		_ body: (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>,
		         UnsafePointer<CChar>, UnsafePointer<CChar>) -> Void
	) {
		platform.withCString { platformPtr in
			session.appID.withCString { appIDPtr in
				session.appName.withCString { appNamePtr in
					session.windowTitle.withCString { titlePtr in
						session.iconPath.withCString { pathPtr in
							body(platformPtr, appIDPtr, appNamePtr, titlePtr, pathPtr)
						}
					}
				}
			}
		}
	}
}

@main
struct TimeArcServiceMain {
	static func main() {
		autoreleasepool {
			let exitCode = TimeArcService().run()
			exit(exitCode)
		}
	}
}
