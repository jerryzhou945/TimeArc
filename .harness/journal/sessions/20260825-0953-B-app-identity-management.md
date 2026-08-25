# Session Log — App identity management

## Metadata

- Agent / Author: Codex
- Track: **B (Feature)**
- Date: 2026-08-25
- Branch: `codex/stats-period-layout`

## Goal

Stabilize desktop statistics icons, force merged WeChat activity to use the
main executable's default icon, and add reversible custom application IDs.

## Service side

The service keeps writing raw executable identities exactly as it does today.
No sampler, database schema, or writer behavior changes.

## UI side

The UI stores a source-group-to-custom-ID map in its private settings database.
`UsageStatManager` applies it during read-only aggregation and selects a stable,
valid representative executable path for each effective group.

## Rules and plan

- Rules affected: `rules/01-architecture.md`, `rules/04-ui-conventions.md` are
  constraints only; no text change is expected unless implementation reveals
  a documented contract mismatch.
- No frozen file, schema, or C ABI change is planned.
- Design: `docs/superpowers/specs/2026-08-25-app-identity-icon-stability-design.md`.

## Outcome

Design approved in chat; implementation pending written-spec review.

- Completed: root-cause investigation and written design specification.
- Incomplete: implementation and runtime verification.
- Verification: spec placeholder/ambiguity scan and harness audit.
- Next: user reviews the written spec, then an implementation plan is written.
- Risks: custom aliases must never mutate the service-owned database.
