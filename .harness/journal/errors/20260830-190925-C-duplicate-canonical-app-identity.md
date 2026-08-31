# Error Report - duplicate-canonical-app-identity

## Metadata

- Level: **L2**
- Track: **C**
- Topic: duplicate-canonical-app-identity
- Recorded: 2026-08-30T19:09:25Z
- Session: `.harness/journal/sessions/20260830-1404-C-duplicate-canonical-app-identity.md`
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Persisted categorization variants with the same canonical ref resolve to different rule ids, so one installed app (WeChat and WeChatAppEx) appears twice and the helper row gets the wrong icon.

## 2. Evidence

The real service database contains both `Weixin.exe` and
`WeChatAppEx.exe`. The persisted `categorization` setting maps them to
`app:wechat` and `app:wechat@wechatappex`; the latter carries
`ref: app:wechat`. Both therefore inherit the same localized WeChat label,
while the matcher currently returns each concrete rule id as its identity.

## 3. Root cause

- Immediate cause: `Matcher::resolve()` returns `rule.id` as the grouping
  identity even when the stored rule is an automatically materialized variant
  with a canonical `rule.ref`.
- Underlying cause: `ref` was used only to restore presentation metadata, not
  as the canonical application identity contract.
- Why the harness/checklists did not prevent it: existing round-trip tests
  cover labels and categories but not two stored variants sharing one ref.

## 4. Fix

- Files changed: `src/services/categorization/matcher.h`,
  `tests/db_smoke.cpp`.
- Short description: keep the concrete rule id for editing and use an explicit
  WeChat alias policy for canonical grouping; broad defaults such as other
  browsers keep distinct materialized identities. The representative path
  policy then selects `Weixin.exe` instead of `WeChatAppEx.exe` for the native
  icon.
- Commit: pending commit.

## 5. Prevention

One-off, no harness change needed. The new matcher regression covers two
executable rules sharing one canonical ref.
