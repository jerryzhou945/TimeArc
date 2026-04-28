// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

// Install a QtMessageHandler that mirrors Warning/Critical/Fatal messages
// into a harness log file at <DataLocation>/TimeArc/logs/harness-qt.log.
//
// Intended usage: call installHarnessLogger() exactly once, early in UI
// main(), before any QObject is constructed. The handler delegates to the
// previously-installed handler first (usually Qt's default), so console
// output is preserved. Idempotent: further calls return the same path.
//
// See .harness/ for the consumer: tools/scan_qt_log.py converts each
// log line into an L2 error report.

#ifndef TIMEARC_SRC_SERVICES_HARNESSLOGGER_H
#define TIMEARC_SRC_SERVICES_HARNESSLOGGER_H

#include <QString>

QString installHarnessLogger();

#endif  // TIMEARC_SRC_SERVICES_HARNESSLOGGER_H
