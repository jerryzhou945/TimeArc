# B — Cross-device sync design

## Goal

Design a mainland-China-first account and selective cross-device usage sync
system for shared desktop/Android apps, without changing the service database
contract.

## Service side / UI side

**Service side:** the native collector remains local-only and continues to write
`timearc_service.db`; it emits no network traffic and receives no account data.

**UI side:** the Qt app reads desktop history through the existing read-only
connection, aggregates allowlisted apps into daily rows, and owns auth, outbox,
pull cache, sync state, and cross-device presentation in `timearc.db`.

## What happened

Selected TimeArc Sync API on Tencent CloudBase Auth, CloudBase cloud hosting,
and CloudBase MySQL. Wrote the master application mapping, schema, protocol,
privacy, UI, testing, Git delivery, and Epic checklist documents. No product
code, database, frozen file, or external cloud resource was changed.

## Outcome

Design is awaiting user review. Implementation remains incomplete; after
approval, create one execution plan per Epic beginning with E0 delivery rules.
Future implementation is expected to touch rules 01, 03, 04, and 06 only where
the corresponding code or dependency changes require it.
