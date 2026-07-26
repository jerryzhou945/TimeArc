## Goal

Explain the currently implemented Windows tracking-service command-line interface without changing application behavior.

## What happened

Reviewed the Windows entry point, lifecycle backend, tracker stop/single-instance mechanics, Qt caller, README, and the explicitly proposed—but unimplemented—future CLI specification.

## Outcome

Documented the current legacy flags, outputs, exit codes, asynchronous behavior, autostart backend, edge cases, and the distinction from the proposed command-oriented interface. No product code changed and no build or runtime execution was needed.
