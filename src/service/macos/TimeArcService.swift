// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

final class TimeArcService {
	func run() -> Int32 {
		// Keep service process alive until tracker loop is introduced.
		RunLoop.current.run()
		return 0
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
