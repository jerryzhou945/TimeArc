// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation
import Darwin
import Dispatch

final class TimeArcService {
	private struct ActiveSession {
		let appID: String
		let appName: String
		let windowTitle: String
		let iconPath: String
		let start: Int64
	}

	private struct MediaSession {
		let appID: String
		let appName: String
		let mediaTitle: String
		let iconPath: String
		let start: Int64
		var lastSeen: Int64
	}

	private struct ServiceConfig {
		var idleThresholdSeconds: Double = 60.0
		var trackEnabled: Bool = true

		static func load(from url: URL) -> ServiceConfig {
			var config = ServiceConfig()
			guard let data = try? Data(contentsOf: url),
			      let object = try? JSONSerialization.jsonObject(with: data),
			      let json = object as? [String: Any] else {
				return config
			}

			if let trackEnabled = json["track_enabled"] as? Bool {
				config.trackEnabled = trackEnabled
			}

			if let idleThreshold = json["idle_threshold_ms"] as? NSNumber {
				let milliseconds = idleThreshold.doubleValue
				if milliseconds >= 1000.0 && milliseconds <= 86_400_000.0 {
					config.idleThresholdSeconds = milliseconds / 1000.0
				} else {
					fputs("TimeArc macOS service: ignoring invalid idle_threshold_ms\n", stderr)
				}
			}

			return config
		}
	}

	private final class StopFlag {
		private let lock = NSLock()
		private var shouldStop = false

		var requested: Bool {
			lock.lock()
			defer { lock.unlock() }
			return shouldStop
		}

		func request() {
			lock.lock()
			shouldStop = true
			lock.unlock()
		}
	}

	private final class SingleInstanceLock {
		private let descriptor: Int32

		enum AcquisitionResult {
			case acquired(SingleInstanceLock)
			case alreadyRunning
			case failed
		}

		private init(descriptor: Int32) {
			self.descriptor = descriptor
		}

		static func acquire(url: URL) -> AcquisitionResult {
			do {
				try FileManager.default.createDirectory(
					at: url.deletingLastPathComponent(),
					withIntermediateDirectories: true
				)
			} catch {
				fputs("TimeArc macOS service: failed to create usage directory for lock\n", stderr)
				return .failed
			}

			let fd = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
			guard fd >= 0 else {
				fputs("TimeArc macOS service: failed to open lock file\n", stderr)
				return .failed
			}
			guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
				close(fd)
				fputs("TimeArc macOS service: another instance is already running\n", stderr)
				return .alreadyRunning
			}

			_ = ftruncate(fd, 0)
			let pid = "\(getpid())\n"
			pid.withCString { pointer in
				_ = write(fd, pointer, strlen(pointer))
			}
			return .acquired(SingleInstanceLock(descriptor: fd))
		}

		deinit {
			flock(descriptor, LOCK_UN)
			close(descriptor)
		}
	}

	private let platform = "macos"
	private let pollInterval: TimeInterval = 1.0
	private let mediaSilenceGraceSeconds: Int64 = 3
	private let mediaFlushIntervalSeconds: Int64 = 15

	func run() -> Int32 {
		let usageDirectory = usageDirectoryURL()
		do {
			try FileManager.default.createDirectory(at: usageDirectory,
			                                        withIntermediateDirectories: true)
		} catch {
			fputs("TimeArc macOS service: failed to create usage directory\n", stderr)
			return 1
		}

		let instanceLock: SingleInstanceLock
		switch SingleInstanceLock.acquire(
			url: usageDirectory.appendingPathComponent("time-arc-service.lock")
		) {
		case .acquired(let lock):
			instanceLock = lock
		case .alreadyRunning:
			return 0
		case .failed:
			return 1
		}

		let config = ServiceConfig.load(
			from: usageDirectory.appendingPathComponent("usage_config.json")
		)

		if ta_storage_init() != 0 {
			fputs("TimeArc macOS service: failed to initialize storage\n", stderr)
			return 1
		}
		defer {
			ta_clear_current_usage()
			ta_storage_shutdown()
		}

		if !config.trackEnabled {
			ta_clear_current_usage()
			return 0
		}

		var env = AppEnv()
		var session: ActiveSession? = nil
		var mediaSession: MediaSession? = nil
		let stopFlag = StopFlag()
		let signalSources = installSignalHandlers(stopFlag: stopFlag)

		withExtendedLifetime(instanceLock) {
			withExtendedLifetime(signalSources) {
				while !stopFlag.requested {
					let now = Int64(Date().timeIntervalSince1970)
					env.update()

					if env.getIdleSeconds() >= config.idleThresholdSeconds {
						close(session, at: now)
						session = nil
						closeMedia(mediaSession, at: now)
						mediaSession = nil
						ta_clear_current_usage()
						Thread.sleep(forTimeInterval: pollInterval)
						continue
					}

					guard let appID = env.appID, !appID.isEmpty else {
						close(session, at: now)
						session = nil
						pollMedia(type: .null, appID: "", appName: "",
						          fallbackTitle: "", iconPath: "", now: now,
						          session: &mediaSession)
						ta_clear_current_usage()
						Thread.sleep(forTimeInterval: pollInterval)
						continue
					}

					let title = env.windowTitle ?? ""
					let appName = env.getAppName()
					let iconPath = env.getAppIcon()

					pollMedia(type: env.getMediaType(), appID: appID, appName: appName,
					          fallbackTitle: title, iconPath: iconPath, now: now,
					          session: &mediaSession)

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
			}
		}

		let end = Int64(Date().timeIntervalSince1970)
		close(session, at: end)
		closeMedia(mediaSession, at: end)

		return 0
	}

	private func usageDirectoryURL() -> URL {
		FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent(".timearc")
			.appendingPathComponent("usage")
	}

	private func installSignalHandlers(stopFlag: StopFlag) -> [DispatchSourceSignal] {
		signal(SIGTERM, SIG_IGN)
		signal(SIGINT, SIG_IGN)

		return [SIGTERM, SIGINT].map { signalNumber in
			let source = DispatchSource.makeSignalSource(signal: signalNumber,
			                                            queue: DispatchQueue.global())
			source.setEventHandler {
				stopFlag.request()
			}
			source.resume()
			return source
		}
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

	private func pollMedia(type: MediaType, appID: String, appName: String,
	                       fallbackTitle: String, iconPath: String, now: Int64,
	                       session: inout MediaSession?) {
		if type == .null {
			if let current = session,
			   now - current.lastSeen > mediaSilenceGraceSeconds {
				closeMedia(current, at: current.lastSeen + 1)
				session = nil
			}
			return
		}

		let title = mediaTitle(for: type, fallbackTitle: fallbackTitle)
		if let current = session {
			if current.appID == appID && current.mediaTitle == title {
				session?.lastSeen = now
				if now - current.start >= mediaFlushIntervalSeconds {
					closeMedia(session, at: now)
					session = MediaSession(appID: appID, appName: appName,
					                       mediaTitle: title, iconPath: iconPath,
					                       start: now, lastSeen: now)
				}
				return
			}

			closeMedia(current, at: now)
		}

		session = MediaSession(appID: appID, appName: appName, mediaTitle: title,
		                       iconPath: iconPath, start: now, lastSeen: now)
	}

	private func mediaTitle(for type: MediaType, fallbackTitle: String) -> String {
		if !fallbackTitle.isEmpty {
			return fallbackTitle
		}

		switch type {
		case .video:
			return "Video Playback"
		case .audio:
			return "Audio Playback"
		case .null:
			return ""
		}
	}

	private func closeMedia(_ session: MediaSession?, at end: Int64) {
		guard let session = session, end > session.start else {
			return
		}

		platform.withCString { platformPtr in
			"audio".withCString { sourcePtr in
				session.appID.withCString { appIDPtr in
					session.appName.withCString { appNamePtr in
						session.mediaTitle.withCString { titlePtr in
							session.iconPath.withCString { pathPtr in
								_ = ta_write_usage_record_with_source(
									platformPtr, sourcePtr, appIDPtr, appNamePtr,
									titlePtr, pathPtr, session.start,
									UInt64(end - session.start)
								)
							}
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
