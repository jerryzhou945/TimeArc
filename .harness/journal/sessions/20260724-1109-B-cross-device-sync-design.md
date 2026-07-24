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

Design was approved. The E0 delivery-workflow plan is complete at
`docs/superpowers/plans/2026-07-24-cross-device-sync-e0-delivery-workflow.md`.
Implementation remains incomplete; Rule 08 has not yet been changed and E1-E9
have not started. Next: choose an execution mode and implement E0. Risks:
CloudBase production setup and app aliases still require external validation.
