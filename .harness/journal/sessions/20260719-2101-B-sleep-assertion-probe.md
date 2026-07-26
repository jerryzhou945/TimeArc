# Sleep Assertion Probe

## Goal

Implement the macOS sleep-assertion classification and per-process priority rules inside `SleepAssertionProbe.getSleepAssertions()`.

## Plan

Service side: Read active IOKit power assertions, ignore unsupported types, and emit at most one `SleepAssertionType` per PID with `system` preferred over `foreground`, then `background`.

UI side: No UI or disk-contract behavior changes; existing service consumers continue receiving the probe's in-memory PID-to-assertion mapping.

Expected product file: `src/service/macos/Tracking/SleepAssertionProbe.swift`. Do not touch CMake, shared contracts, UI, schema, or other tracking sources. Rules 01 and 02 remain accurate and need no update.

## Outcome

Implemented exact active-assertion classification with per-PID priority `system > foreground > background` and a `nil` result for no valid assertions. Swift parsing and whitespace checks passed. The repository baseline build remains blocked before reaching this source because the existing macOS reorganization deleted `WindowIdentifying.swift` while CMake still references it; isolated typechecking is also blocked by the installed Swift compiler/SDK version mismatch.
