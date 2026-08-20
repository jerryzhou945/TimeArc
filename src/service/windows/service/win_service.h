#ifndef TIMEARC_WIN_SERVICE_H
#define TIMEARC_WIN_SERVICE_H

// Windows lifecycle verbs for user-session logon autostart.
//
// Collection must run as the interactive user. Route A uses a logon task,
// falling back to HKCU Run, to avoid Session 0 and profile mismatches.
//
// main.c dispatches verbs; no arguments retains the compatible tracker path.

// Register logon autostart, preferring a task over HKCU Run.
int timearc_win_service_install(void);

// Remove task and Run entries; missing entries count as clean.
int timearc_win_service_uninstall(void);

// Start an idempotent tracker in the current user session.
int timearc_win_service_start(void);

// Request a clean tracker shutdown through the Local\TimeArcStop event.
int timearc_win_service_stop(void);

// Print machine-readable autostart and running state. Return 0 if registered.
int timearc_win_service_status(void);

// Print the cross-platform status payload documented in src/service/README.md.
int timearc_win_service_status_json(void);

// Deferred Route B SCM service entry point.
int timearc_win_service_run(void);

#endif
