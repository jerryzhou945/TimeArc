# Doctor command design

**Goal.** Define the checks, output contract, severity model, and privacy boundaries for the proposed `time-arc-service doctor` command without implementing it.

**Service side.** `doctor` runs bounded read-only checks across executable/configuration, runtime control, autostart, platform permissions and probes, storage, and packaging; it emits stable check IDs and never samples usage content or repairs state.

**UI side.** Routine UI polling continues to consume `status`; `doctor` is a user/support tool whose JSON may be attached to support reports but is not a UI state API.

**Scope.** Design response and this session record only. No service source, README, rules, schema, CMake, build, or runtime behavior changed.

**Outcome.** Specified default and deep check sets, result schema, aggregation and exit rules, redaction policy, timeout behavior, and platform applicability. Implementation and validation remain future work.
