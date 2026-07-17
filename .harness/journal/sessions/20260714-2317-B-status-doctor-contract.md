# Status and doctor command contract

**Goal.** Define distinct output and behavior contracts for the proposed `status` and `doctor` service commands without implementing them.

**Service side.** `status` emits a fast stable snapshot of observable collector, configured tracking, and collector-autostart facts; `doctor` runs bounded read-only checks and emits stable check IDs, results, summaries, and hints.

**UI side.** The UI consumes only `status --json`; `doctor` is intended for people and support tooling and is not part of routine UI polling.

**Scope.** Design response and this session record only. `src/service/CLI.md` is absent, so it was not recreated; no source, rules, README, schema, CMake, build, or runtime behavior changed.

**Outcome.** Produced a concrete functional split, text formats, JSON envelopes, check vocabulary, option set, and exit-code policy. Implementation and verification remain future work.
